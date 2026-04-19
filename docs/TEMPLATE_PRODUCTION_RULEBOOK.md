# Template Production Rulebook (v1)

이 문서는 템플릿을 "주기적으로" 추가할 때 디자인 품질과 유지보수성을 일정하게 유지하기 위한 운영 기준입니다.

## 1) Production Cadence

- 주간: 신규 4종 (세로 2, 정사각 1, 가로 1)
- 월간: 누적 16종 + 상위 템플릿 리프레시 8종
- 분기: 저성과 템플릿 정리 및 대체

## 2) Mandatory Metadata

모든 템플릿은 아래 필드를 반드시 채웁니다.

- `id`: 규칙형 ID (`pack|data` + 카테고리 + 스타일 + 일련번호)
- `name`: 2~8자 권장, 콘셉트가 바로 읽히는 이름
- `category`: 여행/커플/가족/생일/미니멀/감성/포스터 등
- `tags`: 3~6개
- `style`: editorial, soft, modern, retro, minimal 등
- `recommendedPhotoCount`: 1~8
- `difficulty`: easy/normal/hard
- `previewThumbUrl`, `previewDetailUrl`, `previewImageUrls`

## 3) Visual Quality Rules

- 텍스트 계층: 타이틀/서브/본문 역할 분리
- 타이포 스케일: 큰 제목 1개 + 보조 텍스트 1~2개로 제한
- 여백: 가장자리 최소 6% safe area 유지
- 장식 레이어: 스티커/프레임은 "의도 있는 2~5개"만 사용
- 과도한 겹침 금지: 사진/문구 가독성 우선

## 4) Preview-Apply Consistency Rules

- 미리보기와 실제 적용 레이어 구성은 동일해야 함
- 미리보기 전용 보정은 색감/크롭만 허용, 레이아웃 변경 금지
- 템플릿별 프리뷰 이미지 4장 고정 매핑 권장
- 동일 배치 템플릿끼리 이미지 중복 금지
- 스토어 카드/상세 커버/페이지 미리보기는 승인된 export 이미지 우선 사용
- `coverImageUrl == previewImages[0]` 를 강제
- `templateJson` 재렌더 미리보기는 fallback 용도로만 허용

## 5) Image Curation Rules

- 템플릿 분위기와 이미지 톤 일치 필수
- 비슷한 색상/피사체 반복 노출 금지
- 세로/정사각/가로 비율별 크롭 품질 사전 확인
- 저해상도/노이즈 심한 이미지는 제외
- Figma 최종 승인 이미지는 배포 전에 export 해서 CDN URL로 고정
- 최종 JSON에는 `figma.com/api/mcp/asset/...` 직접 저장 금지
- 로컬 asset은 fallback 또는 개발 검수용으로만 유지
- 업로드된 이미지 파일은 배포 전에 실제 디코드 검증 필수

## 6) Definition of Done

아래를 모두 만족하면 배포 가능:

- `dart analyze` 통과
- 템플릿 패널 미리보기 확인 (세로/정사각/가로)
- 적용 후 캔버스 결과 확인 (텍스트/프레임 위치 불일치 없음)
- 스크롤 성능 영향 없음 (이미지 로딩으로 프레임 저하 없음)
- 스토어/상세/편집기/읽기 화면에서 CDN 이미지와 Figma 승인본 일치 확인
- 최종 JSON의 이미지 경로가 CDN 또는 fallback asset만 사용
- 스토어 카드/상세 커버/페이지 미리보기 대표 이미지가 서로 동일함

## 6.1) Figma Parity Rules

- 템플릿은 "비슷한 톤"이 아니라 Figma 승인본과 1:1 일치해야 함
- 제목/본문이 긴 카드형 페이지는 Figma 줄바꿈 위치를 문자열 자체에 반영
- 밝은 카드형 레이아웃은 페이지 전체 다크 배경 금지
- 다크 컬러는 프레임, 보더, 오버레이 역할로만 사용하고 텍스트 배경을 덮지 않음
- 커버 타이틀/서브카피/이름은 서로 겹치지 않도록 세로 간격을 개별 검증
- 세로/정사각/가로 variant 모두에서 풀블리드 이미지는 각 비율에 맞게 다시 검증
- release gate는 줄바꿈 누락, 과한 다크 페이지 배경, 저대비 텍스트를 실패로 처리해야 함

## 7) Monthly Operating Loop

1. 신규 템플릿 16종 기획
2. 주차별 4종 제작 및 미리보기 이미지 큐레이션
3. Figma 승인 이미지 export 및 CDN 업로드
4. QA 체크리스트 통과
5. 클릭률/적용률 기준 상위 템플릿 상단 고정
6. 저성과 템플릿 이미지/문구 A/B 리프레시
