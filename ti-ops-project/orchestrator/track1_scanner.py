from kubernetes import client, config

class Track1Scanner:
    def __init__(self):
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.custom_api = client.CustomObjectsApi()

    def scan_cve(self, target_cve):
        print(f"   🔎 [Track 1] CVE 스캔: {target_cve}")
        try:
            reports = self.custom_api.list_cluster_custom_object(
                group="aquasecurity.github.io",
                version="v1alpha1",
                plural="vulnerabilityreports"
            )
            found = False
            for report in reports.get('items', []):
                vulns = report.get('report', {}).get('vulnerabilities', [])
                for v in vulns:
                    if v.get('vulnerabilityID') == target_cve:
                        print(f"   🚨 발견됨! 리소스: {report['metadata']['name']}")
                        found = True
            if not found:
                print(f"   ✅ 클러스터 안전함.")
        except Exception as e:
            print(f"   ⚠️ K8s API 접근 실패 (Trivy 미설치 등): {e}")
