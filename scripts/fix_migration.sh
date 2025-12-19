#!/bin/bash

# =================================================================
# Project: Directory Migration Fixer
# From: ~/ti-ops-project -> To: ~/project
# =================================================================

set -e

# 현재 디렉토리를 기준으로 설정
CURRENT_DIR=$(pwd)
echo "📂 현재 프로젝트 위치: $CURRENT_DIR"

# 1. 깨진 가상환경(venv) 복구
echo "🧹 [1/3] 깨진 가상환경 삭제 및 재생성 중..."
rm -rf orchestrator/venv venv  # 기존 venv 삭제
python3 -m venv orchestrator/venv # orchestrator 폴더 안에 venv 생성 (구조 유지)

# 2. 필수 패키지 재설치
echo "📦 [2/3] 라이브러리 재설치 중..."
source orchestrator/venv/bin/activate
pip install --upgrade pip
# 지금까지 사용한 모든 라이브러리 설치
pip install stix2 taxii2-client kubernetes gitpython pyyaml requests

# 3. 코드 내 경로 수정 (ti-ops-project -> project)
echo "✍️ [3/3] 파이썬 코드 내 하드코딩된 경로 수정 중..."

# track2_gitops.py 파일이 있는지 확인 후 수정
GITOPS_FILE="orchestrator/track2_gitops.py"
if [ -f "$GITOPS_FILE" ]; then
    # sed 명령어로 경로 문자열 치환
    sed -i 's|ti-ops-project|project|g' $GITOPS_FILE
    echo "   ✅ $GITOPS_FILE 경로 수정 완료"
else
    echo "   ⚠️ $GITOPS_FILE 파일을 찾을 수 없습니다. 경로를 확인하세요."
fi

# 4. 정책 저장소(Policy Repo) 경로 재설정
POLICY_REPO="$HOME/project/policy-repo"
if [ ! -d "$POLICY_REPO" ]; then
    echo "   ⚠️ 정책 저장소($POLICY_REPO)가 없습니다. 새로 생성합니다."
    mkdir -p $POLICY_REPO
    cd $POLICY_REPO
    git init
    git config user.name "TI-Ops Bot"
    git config user.email "bot@project.local"
    # 기본 deny-list.yaml 생성
    cat <<EOF > deny-list.yaml
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
    git add deny-list.yaml
    git commit -m "Initial commit after migration"
    cd $CURRENT_DIR
fi

echo "===================================================="
echo "✅ 복구 완료! 이제 아래 명령어로 실행해보세요."
echo "source orchestrator/venv/bin/activate"
echo "python3 orchestrator/orchestrator.py"
echo "===================================================="
