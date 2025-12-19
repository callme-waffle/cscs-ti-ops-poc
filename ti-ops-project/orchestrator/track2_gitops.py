import os
import yaml
from git import Repo

class Track2GitOps:
    def __init__(self):
        self.repo_path = "/home/waffle/project"
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
