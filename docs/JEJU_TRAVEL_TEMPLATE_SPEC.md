# Jeju Travel Template Spec

이 문서는 SnapFit의 제주도 여행 템플릿 제작용 기준 문서다.
목표는 피그마 승인본과 앱 결과물이 오차 없이 일치하는 상품형 여행 템플릿을 만드는 것이다.

## 1. 기본 정보

- `templateId`: `jeju_travel_v1`
- `templateSlug`: `jeju_travel`
- `category`: `travel`
- `theme`: `Jeju`
- `mood`: `clean editorial / airy coastal / calm warm daylight`
- `masterAspect`: `portrait`
- `masterSize`: `1080 x 1440`
- `variants`:
  - `portrait`: `1080 x 1440`
  - `square`: `1440 x 1440`
  - `landscape`: `1440 x 1080`

## 2. 아트디렉션

핵심 키워드:
- 제주 바다
- 현무암
- 바람
- 억새
- 감귤
- 해변 산책
- 드라이브
- 여백 있는 여행 에디토리얼

톤앤매너:
- 배경은 너무 무겁지 않은 `off-white`, `sand`, `mist blue`, `sea gray`
- 포인트는 `deep ocean navy`, `tangerine`, `basalt charcoal`
- 타이포는 여행 매거진 느낌의 차분한 위계
- 사진은 장식이 아니라 실제 풍경과 장소감이 읽혀야 함

금지:
- 과한 보라/핑크 톤
- 카드형 반복만으로 세트 구성
- 한 세트 안에서 사진 무드가 과하게 섞이는 구성
- 제주도와 무관한 도시/웨딩/실내 스튜디오 사진 사용

## 3. 무료 이미지 소스 기준

우선순위:
1. `Pexels`
2. `Unsplash`
3. `Pixabay`

검색 키워드 예시:
- `jeju island coast`
- `jeju beach`
- `jeju tangerine`
- `jeju canola`
- `jeju stone wall`
- `jeju windmill`
- `jeju road trip`
- `korea island ocean`
- `volcanic rock coast`

이미지 선택 기준:
- 자연광 위주
- 과한 필터 금지
- 브랜드 로고 노출 금지
- 페이지마다 가능하면 다른 이미지 사용
- 중복 사용 시 역할과 크롭이 확실히 달라야 함

## 4. 권장 페이지 구성

권장 페이지 수:
- `14 ~ 18`

권장 시퀀스 예시:
1. `COVER_FULL_BLEED`
2. `OPENING_EDITORIAL`
3. `MAP_AND_TITLE`
4. `COASTAL_PHOTO_FRAME`
5. `DAY_PLAN_TIMELINE`
6. `POSTCARD_GRID`
7. `QUOTE_BREAK`
8. `SPOTLIGHT_PLACE`
9. `PHOTO_STRIP`
10. `FOOD_AND_CAFE`
11. `DETAILS_AND_TICKETS`
12. `SUNSET_POSTER`
13. `MEMORIES_NOTES`
14. `ENDING_FULL_BLEED`

필수 역할:
- 풀블리드 커버 1장 이상
- 타이포 중심 페이지 2장 이상
- 사진 중심 페이지 5장 이상
- 정보 정리형 페이지 2장 이상
- 엔드 포스터형 페이지 1장 이상

## 5. 페이지별 하드 룰 초안

### COVER_FULL_BLEED
- 배경 이미지 필수
- 제목, 지역명, 여행 기간 위계 필수
- 첫 화면에서 제주 무드가 바로 읽혀야 함

### MAP_AND_TITLE
- 지도/경로/지역 텍스트가 한눈에 읽혀야 함
- 지나치게 작은 캡션 금지

### DAY_PLAN_TIMELINE
- 시간 축 또는 루트 흐름이 분명해야 함
- 정보 카드 반복만으로 끝내지 말 것

### QUOTE_BREAK
- 짧은 문장, 충분한 여백, 2~4줄 내 구성
- 사진이 있다면 배경 또는 보조 시각 요소 역할

### ENDING_FULL_BLEED
- 감정 정리형 카피
- 어두운 배경을 쓰더라도 텍스트 대비 충분히 확보

## 6. 비율 대응 원칙

- `portrait master`를 기준으로 제작한다.
- `square`, `landscape`는 `variants`로 우선 파생한다.
- 단순 축소/중앙 정렬 금지
- 풀블리드 사진은 각 비율에서 항상 캔버스를 꽉 채워야 함
- 제목/부제/메타 정보는 각 비율에서 `safe area` 안에 있어야 함
- QA에서 깨지는 페이지는 해당 페이지에 한해 비율별 Figma 원본 프레임을 추가한다.

## 7. 운영 체크리스트

- Figma 승인본 존재
- 무료 라이선스 이미지 사용 확인
- cover와 previewImages[0] 일치
- previewImages 최소 4장 이상
- 페이지별 레이아웃 다양성 확인
- 제주도 주제 일치성 확인
- 텍스트 오버플로우 없음
- CDN 이미지 404 없음
- 업로드 이미지 디코드 검증 통과
- 앱 4개 화면에서 Figma와 1:1 검수

## 8. 다음 작업 순서

1. 피그마에서 `JEJU_TRAVEL_REFINED_MASTER` 제작
2. `portrait master` 14~18페이지 구성
3. 제주도 무료 이미지 반영
4. 대표 preview 프레임 선정
5. export checklist 작성
6. CDN 업로드
7. handoff JSON / templateJson 생성
8. variant QA
9. 서버 업서트
