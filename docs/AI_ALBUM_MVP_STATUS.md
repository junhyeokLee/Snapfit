# Snapfit AI 앨범 MVP 상태

이 문서는 현재 `sunduk/ai-album-theme-curation` 브랜치 기준 AI 앨범 초안 만들기 MVP의 구현 범위, 검증 상태, 남은 위험요소를 정리한다.

## 현재 결론

AI 앨범은 별도 자동 완성 기능이 아니라, 사용자가 직접 확정하기 전에 Snapfit이 **허용된 사진 안에서 앨범 초안을 정리해 주는 보조 플로우**다.

현재 MVP는 다음 원칙으로 구현되어 있다.

- 직접 구성 플로우와 AI 초안 플로우를 분리한다.
- AI 주제/사진 범위/포인트 안내는 AI 플로우에서만 노출한다.
- 추천 결과 리뷰 전에는 실제 앨범을 확정하지 않는다.
- 실패/권한/사진 부족 상태에서는 포인트를 차감하지 않는다.
- 원본 사진 업로드나 전체 사진첩 분석처럼 보이는 표현을 피한다.
- 최종 편집은 기존 editor에서 사용자가 직접 수정할 수 있게 한다.

## 구현된 사용자 플로우

```text
새 앨범 만들기
→ 시작 방식 선택
   ├─ 직접 구성하기
   │  └─ 기존 앨범 기본 설정 / editor 플로우
   └─ AI 초안으로 시작하기
      └─ AI 주제 선택
         └─ 사진 범위 선택
            └─ 포인트 확인
               └─ AI 초안 생성 진행
                  └─ 추천 결과 리뷰
                     └─ 이 구성으로 시작하기
                        └─ editor handoff 안전성 검사
                           └─ 기존 editor 진입
```

## 구현된 주요 기능

### 시작 방식 분리

- 직접 구성은 AI 주제/포인트/추천 문구 없이 기존 수동 제작으로 진입한다.
- AI 초안은 별도 카드로 시작하며 첫 생성 무료/AI 전용 경로임을 안내한다.
- 수동 제작이 열등해 보이지 않도록 AI 기능 홍보 문구를 과하게 넣지 않는다.

### AI 주제 선택

- AI 플로우에서만 주제를 선택한다.
- 지원 주제: 커플, 여행, 가족, 친구, 아기·성장, 생일·기념일, 일상, 직접 입력.
- 주제는 앨범 카테고리 확정값이 아니라 사진 흐름/제목 추천을 위한 힌트로 취급한다.

### 사진 범위 선택

- AI가 볼 사진 범위를 사용자가 먼저 정한다.
- 지원 범위: 최근 30일, 날짜 선택, 앨범 선택, 직접 고르기, 선택한 사진만 사용.
- 화면에는 다음 privacy reassurance를 표시한다.

```text
원본 사진은 서버로 보내지 않고, 기기 안에서만 살펴봐요.
```

### 포인트 확인

- AI 초안 생성 직전 포인트 사용 기준을 확인한다.
- 첫 생성 무료 상태와 유료 preview 상태를 분리한다.
- 현재 서버 차감 연동 전이므로 `차감되었습니다`, `결제됩니다`, `환불됩니다` 같은 확정 결제성 표현을 쓰지 않는다.
- 현재 표시 기준:
  - `사용 기준`: `성공 시만 처리`
  - `실패 시`: `실패 시 차감 없음`
- 생성 진행 화면도 같은 정책을 안내한다.

```text
성공한 초안만 사용 처리돼요. 실패하면 차감되지 않아요.
```

### AI 초안 생성 / 큐레이션

- `AiAlbumDraftGenerationService`가 사진 후보를 수집하고 `AiAlbumCurationEngine`으로 초안을 만든다.
- 성공 결과만 `shouldChargePoints: true`로 표시한다.
- 실패/권한/사진 부족/저품질 사진 상태는 모두 `shouldChargePoints: false`다.
- 현재 큐레이션은 앱 내부 metadata-first 로직이다. 실제 서버 Vision/LLM 응답으로 교체되기 전 단계다.

### 추천 결과 리뷰

- AI가 추천한 사진과 제외한 사진을 리뷰 화면에서 보여준다.
- 제외 이유를 사용자에게 설명한다.
- 사용자는 제외 사진을 다시 추가할 수 있다.
- 리뷰 화면에서 바로 확정 생성하지 않고, `이 구성으로 시작하기`를 눌러 editor로 넘긴다.

### editor handoff 안전장치

`AiAlbumDraftTemplateBuilder.validateEditorReady()`가 editor 진입 전 최종 무결성을 확인한다.

검사하는 사유:

- `emptyRecommendedPhotos`: 추천 사진이 비어 있음
- `pageCountMismatch`: draft page count와 생성 page 수가 맞지 않음
- `missingLocalImageAsset`: editor에 넣을 local image asset layer가 없음

안전하지 않으면 editor를 빈 상태로 열지 않고 기존 failure/recovery 화면으로 돌린다.

## 구현된 failure / recovery 상태

| 상태 | 의미 | 사용자 안내 | Primary CTA | 포인트 |
| --- | --- | --- | --- | --- |
| `permissionDenied` | 사진 접근 권한이 없음 | 사진 권한을 열어야 함 | `사진 권한 열기` | 차감 없음 |
| `insufficientPhotos` | 후보 사진 수가 최소 기준보다 적음 | 사진 범위를 더 넓게 선택 | `사진 범위 다시 고르기` | 차감 없음 |
| `insufficientPhotos` + limited | 선택한 사진 안에서 부족 | 사진을 더 허용/선택 | `사진 더 선택하기` | 차감 없음 |
| `lowQualityPhotos` | 사진 수는 있으나 스크린샷/저해상도 위주라 추천 후보 부족 | 여행/일상 사진 범위 재선택 | `사진 범위 다시 고르기` | 차감 없음 |
| editor readiness failure | 초안은 있으나 editor로 안전하게 넘길 수 없음 | 안전하게 열지 않고 복구 | `사진 범위 다시 고르기` | 차감 없음 |
| generic failed | 알 수 없는 생성 실패 | 재시도/수동 구성 | `사진 범위 다시 고르기` | 차감 없음 |

모든 실패 화면은 보조 CTA `직접 구성하기`를 유지한다.

## 현재 테스트 커버리지

AI 앨범 관련 주요 테스트:

- `test/widget/ai_album_start_step_test.dart`
- `test/widget/ai_album_theme_step_test.dart`
- `test/widget/ai_album_photo_range_step_test.dart`
- `test/widget/ai_album_point_confirmation_step_test.dart`
- `test/widget/ai_album_recommendation_review_step_test.dart`
- `test/widget/ai_album_draft_failure_step_test.dart`
- `test/widget/ai_album_split_flow_goldens_test.dart`
- `test/unit/ai_album_curation_engine_test.dart`
- `test/unit/ai_album_draft_generation_service_test.dart`
- `test/unit/ai_album_draft_template_builder_test.dart`
- `test/unit/ai_album_photo_candidate_collector_test.dart`

최근 검증 기준:

```bash
export PATH=/opt/data/flutter-sdk-release/bin:$PATH
flutter analyze
flutter test
git diff --check
```

## 아직 실제 구현 전인 항목

### Supabase / 서버 포인트 연동

현재 포인트 화면은 UX preview와 정책 안내 수준이다.

남은 작업:

- 첫 AI 생성 무료 사용 여부를 사용자별로 저장한다.
- 성공한 AI 초안에 대해서만 300P 사용 처리를 서버에서 원자적으로 기록한다.
- 실패/권한 부족/사진 부족/저품질/무결성 실패에서는 포인트를 차감하지 않는다.
- Flutter 클라이언트가 임의로 포인트를 차감하지 않도록 Supabase RLS 또는 Edge Function 경로로 보호한다.

### 실제 AI 서버/모델 연동

현재 초안 생성은 metadata-first 앱 내부 로직이다.

남은 작업:

- 서버 Vision/LLM 또는 Edge Function 연동 여부 결정
- 원본 사진 업로드 정책 결정
- 썸네일/metadata만 보낼지, 사용자가 명시 동의한 사진만 업로드할지 결정
- 서버 실패/timeout 상태를 현재 failure/recovery 구조에 매핑

### 제한된 사진 권한 picker 개선

현재 limited-library recovery는 사진 범위 선택 단계로 돌아가는 수준이다.

남은 작업:

- iOS limited library picker 직접 재오픈 가능 여부 확인
- Android selected photos 재선택 UX 확인
- 플랫폼별 불가능한 경우 앱 설정 또는 범위 선택 fallback 유지

### 실제 기기 QA

VPS/Flutter test로 커버하기 어려운 항목이다.

필수 실제 기기 확인:

- 사진 권한 거부
- 사진 일부만 허용
- 사진 0장/부족
- 스크린샷·저해상도 위주
- 정상 생성 후 editor 진입
- editor 진입 실패 fallback
- 첫 무료/유료 포인트 상태

### 저장/업로드 end-to-end

AI 초안이 editor로 들어간 뒤 실제 저장/업로드까지 확인해야 한다.

남은 작업:

- AI 추천 사진의 local asset이 editor 저장 과정에서 업로드되는지 확인
- Supabase storage URI 변환과 기존 album persistence 경로 확인
- 네트워크/스토리지 quota 실패 시 기존 사용자 친화 error mapping과 연결 확인

## QA 체크리스트

### 정상 플로우

- [ ] 직접 구성하기는 AI 주제/포인트 화면 없이 기존 제작으로 진입한다.
- [ ] AI 초안은 주제 → 사진 범위 → 포인트 확인 → 생성 → 리뷰 → editor 순서로 진행된다.
- [ ] 추천 사진이 editor page image layer로 유지된다.
- [ ] 제외 사진을 다시 추가한 뒤 editor에 반영된다.

### 권한/사진 상태

- [ ] 사진 권한 거부 시 `사진 권한 열기`가 보인다.
- [ ] limited library에서 사진 부족 시 `사진 더 선택하기`가 보인다.
- [ ] 일반 사진 부족 시 `사진 범위 다시 고르기`가 보인다.
- [ ] 스크린샷/저해상도 위주이면 `앨범에 어울리는 사진이 조금 부족해요` 상태가 보인다.

### editor handoff

- [ ] 추천 사진이 없으면 editor로 진입하지 않는다.
- [ ] page count mismatch이면 editor로 진입하지 않는다.
- [ ] local image asset layer가 없으면 editor로 진입하지 않는다.
- [ ] 실패 시 기존 recovery 화면으로 돌아가고 `직접 구성하기`가 유지된다.

### 포인트/신뢰 UX

- [ ] 첫 생성 무료 상태에서는 `무료로 초안 만들기`가 보인다.
- [ ] 유료 preview 상태에서는 무료 혜택 문구가 섞이지 않는다.
- [ ] 생성 전/중/실패 화면에서 차감 시점을 오해하지 않는다.
- [ ] 실패 상태에서는 `포인트는 차감되지 않았어요`가 보인다.
- [ ] `결제되었습니다`, `환불`, `서버에서 사진 분석` 같은 표현이 없다.

## 다음 추천 순서

1. Supabase 포인트 차감/무료 1회 사용 기록 설계
2. 제한된 사진 권한 picker의 실제 플랫폼 동작 확인
3. AI draft 서버/모델 연동 방식 결정
4. 실제 기기 사진 권한 QA
5. AI 초안 → editor 저장/업로드 end-to-end 검증

## PR 리뷰 포인트

리뷰할 때 특히 아래를 확인한다.

- AI 플로우가 직접 구성 플로우를 침범하지 않는지
- 실패 상태가 포인트 차감처럼 보이지 않는지
- 사진 privacy 카피가 실제 동작보다 과장되지 않는지
- editor에 빈 앨범/빈 이미지 레이어가 열리지 않는지
- MVP와 future server/Supabase work 경계가 명확한지
