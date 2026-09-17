# AI Detector

인스타그램 게시물을 공유하면 AI 생성 확률을 퍼센티지로 보여주는 iOS 앱. 구현 스펙은 [PROMPT.md](PROMPT.md)를 참고.

```
backend/   Node.js + Fastify API 서버 (og:image 추출, AI 판별 프로바이더 연동)
ios/       SwiftUI 앱 + Share Extension (xcodegen project.yml로 생성)
```

## 백엔드 실행

```bash
cd backend
npm install
npm run dev        # http://localhost:8787
npm test           # 단위/통합 테스트 (fetch를 모킹해서 네트워크 없이 실행)
```

기본값은 `AI_PROVIDER=mock`(외부 API 키 없이 이미지 해시로 결정론적 확률 생성)입니다.
실제 판별을 붙이려면 `.env.example`을 참고해 `AI_PROVIDER=sightengine`(Sightengine API 키) 또는 `AI_PROVIDER=illuminarty`(Illuminarty API 키, 이미지 전용)를 설정하세요.

**알려진 제약**: 이 개발 환경에서 실제 instagram.com에 요청해보면 인스타그램이 클라우드/데이터센터 IP를 challenge/checkpoint 페이지로 막아 `og:image`를 아예 내려주지 않는 것을 확인했습니다 (PROMPT.md 8번 항목에서 경고한 리스크). 실제 배포 전에 가정용 네트워크나 별도 프록시 환경에서 재검증이 필요합니다.

## 백엔드를 AWS 서버에 배포하기

레지스트리(Docker Hub/ECR) 없이 로컬에서 이미지를 빌드해 SSH로 바로 올리는 방식입니다. AWS 서버에는 Docker와, 도메인의 HTTPS를 처리해 8787 포트로 넘겨주는 리버스 프록시(nginx/Caddy 등)가 이미 떠 있다고 가정합니다.

1. `backend/.env.example`을 참고해서 **서버에** `~/aidetector-backend/.env` 파일을 미리 만들어두세요 (API 키가 로컬→서버 배포 경로에 실리지 않도록, 이 스크립트는 `.env`를 건드리지 않습니다).
2. `backend/scripts/deploy.sh` 상단의 `SSH_HOST` / `SSH_USER` / `SSH_KEY` / `PLATFORM`(EC2가 Graviton이면 `linux/arm64`)을 본인 서버 값으로 채우세요.
3. 로컬 맥에서 실행:
   ```bash
   cd backend
   ./scripts/deploy.sh
   ```
   이미지를 빌드 → `docker save`로 압축 → `scp`로 서버에 전송 → 서버에서 `docker load` + `docker compose up -d`까지 한 번에 처리합니다.
4. **업데이트할 때도 같은 명령**(`./scripts/deploy.sh`)을 다시 실행하면 됩니다. git clone이나 서버에서의 빌드는 필요 없고, 항상 로컬 코드 기준으로 새 이미지를 만들어 컨테이너를 교체합니다.

로컬에 Docker가 없다면 `brew install docker docker-buildx colima && colima start` 로 가볍게 준비할 수 있습니다(Docker Desktop 불필요). 이 방식으로 실제 이미지를 빌드·실행해서 정상 동작을 확인했습니다.

## iOS 앱 빌드

```bash
brew install xcodegen   # 최초 1회
cd ios
xcodegen generate
open AIDetector.xcodeproj
```

- 타깃: `AIDetector`(메인 앱), `AIDetectorShare`(공유 확장) — 둘 다 App Group `group.com.kukjinman.aidetector` 공유
- 배포 타깃 iOS 17.0 (SwiftData가 iOS 17부터 지원되어 PROMPT.md의 "iOS 16+"에서 상향)
- 백엔드 주소는 앱의 **설정 탭**에서 바꿀 수 있습니다(App Group 공유 저장소에 저장되어 공유 확장도 같은 값을 씀). 기본값은 `http://localhost:8787`.
  - **시뮬레이터**는 맥과 네트워크 네임스페이스를 공유해서 `localhost` 그대로 써도 됩니다.
  - **실기기**에서는 `localhost`가 폰 자신을 가리키므로 반드시 맥의 LAN IP로 바꿔야 합니다 (`ipconfig getifaddr en0`으로 확인, 예: `http://192.168.x.x:8787`). 폰과 맥이 같은 Wi-Fi에 있어야 하고, `NSAllowsLocalNetworking` ATS 예외가 사설 IP 대역(RFC1918)을 이미 허용하므로 추가 설정은 필요 없습니다.
- 실제 기기에서 공유 확장을 쓰려면 Xcode에서 본인의 Apple Developer 팀을 지정하고, App Group을 개발자 계정에 등록해야 합니다. 시뮬레이터 빌드는 이미 확인했습니다.
- 배포용 백엔드로 바꿀 때 `App/Info.plist`, `ShareExtension/Info.plist`의 `NSAllowsLocalNetworking` ATS 예외를 제거하세요.

## 검증한 것

- 백엔드 유닛/통합 테스트 11개 전부 통과 (URL 검증, og:image 파싱, 에러 코드, 캐싱)
- `tsc` 타입체크 통과
- Xcode 프로젝트 생성 및 시뮬레이터용 빌드 성공 (메인 앱 + 공유 확장 임베딩/코드사이닝 포함)
- 시뮬레이터에 설치·실행해 홈 화면 UI가 스펙대로 렌더링되는 것 확인

## 새 홈 화면 · 텍스트/미디어 · 횟수권

홈과 설정을 참고 이미지의 파스텔 카드 레이아웃으로 구성했습니다. 텍스트(GPTZero), 이미지·10초 이하 영상(Sightengine), Instagram 공개 미리보기 분석을 지원합니다. URL 분석은 영상 전체가 아닌 미리보기 이미지 분석입니다. TikTok은 지원하지 않습니다.

- **Node 24+**가 필요합니다 (`node:sqlite` 지갑). 로컬 영상 분석에는 `ffprobe`도 필요합니다.
- 기본 mock 모드는 실제 판별이 아닌 데모이며 결제가 비활성화됩니다.
- 실제 API는 `BILLING_ENABLED=true`와 Apple 설정이 필요합니다. `.env`를 사용할 때 `node --env-file=.env --import tsx src/server.ts`로 실행하세요.
- 6회/20회/50회 소모성 상품, StoreKit 2 구매, Apple 서버 서명 검증, SQLite 잔액, 중복 지급 방지, 실패 환급, 공유 확장 지갑을 추가했습니다.
- 본인 서버에서 `/privacy`, `/terms`, `/support`, `/`를 제공합니다. 타사 참고 도메인은 서비스 주소로 사용하지 않습니다.
- Release 주소는 `ios/project.yml`의 `API_BASE_URL`, `PUBLIC_WEBSITE_URL`로 지정합니다. 기본 `example.invalid`는 반드시 교체해야 합니다.
- 판매 가격, 약관 필수 정보, 결제 등록과 운영 제약은 **[출시 체크리스트](docs/LAUNCH_CHECKLIST.md)**를 확인하세요.

이전의 결과 전역 캐시는 제거하고 지갑별 요청 ID로 24시간 결과 재전송을 지원합니다. 개발 모드 외 모든 분석은 유효한 지갑과 동의 및 충분한 잔액이 있어야 수행됩니다. 새 요청마다 성공 시 1회를 사용합니다.

## AWS 앱 연결 확인 (2026-09-17)

현재 앱 기본 주소는 `https://kukjinman.com/aidetector/`입니다. 개발용 주소를 이전에 저장했다면 앱 설정에서 변경하세요.
시뮬레이터 앱의 URLSession으로 `/healthz` 200과 `/v1/config` 404를 확인했습니다. 구버전 서버와의 통신은 정상이지만 새 앱 기능에는 백엔드 전환이 필요합니다.
검증 방법과 실기기 서명 제약은 [앱 연결 검증 기록](docs/APP_CONNECTION_TEST.md)을 참고하세요.
