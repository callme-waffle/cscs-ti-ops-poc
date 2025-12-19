from track2_gitops import Track2GitOps

def run_phase3_test():
    print("🚀 [Test] Phase 3: 악성 IP 차단 (수정된 Git 구조)\n")
    
    # 테스트용 악성 IP
    malicious_ip = "203.0.113.99" 
    print(f"[Orchestrator] 📥 위협 감지: {malicious_ip}")

    handler = Track2GitOps()
    handler.update_policy(malicious_ip)

if __name__ == "__main__":
    run_phase3_test()
