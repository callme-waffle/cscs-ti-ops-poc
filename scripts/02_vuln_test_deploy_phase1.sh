# 1. 취약한 Nginx 배포 (테스트용)
kubectl create deployment vulnerable-nginx --image=nginx:1.14.2

# 2. 배포 확인 (Running 상태가 될 때까지 대기)
kubectl get pods

# 3. Trivy가 리포트를 생성했는지 확인 (약 1~2분 소요)
# 생성되면 vulnerable-nginx-xxx 형태의 리포트가 조회됩니다.
kubectl get vulnerabilityreports -A
