#!/bin/bash

# =================================================================
# Project: TI-Ops Phase 3 Standalone (GitOps Only)
# Target: Track 2 (IP Blocking -> Git Commit)
# =================================================================

# 1. 작업 디렉토리 설정
BASE_DIR="$HOME/project/ti-ops-project"
ORCH_DIR="$BASE_DIR/orchestrator"
POLICY_DIR="$BASE_DIR/manifests/security"
mkdir -p "$ORCH_DIR" "$POLICY_DIR"
cd "$BASE_DIR"

echo "🔵 [1/4] GitOps 환경(정책 저장소) 초기화..."

# Git 저장소 초기화 (없으면 생성)
if [ ! -d ".git" ]; then
    git init
    git config user.name "TI-Ops Bot"
    git config user.email "bot@ti-ops.local"
fi

# 차단 정책(NetworkPolicy) 초기화 (깨끗한 상태로 시작)
cat <<EOF > "$POLICY_DIR/deny-list.yaml"
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: threat-intel-deny-list
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except: []
EOF

# 초기 상태 커밋
git add "$POLICY_DIR/deny-list.yaml"
git commit -m "Reset policy for Phase 3 test" > /dev/null 2>&1 || true
echo "   ✅ deny-list.yaml 초기화 완료"

# 2. Python 환경 준비
echo "🔵 [2/4] Python 라이브러리 확인..."
if [ ! -d "$ORCH_DIR/venv" ]; then
    python3 -m venv "$ORCH_DIR/venv"
fi
source "$ORCH_DIR/venv/bin/activate"
pip install pyyaml gitpython stix2 taxii2-client > /dev/null 2>&1

# 3. Phase 3 전용 파이썬 코드 생성
echo "🔵 [3/4] 코드 생성 (Track 2 GitOps & Test Orchestrator)..."

# [코드 1] GitOps 핸들러 (track2_gitops.py)
cat <<EOF > "$ORCH_DIR/track2_gitops.py"
import os
import yaml
from git import Repo

class Track2GitOps:
    def __init__(self):
        # 스크립트가 실행되는 BASE_DIR 기준
        self.repo_path = "$BASE_DIR"
        self.file_path = os.path.join(self.repo_path, "manifests/security/deny-list.yaml")

    def update_policy(self, ip):
        print(f"🛡️ [Track 2] 정책 업데이트 요청: {ip}")
        
        # 1. YAML 읽기
        with open(self.file_path, 'r') as f:
            data = yaml.safe_load(f)

        # 2. 구조 탐색 및 IP 추가
        try:
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']
        except (KeyError, TypeError):
             # 구조가 없으면 생성
            data['spec']['egress'][0]['to'][0]['ipBlock']['except'] = []
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']

        cidr = f"{ip}/32"
        if cidr not in target_list:
            target_list.append(cidr)
            
            # 3. 파일 저장
            with open(self.file_path, 'w') as f:
                yaml.dump(data, f, default_flow_style=False)
            print(f"   📝 YAML 수정 완료: {cidr} 추가됨")

            # 4. Git Commit
            self._commit(cidr)
        else:
            print(f"   ⚠️ 이미 차단된 IP입니다.")

    def _commit(self, ip):
        try:
            repo = Repo(self.repo_path)
            repo.index.add([self.file_path])
            repo.index.commit(f"Block Malicious IP {ip}")
            print(f"   ✅ Git Commit 완료!")
        except Exception as e:
            print(f"   ❌ Git Error: {e}")
EOF

# [코드 2] Phase 3 테스트용 오케스트레이터 (orchestrator_phase3.py)
# 복잡한 로직 없이 오직 'IP 위협' 하나만 생성해서 Track 2로 보냄
cat <<EOF > "$ORCH_DIR/orchestrator_phase3.py"
import uuid
from track2_gitops import Track2GitOps

def run_phase3_test():
    print("🚀 [Test] Phase 3: 악성 IP 차단 자동화 테스트 시작\n")
    
    # 1. 가상의 악성 IP 생성 (Simulated STIX Indicator)
    malicious_ip = "192.168.77.88" 
    print(f"[Orchestrator] 📥 위협 정보 수신: 악성 IP '{malicious_ip}'")

    # 2. Track 2 핸들러 호출
    handler = Track2GitOps()
    handler.update_policy(malicious_ip)

if __name__ == "__main__":
    run_phase3_test()
EOF

# 4. 실행 및 검증
echo "🔵 [4/4] 테스트 실행..."
python3 "$ORCH_DIR/orchestrator_phase3.py"

echo -e "\n🔎 [검증 결과]"
echo "1. Git 로그 확인 (최신 커밋):"
git log --oneline -n 1
echo ""
echo "2. 파일 내용 확인 (IP 추가 여부):"
grep "192.168.77.88" "$POLICY_DIR/deny-list.yaml"

if grep -q "192.168.77.88" "$POLICY_DIR/deny-list.yaml"; then
    echo -e "\n✅ Phase 3 테스트 성공! (IP가 YAML에 추가되고 커밋되었습니다)"
else
    echo -e "\n❌ 실패: IP가 파일에서 발견되지 않았습니다."
fi
