#!/bin/bash

# =================================================================
# Project: TI-Ops Phase 4 Fixer
# Description: Force install dependencies to correct venv and run
# =================================================================

# 1. 경로 명시적 설정
BASE_DIR="$HOME/project/ti-ops-project"
ORCH_DIR="$BASE_DIR/orchestrator"
VENV_DIR="$ORCH_DIR/venv"
PYTHON_BIN="$VENV_DIR/bin/python3"
PIP_BIN="$VENV_DIR/bin/pip"

cd "$BASE_DIR"

echo "🔵 [1/4] 가상환경(venv) 점검 및 복구..."

# 가상환경이 없으면 생성, 있어도 깨졌을 수 있으므로 확인
if [ ! -f "$PYTHON_BIN" ]; then
    echo "   ⚠️ 가상환경이 없거나 손상되었습니다. 재생성합니다..."
    rm -rf "$VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

echo "🔵 [2/4] 라이브러리 강제 재설치 (Target: $VENV_DIR)..."
# 중요: 스크립트 내에서 pip를 직접 호출하여 확실하게 설치
"$PIP_BIN" install --upgrade pip > /dev/null 2>&1
"$PIP_BIN" install kubernetes stix2 taxii2-client gitpython pyyaml requests

echo "🔵 [3/4] Python 모듈 코드 재생성 (Track 1, 2, 3)..."

# Track 1 Scanner
cat <<EOF > "$ORCH_DIR/track1_scanner.py"
from kubernetes import client, config

class Track1Scanner:
    def __init__(self):
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.custom_api = client.CustomObjectsApi()

    def scan_cve(self, target_cve):
        print(f"   🔎 [Track 1] CVE 스캔: {target_cve}")
        try:
            reports = self.custom_api.list_cluster_custom_object(
                group="aquasecurity.github.io",
                version="v1alpha1",
                plural="vulnerabilityreports"
            )
            found = False
            for report in reports.get('items', []):
                vulns = report.get('report', {}).get('vulnerabilities', [])
                for v in vulns:
                    if v.get('vulnerabilityID') == target_cve:
                        print(f"   🚨 발견됨! 리소스: {report['metadata']['name']}")
                        found = True
            if not found:
                print(f"   ✅ 클러스터 안전함.")
        except Exception as e:
            print(f"   ⚠️ K8s API 접근 실패 (Trivy 미설치 등): {e}")
EOF

# Track 2 GitOps
cat <<EOF > "$ORCH_DIR/track2_gitops.py"
import os
import yaml
from git import Repo

class Track2GitOps:
    def __init__(self):
        self.repo_path = "$HOME/project"
        self.file_path = os.path.join(self.repo_path, "ti-ops-project/manifests/security/deny-list.yaml")

    def update_policy(self, ip):
        print(f"   🛡️ [Track 2] 정책 업데이트: {ip}")
        if not os.path.exists(self.file_path):
            print("   ⚠️ 파일 없음 (Skip)")
            return

        with open(self.file_path, 'r') as f:
            data = yaml.safe_load(f)
        
        try:
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']
        except:
            data['spec']['egress'][0]['to'][0]['ipBlock']['except'] = []
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']
            
        cidr = f"{ip}/32"
        if cidr not in target_list:
            target_list.append(cidr)
            with open(self.file_path, 'w') as f:
                yaml.dump(data, f, default_flow_style=False)
            
            try:
                repo = Repo(self.repo_path)
                repo.index.add(["ti-ops-project/manifests/security/deny-list.yaml"])
                repo.index.commit(f"Block {ip}")
                print(f"   ✅ Git Commit 완료")
            except Exception as e:
                print(f"   ⚠️ Git Commit 실패: {e}")
EOF

# Track 3 ART (Attack Simulation)
cat <<EOF > "$ORCH_DIR/track3_art.py"
from kubernetes import client, config
import uuid

class Track3ART:
    def __init__(self):
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.batch_api = client.BatchV1Api()

    def run_simulation(self, t_id):
        print(f"   ⚔️ [Track 3] 공격 시뮬레이션 Job 생성: {t_id}")
        job_name = f"art-sim-{t_id.lower()}-{uuid.uuid4().hex[:6]}"
        
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
                                name="art",
                                image="alpine",
                                command=["/bin/sh", "-c"],
                                args=[f"echo '🔥 Simulating {t_id}...'; sleep 2; echo '✅ Done'"]
                            )
                        ]
                    )
                ),
                ttl_seconds_after_finished=60
            )
        )
        try:
            self.batch_api.create_namespaced_job("default", job)
            print(f"   🚀 Job 실행됨: {job_name}")
        except Exception as e:
            print(f"   ❌ Job 생성 실패: {e}")
EOF

# Orchestrator Main
cat <<EOF > "$ORCH_DIR/orchestrator.py"
import json
import uuid
from track1_scanner import Track1Scanner
from track2_gitops import Track2GitOps
from track3_art import Track3ART

def run():
    print("\n🚀 [Final] TI-Ops 통합 파이프라인 가동")
    t1 = Track1Scanner()
    t2 = Track2GitOps()
    t3 = Track3ART()
    
    # 시나리오 데이터
    threats = [
        ('vulnerability', 'CVE-2020-27350'),
        ('indicator', '1.2.3.4'),
        ('attack-pattern', 'T1105') # Ingress Tool Transfer
    ]
    
    for type, val in threats:
        print("-" * 40)
        if type == 'vulnerability':
            print(f"📥 위협 감지: {val} (CVE)")
            t1.scan_cve(val)
        elif type == 'indicator':
            print(f"📥 위협 감지: {val} (IP)")
            t2.update_policy(val)
        elif type == 'attack-pattern':
            print(f"📥 위협 감지: {val} (Attack Pattern)")
            t3.run_simulation(val)

if __name__ == "__main__":
    run()
EOF

echo "🔵 [4/4] 통합 테스트 실행 (Using: $PYTHON_BIN)..."
# 중요: 가상환경의 python3를 명시적으로 호출
"$PYTHON_BIN" "$ORCH_DIR/orchestrator.py"

echo -e "\n🔎 [결과 확인] 생성된 K8s Job 목록:"
kubectl get jobs
