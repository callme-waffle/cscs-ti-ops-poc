import os
import yaml
from git import Repo

class Track2GitOps:
    def __init__(self):
        # 스크립트가 실행되는 BASE_DIR 기준
        self.repo_path = "/home/waffle/project/ti-ops-project"
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
