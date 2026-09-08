# 가장 빛나던 우리: 맥시멀 스크랩북

> 이전 검토안 기록이다. 현재 시안과 신규 자산은 [오브젝트 콜라주](luminous_zine_study.md)에서 관리한다.

2026-09-08. 사용자의 최신 요청에 따라 이전의 미니멀 유료 후보를 같은 URL에서 교체했다.
무료 37종과 함께여서 좋은 날 24쪽은 변경하지 않는다. 이 후보는 표지+대표 내지 6쪽이며 아직 유료 상품이 아니다.

## 구성

- 체크와 스트라이프 종이, 찢어진 편지지, 겹친 매트와 마스킹테이프.
- 새 로즈 레이스 사진 프레임, 우표 사진 매트, 하트 사진 창.
- 체크 리본·봉인·압화 콜라주 PNG, 리본 라벨·레이스 메달·하트 봉인·포스트마크·별 배지.
- 장식 서체(Samlip), 편집 가능한 흰 테두리/겹인쇄 스티커 글자, 읽기 쉬운 작은 명조 리본 문구.
- 세 규격에서 동일한 주제를 재배치. 사진과 문구는 낱개 편집을 유지한다.
- 꾸밈 재료 패널: 스티커·종이 10종, 사진 프레임 3종, 문구 구성 3종. 확대와 최신 즐겨찾기 우선 정렬을 지원한다.

초기에는 후보 전용이었다. 2026-09-08 후속 요청으로 재료는 실제 편집기에 연결했다(`paper_collage_materials.md`). 후보 앨범은 여전히 미출시이며, 별도로 가격을 설정하거나 결제를 활성화하지 않는다.
기존 outline/editionScallop/editionCameo/editionTriptych 키는 저장 문서 호환을 위해 유지한다.
같은 사진 비교 모드에서는 양쪽 칸 수로 사용 가능한 공통 사진 묶음을 제한하고, 칸 수가 더 많은 쪽은 사진을 반복한다.
원본 사진 모드는 변경하지 않는다.

## 생성 이미지

내장 image_gen 도구를 사용했다. CLI 및 앱의 OpenAI/Anthropic API는 사용하지 않았다.
앨범 전체를 AI로 생성한 것이 아니라 장식 PNG 두 장을 생성하고 레이아웃은 코드로 조판했다.
두 PNG는 1254×1254, 실제 투명 alpha이며 사진 프레임 중앙이 투명함을 검사한다.
생성 원본을 변형하지 않고 아래 프로젝트 경로에 복사했다.

- `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/luminous_lace_frame.png`
- `/Users/devsheep/SnapFit/SnapFit/assets/sticker/studio/luminous_bow_collage.png`

### 레이스 프레임 최종 프롬프트

```text
Use case: stylized-concept.
Asset type: an ORIGINAL reusable decorative photo-frame PNG for a maximalist romantic Korean scrapbook album, NOT a finished page or app mockup.
Primary request: a richly detailed ornate cut-paper frame with a rectangular empty photo aperture. Front-facing flat lay, square 1:1 canvas, perfectly symmetrical main rectangular aperture from about x=19% to81%, y=19% to81%. The aperture and all area outside the frame must be genuinely transparent alpha, not white and not a checkerboard.
Style: exquisite tactile scrapbook stationery, scalloped ivory lace-paper border, fine burgundy engraved curlicues, a narrow mint inner pinstripe, tiny pearl-like white paper dots, printed rose-pink and vermilion floral corner flourishes, a small vermilion silk ribbon tied at the top. Dense meticulous layers of cut paper with softly raised edges, celebratory editorial craft, not dark antique metal, no 3D room or perspective.
Composition: outer silhouette fills 94% of the canvas with a 3% transparent safety margin. Decorations limited to frame band and corners; the center photo aperture remains completely empty and fully transparent. All details sharp at full size.
Palette: warm white, vermilion red, pale pink, deep cranberry and fresh mint, tiny muted gold line accents.
No words, letters, numbers, people, photographs, logos or watermarks. No cast shadow outside the silhouette. This must work as an alpha overlay above a user's editable photo.
```

### 리본 콜라주 최종 프롬프트

```text
Use case: stylized-concept.
Asset type: one original transparent PNG decorative sticker cluster for a lavish romantic scrapbook album.
Primary request: a charming maximalist cutout cluster assembled from a large vermilion-red and rose-pink gingham fabric bow with long curling tails, two small heart-shaped crimson wax seals, tiny pressed daisies and pink floral sprigs, a scalloped mint paper medallion tucked behind the bow, small decorative red and white paper stars and miniature pearl accents. One cohesive irregular cluster, not a sticker sheet. Front-on flat lay.
Style: contemporary high-quality Korean diary decorating / tactile editorial collage. Realistic woven fabric, layered paper cut edges, delicate engraved details on the seals, crisp photoreal craft textures. Joyful and exuberant, bright, precious but not antique brown.
Composition: square canvas, cluster fills 88% of canvas, full silhouette visible, genuinely transparent alpha background around all edges and holes. Lots of internal detail; keep the layers coherently arranged. Centered with 5% transparent margin. White die-cut edging only immediately around individual paper pieces.
No readable text, letters, numbers, photos, people, logos, watermark, checkerboard, flat background or oversized drop shadow.
```

## 남은 출시 조건

심미적 승인, 전체 앨범 확장, 샘플 사진과 서체의 상품 배포 권리, 실기기 성능, 실제 인쇄 교정이 남아 있다.
특히 새 비트맵 프레임의 인쇄 파이프라인 사전 로딩은 판매 전 별도 검증해야 한다.
화려함을 높인 시안이며 자동 테스트 통과를 유료 가치나 경쟁사 대비 우위로 간주하지 않는다.

미리보기: http://127.0.0.1:4323/?collection=luminous-edition#/luminous-edition

## 검증 결과

- 관련 Flutter 테스트 95개 통과, 정적 분석 문제 없음, release 웹 빌드 완료.
- 무료 완성판 25면과 새 후보 7면의 세 규격 텍스트 범위·겹침·저장 왕복을 확인했다.
- 새 프레임 3종을 포함해 편집기와 미리보기의 픽셀 일치를 검사했다.
- Chrome 390×844, 844×390, 1440×900에서 후보 7면·세 규격·문구 편집·재료 탭·확대·
  재료 즐겨찾기·비교 모드 전환·무료판 복귀를 모두 확인했다. 페이지 예외와 실패한 리소스 요청은 없었다.
- 브라우저 검증 보고서: `output/template-preview/luminous-edition/browser/report.json`.
