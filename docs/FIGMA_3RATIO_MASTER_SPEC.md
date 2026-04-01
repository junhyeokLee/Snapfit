# Figma 3-Ratio Master Spec (SnapFit)

이 문서는 SnapFit 템플릿을 Figma에서 제작할 때, 앱 렌더와 오차 없이 맞추기 위한 고정 규격입니다.

## 1) 고정 비율/프레임

- 세로형: `ratio = 0.75 (6:8)` -> `1080 x 1440`
- 정사각: `ratio = 1.0 (8:8)` -> `1440 x 1440`
- 가로형: `ratio = 1.3333 (8:6)` -> `1440 x 1080`

위 3개 프레임을 한 세트로 제작합니다.

## 2) 파일/페이지 구조

- Figma 파일 내 페이지: `Template_Master`
- 프레임 이름:
  - `cover_portrait`
  - `cover_square`
  - `cover_landscape`
  - `page_portrait`
  - `page_square`
  - `page_landscape`

권장: 커버와 페이지를 분리해서 제작하고, 같은 템플릿은 레이어 ID를 3비율에서 동일하게 유지합니다.

## 3) 레이어 타입 정책 (필수)

- `TEXT`: 수정 가능한 텍스트
- `IMAGE`: 사용자 교체 가능한 사진 슬롯
- `DECORATION`: 배경, 라벨 배경, 도형, 스티커

금지:
- 텍스트를 이미지로 합치기
- 라벨 배경+문구를 통이미지로 합치기
- 커버 전체를 단일 플랫 이미지로 고정하기

## 4) 좌표/크기 변환 규칙

앱 JSON은 비율 좌표를 사용합니다(0~1).

- `x = nodeX / frameWidth`
- `y = nodeY / frameHeight`
- `w = nodeWidth / frameWidth`
- `h = nodeHeight / frameHeight`

소수점 4자리 권장.

## 5) 텍스트 규칙

- 폰트: 앱에 실제 존재하는 폰트만 사용
- 필수 전달값:
  - `text`
  - `fontFamily`
  - `fontSize`
  - `fontWeight`
  - `color`
  - `letterSpacing`(있으면)
  - `align`

## 6) 3비율 대응 방식

원칙:
- 기본은 세로형(`portrait`) 기준 제작
- 정사각/가로형은 `aspectOverrides`로 미세 보정

예시:

```json
{
  "id": "summer_title",
  "type": "text",
  "x": 0.07, "y": 0.02, "w": 0.86, "h": 0.12,
  "z": 10,
  "text": "SUMMER",
  "align": "left",
  "textStyle": {
    "fontSize": 90,
    "fontFamily": "Inter",
    "fontWeight": "w800",
    "color": "#5A6642"
  },
  "aspectOverrides": {
    "square": { "x": 0.06, "w": 0.88 },
    "landscape": { "x": 0.05, "w": 0.90, "h": 0.14 }
  }
}
```

## 7) 안전 영역(권장)

- 상단 타이틀 안전 영역: 상단 12% 내부
- 하단 라벨 안전 영역: 하단 10% 내부
- 가장자리 여백: 최소 4%

## 8) QA 체크 (반드시)

1. 텍스트/라벨/배경이 개별 선택 가능한가
2. 세로/정사각/가로에서 요소가 겹치지 않는가
3. 미리보기와 적용 결과 톤/위치가 일치하는가
4. 이미지 슬롯이 실제 사용자 사진으로 교체 가능한가
