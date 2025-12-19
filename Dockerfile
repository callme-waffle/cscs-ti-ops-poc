FROM python:3.11-slim

WORKDIR /app

# 시스템 패키지 설치 (Git 필수)
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# 라이브러리 설치
RUN pip install --no-cache-dir kubernetes stix2 taxii2-client gitpython pyyaml requests

# 소스코드 복사 (orchestrator 폴더 내용물을 /app으로)
COPY ti-ops-project/orchestrator/ .

# 실행 권한
RUN chmod +x orchestrator.py

# 기본 엔트리포인트 없음 (Command로 제어)
