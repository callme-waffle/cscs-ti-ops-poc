import time
from track3_dynamic import Track3Dynamic

def run():
    print("\n🚀 [Dynamic] GitHub 연동 공격 자동화 테스트\n")
    art = Track3Dynamic()
    
    # 테스트할 T-ID 목록 (실제 Atomic Red Team에 존재하는 ID)
    # T1059.001: PowerShell (리눅스용 pwsh 테스트가 있는지 확인됨) -> 리눅스용 대체: T1033
    # T1033: System Owner/User Discovery (whoami 실행)
    # T1083: File and Directory Discovery (ls 실행)
    scenarios = ["T1033", "T1083"] 

    for t_id in scenarios:
        print(f"-"*50)
        print(f"📥 위협 인텔리전스 수신: {t_id}")
        art.run_simulation(t_id)
        time.sleep(2)

if __name__ == "__main__":
    run()
