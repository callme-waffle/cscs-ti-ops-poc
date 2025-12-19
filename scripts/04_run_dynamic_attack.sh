#!/bin/bash

# =================================================================
# Project: TI-Ops Phase 4 (Dynamic Fetch from GitHub)
# Description: STIX T-ID -> Fetch YAML from GitHub -> Execute
# =================================================================

BASE_DIR="$HOME/project/ti-ops-project"
ORCH_DIR="$BASE_DIR/orchestrator"
VENV_DIR="$ORCH_DIR/venv"
PYTHON_BIN="$VENV_DIR/bin/python3"

cd "$BASE_DIR"

echo "🔵 [1/3] Track 3: Dynamic ART Fetcher 모듈 생성..."

# [핵심] GitHub에서 YAML을 파싱하는 똑똑한 모듈
cat <<EOF > "$ORCH_DIR/track3_dynamic.py"
import yaml
import requests
from kubernetes import client, config
import uuid

class Track3Dynamic:
    def __init__(self):
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.batch_api = client.BatchV1Api()
        
        # Atomic Red Team GitHub 주소 패턴
        self.base_url = "https://raw.githubusercontent.com/redcanaryco/atomic-red-team/master/atomics"

    def fetch_attack_command(self, t_id):
        """GitHub에서 T-ID에 해당하는 YAML을 다운로드하고 리눅스 명령어를 추출"""
        url = f"{self.base_url}/{t_id}/{t_id}.yaml"
        print(f"   📡 [GitHub] 공격 코드 다운로드 중... ({t_id})")
        
        try:
            response = requests.get(url)
            if response.status_code != 200:
                print(f"   ❌ GitHub에 해당 기술({t_id}) 파일이 없습니다.")
                return None
            
            data = yaml.safe_load(response.text)
            
            # YAML 안에 있는 여러 테스트 중 'linux' 플랫폼용 찾기
            for test in data.get('atomic_tests', []):
                if 'linux' in test.get('supported_platforms', []):
                    # 실행 명령어 추출 (executor -> command)
                    cmd = test['executor']['command']
                    
                    # (옵션) 불필요한 공백 제거 및 한 줄로 변환
                    clean_cmd = cmd.strip()
                    print(f"   ✅ [추출 완료] 공격명: {test['name']}")
                    return clean_cmd
            
            print("   ⚠️ 리눅스용 공격 코드가 없습니다.")
            return None

        except Exception as e:
            print(f"   ❌ 파싱 오류: {e}")
            return None

    def run_simulation(self, t_id):
        # 1. GitHub에서 명령어 가져오기 (동적)
        command_str = self.fetch_attack_command(t_id)
        
        if not command_str:
            return

        print(f"   ⚔️ [Track 3] 동적 생성된 공격 Job 실행: {t_id}")
        job_name = f"dyn-attack-{t_id.lower().replace('.', '-')}-{uuid.uuid4().hex[:6]}"
        
        # 2. 파드 생성 (추출한 명령어 주입)
        # 실제 환경에서는 의존성 문제로 실패할 수 있으므로, 쉘(sh)로 감싸서 실행
        final_cmd = ["/bin/sh", "-c", f"{command_str}"]

        job = client.V1Job(
            api_version="batch/v1",
            kind="Job",
            metadata=client.V1ObjectMeta(name=job_name),
            spec=client.V1JobSpec(
                template=client.V1PodTemplateSpec(
                    spec=client.V1PodSpec(
                        restart_policy="Never",
                        containers=[
                            client.V1Container(
                                name="attacker",
                                image="ubuntu:latest", # 다양한 명령 지원을 위해 ubuntu 사용
                                command=final_cmd,
                                # 의존성 설치가 필요한 경우를 대비해 업데이트 먼저 수행
                                args=[], 
                            )
                        ]
                    )
                ),
                ttl_seconds_after_finished=300
            )
        )

        try:
            self.batch_api.create_namespaced_job("default", job)
            print(f"   🚀 Job 생성됨: {job_name}")
        except Exception as e:
            print(f"   ❌ Job 생성 실패: {e}")
EOF

echo "🔵 [2/3] Orchestrator: 동적 테스트 시나리오..."

cat <<EOF > "$ORCH_DIR/orchestrator_dynamic.py"
import time
from track3_dynamic import Track3Dynamic

def run():
    print("\n🚀 [Dynamic] GitHub 연동 공격 자동화 테스트\n")
    art = Track3Dynamic()
    
    # 테스트할 T-ID 목록 (실제 Atomic Red Team에 존재하는 ID)
    # T1059.001: PowerShell (리눅스용 pwsh 테스트가 있는지 확인됨) -> 리눅스용 대체: T1033
    # T1033: System Owner/User Discovery (whoami 실행)
    # T1083: File and Directory Discovery (ls 실행)
    scenarios = ["T1033", "T1083"] 

    for t_id in scenarios:
        print(f"-"*50)
        print(f"📥 위협 인텔리전스 수신: {t_id}")
        art.run_simulation(t_id)
        time.sleep(2)

if __name__ == "__main__":
    run()
EOF

echo "🔵 [3/3] 실행 및 결과 확인..."
"$PYTHON_BIN" "$ORCH_DIR/orchestrator_dynamic.py"

echo -e "\n🔎 [결과] 생성된 Job 확인:"
kubectl get jobs --sort-by=.metadata.creationTimestamp
