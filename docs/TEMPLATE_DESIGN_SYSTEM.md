# SnapFit Template Design System

## 1) Core Tokens
- Typography
  - Title: `BookMyungjo` / `Cormorant` / `SeoulNamsan`
  - Body: `Raleway` / `Run`
  - Size rule: cover title 28~34, body 13~15
- Color
  - Keep `background/surface/primary/secondary/accent` 5-token palette
  - Text contrast target: minimum 4.5:1
- Spacing
  - 8pt grid
  - Outer padding: 24
  - Section gap: 16
  - Card radius: 14

## 2) Component Rules
- Cover composition: `hero image + short headline + style sublabel`
- Page composition patterns (rotate by page index)
  - Pattern A: 1 big image + caption
  - Pattern B: 2 split images + note
  - Pattern C: 1 top + 2 bottom collage
- Text layer rule
  - max 2~4 layers/page based on template style

## 3) Six Style Guides
- Travel: open composition, fresh colors, frame `photoCard/filmSquare`
- Family: stable portrait layout, warm neutrals, frame `paperTapeCard/collageTile`
- Couple: emotional contrast, romantic highlight, frame `polaroidClassic/posterPolaroid`
- Graduation: tidy grid and clear headings, frame `collageTile/filmSquare`
- Retro: low saturation + vintage feel, frame `roughPolaroid/filmSquare`
- Minimal: fewer decorations, more whitespace, frame `softGlow`

## 4) Production Checklist
- Title clipping 없음 (cover/list/detail)
- 360px width에서도 오버플로우 없음
- 다크/라이트에서 본문 가독성 유지
- 템플릿 적용 후 생성 앨범 커버/페이지 이미지 일치
- 템플릿 사용률/완료율 모니터링 가능

## 5) Data Contract
Frontend model (`PremiumTemplate`) fields used for operation:
- `category`, `tags`, `weeklyScore`, `isNew`

These fields must be delivered by backend template API.
