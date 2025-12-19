import sys
import os
import time
from track1_scanner import Track1Scanner
from track2_gitops import Track2GitOps
from track3_dynamic import Track3Dynamic

def run_deploy_event():
    """ [Mode 1] 배포 이벤트 발생 시 -> Track 1 (취약점 스캔)만 실행 """
    print("\n🚀 [Event: Deployment] 배포 감지 -> Track 1 실행")
    t1 = Track1Scanner()
    # 실제로는 Trivy 리포트 전체를 조회하거나, 특정 배포 건을 조회
    # 데모를 위해 특정 CVE를 타겟팅
    target_cve = "CVE-2020-27350"
    print(f"   🎯 타겟 CVE 스캔: {target_cve}")
    t1.scan_cve(target_cve)

def run_stix_event():
    """ [Mode 2] 주기적/STIX 이벤트 발생 시 -> Track 2 (IP 차단) & Track 3 (공격 시뮬레이션) """
    print("\n🚀 [Event: Threat Intel] 주기적 감시 -> Track 2 & 3 실행")
    
    # 1. Track 2: GitOps (IP 차단)
    # K8s 내부에서는 환경변수로 주입된 경로 사용, 없으면 로컬 기본값
    repo_path = os.getenv("REPO_PATH", "/home/waffle/project")
    t2 = Track2GitOps() 
    # Track2GitOps 내부에서 repo_path를 유연하게 처리하도록 수정 필요하지만
    # 데모를 위해 기존 로직 활용 (환경변수 주입 예정)
    
    malicious_ip = "1.2.3.4"
    print(f"   🛡️ [Track 2] 악성 IP 처리: {malicious_ip}")
    t2.update_policy(malicious_ip)

    # 2. Track 3: Attack Simulation
    t3 = Track3Dynamic()
    attack_id = "T1033" # System Owner/User Discovery
    print(f"   ⚔️ [Track 3] 공격 시뮬레이션: {attack_id}")
    t3.run_simulation(attack_id)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "help"
    
    if mode == "deploy":
        run_deploy_event()
    elif mode == "cron":
        run_stix_event()
    else:
        print("Usage: python orchestrator.py [deploy|cron]")
