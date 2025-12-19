#!/bin/bash

# =================================================================
# Project: TI-Ops Final Pipeline Setup
# Path: ~/project/scripts/create_final_pipeline.sh
# Description: Automate K8s setup for Event-Driven Security Ops
# =================================================================

# 1. 환경 변수 및 디렉토리 설정
BASE_DIR="$HOME/project"
K8S_DIR="$BASE_DIR/k8s"
ORCH_DIR="$BASE_DIR/ti-ops-project/orchestrator"
SCRIPTS_DIR="$BASE_DIR/scripts"

mkdir -p "$K8S_DIR"
mkdir -p "$SCRIPTS_DIR"

echo "🔵 [1/5] Orchestrator 코드 고도화 (이벤트 기반 분기 처리)..."

# orchestrator.py를 모드별 실행이 가능하도록 수정
cat <<EOF > "$ORCH_DIR/orchestrator.py"
import sys
import os
import time
from track1_scanner import Track1Scanner
from track2_gitops import Track2GitOps
from track3_dynamic import Track3Dynamic

def run_deploy_event():
    """ [Mode 1] 배포 이벤트 발생 시 -> Track 1 (취약점 스캔)만 실행 """
    print("\n🚀 [Event: Deployment] 배포 감지 -> Track 1 실행")
    t1 = Track1Scanner()
    # 실제로는 Trivy 리포트 전체를 조회하거나, 특정 배포 건을 조회
    # 데모를 위해 특정 CVE를 타겟팅
    target_cve = "CVE-2020-27350"
    print(f"   🎯 타겟 CVE 스캔: {target_cve}")
    t1.scan_cve(target_cve)

def run_stix_event():
    """ [Mode 2] 주기적/STIX 이벤트 발생 시 -> Track 2 (IP 차단) & Track 3 (공격 시뮬레이션) """
    print("\n🚀 [Event: Threat Intel] 주기적 감시 -> Track 2 & 3 실행")
    
    # 1. Track 2: GitOps (IP 차단)
    # K8s 내부에서는 환경변수로 주입된 경로 사용, 없으면 로컬 기본값
    repo_path = os.getenv("REPO_PATH", "$BASE_DIR")
    t2 = Track2GitOps() 
    # Track2GitOps 내부에서 repo_path를 유연하게 처리하도록 수정 필요하지만
    # 데모를 위해 기존 로직 활용 (환경변수 주입 예정)
    
    malicious_ip = "1.2.3.4"
    print(f"   🛡️ [Track 2] 악성 IP 처리: {malicious_ip}")
    t2.update_policy(malicious_ip)

    # 2. Track 3: Attack Simulation
    t3 = Track3Dynamic()
    attack_id = "T1033" # System Owner/User Discovery
    print(f"   ⚔️ [Track 3] 공격 시뮬레이션: {attack_id}")
    t3.run_simulation(attack_id)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "help"
    
    if mode == "deploy":
        run_deploy_event()
    elif mode == "cron":
        run_stix_event()
    else:
        print("Usage: python orchestrator.py [deploy|cron]")
EOF

# Track 2 GitOps 경로 호환성 수정 (K8s Volume Mount 대응)
# 기존 Track2GitOps 코드를 살짝 수정하여 REPO_PATH 환경변수를 우선하도록 함
sed -i 's|self.repo_path = os.path.expanduser("~/project")|self.repo_path = os.getenv("REPO_PATH", os.path.expanduser("~/project"))|g' "$ORCH_DIR/track2_gitops.py"


echo "🔵 [2/5] Docker 이미지 빌드 준비..."

# Dockerfile 생성
cat <<EOF > "$BASE_DIR/Dockerfile"
FROM python:3.11-slim

WORKDIR /app

# 시스템 패키지 설치 (Git 필수)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 라이브러리 설치
RUN pip install --no-cache-dir kubernetes stix2 taxii2-client gitpython pyyaml requests

# 소스코드 복사 (orchestrator 폴더 내용물을 /app으로)
COPY ti-ops-project/orchestrator/ .

# 실행 권한
RUN chmod +x orchestrator.py

# 기본 엔트리포인트 없음 (Command로 제어)
EOF

echo "🔵 [3/5] Docker 이미지 빌드 및 Kind 클러스터 로드..."
cd "$BASE_DIR"
# 이미지 빌드
docker build -t ti-ops-orchestrator:latest .

# Kind 클러스터에 이미지 로드 (이 과정이 없으면 ImagePullErr 발생)
# 클러스터 이름이 ti-ops-cluster라고 가정 (다르면 수정 필요)
if kind get clusters | grep -q "ti-ops-cluster"; then
    echo "   📦 Kind 클러스터(ti-ops-cluster)에 이미지 로드 중..."
    kind load docker-image ti-ops-orchestrator:latest --name ti-ops-cluster
else
    echo "   ⚠️ Kind 클러스터를 찾을 수 없습니다. 이미지 로드 스킵."
fi


echo "🔵 [4/5] Kubernetes 매니페스트 생성 (RBAC, CronJob, Job)..."

# 1. RBAC (권한 설정)
cat <<EOF > "$K8S_DIR/01-rbac.yaml"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ti-ops-sa
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ti-ops-role
rules:
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["create", "get", "list", "delete"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies"]
  verbs: ["get", "update", "patch"]
- apiGroups: ["aquasecurity.github.io"]
  resources: ["vulnerabilityreports"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ti-ops-binding
subjects:
- kind: ServiceAccount
  name: ti-ops-sa
  namespace: default
roleRef:
  kind: ClusterRole
  name: ti-ops-role
  apiGroup: rbac.authorization.k8s.io
EOF

# 2. CronJob (Track 2 & 3 - 주기적 실행)
# 주의: GitOps가 동작하려면 실제 Git Repo가 있는 호스트 경로를 마운트해야 함
# Kind 환경이므로 hostPath 마운트 사용 (실 운영에선 PVC 또는 Git Clone 방식 사용)
cat <<EOF > "$K8S_DIR/02-cronjob-stix.yaml"
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ti-ops-stix-watcher
spec:
  schedule: "*/5 * * * *" # 5분마다 실행
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: ti-ops-sa
          containers:
          - name: orchestrator
            image: ti-ops-orchestrator:latest
            imagePullPolicy: Never # Kind 로드 이미지 사용
            command: ["python3", "orchestrator.py", "cron"]
            env:
            - name: REPO_PATH
              value: "/project" # 컨테이너 내부 경로
            volumeMounts:
            - name: git-repo
              mountPath: /project
          restartPolicy: OnFailure
          volumes:
          - name: git-repo
            hostPath:
              path: $HOME/project # 호스트의 실제 프로젝트 경로
              type: Directory
EOF

# 3. Hook Job (Track 1 - 배포 시 실행)
# ArgoCD가 있다고 가정하고 Hook Annotation 추가
cat <<EOF > "$K8S_DIR/03-hook-deploy-scan.yaml"
apiVersion: batch/v1
kind: Job
metadata:
  name: ti-ops-deploy-scanner
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      serviceAccountName: ti-ops-sa
      containers:
      - name: scanner
        image: ti-ops-orchestrator:latest
        imagePullPolicy: Never
        command: ["python3", "orchestrator.py", "deploy"]
      restartPolicy: Never
EOF

echo "🔵 [5/5] 매니페스트 적용..."
kubectl apply -f "$K8S_DIR/"

echo -e "\n✅ 모든 설정이 완료되었습니다!"
echo "---------------------------------------------------------"
echo "📂 생성된 파일 위치: ~/project/k8s/"
echo "1. CronJob 확인: kubectl get cronjob"
echo "2. 수동 테스트(Deploy): kubectl create job --from=cronjob/ti-ops-stix-watcher manual-stix-test"
echo "---------------------------------------------------------"
