#!/bin/bash

# =================================================================
# Project: TI-Ops Phase 3 (Fixed Git Structure)
# Git Root: ~/project
# Working Dir: ~/project/ti-ops-project
# =================================================================

# 1. 경로 설정
GIT_ROOT="$HOME/project"
WORK_DIR="$GIT_ROOT/ti-ops-project"
ORCH_DIR="$WORK_DIR/orchestrator"
POLICY_DIR="$WORK_DIR/manifests/security"

mkdir -p "$ORCH_DIR" "$POLICY_DIR"
cd "$WORK_DIR"

echo "🔵 [1/4] 정책 파일(YAML) 초기화..."

# 차단 정책(NetworkPolicy) 생성
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

# Git에 정책 파일 반영 (상위 Git Root 사용)
cd "$GIT_ROOT"
git add "$POLICY_DIR/deny-list.yaml"
git commit -m "Reset policy for Phase 3 test" > /dev/null 2>&1 || true
cd "$WORK_DIR"
echo "   ✅ deny-list.yaml 초기화 및 Git 등록 완료"

# 2. Python 라이브러리 확인
echo "🔵 [2/4] Python 라이브러리 준비..."
if [ ! -d "$ORCH_DIR/venv" ]; then
    python3 -m venv "$ORCH_DIR/venv"
fi
source "$ORCH_DIR/venv/bin/activate"
pip install pyyaml gitpython stix2 taxii2-client > /dev/null 2>&1

# 3. 파이썬 코드 생성 (경로 수정 적용)
echo "🔵 [3/4] GitOps 핸들러 코드 생성..."

# [코드 1] GitOps 핸들러 (track2_gitops.py)
# 핵심 변경: repo_path는 ~/project, 파일 경로는 ti-ops-project/...
cat <<EOF > "$ORCH_DIR/track2_gitops.py"
import os
import yaml
from git import Repo

class Track2GitOps:
    def __init__(self):
        # 1. Git Root는 '~/project' 입니다.
        self.repo_path = os.path.expanduser("~/project")
        
        # 2. Git Root 기준, YAML 파일의 상대 경로
        self.file_rel_path = "ti-ops-project/manifests/security/deny-list.yaml"
        self.file_full_path = os.path.join(self.repo_path, self.file_rel_path)

    def update_policy(self, ip):
        print(f"🛡️ [Track 2] 정책 업데이트 요청: {ip}")
        
        if not os.path.exists(self.file_full_path):
            print(f"   ❌ 파일 없음: {self.file_full_path}")
            return

        # YAML 읽기 및 수정
        with open(self.file_full_path, 'r') as f:
            data = yaml.safe_load(f)

        try:
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']
        except (KeyError, TypeError):
            data['spec']['egress'][0]['to'][0]['ipBlock']['except'] = []
            target_list = data['spec']['egress'][0]['to'][0]['ipBlock']['except']

        cidr = f"{ip}/32"
        if cidr not in target_list:
            target_list.append(cidr)
            
            with open(self.file_full_path, 'w') as f:
                yaml.dump(data, f, default_flow_style=False)
            print(f"   📝 YAML 수정 완료: {cidr}")

            # Git Commit 호출
            self._commit(cidr)
        else:
            print(f"   ⚠️ 이미 차단된 IP입니다.")

    def _commit(self, ip):
        try:
            # 상위 Git 저장소 로드
            repo = Repo(self.repo_path)
            
            # 변경된 파일 추가 (Git Root 기준 상대 경로 사용 권장)
            repo.index.add([self.file_rel_path])
            
            repo.index.commit(f"Block Malicious IP {ip}")
            print(f"   ✅ Git Commit 완료! (Repo: {self.repo_path})")
        except Exception as e:
            print(f"   ❌ Git Error: {e}")
EOF

# [코드 2] 테스트 실행기
cat <<EOF > "$ORCH_DIR/orchestrator_phase3.py"
from track2_gitops import Track2GitOps

def run_phase3_test():
    print("🚀 [Test] Phase 3: 악성 IP 차단 (수정된 Git 구조)\n")
    
    # 테스트용 악성 IP
    malicious_ip = "203.0.113.99" 
    print(f"[Orchestrator] 📥 위협 감지: {malicious_ip}")

    handler = Track2GitOps()
    handler.update_policy(malicious_ip)

if __name__ == "__main__":
    run_phase3_test()
EOF

# 4. 실행 및 검증
echo "🔵 [4/4] 테스트 실행..."
python3 "$ORCH_DIR/orchestrator_phase3.py"

echo -e "\n🔎 [검증 결과]"
# Git 로그는 상위 폴더에서 확인
cd "$GIT_ROOT"
echo "1. Git 로그 확인 (최신 커밋):"
git log --oneline -n 1
echo ""
echo "2. 파일 내용 확인:"
grep "203.0.113.99" "$POLICY_DIR/deny-list.yaml"

if grep -q "203.0.113.99" "$POLICY_DIR/deny-list.yaml"; then
    echo -e "\n✅ Phase 3 테스트 성공! (단일 Git 구조 적용됨)"
else
    echo -e "\n❌ 실패: IP가 반영되지 않았습니다."
fi
