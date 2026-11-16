import 'package:flutter/material.dart';

/// 페이지 템플릿 내 하나의 슬롯(이미지/텍스트) 정의
/// 좌표는 캔버스 대비 비율(0.0~1.0)로 정의. 슬롯 간 여백을 두려면 left/top/width/height에 여백 반영.
class PageTemplateSlot {
  final String type; // 'image' | 'text'
  /// 캔버스 대비 비율: left, top, width, height (0.0~1.0)
  final double left;
  final double top;
  final double width;
  final double height;
  final double rotation; // 도(degree)
  final String? imageBackground;
  final String? imageTemplate;
  final String? defaultText;
  final String? textBackground;

  const PageTemplateSlot({
    required this.type,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.imageBackground,
    this.imageTemplate,
    this.defaultText,
    this.textBackground,
  });
}

enum PageLayoutCategory {
  photo,
  grid,
  editorial,
  diary;

  String get label => switch (this) {
    photo => '사진 중심',
    grid => '균형 분할',
    editorial => '매거진',
    diary => '사진과 기록',
  };
}

/// A built-in page arrangement. Its ID also identifies saved favorites.
class PageTemplate {
  final String id;
  final String name;
  final String? thumbnailAsset;
  final List<PageTemplateSlot> slots;
  final Color backgroundColor;
  final PageLayoutCategory category;
  final String description;

  int get photoCount => slots.where((slot) => slot.type == 'image').length;
  int get textCount => slots.where((slot) => slot.type == 'text').length;

  const PageTemplate({
    required this.id,
    required this.name,
    this.thumbnailAsset,
    required this.slots,
    this.backgroundColor = Colors.white,
    this.category = PageLayoutCategory.photo,
    this.description = '',
  });
}

/// 슬롯 간 여백 비율 (캔버스 기준)
const double _margin = 0.016;

// --- The Journey: 상단 1칸 가로 전체, 하단 5칸 동일 크기
List<PageTemplateSlot> get _journeySlots {
  const m = _margin;
  final topH = 0.38 - m * 1.5;
  final bottomH = 0.62 - m * 1.5;
  final bottomSlotW = (1 - m * 6) / 5;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: 1 - m * 2,
      height: topH,
      rotation: 0,
    ),
    for (int i = 0; i < 5; i++)
      PageTemplateSlot(
        type: 'image',
        left: m + (m + bottomSlotW) * i,
        top: 0.38 + m * 0.5,
        width: bottomSlotW,
        height: bottomH,
        rotation: 0,
      ),
  ];
}

// --- Grid Mosaic: 3x3 균등
List<PageTemplateSlot> get _gridMosaicSlots {
  const m = _margin;
  final cell = (1 - m * 4) / 3;
  final List<PageTemplateSlot> list = [];
  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 3; col++) {
      list.add(
        PageTemplateSlot(
          type: 'image',
          left: m + (m + cell) * col,
          top: m + (m + cell) * row,
          width: cell,
          height: cell,
          rotation: 0,
        ),
      );
    }
  }
  return list;
}

// --- Cinematic Spread: 상단 1칸 넓게(약 55%), 하단 2칸
List<PageTemplateSlot> get _cinematicSlots {
  const m = _margin;
  final topH = 0.55 - m * 1.5;
  final bottomH = 0.45 - m * 1.5;
  final halfW = (1 - m * 3) / 2;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: 1 - m * 2,
      height: topH,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: 0.55 + m * 0.5,
      width: halfW,
      height: bottomH,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: m * 2 + halfW,
      top: 0.55 + m * 0.5,
      width: halfW,
      height: bottomH,
      rotation: 0,
    ),
  ];
}

// --- Editorial Focus: 좌측 정사각형 이미지 1칸, 우측 텍스트 1칸
// ignore: unused_element
List<PageTemplateSlot> get _editorialSlots {
  const m = _margin;
  final leftW = (1 - m * 3) / 2;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: leftW,
      height: 1 - m * 2,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'text',
      left: m * 2 + leftW,
      top: m,
      width: leftW,
      height: 1 - m * 2,
      rotation: 0,
      defaultText: '오늘의 한 줄을 적어보세요',
      textBackground: 'note',
    ),
  ];
}

// --- Memory Mix: 좌상 큰 칸, 우상 중간, 하단 3칸(좌 가로막대, 중 작은 칸, 우 세로)
// ignore: unused_element
List<PageTemplateSlot> get _memoryMixSlots {
  const m = _margin;
  final big = 0.5 - m * 1.5;
  final midW = (1 - m * 3) / 2;
  final midH = 0.45 - m * 1.5;
  final bottomY = 0.45 + m;
  final bottomH = 0.55 - m * 1.5;
  final leftBarW = 0.32 - m;
  final small = 0.18;
  final rightBarX = 0.32 + m * 2 + small;
  final rightBarW = 1 - rightBarX - m;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: big,
      height: big,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: 0.5 + m * 0.5,
      top: m,
      width: midW,
      height: midH,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: 0.32 + m,
      top: bottomY + (bottomH - small) / 2,
      width: small,
      height: small,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: bottomY,
      width: leftBarW,
      height: bottomH,
      rotation: 0,
    ),
    PageTemplateSlot(
      type: 'image',
      left: rightBarX,
      top: bottomY,
      width: rightBarW,
      height: bottomH,
      rotation: 0,
    ),
  ];
}

// --- Text Heavy: 전체 영역 1개 텍스트 슬롯
// ignore: unused_element
List<PageTemplateSlot> get _textHeavySlots {
  const m = _margin;
  return [
    PageTemplateSlot(
      type: 'text',
      left: m,
      top: m,
      width: 1 - m * 2,
      height: 1 - m * 2,
      rotation: 0,
      defaultText: '여기에 텍스트를 입력하세요',
      textBackground: 'note',
    ),
  ];
}

// --- Photo + Quote: 상단 이미지 1칸, 하단 텍스트 1칸
// ignore: unused_element
List<PageTemplateSlot> get _photoQuoteSlots {
  const m = _margin;
  final topH = 0.66 - m * 1.5;
  final bottomH = 0.34 - m * 1.5;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: 1 - m * 2,
      height: topH,
      rotation: 0,
      imageBackground: 'polaroid',
    ),
    PageTemplateSlot(
      type: 'text',
      left: m,
      top: 0.66 + m * 0.5,
      width: 1 - m * 2,
      height: bottomH,
      rotation: 0,
      defaultText: '사진 아래에 캡션을 적어보세요',
      textBackground: 'tag',
    ),
  ];
}

// --- Caption Collage: 상단 2칸 이미지, 하단 캡션 텍스트 바
// ignore: unused_element
List<PageTemplateSlot> get _captionCollageSlots {
  const m = _margin;
  final topH = 0.74 - m * 1.5;
  final bottomH = 0.26 - m * 1.5;
  final halfW = (1 - m * 3) / 2;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: halfW,
      height: topH,
      rotation: 0,
      imageBackground: 'round',
    ),
    PageTemplateSlot(
      type: 'image',
      left: m * 2 + halfW,
      top: m,
      width: halfW,
      height: topH,
      rotation: 0,
      imageBackground: 'round',
    ),
    PageTemplateSlot(
      type: 'text',
      left: m,
      top: 0.74 + m * 0.5,
      width: 1 - m * 2,
      height: bottomH,
      rotation: 0,
      defaultText: '오늘의 기록',
      textBackground: 'tape',
    ),
  ];
}

// --- Scrap Note: 이미지 2칸 + 텍스트 1칸 (메모 영역)
// ignore: unused_element
List<PageTemplateSlot> get _scrapNoteSlots {
  const m = _margin;
  final leftW = 0.58 - m * 1.5;
  final rightW = 0.42 - m * 1.5;
  final topH = 0.52 - m * 1.5;
  final bottomH = 0.48 - m * 1.5;
  return [
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: m,
      width: leftW,
      height: topH,
      rotation: 0,
      imageBackground: 'film',
    ),
    PageTemplateSlot(
      type: 'image',
      left: m,
      top: 0.52 + m * 0.5,
      width: leftW,
      height: bottomH,
      rotation: 0,
      imageBackground: 'film',
    ),
    PageTemplateSlot(
      type: 'text',
      left: 0.58 + m * 0.5,
      top: m,
      width: rightW,
      height: 1 - m * 2,
      rotation: 0,
      defaultText: '메모',
      textBackground: 'note',
    ),
  ];
}

PageTemplateSlot _photoSlot(double x, double y, double w, double h) =>
    PageTemplateSlot(type: 'image', left: x, top: y, width: w, height: h);

PageTemplateSlot _textSlot(
  double x,
  double y,
  double w,
  double h, {
  String text = '짧은 기록을 남겨보세요.',
}) => PageTemplateSlot(
  type: 'text',
  left: x,
  top: y,
  width: w,
  height: h,
  defaultText: text,
);

List<PageTemplateSlot> _layoutGrid(
  int columns,
  int rows, {
  double left = .04,
  double top = .04,
  double width = .92,
  double height = .92,
  double gap = .025,
}) {
  final cellW = (width - (columns - 1) * gap) / columns;
  final cellH = (height - (rows - 1) * gap) / rows;
  return [
    for (var row = 0; row < rows; row++)
      for (var column = 0; column < columns; column++)
        _photoSlot(
          left + column * (cellW + gap),
          top + row * (cellH + gap),
          cellW,
          cellH,
        ),
  ];
}

// New arrangements use plain photo and text frames only. They require no
// purchased materials or sample photos, and work in every album proportion.
List<PageTemplate> get _additionalPageLayouts => [
  PageTemplate(
    id: 'gallery_mat',
    name: '여백 속 한 장',
    category: PageLayoutCategory.photo,
    description: '넉넉한 종이 여백으로 사진에 집중해요.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [_photoSlot(.08, .09, .84, .82)],
  ),
  PageTemplate(
    id: 'portrait_window',
    name: '세로의 순간',
    category: PageLayoutCategory.photo,
    description: '세로 사진을 가운데 길게 보여줘요.',
    slots: [_photoSlot(.24, .06, .52, .88)],
  ),
  PageTemplate(
    id: 'panorama_pair',
    name: '두 번의 파노라마',
    category: PageLayoutCategory.photo,
    description: '풍경 두 장 사이에 숨 쉴 여백을.',
    backgroundColor: const Color(0xFFF8FAFB),
    slots: [_photoSlot(.06, .09, .88, .35), _photoSlot(.06, .56, .88, .35)],
  ),
  PageTemplate(
    id: 'hero_pair_right',
    name: '한 장과 두 조각',
    category: PageLayoutCategory.photo,
    description: '큰 세로 장면 곁에 작은 사진 두 장.',
    slots: [
      _photoSlot(.04, .04, .59, .92),
      _photoSlot(.65, .04, .31, .45),
      _photoSlot(.65, .51, .31, .45),
    ],
  ),
  PageTemplate(
    id: 'hero_pair_bottom',
    name: '넓은 장면의 여운',
    category: PageLayoutCategory.photo,
    description: '대표 가로 사진 아래 두 장을 이어요.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [
      _photoSlot(.04, .04, .92, .59),
      _photoSlot(.04, .65, .45, .31),
      _photoSlot(.51, .65, .45, .31),
    ],
  ),
  PageTemplate(
    id: 'asymmetric_duo',
    name: '엇갈린 두 장',
    category: PageLayoutCategory.photo,
    description: '크기와 높이를 달리해 자연스러운 리듬.',
    slots: [_photoSlot(.05, .08, .53, .66), _photoSlot(.62, .32, .33, .56)],
  ),
  PageTemplate(
    id: 'four_windows',
    name: '네 개의 창',
    category: PageLayoutCategory.grid,
    description: '넓은 여백과 단정한 네 개의 창.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: _layoutGrid(
      2,
      2,
      left: .08,
      top: .08,
      width: .84,
      height: .84,
      gap: .06,
    ),
  ),
  PageTemplate(
    id: 'six_contact_portrait',
    name: '여섯 장 세로 모음',
    category: PageLayoutCategory.grid,
    description: '두 칸씩 세 줄로 모으는 여섯 장.',
    slots: _layoutGrid(2, 3),
  ),
  PageTemplate(
    id: 'six_contact_landscape',
    name: '여섯 장 가로 모음',
    category: PageLayoutCategory.grid,
    description: '세 칸씩 두 줄로 나란히 담아요.',
    slots: _layoutGrid(3, 2),
  ),
  PageTemplate(
    id: 'eight_contact_portrait',
    name: '여덟 장의 하루',
    category: PageLayoutCategory.grid,
    description: '하루의 장면을 두 칸씩 차곡차곡.',
    backgroundColor: const Color(0xFFF8FAFB),
    slots: _layoutGrid(2, 4),
  ),
  PageTemplate(
    id: 'eight_film',
    name: '여덟 컷 필름',
    category: PageLayoutCategory.grid,
    description: '필름을 펼치듯 네 칸씩 두 줄로.',
    slots: _layoutGrid(4, 2),
  ),
  PageTemplate(
    id: 'seven_focus',
    name: '일곱 장의 모자이크',
    category: PageLayoutCategory.grid,
    description: '대표 장면 하나와 여섯 개의 디테일.',
    slots: [
      _photoSlot(.05, .05, .58, .58),
      for (var i = 0; i < 3; i++) _photoSlot(.65, .05 + i * .20, .30, .18),
      for (var i = 0; i < 3; i++) _photoSlot(.05 + i * .31, .68, .28, .27),
    ],
  ),
  PageTemplate(
    id: 'nine_gallery',
    name: '아홉 장의 작은 전시',
    category: PageLayoutCategory.grid,
    description: '작은 사진마다 같은 여백을 둘러요.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: _layoutGrid(
      3,
      3,
      left: .07,
      top: .07,
      width: .86,
      height: .86,
      gap: .04,
    ),
  ),
  PageTemplate(
    id: 'five_mosaic',
    name: '다섯 장의 퍼즐',
    category: PageLayoutCategory.grid,
    description: '하나의 큰 장면에 네 장을 맞춰요.',
    slots: [
      _photoSlot(.04, .04, .59, .59),
      _photoSlot(.65, .04, .31, .285),
      _photoSlot(.65, .345, .31, .285),
      _photoSlot(.04, .65, .45, .31),
      _photoSlot(.51, .65, .45, .31),
    ],
  ),
  PageTemplate(
    id: 'editorial_side',
    name: '사진 곁의 이야기',
    category: PageLayoutCategory.editorial,
    description: '큰 사진과 글을 나란히 읽는 지면.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [
      _photoSlot(.06, .10, .55, .80),
      _textSlot(.65, .14, .29, .15, text: '제목을 적어보세요'),
      _textSlot(.65, .35, .29, .44),
    ],
  ),
  PageTemplate(
    id: 'editorial_hero_caption',
    name: '큰 사진, 짧은 문장',
    category: PageLayoutCategory.editorial,
    description: '사진을 크게 두고 제목과 한 줄을 더해요.',
    slots: [
      _photoSlot(.05, .05, .90, .65),
      _textSlot(.05, .76, .90, .08, text: '제목을 적어보세요'),
      _textSlot(.05, .87, .90, .08),
    ],
  ),
  PageTemplate(
    id: 'editorial_columns',
    name: '두 장의 에디토리얼',
    category: PageLayoutCategory.editorial,
    description: '사진 두 장을 제목과 기록으로 묶어요.',
    slots: [
      _textSlot(.05, .06, .90, .11, text: '이 장면의 제목'),
      _photoSlot(.05, .23, .44, .48),
      _photoSlot(.51, .23, .44, .48),
      _textSlot(.05, .77, .90, .17),
    ],
  ),
  PageTemplate(
    id: 'editorial_feature',
    name: '오늘의 특집',
    category: PageLayoutCategory.editorial,
    description: '대표 사진과 디테일로 만드는 작은 매거진.',
    backgroundColor: const Color(0xFFF8FAFB),
    slots: [
      _textSlot(.05, .05, .90, .09, text: '오늘의 이야기를 적어보세요'),
      _photoSlot(.05, .18, .57, .65),
      _photoSlot(.65, .18, .30, .30),
      _photoSlot(.65, .51, .30, .32),
      _textSlot(.05, .87, .90, .08),
    ],
  ),
  PageTemplate(
    id: 'editorial_triptych',
    name: '세 장으로 읽는 순간',
    category: PageLayoutCategory.editorial,
    description: '같은 높이의 세 장과 여유 있는 문장.',
    slots: [
      _textSlot(.05, .07, .90, .14, text: '이 장면의 제목'),
      ..._layoutGrid(
        3,
        1,
        left: .05,
        top: .30,
        width: .90,
        height: .47,
        gap: .025,
      ),
      _textSlot(.05, .83, .90, .12),
    ],
  ),
  PageTemplate(
    id: 'daily_postcard',
    name: '오늘의 엽서',
    category: PageLayoutCategory.diary,
    description: '사진 한 장과 그날의 마음을 엽서처럼.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [
      _photoSlot(.08, .08, .84, .56),
      _textSlot(.08, .70, .84, .08, text: '오늘의 제목'),
      _textSlot(.08, .82, .84, .12),
    ],
  ),
  PageTemplate(
    id: 'two_scenes_note',
    name: '두 장과 한 줄',
    category: PageLayoutCategory.diary,
    description: '함께 간직할 두 장과 짧은 일기.',
    slots: [
      _photoSlot(.05, .07, .44, .55),
      _photoSlot(.51, .07, .44, .55),
      _textSlot(.05, .69, .90, .10, text: '함께 남길 제목'),
      _textSlot(.05, .83, .90, .12),
    ],
  ),
  PageTemplate(
    id: 'photo_left_journal',
    name: '사진 옆 작은 일기',
    category: PageLayoutCategory.diary,
    description: '왼쪽에는 장면을, 오른쪽에는 마음을.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [
      _photoSlot(.05, .08, .42, .38),
      _photoSlot(.05, .50, .42, .38),
      _textSlot(.53, .08, .42, .15, text: '오늘의 제목'),
      _textSlot(.53, .29, .42, .57),
    ],
  ),
  PageTemplate(
    id: 'three_moment_notes',
    name: '장면마다 한 줄',
    category: PageLayoutCategory.diary,
    description: '세 장의 사진에 각자의 이야기를 붙여요.',
    slots: [
      for (var i = 0; i < 3; i++) ...[
        _photoSlot(.05, .06 + i * .30, .40, .25),
        _textSlot(.49, .09 + i * .30, .46, .20),
      ],
    ],
  ),
  PageTemplate(
    id: 'four_scenes_reflection',
    name: '네 장으로 돌아보기',
    category: PageLayoutCategory.diary,
    description: '사진 네 장 아래 한 달의 기억을 남겨요.',
    backgroundColor: const Color(0xFFFFFCF7),
    slots: [
      ..._layoutGrid(
        2,
        2,
        left: .06,
        top: .06,
        width: .88,
        height: .57,
        gap: .03,
      ),
      _textSlot(.06, .71, .88, .08, text: '기억하고 싶은 제목'),
      _textSlot(.06, .83, .88, .12),
    ],
  ),
];

/// Current: 위쪽 큰 1칸 + 아래쪽 2칸 (여백 포함)
/// Collage: 2x2 균등 (여백 포함)
/// Focus: 위쪽 큰 1칸 + 아래쪽 3칸 (여백 포함)
List<PageTemplate> get pageTemplates => [
  // 1. Current – 위 큰 1칸, 아래 2칸
  PageTemplate(
    id: 'basic',
    category: PageLayoutCategory.photo,
    description: '큰 사진 한 장에 두 장의 장면을 더해요.',
    name: '세 장의 흐름',
    backgroundColor: const Color(0xFFFFFBF5),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: 1 - _margin * 2,
        height: (2 / 3) - _margin * 1.5,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: (2 / 3) + _margin * 0.5,
        width: (1 - _margin * 3) / 2,
        height: (1 / 3) - _margin * 1.5,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: (2 / 3) + _margin * 0.5,
        width: (1 - _margin * 3) / 2,
        height: (1 / 3) - _margin * 1.5,
        rotation: 0,
      ),
    ],
  ),
  // 2. Collage – 2x2
  PageTemplate(
    id: 'collage',
    category: PageLayoutCategory.grid,
    description: '네 장을 같은 크기로 정돈해요.',
    name: '콜라주',
    backgroundColor: const Color(0xFFF8F5EF),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin * 2 + (1 - _margin * 3) / 2,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: _margin * 2 + (1 - _margin * 3) / 2,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
    ],
  ),
  // 3. Focus – 위 큰 1칸, 아래 3칸
  PageTemplate(
    id: 'focus',
    category: PageLayoutCategory.photo,
    description: '대표 사진과 세 장의 작은 장면.',
    name: '한 장에 집중',
    backgroundColor: const Color(0xFFFFF8F0),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: 1 - _margin * 2,
        height: (2 / 3) - _margin * 1.5,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: (2 / 3) + _margin * 0.5,
        width: (1 - _margin * 4) / 3,
        height: (1 / 3) - _margin * 1.5,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 4) / 3,
        top: (2 / 3) + _margin * 0.5,
        width: (1 - _margin * 4) / 3,
        height: (1 / 3) - _margin * 1.5,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 3 + ((1 - _margin * 4) / 3) * 2,
        top: (2 / 3) + _margin * 0.5,
        width: (1 - _margin * 4) / 3,
        height: (1 / 3) - _margin * 1.5,
        rotation: 0,
      ),
    ],
  ),
  // 4. The Journey – 상단 1칸 가로 넓게, 하단 5칸 동일
  PageTemplate(
    id: 'journey',
    category: PageLayoutCategory.grid,
    description: '넓은 장면 아래 다섯 장을 모아요.',
    name: '여행의 장면들',
    backgroundColor: const Color(0xFFF7FBFF),
    slots: _journeySlots,
  ),
  // 5. Grid Mosaic – 3x3 (9칸)
  PageTemplate(
    id: 'grid_mosaic',
    category: PageLayoutCategory.grid,
    description: '아홉 장으로 한눈에 보는 하루.',
    name: '아홉 장 모자이크',
    backgroundColor: const Color(0xFFFAF8FF),
    slots: _gridMosaicSlots,
  ),
  // 6. Cinematic Spread – 상단 1칸 넓게, 하단 2칸
  PageTemplate(
    id: 'cinematic',
    category: PageLayoutCategory.photo,
    description: '가로 장면과 두 장의 후속 컷.',
    name: '시네마틱 장면',
    backgroundColor: const Color(0xFFF4F5F7),
    slots: _cinematicSlots,
  ),
  // 7. Full Single – 사진 1장이 화면을 거의 꽉 채우는 레이아웃
  PageTemplate(
    id: 'full_single',
    category: PageLayoutCategory.photo,
    description: '한 장을 가장 크게 보여줘요.',
    name: '가득 채우기 · 한 장',
    backgroundColor: const Color(0xFFFFFFFF),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: 1 - _margin * 2,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
    ],
  ),
  // 8. Full Duo Vertical – 좌/우 2장, 세로로 크게
  PageTemplate(
    id: 'full_duo_vertical',
    category: PageLayoutCategory.photo,
    description: '두 장을 좌우로 크게 나란히.',
    name: '가득 채우기 · 나란히',
    backgroundColor: const Color(0xFFF7FBF7),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
    ],
  ),
  // 9. Full Duo Horizontal – 상/하 2장, 가로로 크게
  PageTemplate(
    id: 'full_duo_horizontal',
    category: PageLayoutCategory.photo,
    description: '두 장의 가로 사진을 위아래로.',
    name: '가득 채우기 · 위아래',
    backgroundColor: const Color(0xFFFFFAF4),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: 1 - _margin * 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin * 2 + (1 - _margin * 3) / 2,
        width: 1 - _margin * 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
    ],
  ),
  // 10. Full Triple Strip – 세로로 3등분한 스트립 레이아웃 (위/중/아래)
  PageTemplate(
    id: 'full_triple_strip',
    category: PageLayoutCategory.grid,
    description: '세 장의 가로 사진을 차례대로.',
    name: '가득 채우기 · 세 줄',
    backgroundColor: const Color(0xFFF7FBFF),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: 1 - _margin * 2,
        height: (1 - _margin * 4) / 3,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin * 2 + (1 - _margin * 4) / 3,
        width: 1 - _margin * 2,
        height: (1 - _margin * 4) / 3,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin * 3 + ((1 - _margin * 4) / 3) * 2,
        width: 1 - _margin * 2,
        height: (1 - _margin * 4) / 3,
        rotation: 0,
      ),
    ],
  ),
  // 11. Full Triple Columns – 세로 3분할 컬럼 레이아웃
  PageTemplate(
    id: 'full_triple_columns',
    category: PageLayoutCategory.grid,
    description: '세 장의 세로 사진을 한 줄에.',
    name: '가득 채우기 · 세 칸',
    backgroundColor: const Color(0xFFFAF7FF),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: (1 - _margin * 4) / 3,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 4) / 3,
        top: _margin,
        width: (1 - _margin * 4) / 3,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 3 + ((1 - _margin * 4) / 3) * 2,
        top: _margin,
        width: (1 - _margin * 4) / 3,
        height: 1 - _margin * 2,
        rotation: 0,
      ),
    ],
  ),
  // 12. Full 4-Grid – 2x2 균등(상/하 2칸씩), Collage보다 여백을 조금만 두는 버전
  PageTemplate(
    id: 'full_four_grid',
    category: PageLayoutCategory.grid,
    description: '빈틈을 줄인 네 장의 구성.',
    name: '가득 채우기 · 네 칸',
    backgroundColor: const Color(0xFFF8F8F8),
    slots: [
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: _margin,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin,
        top: _margin * 2 + (1 - _margin * 3) / 2,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
      PageTemplateSlot(
        type: 'image',
        left: _margin * 2 + (1 - _margin * 3) / 2,
        top: _margin * 2 + (1 - _margin * 3) / 2,
        width: (1 - _margin * 3) / 2,
        height: (1 - _margin * 3) / 2,
        rotation: 0,
      ),
    ],
  ),
  ..._additionalPageLayouts,
];

PageTemplate? pageTemplateById(String id) {
  try {
    return pageTemplates.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}
