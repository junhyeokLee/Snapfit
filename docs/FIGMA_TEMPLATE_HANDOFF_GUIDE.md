# Figma Template Handoff Guide (Designer-Friendly)

이 문서는 디자이너가 Figma에서 만든 템플릿을 개발자가 **코드 수정 최소화**로 앱에 반영하기 위한 실무 가이드입니다.

## 1) 목표

- 디자이너는 Figma에서 레이아웃/타이포/스티커 배치를 설계
- 개발자는 JSON 핸드오프 파일을 받아 변환 스크립트 실행
- 앱은 `assets/templates/generated/latest.json`로 즉시 반영

관련 기준 문서:

- 3비율 제작 규격: `docs/FIGMA_3RATIO_MASTER_SPEC.md`
- 네이밍/매핑 규칙: `docs/FIGMA_LAYER_NAMING_AND_MAPPING_RULES.md`

## 2) 작업 순서

1. Figma에서 템플릿 아트보드 1개 제작
2. 레이어를 아래 규칙에 맞춰 네이밍
3. 핸드오프 JSON 작성 (`assets/templates/figma_handoff_example.json` 참고)
4. 변환 스크립트 실행
5. 앱에서 템플릿 미리보기/적용 결과 QA

## 3) 레이어 네이밍 규칙 (권장)

- 배경: `bg_*` (예: `bg_paper`)
- 이미지 슬롯: `img_*` (예: `img_main`, `img_sub_1`)
- 제목: `title_*` / 본문: `body_*` / 캡션: `caption_*`
- 스티커/장식: `sticker_*`, `deco_*`

상세 규칙은 `docs/FIGMA_LAYER_NAMING_AND_MAPPING_RULES.md`를 우선 따릅니다.

## 4) 좌표 규칙

- 좌표/크기는 캔버스 기준 비율값(0~1) 사용
- 예: `x=0.08, y=0.12, w=0.84, h=0.52`
- 회전은 degree

## 5) 핸드오프 JSON 필드 (v2 권장)

- `id`, `name`, `category`, `tags`, `style`, `aspect`
- `templateId`, `version`, `lifecycleStatus(draft|qa_passed|published|deprecated)`
- `previewImages` (최소 3장)
- `pages[]` (**권장, 페이지 세트 방식**):
  - `pageNumber`, `layoutId`, `role(cover|inner|chapter|end)`, `recommendedPhotoCount`
  - `layers[]`:
    - 공통: `id`, `type`, `x`, `y`, `w`, `h`, `z`, `rotation`
    - 이미지: `frame`
    - 텍스트: `text`, `align`, `textStyle`
    - 장식: `style`
- `layers[]` (레거시 fallback, pages 미존재 시에만 사용):
  - 공통: `id`, `type`, `x`, `y`, `w`, `h`, `z`, `rotation`
  - 이미지: `frame`
  - 텍스트: `text`, `align`, `textStyle`
  - 장식: `style`

> 운영 권장: 신규 템플릿은 `pages[]`만 사용하고, `layers[]`는 구버전 호환용으로만 유지합니다.

## 6) 변환 실행

```bash
cd /Users/devsheep/SnapFit/SnapFit
dart run tool/figma_handoff_import.dart \
  --input=assets/templates/figma_handoff_example.json \
  --output=assets/templates/generated/latest.json
```

스토어(커버+페이지)용 템플릿 JSON 변환:

```bash
dart run tool/build_store_templates_from_handoff.dart \
  --input=assets/templates/figma_handoff_example.json \
  --output=assets/templates/generated/store_latest.json \
  --pages=12
```

## 7) 앱 반영 확인

1. 앱 `hot restart`
2. 스토어 템플릿 상세 미리보기 확인
3. `템플릿 사용하기` 이후 커버/페이지 적용 동일성 확인
4. 텍스트 가독성/프레임/스티커 어울림 확인

## 8) 디자이너 체크리스트

- 제목 1개 + 보조 텍스트 1~2개로 과밀 방지
- 스티커는 2~5개 내에서 의도 있게 배치
- 사진 영역을 가리지 않도록 안전 여백 확보
- 텍스트 대비(명도) 4.5:1 이상

## 9) 확장 포인트

- 팀 운영 시 Figma 플러그인/스크립트로 이 JSON 자동 내보내기
- 템플릿 승인 워크플로(디자이너 승인/QA 승인/배포 승인) 분리
- 템플릿 버전(`version`) + 라이프사이클(`lifecycleStatus`) 관리

## 10) 새로운 요소(스티커/특수 레이아웃) 제한 없이 가능한가?

실무적으로는 **거의 무제한에 가깝게 확장 가능**하지만, 렌더 엔진이 이해하는 타입/키 범위는 있습니다.

- 현재 레이어 타입:
  - `image` (사진 슬롯)
  - `text` (타이포)
  - `decoration` (배경/스티커/도형 장식)
- 즉, 새 모양은 대부분 `decoration` 스타일 키로 확장합니다.

### 확장 방법

1. Figma에서 새 요소 디자인
2. 앱에서 해당 스타일 키 추가
   - 배경/도형 계열: `layer_builder_decoration_presets.dart`
   - 스티커 계열: `layer_builder_sticker_decorations.dart`
   - 프레임 계열: `layer_builder_frame_switch.dart`
3. JSON에서 `style` 또는 `frame`으로 사용

### 운영 권장

- 디자이너는 JSON에서 키만 사용하고, 신규 키 등록은 개발 파이프라인에서 처리
- 신규 키 추가 시 QA에서 iOS/Android 둘 다 렌더 확인
