#!/bin/bash

# =================================================================
# Project: TI-Ops Orchestrator Setup (Phase 1)
# Description: STIX/TAXII2 Client setup & Routing Logic
# =================================================================

set -e

PROJECT_DIR="$HOME/ti-ops-project/orchestrator"
VENV_DIR="$PROJECT_DIR/venv"

echo "📂 [1/4] 프로젝트 디렉토리 생성: $PROJECT_DIR"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

echo "🐍 [2/4] Python 가상 환경 설정 및 라이브러리 설치..."
sudo apt-get install -y python3-venv
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

# 필수 라이브러리 설치
pip install --upgrade pip
pip install stix2 taxii2-client requests gitpython kubernetes

echo "✍️ [3/4] Orchestrator 핵심 로직(orchestrator.py) 생성 중..."
cat <<EOF > orchestrator.py
import json
from taxii2client.v21 import Server
from stix2 import TAXIICollectionSource, Filter

class TIOrchestrator:
    def __init__(self):
        self.server_url = "https://limo.anomali.com/taxii"
        self.capec_to_attack_map = {
            "CAPEC-185": "T1105",  # Malicious Software Download
            "CAPEC-66": "T1190",   # SQL Injection
        }

    def fetch_threats(self):
        print(f"📡 Anomali Limo 접속 중... ({self.server_url})")
        try:
            server = Server(self.server_url)
            api_root = server.api_roots[0]
            # 첫 번째 컬렉션(보통 공용 피드) 사용
            collection = api_root.collections[0]
            print(f"✅ 컬렉션 연결됨: {collection.title}")
            
            source = TAXIICollectionSource(collection)
            # 최신 위협 분석을 위해 모든 객체 로드 (실습용)
            return source.query()
        except Exception as e:
            print(f"❌ 데이터 수집 실패: {e}")
            return []

    def route_threat(self, obj):
        """STIX 객체 유형별 3개 트랙 분류 로직"""
        obj_type = obj.get('type')
        
        # Track 1: Vulnerability (CVE 기반)
        if obj_type == 'vulnerability':
            cve_id = self._get_external_id(obj, 'cve')
            print(f"➔ [Track 1] Vulnerability 탐지: {cve_id} (Trivy 연동 예정)")
            return ('T1', cve_id)

        # Track 2: Indicator (IP/Domain 기반)
        elif obj_type == 'indicator':
            pattern = obj.get('pattern', '')
            print(f"➔ [Track 2] Indicator 탐지: {obj.get('name')} (GitOps 정책 연동 예정)")
            return ('T2', pattern)

        # Track 3: Attack Pattern (TTP/CAPEC 기반)
        elif obj_type == 'attack-pattern':
            capec_id = self._get_external_id(obj, 'capec')
            attack_id = self.capec_to_attack_map.get(capec_id, "Unknown-TID")
            print(f"➔ [Track 3] Attack Pattern 탐지: {obj.get('name')} ({capec_id} -> {attack_id}) (ART/ZAP 연동 예정)")
            return ('T3', attack_id)

        return (None, None)

    def _get_external_id(self, obj, source_name):
        for ref in obj.get('external_references', []):
            if ref.get('source_name') == source_name:
                return ref.get('external_id')
        return "N/A"

if __name__ == "__main__":
    orchestrator = TIOrchestrator()
    objects = orchestrator.fetch_threats()
    
    print(f"\n📊 총 {len(objects)}개의 STIX 객체 분석 시작...\n")
    
    counts = {"T1": 0, "T2": 0, "T3": 0}
    for obj in objects[:50]: # 성능상 상위 50개만 우선 테스트
        track, val = orchestrator.route_threat(obj)
        if track:
            counts[track] += 1
            
    print("\n" + "="*40)
    print(f"✅ 분석 완료: Track1({counts['T1']}), Track2({counts['T2']}), Track3({counts['T3']})")
    print("="*40)
EOF

echo "🚀 [4/4] Orchestrator 초기 가동 테스트..."
python3 orchestrator.py

echo ""
echo "===================================================="
echo "✅ Phase 1 완료! 'orchestrator.py'가 준비되었습니다."
echo "위 스크립트는 Anomali Limo에서 실제 데이터를 긁어와"
echo "우리가 설계한 3가지 트랙으로 분류하는 작업을 수행합니다."
echo "===================================================="
