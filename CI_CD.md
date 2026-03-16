# SnapFit Frontend CI 안내

이 저장소의 CI는 GitHub Actions로 테스트를 자동 실행합니다.

## CI 동작

- `main`, `master` 브랜치로 push 시
- PR 생성/업데이트 시

워크플로우 파일:
- `.github/workflows/ci.yml`

실행 내용:
- `flutter pub get`
- `flutter test`
