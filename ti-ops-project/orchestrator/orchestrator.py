import json
import uuid
from track1_scanner import Track1Scanner
from track2_gitops import Track2GitOps
from track3_art import Track3ART

def run():
    print("\n🚀 [Final] TI-Ops 통합 파이프라인 가동")
    t1 = Track1Scanner()
    t2 = Track2GitOps()
    t3 = Track3ART()
    
    # 시나리오 데이터
    threats = [
        ('vulnerability', 'CVE-2020-27350'),
        ('indicator', '1.2.3.4'),
        ('attack-pattern', 'T1105') # Ingress Tool Transfer
    ]
    
    for type, val in threats:
        print("-" * 40)
        if type == 'vulnerability':
            print(f"📥 위협 감지: {val} (CVE)")
            t1.scan_cve(val)
        elif type == 'indicator':
            print(f"📥 위협 감지: {val} (IP)")
            t2.update_policy(val)
        elif type == 'attack-pattern':
            print(f"📥 위협 감지: {val} (Attack Pattern)")
            t3.run_simulation(val)

if __name__ == "__main__":
    run()
