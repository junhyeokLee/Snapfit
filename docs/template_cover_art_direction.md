# 표지 사진과 구성 기준

2026-10-07. 현재 공개 카탈로그: 무료 37종, 유료 14종.

## 표지를 구분하는 기준

- 주인공 사진뿐 아니라 보조 사진도 다른 템플릿 표지와 공유하지 않는다. 현재 총 57개 사진 슬롯은 모두 다른 사진이다.
- 파일명만 바꾸거나 재인코딩한 동일 사진은 새 사진으로 인정하지 않는다. 32x32로 정규화한 실제 픽셀 비교도 검사한다. 이 검사는 동일 이미지 검출을 위한 보조 장치이며 색감·구도에 대한 사람의 검토를 대신하지 않는다.
- 같은 카테고리 안에서도 실내/야외, 낮/밤, 인물/디테일, 밝은/짙은 장면을 구분한다. 색 필터로 같은 사진을 다르게 보이게 만들지 않는다.
- 큰 제목, 정렬, 활자, 여백을 실제 사진의 비어 있는 부분에 맞춘다. 문구는 이미지에 구워 넣지 않고 편집 가능한 텍스트로 유지한다.
- 세로·정사각·가로 모두 문구 높이, 문구끼리의 겹침, 캔버스 경계, 사진 표시를 검사한다.
- 목록용 PNG도 51종 모두 실제 Flutter 표지와 픽셀 대조한다. 표지 원본을 수정하면 해당 미리보기를 재생성해야 검사에 통과한다. 목록 PNG끼리의 픽셀 중복도 별도 검사한다.
- 변경은 새 템플릿 생성 자료에만 적용한다. 고객이 저장한 앨범 레이어는 변경하지 않는다. 기존 유료 판본은 `refineCover: false`, 기존 컨셉 판본은 `refineQuality: false`로 보존한다.
- 무료 템플릿은 무료 소재만 포함한다. 표지의 교체 가능한 샘플 사진은 유료 꾸밈 소재가 아니며 가격 변경이나 추가 구매를 만들지 않는다.
- 표지 개편이 기존 인쇄·유통·판매 검수를 대신하지 않는다. 새 유료 표지 검토 상태는 `pending-visual-approval`로 기록한다.

## 제작 사진 9장

모두 내장 `image_gen.imagegen`으로 새로 생성한 사진형 샘플이며 실제 촬영 사진이라고 표시하지 않는다. 생성 원본은 Codex 이미지 폴더에 보관하고 아래 프로젝트 경로에 복사했다. 인물은 특정 실존 인물을 지정하지 않았다. 생성 요청에는 문구·로고·워터마크·테두리를 넣지 않았으며 디자인 문구는 앱에서 별도 구성한다.

공통 경로: `assets/templates/original_editorial/images/`.

| 파일 | 사용 표지 | 제작 방향 / 프롬프트 요지 |
| --- | --- | --- |
| `cover_wedding_mono.png` | 약속을 묶은 책 | Photorealistic-natural. Square monochrome Korean wedding reportage, bride in satin gown and groom in tuxedo, contemporary museum corridor, clear architectural diagonal light, figures middle-right, quiet upper-left for editable title, real textures, no blur or Mediterranean garden. |
| `cover_little_wardrobe.png` | 너의 작은 옷장 | Photorealistic-natural. Square nursery wardrobe with mustard knit cardigan, pale blue romper, white muslin dress and folded coral blanket, eucalyptus-green wall, morning light, textile detail, garments middle-right with quiet upper-left, no people or baked text. |
| `cover_family_supper.png` | 우리 집 식탁 | Photorealistic-natural. Square overhead Korean family evening meal, four pairs of natural hands, handmade celadon/cobalt ceramics, dark walnut table, vermilion striped linen, clear food texture, quiet dark wood at top for title, warm light, no pale white-table still life. |
| `cover_dog_rose.png` | 산책하고 낮잠 | Photorealistic-natural. Square eye-level Jack Russell portrait, brick-red harness, dusty pink stucco wall and burgundy leaves, entire head and ears visible, natural afternoon light, quiet upper-left, realistic fur, no green-lawn golden retriever scene. |
| `cover_cat_cobalt.png` | 작은 동거인 | Photorealistic-natural. Square tuxedo cat with yellow-green eyes on cobalt velvet chair, light-blue wall, real fur detail and daylight, face and ears visible lower-right, quiet upper-left, no gray tabby/window or gray sofa nap. |
| `cover_shared_rain.png` | 같이 사는 계절 | Photorealistic-natural. Square candid Korean couple making coffee at home, side/back view, dusty teal cabinets and burgundy mug, rainy window, warm indoor light against cool daylight, quiet teal upper-left, realistic hands and clear texture, no beige cafe. |
| `cover_generations_home.png` | 세대를 잇는 사진 | Photorealistic-natural. Square Korean grandparents, adult daughter, son-in-law and granddaughter sharing an album on a powder-blue sofa in winter, lilac wool and plum wall, all faces visible in central group, gentle window light, no outdoor picnic. |
| `cover_friends_evening.png` | 함께라서 좋은 날 | Photorealistic-natural. Square four Korean friends laughing over dinner in a contemporary restaurant, green banquette, cherry-red tile and amber lamps, all heads visible, real skin/hands and clear plates, wine-red night palette, no daytime park or graphic confetti. |
| `cover_cinema_dance.png` | 영화 같던 하루 | Photorealistic-natural. Square Korean wedding reception dance, ivory satin and dark tuxedo, oxblood velvet hall, natural hands and sharp faces in central crop-safe region, quiet upper area for editable type, no garden, cake, collage, heavy blur or baked text. |

## 기존 표지 추가 개편

- 재검사 시 현재 공개 표지의 사진 57장과 목록 PNG 51종에서 중복은 없었고, 원본과 목록 이미지도 일치했다. 다만 웨딩 표지 일부의 정원 구도가 비슷하여 저녁 무도 장면으로 구분했다.
- ‘빛으로 엮은 우리’는 전면 사진과 상단 명조 문구, ‘여행의 결’은 큰 항구 사진과 아래 기록 영역, ‘작은 날의 기록’은 라일락 색과 큰 꽃다발 사진으로 개편했다.
- 기본 3종은 `AuthoredCollection.document`의 현재 카탈로그에서만 보강한다. 직접 작성된 기존 초안 함수와 모든 내지·사용자 저장 레이어는 수정하지 않는다.
- ‘영화 같던 하루’는 별도 저녁 사진과 중앙 활자, ‘여행의 우편함’은 더 큰 우편형 사진 프레임으로 보강했다. 무료 확장 32종 중 전면 사진형 표지는 9종이다.
- 폐기된 3종과 이전 검수 판본은 판매 목록에 표시하지 않으며 저장 자료 호환용으로만 보존한다. 이들과 현행 판본의 사진 공유를 이유로 고객 앨범을 바꾸지 않는다.

## 검증과 미리보기

새 저녁 사진의 전체 생성 프롬프트 (내장 `image_gen.imagegen`, CLI/API 호출 아님):

```text
Use case: photorealistic-natural. Asset type: one exclusive full-bleed sample photograph for SnapFit's Korean wedding album cover '영화 같던 하루'. Create a high-quality square editorial photograph of an adult Korean bride and groom dancing together at their small wedding reception in the evening. Genuine affectionate smiles and natural motion, anatomically correct hands, sharp faces. Bride in contemporary white satin dress, groom in a dark tuxedo. Entire heads and bodies fit within the central 60 percent width so portrait and landscape crops remain usable. Keep the couple's heads around 42 percent down from the top and dancing bodies below. Real elegant vintage indoor hall, rich oxblood velvet curtains and warm candlelight in the background, a little cream floral arrangement at the outer edge, dark wine-colored upper area quietly available for separately added typography. Overall colors deep burgundy, ivory satin and restrained warm gold. Beautiful cinematic but crisp natural photography, realistic skin and satin texture, high detail, no artificial glow, no heavy blur, no bokeh decorations. This must look very different from a daytime garden wedding, not rustic olive trees, not wedding cake or close-up held hands. No text, typography, logos, frames or watermark; no collage. Render only the photograph, not an album mockup.
```

- `test/unit/template_cover_diversity_test.dart`: 전체 사진 독점 사용, 파일·픽셀 중복, 3규격 타이포그래피, 유료 내지·기존 판본 보존.
- `test/tool/template_cover_review_test.dart`: 실제 Flutter 렌더러로 51종 × 3규격 표지와 사진 목록 출력.
- `test/tool/catalog_thumbnail_export_test.dart`: 앱 스토어용 캐시 미리보기 재생성. 스크롤 중 복잡한 템플릿을 다시 그리지 않는 기존 구조를 유지한다.
- `test/tool/catalog_cover_audit_test.dart`: 캐시 51종 중복 검사 및 실제 최신 표지와 660px 렌더링 대조. `--dart-define=EXPORT_COVER_AUDIT=true` 실행 시 `output/settings-template-qa/catalog-cover-audit.json` 출력.
- 동일 갤러리 `output/settings-template-qa/index.html#cover-diversity`에서 전체 표지를 나란히 검토한다.

기존 스톡 사진의 원출처·권리 검토는 각 `_licenses` 문서의 기록을 유지한다. 이번 변경이 기존 미확인 권리를 확인된 것으로 바꾸지는 않는다.

## 추가 개편 검증 결과

- 공개 템플릿 51종: 무료 37종, 유료 14종 유지.
- 표지의 모든 사진 슬롯 57개: 파일 경로와 정규화한 픽셀 중복 없음.
- 표지 51종 × 세 가지 규격: 캔버스 경계·실제 글꼴 높이·문구 겹침·무료 소재 규칙 통과.
- 앱 목록용 미리보기 51종: 최신 Flutter 렌더링과 평균 픽셀 차이 0. 미리보기끼리의 중복 검사도 통과.
- 기존 기본 3종의 초안 함수와 내지·식별자·장 구성 보존 검사 통과. 기존 유료 판본 보존 검사도 통과.
- 스토어의 가로·세로 검색으로 51종을 각각 찾고 상세보기·즐겨찾기까지 확인. 펼침형 검색 UI를 반영하지 못한 예전 테스트를 보완한 후 재검사 통과.
- 이번 변경의 정적 검사 10개 파일에서 오류·경고 없음. 갤러리 이미지 72개 참조가 모두 존재.
- 실제 기기 실행 및 운영 DB 갱신은 이 검증에 포함하지 않음.

동일 갤러리 `output/settings-template-qa/index.html#refined-covers`에 기존 무료 표지 5종의 전후 비교와 전체 표지 목록을 추가했다.
