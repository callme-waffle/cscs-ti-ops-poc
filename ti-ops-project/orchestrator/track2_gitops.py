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
