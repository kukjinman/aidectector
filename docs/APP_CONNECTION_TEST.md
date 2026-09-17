# iOS ↔ AWS 통신 확인 (2026-09-17)

앱 기본 서버 주소를 `https://kukjinman.com/aidetector/`로 설정했습니다.
시뮬레이터 앱을 호스트로 사용하는 XCTest에서 실제 URLSession HTTPS 요청을 수행했습니다.

- GET `/aidetector/healthz`: 200, status=ok
- GET `/aidetector/v1/config`: 404
- XCTest `BackendConnectionTests.testAWSConnectionFromInstalledApp`: 통과

통과의 의미는 HTTPS 연결과 구버전 감지가 정상이라는 뜻입니다.
새 서버의 지갑·결제·실제 AI 분석이 검증된 것은 아닙니다.
기존 서버는 교체하지 않았고 API 과금 요청이나 사용자 자료 업로드는 하지 않았습니다.

앱 설정에서 “서버 연결 확인”으로 다시 확인할 수 있습니다.
개발용 서버 주소를 이전에 저장했다면 해당 값을 위 HTTPS 주소로 변경하세요.
서버가 새 버전으로 전환되면 설정 API도 200이어야 합니다.

실행 명령:
```sh
cd ios
xcodegen generate
xcodebuild -project AIDetector.xcodeproj -scheme AIDetector \
  -destination 'platform=iOS Simulator,id=848D49CB-D64F-4912-A4A0-7CA97A103720' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO test
```

통신 테스트는 외부 서버 상태를 확인하는 통합 테스트여서 네트워크 연결이 필요합니다.

실기기 정식 빌드에서는 공유 확장 프로필의 App Group 권한 누락으로 실패했습니다.
현재 개발 팀은 메인 앱의 그룹은 허용하지만 `com.kukjinman.aidetector.app.share` 프로필에는 그룹이 없습니다.
Apple Developer에서 해당 확장 App ID에도 `group.com.kukjinman.aidetector`를 연결하고 프로필을 갱신해야 합니다.
이번 실기기 확인용 앱은 별도 임시 프로젝트에서 공유 확장만 제외해 빌드했습니다. 원본 프로젝트의 공유 확장은 유지됩니다.
