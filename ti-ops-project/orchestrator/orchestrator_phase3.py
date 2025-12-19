import uuid
from track2_gitops import Track2GitOps

def run_phase3_test():
    print("🚀 [Test] Phase 3: 악성 IP 차단 자동화 테스트 시작\n")
    
    # 1. 가상의 악성 IP 생성 (Simulated STIX Indicator)
    malicious_ip = "192.168.77.88" 
    print(f"[Orchestrator] 📥 위협 정보 수신: 악성 IP '{malicious_ip}'")

    # 2. Track 2 핸들러 호출
    handler = Track2GitOps()
    handler.update_policy(malicious_ip)

if __name__ == "__main__":
    run_phase3_test()
