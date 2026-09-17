# AWS 서버 Codex에 전달할 프롬프트

아래 내용을 서버에서 실행 중인 Codex에 붙여넣으세요.

```text
이 Ubuntu EC2 서버에서 AI Detector 백엔드의 새 릴리스를 검증하고, 운영 설정이 갖춰지면 안전하게 배포해 줘. 기존 서비스와 다른 앱의 가용성을 유지해 줘.

확인된 서버 상태 (2026-09-17):
- 공인 IP: 54.116.136.94 / 사용자 ubuntu / 서울 리전
- EBS 15GiB 확장 및 루트 파티션·ext4 파일시스템 확장 완료
- 루트 파일시스템 약 14G, 남은 공간 약 6.9G (작업 시 다시 확인)
- 현재 Node v22.23.2. 새 릴리스는 Node 24 이상 필요
- aidetector-backend.service와 nginx.service가 실행 중
- 기존 백엔드가 8787 포트를 사용하며 /healthz는 {"status":"ok"}

새 릴리스 경로:
/home/ubuntu/aidetector-releases/aidetector-release-20260917-101115

이 폴더에는 dist/, 운영용 node_modules/, package.json, package-lock.json,
.env, .env.example, certs/, start.sh, SERVER-README.txt, LAUNCH_CHECKLIST.md가 있다.
TypeScript 원본은 없고 빌드된 JavaScript 산출물만 있다.
원본 저장소는 개발자 맥의 /Users/kukjinman/github/AI/aidectector이다.
소스 변경이 필요하면 산출물을 임의로 고치지 말고 변경 요구와 재빌드 필요 사항을 설명해 줘.

환경 설정 현황:
- .env 권한 600, Illuminarty API 키 설정 완료
- AI_PROVIDER=illuminarty, NODE_ENV=production
- BILLING_ENABLED=false, ALLOW_UNBILLED_LOCAL_API=false
- Apple App ID·루트 인증서와 운영자·약관 필수 정보는 미설정
- certs/ 폴더는 만들어져 있지만 인증서는 아직 없음
- Illuminarty 어댑터는 이미지 전용. 영상 지원을 활성화하지 말 것
- 텍스트는 별도 GPTZero 키가 있어야 실제 사용 가능

수행할 작업:
1. 현재 디스크 여유, 릴리스 파일, .env 권한, 기존 systemd 서비스 설정과 nginx 연결 구조를 확인해 줘. API 키·환경변수 값 전체·개인키는 화면이나 로그에 출력하지 마.
2. SERVER-README.txt와 LAUNCH_CHECKLIST.md, dist/server.js의 시작 조건을 확인해 줘. Node 24 이상을 다른 서비스의 기존 Node 실행 경로에 영향을 주지 않는 별도 경로로 설치하고 버전 및 배포 파일의 의존성 호환성을 확인해 줘. 운영 의존성은 이미 포함되어 있으므로 불필요한 npm install은 피하고 npm run dev는 운영에 사용하지 마.
3. 실제 API 과금이나 기존 지갑 변경 없이 격리된 개발 모드의 mock 프로바이더와 메모리 DB로 앱 생성·/healthz·설정·법률 페이지의 스모크 테스트를 수행해 줘. 이 테스트 설정을 공개 운영 서비스에 적용하지 마.
4. 실제 운영에 필요한 미설정 항목을 정확히 정리해 줘. 운영자가 제공한 정보만 반영하고 임의의 사업자 정보·이메일·법률 문구·인증서를 만들어 넣지 마. 결제/법률 시작 조건을 제거하거나 ALLOW_UNBILLED_LOCAL_API를 켜서 공개 서비스로 우회하지 마. 필요한 운영 정보가 없으면 기존 서비스를 유지한 상태로 준비 결과와 부족한 정보를 보고해 줘.
5. 운영 정보가 모두 갖춰지면 기존 서비스 설정과 사용 중인 데이터 경로를 백업하고, 새 릴리스의 Node 절대 경로·WorkingDirectory·환경 설정·영구 SQLite 데이터 경로를 명시한 systemd 설정을 준비해 줘. 데이터 경로는 릴리스 교체와 무관하게 유지하고 기존 데이터가 있는지 먼저 확인해 줘. 하나의 SQLite DB를 여러 서버 프로세스가 동시에 사용하지 않게 해 줘.
6. nginx의 현재 도메인·TLS·다른 사이트 설정을 보존하고 요청 본문/타임아웃을 앱 요구사항에 맞춰 확인해 줘. 실제 소유가 확인된 도메인만 사용해 줘. aidetect.firesyss.com은 타사 참고 사이트이므로 사용하지 마. 구성 검증 후 서비스 전환을 진행하고 실패하면 기존 구성으로 되돌려 줘.
7. 서비스 전환 후 /healthz, /v1/config, /privacy, /terms, 미인증 분석 차단, 서비스 상태를 확인해 줘. Apple 결제와 실제 탐지 성능은 스모크 테스트로 검증했다고 주장하지 마. 검증하지 못한 항목은 명시해 줘.

임의로 기존 폴더·DB·로그를 삭제하거나 전역 런타임을 교체하지 마.
최종 보고에는 변경 파일, 실행/재시작 명령, 사용 포트·데이터 경로,
검증 결과, 롤백 방법, 남은 설정을 간결하게 정리해 줘.
```
