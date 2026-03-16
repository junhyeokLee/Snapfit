# SnapFit 통합 템플릿 스키마 (Unified Template Schema)

결혼 축하, 스크랩북 콜라주, 하트 콜라주, 포토북 등 **여러 스타일의 템플릿을 하나의 JSON 구조로 표현**하기 위한 스키마입니다.  
선언적 레이아웃 데이터와 렌더링 엔진을 분리하는 미리캔버스/캔바 방식에 맞춰 설계했습니다.

---

## 1. 전체 구조

```json
{
  "template_id": "string",
  "version": 1,
  "canvas": { ... },
  "layers": [ ... ]
}
```

- **canvas**: 캔버스 크기, 배경색, 텍스처/장식
- **layers**: z-order대로 쌓이는 레이어 배열 (이미지, 텍스트, 스티커, 장식 등)

---

## 2. Canvas (캔버스)

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| width | number | O | 캔버스 너비 (px 또는 기준 단위) |
| height | number | O | 캔버스 높이 |
| background | string | - | 배경 색상 (#ffffff, #f5f5f0 등) |
| textureUrl | string | - | 배경 텍스처 이미지 URL (격자, 구겨진 종이 등) |
| effect | string | - | 배경 효과 키 ("grid", "crumpled_paper", "plain") |
| decorations | array | - | 배경 위에 먼저 깔리는 레이어(잎사귀, 찢어진 종이 등). 레이어와 동일 스키마, zIndex 낮음 |

**예시**

- **결혼 템플릿**: `background: "#ffffff"`, `effect: "grid"`, `decorations`: 찢어진 종이, 하늘색 선
- **스크랩북**: `textureUrl` 또는 `effect: "crumpled_paper"`
- **포토북**: `background: "#f5f0e8"`, `decorations`: 잎사귀 가지 이미지

---

## 3. Layer (레이어) 공통

모든 레이어 공통 필드:

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| id | string | O | 고유 ID |
| type | string | O | "image" \| "text" \| "sticker" \| "decoration" \| "shape" |
| zIndex | number | - | 겹침 순서(기본 0). 클 수록 앞에 그림 |
| rect | object | O | 위치·크기 (아래 참고) |
| rotation | number | - | 회전 각도(degree), 기본 0 |
| opacity | number | - | 0.0 ~ 1.0, 기본 1.0 |
| isLocked | boolean | - | 편집 잠금 |

**rect** (비율 기반 — 캔버스 대비 0.0~1.0 권장):

```json
{
  "x": 0.1,
  "y": 0.2,
  "w": 0.4,
  "h": 0.3
}
```

- 서버/클라이언트 모두 **비율**로 저장하면 해상도 독립적입니다.
- Flutter에서는 `Positioned(left: x * canvasWidth, top: y * canvasHeight, width: w * canvasWidth, height: h * canvasHeight)` 로 변환합니다.

---

## 4. 레이어 타입별 필드

### 4.1 type: "image"

| 필드 | 타입 | 설명 |
|------|------|------|
| url | string | 이미지 URL (플레이스홀더면 빈 문자열 또는 placeholder_id) |
| placeholderId | string | 사용자 사진 슬롯 식별자 (예: "photo_1", "photo_2") |
| frame | string | 프레임 스타일 ("polaroid", "film", "shadow", "tape", "mat", "none") |
| aspectRatio | string | "free", "1:1", "4:3", "3:4", "16:9" 등 (선택) |
| style.borderColor | string | 테두리 색 (#ffffff 등) |
| style.borderWidth | number | 테두리 두께 |

- **결혼**: 2개 이미지 레이어, frame: "polaroid", rotation으로 기울기
- **스크랩북**: 10개 이상 이미지, style.borderColor/borderWidth, 서로 다른 rotation·zIndex
- **하트 콜라주**: 여러 이미지, rect만 다르고 조합해 하트 형태
- **포토북**: 3개 이미지, 하나는 frame: "film", rotation 있음

### 4.2 type: "text"

| 필드 | 타입 | 설명 |
|------|------|------|
| content | string | 표시 문구. `{{workout_time}}`, `{{date}}` 등 치환자 지원 |
| bindKey | string | 치환자 키 (content에 {{bindKey}} 로 매핑) |
| style | object | 아래 참고 |
| background | string | 텍스트 스타일 키 ("tag", "bubble", "note", "calligraphy", "caption" 등) |

**style**:

| 필드 | 타입 | 설명 |
|------|------|------|
| fontSize | number | 픽셀 또는 비율 기준 |
| fontSizeRatio | number | 캔버스 너비 대비 비율 (반응형) |
| fontFamily | string | "Pretendard", "Script" 등 |
| color | string | #rrggbb 또는 #aarrggbb |
| fontWeight | number | 100~900 |
| fontStyle | string | "normal", "italic" |
| textAlign | string | "left", "center", "right" |
| underline | boolean | 밑줄 |
| highlightColor | string | 형광펜 색 (선택) |

- **결혼**: 메인 제목, 부제목, 캡션, 손글씨 메모 — background/style 조합
- **스크랩북**: "goals!", "habits", "amazing" 등 — 손글씨 스타일, 다양한 색
- **하트**: "Digital Scrapbook" — 스크립트, 단일 텍스트
- **포토북**: "PHOTOBOOK", "김씨네 여름나기", "2099.07.01" — 제목/날짜에 {{date}}, {{family_name}} 바인딩

### 4.3 type: "sticker"

스티커(이미지 기반 장식).

| 필드 | 타입 | 설명 |
|------|------|------|
| url | string | 스티커 이미지 URL |
| assetRef | string | 앱 내 에셋 키 ("heart_1", "star_pink" 등) |

- **결혼**: 하트, 꽃다발, 스마일 아이콘
- **스크랩북**: 별, 물결, 하트, 화살표, 다이아몬드, 캐릭터, 테이프

### 4.4 type: "decoration"

배경·분위기용 장식(텍스처 오버레이, 잎사귀 등). canvas.decorations에 넣거나 layers에 낮은 zIndex로 둘 수 있음.

| 필드 | 타입 | 설명 |
|------|------|------|
| url | string | 장식 이미지 URL |
| assetRef | string | 앱 내 에셋 키 |
| blendMode | string | "normal", "multiply", "overlay" 등 (선택) |

- **결혼**: 찢어진 종이, 하늘색 선
- **포토북**: 좌우 잎사귀 가지

### 4.5 type: "shape"

벡터/도형(선, 하트, 별 등). 복잡해지면 나중에 추가.

| 필드 | 타입 | 설명 |
|------|------|------|
| shapeType | string | "heart", "star", "arrow", "blob", "rectangle" 등 |
| color | string | 채우기 색 |
| strokeColor | string | 선 색 (선택) |
| strokeWidth | number | 선 두께 (선택) |

- **스크랩북**: 노란 배경 직사각형, 빨간 테두리 다이아몬드 등은 shape 또는 스티커 이미지로 표현 가능

---

## 5. 4가지 템플릿 매핑 요약

| 템플릿 | Canvas | 레이어 구성 |
|--------|--------|--------------|
| 결혼 축하 | background #fff, effect grid, decorations (찢어진 종이, 선) | 텍스트 4+ (제목/부제/캡션/메모), 이미지 2 (polaroid), 스티커 3+ (하트, 꽃, 스마일) |
| 스크랩북 콜라주 | texture/effect 구겨진 종이 | 이미지 10+, 스티커 다수, 텍스트 4+ (goals, habits 등), zIndex·rotation 다양 |
| 하트 콜라주 | background 옅은 핑크 | 이미지 N개(하트 형태 배열), 텍스트 1 (Digital Scrapbook) |
| 포토북 | background 아이보리, decorations 잎사귀 | 텍스트 3 (태그, 제목, 날짜), 이미지 3 (일반+필름스트립), rotation·zIndex |

---

## 6. 동적 바인딩 (SnapFit 특화)

텍스트 레이어의 `content`에 치환자를 넣고, 렌더 시점에 데이터로 교체합니다.

```json
{ "type": "text", "content": "오늘 {{workout_time}}분 {{workout_type}} 완료!", "bindKey": "caption" }
```

**권장 치환자 예시**

- `{{workout_time}}`, `{{workout_type}}`, `{{total_volume}}`, `{{date}}`, `{{pr_name}}`, `{{pr_weight}}`
- `{{user_name}}`, `{{family_name}}`, `{{album_creation_date}}`

Flutter에서: `content.replaceAllMapped(RegExp(r'\{\{(\w+)\}\}'), (m) => data[m.group(1)] ?? m.group(0))`

---

## 7. Flutter 렌더링 가이드

1. **캔버스**: `Container` 또는 `DecoratedBox`로 background/texture 적용 후, `Stack`으로 감쌉니다.
2. **레이어 정렬**: `layers`를 `zIndex` 기준 정렬 후, 순서대로 그리면 됩니다.
3. **각 레이어**:
   - `rect` 비율 → 절대 픽셀 (canvasSize 곱하기)
   - `Positioned` + `Transform.rotate` 로 위치·회전
   - type별: `Image`(image/sticker/decoration), `Text`(text), `CustomPaint` 또는 도형 위젯(shape)
4. **기존 코드와 연동**: 현재 `LayerModel`은 image/text만 있으므로, **sticker/decoration**은 `LayerType` 확장 + `LayerBuilder`에 분기 추가. 서버 JSON은 이 스키마로 저장하고, `fromJson` 시 `LayerModel` 또는 공통 레이어 DTO로 파싱하면 됩니다.

---

## 8. 예시 JSON (포토북 스타일 축약)

```json
{
  "template_id": "photobook_summer_001",
  "version": 1,
  "canvas": {
    "width": 1080,
    "height": 1920,
    "background": "#f5f0e8",
    "decorations": [
      {
        "id": "leaf_left",
        "type": "decoration",
        "zIndex": 0,
        "rect": { "x": 0, "y": 0, "w": 0.3, "h": 0.25 },
        "url": "https://.../leaves_left.png"
      }
    ]
  },
  "layers": [
    {
      "id": "tag",
      "type": "text",
      "zIndex": 1,
      "rect": { "x": 0.25, "y": 0.02, "w": 0.5, "h": 0.04 },
      "content": "PHOTOBOOK",
      "background": "labelOutline",
      "style": { "fontSize": 14, "color": "#6b7a6b" }
    },
    {
      "id": "title",
      "type": "text",
      "zIndex": 2,
      "rect": { "x": 0.1, "y": 0.06, "w": 0.8, "h": 0.1 },
      "content": "{{family_name}} 여름나기",
      "style": { "fontSize": 28, "fontFamily": "Calligraphy", "color": "#333333" }
    },
    {
      "id": "photo_1",
      "type": "image",
      "zIndex": 3,
      "rect": { "x": 0.05, "y": 0.18, "w": 0.4, "h": 0.25 },
      "rotation": -3,
      "placeholderId": "photo_1",
      "frame": "none",
      "style": { "borderColor": "#ffffff", "borderWidth": 2 }
    },
    {
      "id": "photo_film",
      "type": "image",
      "zIndex": 5,
      "rect": { "x": 0.25, "y": 0.5, "w": 0.5, "h": 0.22 },
      "rotation": -2,
      "placeholderId": "photo_2",
      "frame": "film"
    },
    {
      "id": "date",
      "type": "text",
      "zIndex": 6,
      "rect": { "x": 0.7, "y": 0.92, "w": 0.25, "h": 0.03 },
      "content": "{{album_creation_date}}",
      "style": { "fontSize": 12, "color": "#6b7a6b" }
    }
  ]
}
```

(실제로는 `rect` 값이 문자열이 아니라 number여야 합니다. 문서 상 오타로 보임 — 코드에서는 0.25, 0.02 등 숫자로 저장.)

이 스키마를 기준으로 서버 DTO와 Flutter 파싱/렌더링을 맞추면, 4가지 템플릿 스타일을 모두 하나의 파이프라인으로 다룰 수 있습니다.
