# Figma Layer Naming and JSON Mapping Rules

이 문서는 Figma 요소를 SnapFit JSON으로 안정적으로 변환하기 위한 네이밍/매핑 규칙입니다.

## 1) 레이어 ID 규칙

- 영문 소문자 + `_` 사용
- 템플릿 전체에서 고유 ID 유지
- 3비율(세로/정사각/가로) 프레임에서 동일 ID 재사용

예:
- `bg_main`
- `top_banner_bg`
- `summer_title`
- `main_photo_slot`
- `bottom_label_bg`
- `bottom_label_text`

## 2) 접두사 규칙

- 배경: `bg_`
- 사진 슬롯: `img_` 또는 `photo_` + `_slot`
- 제목: `title_`
- 본문: `body_`
- 캡션: `caption_`
- 장식/스티커: `deco_` / `sticker_`
- 라벨 배경: `label_bg_`
- 라벨 텍스트: `label_text_`

## 3) 타입 매핑

- Figma Text -> `type: "text"`
- 사진 교체 영역(Rectangle/Image) -> `type: "image"`
- 도형/배경/장식 -> `type: "decoration"`

## 4) 프레임/스타일 매핑

- `image.frame`:
  - 프레임 없음: `"none"` 또는 `""`
  - 카드 스타일: `"photoCard"` 등 앱 지원 프레임 키
- `decoration.style`:
  - 예: `paperYellow`, `paperWhite`, `blossomPinkDust`
  - 앱 엔진에 없는 키는 사용 금지

## 5) 텍스트 분리 원칙

아래는 반드시 분리:
- 타이틀 텍스트
- 하단 문구 텍스트
- 라벨 배경 도형

금지:
- 위 항목을 하나의 이미지로 병합

## 6) JSON 샘플 (완전 편집형)

```json
{
  "id": "figma_template_x",
  "name": "샘플 템플릿",
  "aspect": "portrait",
  "layers": [
    {
      "id": "top_banner_bg",
      "type": "decoration",
      "x": 0.0, "y": 0.0, "w": 1.0, "h": 0.16, "z": 1,
      "style": "paperYellow"
    },
    {
      "id": "summer_title",
      "type": "text",
      "x": 0.07, "y": 0.02, "w": 0.86, "h": 0.12, "z": 10,
      "text": "SUMMER",
      "align": "left",
      "textStyle": {
        "fontSize": 90,
        "fontFamily": "Inter",
        "fontWeight": "w800",
        "color": "#5A6642"
      }
    },
    {
      "id": "main_photo_slot",
      "type": "image",
      "x": 0.0, "y": 0.16, "w": 1.0, "h": 0.74, "z": 3,
      "frame": "none",
      "imageUrl": "https://..."
    },
    {
      "id": "bottom_label_bg",
      "type": "decoration",
      "x": 0.0, "y": 0.90, "w": 1.0, "h": 0.10, "z": 15,
      "style": "paperYellow"
    },
    {
      "id": "bottom_label_text",
      "type": "text",
      "x": 0.16, "y": 0.935, "w": 0.68, "h": 0.04, "z": 20,
      "text": "SNAPKIM 1ST ART EXHIBITION",
      "align": "center",
      "textStyle": {
        "fontSize": 30,
        "fontFamily": "Inter",
        "fontWeight": "w600",
        "color": "#000000"
      }
    }
  ]
}
```

## 7) 최종 체크

1. 레이어 ID 중복 없음
2. 텍스트가 이미지로 병합되지 않음
3. 사진 슬롯 최소 1개 이상
4. 세로/정사각/가로에서 ID 일관성 유지
