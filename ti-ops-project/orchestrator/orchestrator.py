import json
import os
import uuid
from taxii2client.v21 import Server
from stix2 import TAXIICollectionSource, parse
# 방금 만든 스캐너 모듈 임포트
from track1_scanner import Track1Scanner 

class TIOrchestrator:
    def __init__(self):
        self.server_url = "https://limo.anomali.com/taxii"
        self.local_mock_path = "mock_stix_data.json"
        self.vuln_scanner = Track1Scanner() # 스캐너 초기화

    def fetch_threats(self):
        # 네트워크 연결 실패 시 로컬 모드로 전환
        try:
            server = Server(self.server_url)
            # 연결 테스트용
            server.api_roots[0] 
            print("📡 온라인 데이터 수집 중...")
        except:
            print("⚠️  온라인 수집 실패 -> 로컬 시뮬레이션 모드 가동")
            return self._load_mock_data()

    def _load_mock_data(self):
        # Nginx 1.14.2에 실제 존재하는 CVE-2018-16843 포함
        mock_data = {
            "type": "bundle",
            "id": f"bundle--{uuid.uuid4()}",
            "spec_version": "2.1",
            "objects": [
                {
                    "type": "vulnerability",
                    "id": f"vulnerability--{uuid.uuid4()}",
                    "spec_version": "2.1",
                    "name": "CVE-2020-27350",
                    "external_references": [{"source_name": "cve", "external_id": "CVE-2020-27350"}]
                }
            ]
        }
        # 파일 저장 후 파싱해서 리턴
        with open(self.local_mock_path, "w") as f:
            json.dump(mock_data, f)
        
        with open(self.local_mock_path, "r") as f:
            return parse(f.read(), allow_custom=True).objects

    def process_intelligence(self):
        objects = self.fetch_threats()
        
        for obj in objects:
            if obj.type == 'vulnerability':
                # CVE ID 추출
                cve_id = obj.external_references[0].external_id
                print(f"\n[Orchestrator] 📥 새로운 위협 정보 수신: {cve_id}")
                
                # Track 1 스캐너 가동!
                self.vuln_scanner.scan_cve(cve_id)

if __name__ == "__main__":
    app = TIOrchestrator()
    app.process_intelligence()
