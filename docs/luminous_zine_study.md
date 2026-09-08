# 가장 빛나던 우리: 오브젝트 콜라주

이전 시안과 에셋 제작 기록이다. 재료는 모두 보존하며 현재 다시 디자인 중인 후보는 [겹쳐진 순간](paper_photo_diary_rebuild.md)을 참고한다.

2026-09-08. 최신 피드백: 맥시멀한 방향은 유지하되, 촌스러운 장식과 같은 리본의 반복을 바꾼다.
기존 luminous-edition URL/컬렉션을 수정했다. 별도 신상품이나 새 버전을 스토어에 등록하지 않는다.

## 범위

- 표지 1면 + 내지 6면, 세로/정사각/가로 규격.
- 무료 37종 및 무료 전환한 24쪽 앨범은 변경하지 않는다.
- 후보는 unassigned/design-study/catalogPublishable=false. 아직 유료 상품이 아니다.
- 레이스·장미·리본과 Samlip 서체는 현재 후보에서 사용하지 않는다. 기존 문서 호환용 키와 파일은 유지한다.
- 코발트, 토마토 레드, 라임 옐로, 흑백을 중심으로 페이지별 배경과 비중을 바꾼다.
- RiaSans의 굵은 제목, Yeongwol 손글씨, 가는 종이 테두리 문구. 과거의 붉은 겹인쇄 효과는 이 후보에 사용하지 않는다.
- 필름 콘택트 / 찢은 프린트 / 코발트 탭 매트 3종. 사진 칸과 장식, 텍스트는 독립된 편집 레이어로 유지한다.
- 모눈, 찢은 색지, 체크 조각, 티켓, 테이프, 서클, 밑줄 7종은 네이티브 페인터로 그린다.
- 2026-09-08 추가 요청으로 후보에서 제작한 재료는 실제 편집기에 공개했다. 새 스티커·종이 23종(zine 13 + luminous 10), 프레임 9종, 꾸민 문구 7종. 후보 앨범의 상품 공개 여부와는 독립적이다. 자세한 경로와 검증은 `paper_collage_materials.md` 참고.
- 레이아웃 헬퍼의 라디안 값을 문서의 도 단위로 변환해 기울인 조판이 실제 렌더링에 반영되도록 했다.

## 스티커 배치

| 면 | 조합 |
|---|---|
| 표지 | 카메라 + 실버 별 |
| 1 | 시트러스 + 데이지 패치 |
| 2 | 선글라스 + 하트 키링 |
| 3 | 선글라스 + 카메라 |
| 4 | 데이지 패치 + 하트 키링 |
| 5 | 시트러스 + 선글라스 |
| 6 | 실버 별 + 하트 키링 |

모든 면의 조합은 서로 다르고, 각 스티커는 최대 3면에서만 사용한다.

## 생성 방식 및 저장 경로

내장 image_gen 도구로 독립적인 투명 PNG 6종을 각각 생성했다. CLI/API 대체 경로와 앱의 외부 AI API는 사용하지 않았다.
앨범 전체의 자동 AI 생성은 아니며, 장식 PNG를 생성하고 레이아웃/타이포그래피는 직접 구성했다.
생성 원본의 alpha를 유지하고 이미지 편집 없이 프로젝트에 복사했다.

### 블루 포켓 카메라

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_camera.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept.
Asset type: one original reusable die-cut sticker PNG for a contemporary maximalist photo-diary collage.
Subject: a compact cobalt-blue point-and-shoot camera, with a tomato-red shutter button, graphite lens, small yellow wrist strap loosely curling to one side. One camera only, no collage of other objects.
Art direction: independent design magazine meets a playful travel journal. Crisp tactile product illustration with convincing matte plastic and subtle print grain, carefully composed silhouette, a narrow off-white cut-paper border. Modern and graphic, not retro sepia, not cute cartoon, not baroque. Camera tilted 12 degrees as a flat-lay cutout; strap makes an expressive asymmetric silhouette.
Square image. Object fills about 85% of canvas, whole camera and strap visible. Genuinely transparent alpha background outside the die-cut silhouette. No ground, no large cast shadow.
No writing, letters, numerals, logos, flowers, lace, bows, pearls, gold ornament or watermark.
```

### 아크릴 하트 키링

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_heart_key.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept.
Asset type: one original transparent cutout sticker for a contemporary maximalist photo-diary.
Subject: a chunky translucent tomato-red acrylic heart keychain hanging from a brushed silver split ring, with a small vivid citron-yellow cord loop and a tiny rectangular cobalt acrylic tab (blank). One connected keychain object only.
Style: premium tactile product photograph / editorial sticker, casually angled flat lay, visible thickness and polished edges on translucent acrylic, subtle reflections, narrow off-white die-cut outline. Expressive sculptural shape; playful independent magazine art direction, not a children's cartoon, not vintage wedding decoration.
Square canvas, entire object centered with 7% clear margin and about 85% coverage. Genuinely transparent alpha outside object and through the ring hole. No surface, no broad shadow, no checkerboard.
Absolutely no text, logos, letters, numbers, roses, lace, bows, pearls, baroque detail or gold.
```

### 실버 포일 별

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_silver_star.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept. Asset: one original silver inflatable four-point star sticker, transparent PNG, for a contemporary graphic photo diary.
A single asymmetric rounded four-point star made from softly inflated silver foil, one long point and three shorter points, fine crimped heat-seal edge, a few tiny natural creases. Reflective silver with subtle icy-blue reflections and dark graphite accents, not rainbow holographic. Front-facing flat lay, slightly tilted. Sculptural editorial product cutout, crisp and very tactile, no kitschy decoration, no faces or eyes.
Square image, whole star fills 85% of canvas with 7% safe margin. Genuinely transparent background, no ground or large cast shadow. No words, letters, numbers, logo, border frame, bows, flowers, glitter particles, extra stars or watermark.
```

### 블루 데이지 패치

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_daisy_patch.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept. Asset type: one original embroidered fabric patch sticker for a contemporary graphic photo-diary.
One irregular six-petal electric-cobalt daisy patch with a round citron-yellow center and a slightly offset tomato-red stitch contour. Dense visible satin embroidery threads, tiny frayed off-white fabric cut edge, tactile handmade stitching but precise design, no face. Bold flat graphic silhouette mixed with realistic textile detail; joyful independent magazine and streetwear patch design.
Top-down, square canvas, the flower is centered and fills 82% of frame. Genuinely transparent alpha background, no ground, no large shadow, no checkerboard. Exactly one flower patch, no bouquet, no leaves, no labels, no words, no logo, no lace, no pearls, no bows, no vintage ornamental style.
```

### 시트러스 컷아웃

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_citrus.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept.
Asset type: one original die-cut photographic sticker of two overlapping juicy mandarin orange cross-section slices and one small deep-green leaf, for a contemporary picnic/date photo-diary collage.
Art direction: vibrant independent food magazine, extremely crisp macro citrus pulp and natural peel, saturated tangerine and soft yellow, realistic tiny droplets, irregular casual composition. Slim clean warm-white cut edge around the combined silhouette, not a rectangular photo, not a drawing, not generic flat clip art.
Square canvas, composition fills 80% with all edges visible. Genuine transparent alpha background outside the sticker. Top-down studio cutout without ground or broad drop shadow.
No labels, writing, letters, numbers, logos, ornament, lace, ribbons, bouquets, faces or watermark.
```

### 레몬 선글라스

저장 경로: `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/zine_glasses.png`

최종 생성 프롬프트:

```text
Use case: stylized-concept. Asset type: one original cutout sticker of contemporary oval sunglasses for a maximalist summer photo diary.
Subject: one pair of chunky translucent lemon-yellow acetate sunglasses, small elongated oval graphite lenses with a subtle pale-blue reflection, one arm slightly unfolded behind. A tilted front three-quarter flat-lay view that clearly shows the fashionable oval silhouette.
Style: crisp fashion-editorial product cutout, realistic thick acetate edges and tiny tactile surface details, playful bold sculptural shape, narrow off-white die-cut outline. No decorations on the glasses. No retro sepia or antique style.
Square canvas, object fills 85% of width and about 60% height, all arms visible with 6% transparent margin. Genuinely transparent alpha around the object; no ground, no wide cast shadow, no background.
No text, logos, numbers, faces, flowers, ribbons, pearls or watermark.
```

## 검증 범위

네이티브 위젯 렌더, 원본/준비 문서의 텍스트·사진·프레임 저장 호환, 3개 앨범 비율의 줄바꿈/레이어 경계, 신규 소재의 실제 alpha와 조합 다양성을 검사한다.
브라우저 검증은 390×844, 844×390, 1440×900에서 페이지 이동, 문구 편집, 소재 확대, 즐겨찾기, 무료 비교, HTTP 및 콘솔 오류를 확인한다.
실기기(Android/iOS) 및 인쇄 발주용 최종 교정은 이번 시안 검증에 포함되지 않는다.

### 확인 결과

- 전체 관련 회귀 테스트 116개 통과. 신규 종이/PNG 소재 13종의 편집기·템플릿 렌더 일치 검사 포함.
- 티켓 문구의 바코드 겹침 수정 후 소재 테스트 5개 재통과. 목록/확대 보기의 문구 오른쪽 경계를 두 화면 비율에서 검사했다.
- 변경 파일 정적 분석: No issues found.
- 최종 웹 미리보기: 390×844, 844×390, 1440×900 모두 통과. 콘솔 예외·HTTP 오류·외부 AI API 호출 없음.
- 최종 로컬 미리보기 빌드는 release/O1. 인쇄/상용 배포용 산출물은 아니다.
- 브라우저 검증 기록: `output/template-preview/luminous-edition/browser/report.json`.
- 세 규격 렌더/contact sheet: `output/template-preview/luminous-edition/{portrait,square,landscape}/`.
