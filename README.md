## Safe-View: AI 기반 URL 샌드박스 분석 시스템

문자나 이메일로 받은 의심스러운 URL, 클릭하기 전에 안전한지 미리 확인하고 싶다는 아이디어에서 시작된 프로젝트입니다. Safe-View는 사용자가 입력한 URL을 격리된 가상 환경(샌드박스)에서 대신 열어보고, 여러 전문 API와 AI의 종합 분석을 통해 다각적인 안전성 리포트를 제공하는 모바일 애플리케이션입니다.

### 주요 기능

샌드박스 분석: Docker 컨테이너를 이용한 격리된 환경에서 URL을 안전하게 실행하고 스크린샷을 캡처합니다.

다중 API 교차 검증: VirusTotal, Shodan API를 통해 악성 여부와 서버 위치 정보를 교차 분석합니다.

AI 요약 보고서: Google Gemini API를 활용하여 복잡한 분석 결과를 일반 사용자가 이해하기 쉬운 자연어 리포트로 생성합니다.

실시간 피드백: 분석 요청 후, 진행률과 현재 단계를 실시간으로 사용자에게 보여줍니다.

PDF 보고서 생성 및 공유: 전체 분석 결과를 체계적인 PDF 문서로 변환하여 외부로 공유할 수 있습니다.

분석 기록 및 캐싱: 과거 분석 내역을 조회하고, 동일한 URL에 대한 빠른 재분석을 지원합니다.

### 기술

- 클라이언트 (Client): Flutter, Dart

- 서버 (Server): Python, FastAPI, Uvicorn

- 샌드박스 (Sandbox): Docker, Selenium

- 데이터베이스 (Database): MongoDB

- 외부 API: VirusTotal, Shodan, Google Gemini

### Getting Started

1. 전제 조건

Flutter SDK

Python 3.10+

Docker Desktop

MongoDB Community Edition

2. 서버 실행 (safe-view-backend)

   ```

# 1. 서버 디렉토리로 이동

cd safe-view-backend

# 2. 필요한 패키지 설치

pip install -r requirements.txt

# 3. FastAPI 서버 실행

uvicorn main:app --reload
서버는 http://127.0.0.1:8000 에서 실행

3. 클라이언트 실행 (safe-view-app)
   Bash

# 1. 클라이언트 디렉토리로 이동

cd safe-view-app

# 2. Flutter 의존성 패키지 설치

flutter pub get

# 3. iOS 시뮬레이터 또는 실제 기기에서 앱 실행

flutter run

```
