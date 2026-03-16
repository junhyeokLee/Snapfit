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

/// 스크랩북 스타일 페이지 템플릿
class PageTemplate {
  final String id;
  final String name;
  final String? thumbnailAsset;
  final List<PageTemplateSlot> slots;

  const PageTemplate({
    required this.id,
    required this.name,
    this.thumbnailAsset,
    required this.slots,
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

/// Current: 위쪽 큰 1칸 + 아래쪽 2칸 (여백 포함)
/// Collage: 2x2 균등 (여백 포함)
/// Focus: 위쪽 큰 1칸 + 아래쪽 3칸 (여백 포함)
List<PageTemplate> get pageTemplates => [
  // 1. Current – 위 큰 1칸, 아래 2칸
  PageTemplate(
    id: 'basic',
    name: 'Current',
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
    name: 'Collage',
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
    name: 'Focus',
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
  PageTemplate(id: 'journey', name: 'The Journey', slots: _journeySlots),
  // 5. Grid Mosaic – 3x3 (9칸)
  PageTemplate(id: 'grid_mosaic', name: 'Grid Mosaic', slots: _gridMosaicSlots),
  // 6. Cinematic Spread – 상단 1칸 넓게, 하단 2칸
  PageTemplate(
    id: 'cinematic',
    name: 'Cinematic Spread',
    slots: _cinematicSlots,
  ),
  // 7. Full Single – 사진 1장이 화면을 거의 꽉 채우는 레이아웃
  PageTemplate(
    id: 'full_single',
    name: 'Full · 1장',
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
    name: 'Full · 2장 세로',
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
    name: 'Full · 2장 가로',
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
    name: 'Full · 3칸 스트립',
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
    name: 'Full · 3칸 컬럼',
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
    name: 'Full · 4칸',
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
];

PageTemplate? pageTemplateById(String id) {
  try {
    return pageTemplates.firstWhere((t) => t.id == id);
  } catch (_) {
    return null;
  }
}
