#!/bin/bash

# =================================================================
# Project: TI-Ops Infrastructure Setup (Phase 0)
# Target OS: Ubuntu 24.04.3 LTS
# Description: Install Docker, Kind, Kubectl, Helm, ArgoCD, Trivy
# =================================================================

set -e # 오류 발생 시 스크립트 중단

echo "🚀 [1/7] 패키지 업데이트 및 필수 도구 설치..."
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg git python3-pip

# 1. Docker 설치
echo "🐳 [2/7] Docker Engine 설치 중..."
if ! command -v docker &> /dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER
    echo "✔️ Docker 설치 완료 (재로그인 후 권한 적용됨)"
fi

# 2. Kind (Kubernetes in Docker) 설치
echo "☸️ [3/7] Kind 설치 중..."
if ! command -v kind &> /dev/null; then
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
fi

# 3. Kubectl 설치
echo "☸️ [4/7] Kubectl 설치 중..."
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
fi

# 4. Helm 설치
echo "⛵ [5/7] Helm 설치 중..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# 5. Kind 클러스터 생성
echo "🏗️ [6/7] Kind 클러스터 'ti-ops-cluster' 생성 중..."
if ! kind get clusters | grep -q "ti-ops-cluster"; then
    kind create cluster --name ti-ops-cluster
else
    echo "이미 클러스터가 존재합니다."
fi

# 6. 보안 컴포넌트 배포 (ArgoCD, Trivy, RBAC)
echo "🛡️ [7/7] 보안 컴포넌트 배포 시작..."

# ArgoCD
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Trivy Operator
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
helm install trivy-operator aqua/trivy-operator --namespace trivy-system --create-namespace || true

# Orchestrator RBAC 적용
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ti-ops-orchestrator
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ti-ops-orchestrator-role
rules:
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "create", "delete"]
  - apiGroups: ["aquasecurity.github.io"]
    resources: ["vulnerabilityreports"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods", "namespaces"]
    verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ti-ops-orchestrator-binding
subjects:
  - kind: ServiceAccount
    name: ti-ops-orchestrator
    namespace: default
roleRef:
  kind: ClusterRole
  name: ti-ops-orchestrator-role
  api_group: rbac.authorization.k8s.io
EOF

echo "===================================================="
echo "✅ 인프라 구축 완료!"
echo "1. ArgoCD Password 확인: "
echo "   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo "2. ArgoCD 접속 (Port-forward 필요):"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "===================================================="
