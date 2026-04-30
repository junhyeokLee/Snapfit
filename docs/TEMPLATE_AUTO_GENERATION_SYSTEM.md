# SnapFit 앨범 템플릿 자동 생성 시스템

## 목적
- Figma 디자인 데이터를 참고해 Flutter에서 바로 렌더링 가능한 템플릿 JSON을 자동 생성한다.
- Figma 구조를 그대로 직렬화하지 않고, 내부 템플릿 구조와 레이아웃 패턴 시스템으로 변환한다.
- `SAVE THE DATE` 작업에서 겪었던 문제를 반복하지 않도록, 예시 이미지 포함, 비율 대응, 중복 방지, 배포 전 검증까지 한 흐름으로 다룬다.

## 지원 비율
- `landscape`: `16:9`
- `square`: `1:1`
- `portrait`: `9:16`

비율은 단순 scale 금지다. 각 비율마다 재배치 규칙을 가져야 한다.

## 입력
- Figma 디자인 JSON
- 템플릿 타입
  - `wedding`
  - `travel`
  - `couple`
  - `baby`
  - `simple`
- 비율 타입
  - `16:9`
  - `1:1`
  - `9:16`
- 예시 이미지 URL 또는 Figma에서 확정된 preview/image asset 정보

## 출력
1. Flutter 렌더링용 JSON 구조
2. Dart 모델 코드
3. 샘플 템플릿 5개
4. 샘플 템플릿별 다양성/안정성 메트릭

## 절대 원칙
1. 템플릿마다 레이아웃 패턴이 달라야 한다.
   - 좌표만 조금 바꾸는 수준은 금지
   - 이미지 수, 배치 구조, 텍스트 위치, 프레임/장식 구성까지 달라야 함
2. 세 비율 모두에서 깨지면 안 된다.
   - 이미지 왜곡 금지
   - 텍스트 overflow 금지
   - 레이어 겹침 금지
   - safe area 이탈 금지
3. 예시 이미지는 기본 포함이다.
   - 플레이스홀더만 있는 상태는 완료가 아님
   - 대표 프레임뿐 아니라 주요 이미지 슬롯은 실제 예시 이미지가 채워져야 함
4. 미리보기와 실제 적용 경로는 동일 구조를 써야 한다.
   - 스토어 카드
   - 템플릿 상세 커버
   - 페이지 미리보기
   - 실제 사용하기 후 앨범 렌더
5. 템플릿 생성 후 서버 업로드 전 검증이 필수다.
6. 기존 템플릿과 `디자인 언어 거리`가 충분히 멀어야 한다.
   - 색감만 바꾼 수준 금지
   - 프레임 위치만 조금 바꾼 수준 금지
   - 동일한 페이지 skeleton 재사용 금지
   - 새 템플릿은 기존 템플릿과 `tone / motif / frame language / text composition`이 달라야 함

## 디자인 거리 규칙
- 자동 생성기는 템플릿별로 `styleSignature`를 가져야 한다.
- `styleSignature`는 아래를 포함한다.
  - `tone`
  - `primaryColors`
  - `motifs`
  - `forbiddenSimilarityWith`
  - `forbiddenMotifs`
- 새 템플릿 생성 시 아래를 동시에 검사한다.
  - 대표 색상군 겹침
  - 반복되는 프레임 문법 겹침
  - 대표 페이지 5장의 레이아웃 signature 겹침
  - cover 구조 겹침
- 특정 기존 템플릿과 유사도가 높으면 생성 폐기 후 다른 패턴으로 다시 뽑는다.

예시:
- `family_weekend_v1`
  - bright family scrapbook
  - memory wall / soft note / collage
- `anniversary_days_v1`
  - romantic anniversary book
  - date badge / coupon / ribbon / quote card
- `jeju_travel_v1`
  - travel editorial postcard
  - scenic strip / travel tag / wide landscape

즉 `family`를 만든 뒤 `anniversary`를 만들 때는,
가족 템플릿의 `memory wall`, `dark vertical band`, `same collage rhythm`을 그대로 가져오면 안 된다.

## 내부 구조

### 1. FigmaParser
- 역할:
  - `frame / group / text / image / shape` 파싱
  - 페이지/섹션 구조 추출
  - 디자인별 `seed page` 생성
- 추출 정보:
  - 색상
  - 폰트
  - spacing
  - radius
  - alignment
  - image slot
  - zIndex

### 2. TokenExtractor
- 추출 토큰:
  - `typography`
  - `color palette`
  - `spacing scale`
  - `radius`
  - `frame style`
- 목적:
  - Figma 수치를 Flutter 내부 규칙으로 정규화
  - 패턴 재조합 시 일관된 미감 유지

### 3. LayoutPatternGenerator
- 최소 10개 이상의 레이아웃 패턴 보유
- 각 pattern은 반드시 아래를 가진다:
  - 이미지 슬롯 개수
  - 이미지 배치 방식
  - 텍스트 위치
  - 프레임/장식 위치
  - 여백 규칙
- 패턴 예시:
  - `cover_full_bleed_hero`
  - `editorial_split`
  - `postcard_grid`
  - `magazine_strip`
  - `photo_stack_dense`
  - `caption_focus`
  - `soft_frame_collage`
  - `ticket_memory_page`
  - `minimal_quote_break`
  - `ending_full_bleed`

### 4. RatioAdapter
- 각 pattern에 대해 `portrait / square / landscape` 재배치 규칙 보유
- 금지:
  - portrait 결과를 그대로 scale해서 square/landscape에 재사용
- 해야 할 일:
  - 이미지 slot 재배치
  - 텍스트 block 재정렬
  - safe area 재계산
  - frame radius 및 caption band 위치 보정

### 5. TemplateGenerator
- 입력:
  - seed design
  - template type
  - ratio type
  - token set
  - pattern pool
- 출력:
  - Flutter용 `templateJson`
  - cover
  - pages
  - variants

### 6. DuplicateDetector
- 기준:
  - 이미지 슬롯 개수
  - 배치 구조
  - 텍스트 블록 위치
  - 장식 요소 배치
- 방식:
  - `layout signature` 생성
  - `jaccard similarity` 또는 구조 fingerprint 비교
- 판단:
  - 유사도 `85% 이상`이면 중복으로 간주하고 폐기

## 모델 설계

### TemplateModel
- `templateId`
- `title`
- `templateType`
- `coverImageUrl`
- `previewImages`
- `pageCount`
- `flutterTemplateJson`
- `metrics`

### LayerModel
- `id`
- `type`
- `x`
- `y`
- `width`
- `height`
- `rotation`
- `zIndex`
- `style`
- `ratioType`

지원 레이어 타입:
- `image`
- `text`
- `frame`
- `sticker`
- `background`

### LayoutPatternModel
- `patternId`
- `ratioType`
- `imageSlotCount`
- `textBlockCount`
- `frameTypes`
- `safeArea`
- `signature`

## 실제 작업 순서
1. Figma JSON 파싱
2. seed page와 design token 추출
3. LayerModel 기반 구조로 정규화
4. 10개 이상 layout pattern 정의
5. template type별 허용 pattern pool 정의
6. ratio adapter 적용
7. 예시 이미지 자동 삽입
8. duplicate detector로 중복 폐기
9. 샘플 5개 생성
10. release gate 검증
11. CDN/서버 반영

## 검증 기준

### 다양성
- 샘플 5개는 모두 다른 패턴이어야 함
- 전체 overlap rate `<= 0.10`
- 기존 운영 템플릿과의 style similarity도 기준 이하이어야 함
- cover signature 중복 금지
- 대표 5페이지 signature 중복 금지

### 비율 안정성
- `16:9 / 1:1 / 9:16` 모두 지원
- 이미지 왜곡 `0`
- 텍스트 overflow `0`
- safe area 이탈 `0`

### 렌더링 안정성
- Flutter 렌더 실패율 `0`
- 음수 좌표/크기 없음
- 잘못된 zIndex/겹침 없음

### 실제 운영 검증
- 예시 이미지 존재
- preview == actual rendering
- Figma 승인본과 구조 차이 없음
- CDN 이미지 디코드 가능

## 현재 코드 매핑
- 생성 모델:
  - [/Users/devsheep/SnapFit/SnapFit/lib/features/store/domain/entities/generated_template_models.dart](/Users/devsheep/SnapFit/SnapFit/lib/features/store/domain/entities/generated_template_models.dart)
- 기존 레이어 모델:
  - [/Users/devsheep/SnapFit/SnapFit/lib/features/album/domain/entities/layer.dart](/Users/devsheep/SnapFit/SnapFit/lib/features/album/domain/entities/layer.dart)
  - [/Users/devsheep/SnapFit/SnapFit/lib/features/album/domain/entities/layer_export_mapper.dart](/Users/devsheep/SnapFit/SnapFit/lib/features/album/domain/entities/layer_export_mapper.dart)

## 현재 구현 범위
- Figma JSON에서 seed page 파싱
- Flutter templateJson 생성
- 최소 16페이지 생성
- `square`, `landscape` variant 생성
- overlap 10% 초과 후보 폐기
- 샘플 5개 생성
- 예시 이미지 자동 수집

## 다음 확장 우선순위
1. `FigmaParser`, `TokenExtractor`, `LayoutPatternGenerator`, `RatioAdapter`, `DuplicateDetector` 를 별도 파일로 분리
2. `wedding / baby / simple` 타입별 pattern pool 추가
3. screenshot diff 기반 시각 검증 추가
4. store publish 파이프라인과 자동 연결
5. template parity hard rule을 pattern 단위로 확장

## 실행 예시
```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/build_store_templates_from_handoff.dart \
  --input=assets/templates/save_the_date_handoff.json \
  --output=assets/templates/generated/store_latest.json \
  --pages=12
```

## 샘플 출력
- [/Users/devsheep/SnapFit/SnapFit/assets/templates/generated/store_latest.json](/Users/devsheep/SnapFit/SnapFit/assets/templates/generated/store_latest.json)

## 앞으로의 작업 원칙
- 새 템플릿 작업은 이 문서 기준으로 진행한다.
- `SAVE THE DATE`처럼 나중에 수동으로 맞추는 방식이 아니라, 처음부터
  - pattern
  - ratio
  - example image
  - duplicate guard
  - release validation
  을 포함해서 진행한다.
