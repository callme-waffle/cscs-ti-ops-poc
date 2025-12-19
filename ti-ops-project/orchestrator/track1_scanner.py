from kubernetes import client, config

class Track1Scanner:
    def __init__(self):
        # 로컬(Ubuntu)에서 실행 중이므로 ~/.kube/config를 사용해 클러스터 접속
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.custom_api = client.CustomObjectsApi()

    def scan_cve(self, target_cve):
        print(f"🔍 [Track 1] 클러스터 전체에서 '{target_cve}' 검색 중...")
        
        # Trivy가 만든 리포트(VulnerabilityReport)들을 모두 가져옵니다
        reports = self.custom_api.list_cluster_custom_object(
            group="aquasecurity.github.io",
            version="v1alpha1",
            plural="vulnerabilityreports"
        )

        detected = False
        for report in reports.get('items', []):
            # 리포트 안의 취약점 목록 확인
            vulns = report.get('report', {}).get('vulnerabilities', [])
            
            for v in vulns:
                if v.get('vulnerabilityID') == target_cve:
                    # 메타데이터 추출
                    namespace = report['metadata']['namespace']
                    kind = report['metadata']['labels'].get('trivy-operator.resource.kind')
                    name = report['metadata']['labels'].get('trivy-operator.resource.name')
                    
                    print(f"🚨 [경고] 취약한 리소스 발견!")
                    print(f"   • 대상: {namespace} / {kind} / {name}")
                    print(f"   • CVE: {target_cve} (심각도: {v.get('severity')})")
                    print(f"   • 해결버전: {v.get('fixedVersion', '없음')}")
                    print("-" * 30)
                    detected = True
        
        if not detected:
            print(f"✅ 클러스터는 '{target_cve}'로부터 안전합니다.")
