# Snapfit Supabase Auth/Storage Readiness

이 문서는 `sunduk/auth-ui-test-loop`에서 확인한 Supabase Auth, Storage, RLS 운영 준비 체크리스트입니다. 시크릿/API 키/토큰 값은 기록하지 않습니다.

## 현재 코드 기준

- Flutter auth redirect URL 기본값: `snapfit://auth/callback`
- Android intent filter: `snapfit://auth` host 등록됨
- iOS URL scheme: `snapfit` scheme 등록 상태
- Album Storage bucket path: `<auth.uid()>/albums/...`
- Flutter Storage marker: `supabase://album-assets/<auth.uid()>/albums/...`

## Supabase 콘솔에서 확인해야 할 Auth 설정

1. Authentication > URL Configuration
   - Redirect URLs에 `snapfit://auth/callback` 등록
2. Authentication > Email Templates
   - Confirm signup 링크가 위 redirect URL을 허용하는지 확인
   - Reset password 링크가 위 redirect URL을 허용하는지 확인
3. Authentication > Providers
   - Email provider enabled
   - Kakao/Google provider는 실제 앱 키 및 redirect 설정을 별도 확인

## Supabase DB/Storage 체크 결과

VPS에서 확인한 항목:

```txt
tool/supabase_readiness_check.py --profile supabase-core
=> READY: all checks passed.

npx supabase@latest db lint --linked
=> No schema errors found
```

확인된 마이그레이션 구조:

- `profiles` RLS: 본인 또는 admin 조회/수정
- `albums` RLS: 소유자/멤버/admin 접근
- `album_pages` RLS: 앨범 접근 가능 사용자 CRUD
- `storage_quotas` RLS: 본인 또는 admin 조회
- `album-assets` bucket: private, user folder 기반 정책
- `album-assets` storage.objects 정책: `<auth.uid()>/...` 경로 insert/select/update/delete 허용
- legacy `albums/...` 경로 정책도 기존 클라이언트 호환용으로 존재

## 실기기에서 반드시 확인할 항목

- 이메일 회원가입 후 인증 메일 링크 클릭 시 앱 복귀
- 비밀번호 찾기 메일 링크 클릭 시 새 비밀번호 화면 진입
- Android에서 `snapfit://auth/callback` intent 정상 수신
- iOS에서 `snapfit://auth/callback` URL scheme 정상 수신
- 실제 로그인 사용자로 앨범 저장 시 Storage object path가 `<userId>/albums/...`로 생성되는지
- 저장 후 홈/리더/편집 재진입 시 커버와 내지 레이어가 복원되는지

## 현재 남은 리스크

- Supabase 콘솔의 Auth Redirect URLs는 CLI lint로 검증되지 않으므로 콘솔에서 직접 확인 필요
- 실제 Kakao/Google OAuth는 VPS web build만으로 완전 검증 불가
- Android SDK가 VPS에 없어 APK build는 별도 환경 또는 실제 기기/CI에서 확인 필요
