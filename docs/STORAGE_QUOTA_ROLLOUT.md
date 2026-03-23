# Storage Quota Rollout (SnapFit)

## 목표
- 사용자 증가 시 스토리지 비용 폭증 방지
- Free/Pro 플랜 차별화 포인트 제공
- 갑작스러운 생성 차단 없이 단계적으로 롤아웃

## 권장 정책 (v1)
- Free
  - soft limit: `3GB`
  - hard limit: `5GB`
- Pro
  - soft limit: `30GB`
  - hard limit: `50GB`

초기에는 **soft limit 중심 운영** 권장:
- 80%: 안내 배너
- 100%: 경고 + 업그레이드 유도
- 120% 또는 hard limit 도달: 신규 업로드 차단

## 측정 범위
- 사용자별 총 사용량(`usedBytes`)
- 파일 유형별 분리
  - `ALBUM_IMAGE_ORIGINAL`
  - `ALBUM_IMAGE_PREVIEW`
  - `ALBUM_COVER_ORIGINAL`
  - `ALBUM_COVER_PREVIEW`
  - `PROFILE_IMAGE`

## 데이터 모델 (백엔드)
```sql
-- 플랜별 쿼터
create table if not exists plan_storage_limits (
  plan_code varchar(64) primary key,
  soft_limit_bytes bigint not null,
  hard_limit_bytes bigint not null,
  updated_at timestamp not null default now()
);

-- 사용자 누적 사용량(핫패스 조회용)
create table if not exists user_storage_usage (
  user_id varchar(64) primary key,
  used_bytes bigint not null default 0,
  measured_at timestamp not null default now(),
  updated_at timestamp not null default now()
);

-- 파일 단위 ledger(정합성/복구용)
create table if not exists user_storage_ledger (
  id bigserial primary key,
  user_id varchar(64) not null,
  file_key varchar(255) not null unique, -- gs path or object key
  file_kind varchar(64) not null,
  bytes bigint not null,
  album_id bigint null,
  created_at timestamp not null default now(),
  deleted_at timestamp null
);
create index if not exists idx_storage_ledger_user on user_storage_ledger(user_id);
```

## API 스펙 (백엔드)
### 1) quota 조회
- `GET /api/billing/storage/quota?userId={id}`
- 응답
```json
{
  "userId": "1958142146",
  "planCode": "FREE",
  "usedBytes": 734003200,
  "softLimitBytes": 3221225472,
  "hardLimitBytes": 5368709120,
  "softExceeded": false,
  "hardExceeded": false,
  "usagePercent": 14,
  "measuredAt": "2026-03-20T05:22:10.000Z"
}
```

### 2) 업로드 사전검증(선택)
- `POST /api/storage/preflight`
- 요청: `{ "userId":"...", "predictedBytes": 1280000 }`
- 응답: `{ "allowed": true, "reason": null, "quota": { ... } }`

### 3) 업로드 반영
- 업로드 성공 직후 서버에 확정 반영
- `POST /api/storage/usage/commit`
- 요청:
```json
{
  "userId": "1958142146",
  "fileKey": "gs://.../albums/images/xxx_preview.jpg",
  "fileKind": "ALBUM_IMAGE_PREVIEW",
  "bytes": 248320,
  "albumId": 178
}
```

### 4) 삭제 반영
- `POST /api/storage/usage/release`
- 요청: `{ "userId":"...", "fileKey":"gs://.../albums/images/xxx_preview.jpg" }`

## 앱 연동 포인트 (현재 코드 기준)
- Firebase 업로드: `lib/features/album/data/api/storage_service.dart`
- 과금/구독 API: `lib/features/billing/data/billing_repository.dart`
- 신규 Provider: `myStorageQuotaProvider`
  - 파일: `lib/features/billing/data/billing_provider.dart`

## 권장 롤아웃 단계
1. 측정만 활성화(차단 없음) 2~4주
2. UI 배너 노출(80%/100%)
3. Free 하드 제한 적용
4. Pro 하드 제한 적용(충분히 큰 값 유지)

## 운영 체크리스트
- [ ] 업로드 성공/실패/재시도 시 중복 집계 방지(`file_key unique`)
- [ ] 삭제/복구 이벤트의 idempotency 보장
- [ ] 사용자별 상위 사용량 대시보드(Top 1%, 5%, 10%)
- [ ] 이슈 대응용 재계산 배치(job) 마련
