class TemplateTypographyToken {
  final String titleFont;
  final String bodyFont;
  final double titleSize;
  final double bodySize;

  const TemplateTypographyToken({
    required this.titleFont,
    required this.bodyFont,
    required this.titleSize,
    required this.bodySize,
  });
}

class TemplateColorToken {
  final String background;
  final String surface;
  final String primary;
  final String secondary;
  final String accent;

  const TemplateColorToken({
    required this.background,
    required this.surface,
    required this.primary,
    required this.secondary,
    required this.accent,
  });
}

class TemplateSpacingToken {
  final double outerPadding;
  final double sectionGap;
  final double cardRadius;

  const TemplateSpacingToken({
    required this.outerPadding,
    required this.sectionGap,
    required this.cardRadius,
  });
}

class TemplateComponentRule {
  final String coverLayout;
  final String pageLayout;
  final List<String> recommendedFrames;
  final int textLayerLimit;

  const TemplateComponentRule({
    required this.coverLayout,
    required this.pageLayout,
    required this.recommendedFrames,
    required this.textLayerLimit,
  });
}

class TemplateGuide {
  final String key;
  final String name;
  final String category;
  final String tone;
  final TemplateTypographyToken typography;
  final TemplateColorToken colors;
  final TemplateSpacingToken spacing;
  final TemplateComponentRule componentRule;
  final List<String> checklist;

  const TemplateGuide({
    required this.key,
    required this.name,
    required this.category,
    required this.tone,
    required this.typography,
    required this.colors,
    required this.spacing,
    required this.componentRule,
    required this.checklist,
  });
}

class SnapFitTemplateDesignSystem {
  static const spacing = TemplateSpacingToken(
    outerPadding: 24,
    sectionGap: 16,
    cardRadius: 14,
  );

  static const guides = <TemplateGuide>[
    TemplateGuide(
      key: 'travel',
      name: '여행',
      category: '여행',
      tone: '개방감, 시원함, 여백 중심',
      typography: TemplateTypographyToken(
        titleFont: 'BookMyungjo',
        bodyFont: 'SeoulNamsan',
        titleSize: 30,
        bodySize: 14,
      ),
      colors: TemplateColorToken(
        background: '#F6EDE0',
        surface: '#FFFFFF',
        primary: '#0F766E',
        secondary: '#4B5563',
        accent: '#22A7F0',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'hero-photo + caption',
        pageLayout: '1-big photo + 2-support photos',
        recommendedFrames: ['photoCard', 'filmSquare', 'softGlow'],
        textLayerLimit: 3,
      ),
      checklist: ['커버 제목 2줄 이하', '페이지당 이미지 1~3장', '본문 대비 4.5:1 이상'],
    ),
    TemplateGuide(
      key: 'family',
      name: '가족',
      category: '가족',
      tone: '따뜻함, 안정감, 인물 중심',
      typography: TemplateTypographyToken(
        titleFont: 'SeoulNamsan',
        bodyFont: 'Run',
        titleSize: 28,
        bodySize: 14,
      ),
      colors: TemplateColorToken(
        background: '#FAFAF7',
        surface: '#FFFFFF',
        primary: '#1D4ED8',
        secondary: '#475569',
        accent: '#FFB703',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'center portrait + tape frame',
        pageLayout: '2-column portrait grid',
        recommendedFrames: ['paperTapeCard', 'collageTile'],
        textLayerLimit: 3,
      ),
      checklist: ['인물 얼굴 잘림 금지', '사진 모서리 radius 통일', '아이콘 과다 사용 금지'],
    ),
    TemplateGuide(
      key: 'couple',
      name: '연인',
      category: '연인',
      tone: '감정선, 대비, 포인트 강조',
      typography: TemplateTypographyToken(
        titleFont: 'Cormorant',
        bodyFont: 'Run',
        titleSize: 32,
        bodySize: 14,
      ),
      colors: TemplateColorToken(
        background: '#F1E8D7',
        surface: '#FFFFFF',
        primary: '#BE185D',
        secondary: '#6B7280',
        accent: '#F97316',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'center image + emotional title',
        pageLayout: 'hero + diary caption',
        recommendedFrames: ['polaroidClassic', 'posterPolaroid'],
        textLayerLimit: 4,
      ),
      checklist: ['강조 색상 1개만 사용', '본문 크기 13~15 유지', '장식은 3개 이내'],
    ),
    TemplateGuide(
      key: 'graduation',
      name: '졸업',
      category: '졸업',
      tone: '정돈, 기념, 명확한 정보',
      typography: TemplateTypographyToken(
        titleFont: 'SeoulNamsan',
        bodyFont: 'Raleway',
        titleSize: 29,
        bodySize: 13,
      ),
      colors: TemplateColorToken(
        background: '#E8F3FF',
        surface: '#FFFFFF',
        primary: '#1E40AF',
        secondary: '#64748B',
        accent: '#06B6D4',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'title top + 4cut grid',
        pageLayout: 'regular 2x2 grid',
        recommendedFrames: ['collageTile', 'filmSquare'],
        textLayerLimit: 2,
      ),
      checklist: ['인물 수평 맞춤', '그리드 간격 균일', '타이틀/날짜 구분 명확'],
    ),
    TemplateGuide(
      key: 'retro',
      name: '레트로',
      category: '레트로',
      tone: '필름, 빈티지, 질감',
      typography: TemplateTypographyToken(
        titleFont: 'Cormorant',
        bodyFont: 'Run',
        titleSize: 33,
        bodySize: 14,
      ),
      colors: TemplateColorToken(
        background: '#273240',
        surface: '#5A4A3D',
        primary: '#FFE082',
        secondary: '#E5E7EB',
        accent: '#FB923C',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'dark background + warm title',
        pageLayout: 'polaroid collage',
        recommendedFrames: ['roughPolaroid', 'filmSquare'],
        textLayerLimit: 3,
      ),
      checklist: ['채도 낮춤 유지', '텍스트 대비 확보', '필름 프레임 과다 사용 금지'],
    ),
    TemplateGuide(
      key: 'minimal',
      name: '미니멀',
      category: '미니멀',
      tone: '절제, 여백, 타이포 중심',
      typography: TemplateTypographyToken(
        titleFont: 'Raleway',
        bodyFont: 'Raleway',
        titleSize: 28,
        bodySize: 13,
      ),
      colors: TemplateColorToken(
        background: '#F5F6F8',
        surface: '#FFFFFF',
        primary: '#111827',
        secondary: '#6B7280',
        accent: '#0EA5E9',
      ),
      spacing: spacing,
      componentRule: TemplateComponentRule(
        coverLayout: 'single photo + simple headline',
        pageLayout: 'single column with breathing space',
        recommendedFrames: ['softGlow'],
        textLayerLimit: 2,
      ),
      checklist: ['불필요한 스티커 금지', '페이지당 핵심 문장 1개', '콘텐츠 간격 16 이상 유지'],
    ),
  ];
}
