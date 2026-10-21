enum AiDesignTopic { travel, family, baby, couple, friends, daily, celebration }

enum AiDesignMood { editorial, warm, minimal, playful, elegant }

enum AiDesignPalette { neutral, warm, cool, pastel, vivid }

enum AiDesignDensity { quiet, balanced, layered }

class AiTemplateSafeOptions {
  const AiTemplateSafeOptions({
    this.topic = AiDesignTopic.travel,
    this.mood = AiDesignMood.editorial,
    this.palette = AiDesignPalette.neutral,
    this.density = AiDesignDensity.balanced,
  });
  final AiDesignTopic topic;
  final AiDesignMood mood;
  final AiDesignPalette palette;
  final AiDesignDensity density;

  AiTemplateSafeOptions copyWith({
    AiDesignTopic? topic,
    AiDesignMood? mood,
    AiDesignPalette? palette,
    AiDesignDensity? density,
  }) => AiTemplateSafeOptions(
    topic: topic ?? this.topic,
    mood: mood ?? this.mood,
    palette: palette ?? this.palette,
    density: density ?? this.density,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'topic': topic.name,
    'mood': mood.name,
    'palette': palette.name,
    'density': density.name,
  };

  factory AiTemplateSafeOptions.fromJson(Map value) {
    if (value['version'] != 1)
      throw const FormatException('Invalid safe design');
    return AiTemplateSafeOptions(
      topic: AiDesignTopic.values.byName(value['topic'] as String),
      mood: AiDesignMood.values.byName(value['mood'] as String),
      palette: AiDesignPalette.values.byName(value['palette'] as String),
      density: AiDesignDensity.values.byName(value['density'] as String),
    );
  }

  String get summary => [
    switch (topic) {
      AiDesignTopic.travel => '여행',
      AiDesignTopic.family => '가족',
      AiDesignTopic.baby => '성장',
      AiDesignTopic.couple => '둘의 이야기',
      AiDesignTopic.friends => '친구',
      AiDesignTopic.daily => '일상',
      AiDesignTopic.celebration => '기념',
    },
    switch (mood) {
      AiDesignMood.editorial => '에디토리얼',
      AiDesignMood.warm => '따뜻함',
      AiDesignMood.minimal => '미니멀',
      AiDesignMood.playful => '경쾌함',
      AiDesignMood.elegant => '차분한 우아함',
    },
    switch (palette) {
      AiDesignPalette.neutral => '중성색',
      AiDesignPalette.warm => '따뜻한 색',
      AiDesignPalette.cool => '시원한 색',
      AiDesignPalette.pastel => '파스텔',
      AiDesignPalette.vivid => '선명한 색',
    },
    switch (density) {
      AiDesignDensity.quiet => '넉넉한 여백',
      AiDesignDensity.balanced => '균형 있는 구성',
      AiDesignDensity.layered => '풍성한 겹침',
    },
  ].join(' · ');

  // The server reconstructs the same public description from finite choices.
  // Never concatenate a private memo, user copy, photo metadata or profile.
  String get publicDescription => [
    '개인정보 없는 공용 사진집 디자인. 자연스러운 한국어 문구로 구성하세요.',
    switch (topic) {
      AiDesignTopic.travel => '여행 사진집: 풍경과 이동, 쉬어 가는 순간을 담는 보편적인 이야기',
      AiDesignTopic.family => '가족 사진집: 함께하는 평범한 하루와 따뜻한 관계를 담는 보편적인 이야기',
      AiDesignTopic.baby => '성장 사진집: 작은 변화와 일상의 발견을 담는 보편적인 이야기',
      AiDesignTopic.couple => '둘의 사진집: 함께 걷고 쉬는 순간을 담는 보편적인 이야기',
      AiDesignTopic.friends => '친구 사진집: 함께 웃고 나누는 일상을 담는 보편적인 이야기',
      AiDesignTopic.daily => '일상 사진집: 익숙한 장면 속 작은 발견을 담는 보편적인 이야기',
      AiDesignTopic.celebration => '기념 사진집: 축하와 감사의 순간을 담는 보편적인 이야기',
    },
    switch (mood) {
      AiDesignMood.editorial => '에디토리얼: 분명한 타이포 위계, 장면을 엮는 인쇄 잡지의 리듬',
      AiDesignMood.warm => '따뜻함: 부드러운 종이와 편안한 간격, 자연스러운 문장',
      AiDesignMood.minimal => '미니멀: 절제된 요소와 충분한 여백, 사진 중심의 선명한 위계',
      AiDesignMood.playful => '경쾌함: 다양한 사진 크기와 의도적인 겹침, 읽기 쉬운 즐거운 리듬',
      AiDesignMood.elegant => '차분한 우아함: 세심한 정렬과 절제된 소재, 섬세한 타이포 대비',
    },
    switch (palette) {
      AiDesignPalette.neutral => '중성색: 아이보리·회색·짙은 먹색 중심',
      AiDesignPalette.warm => '따뜻한 색: 크림·테라코타·차분한 갈색 중심',
      AiDesignPalette.cool => '시원한 색: 옅은 청색·세이지·짙은 남색 중심',
      AiDesignPalette.pastel => '파스텔: 부드러운 밝은 바탕에 읽기 쉬운 짙은 글자',
      AiDesignPalette.vivid => '선명한 색: 제한된 강조색과 읽기 쉬운 짙은 글자',
    },
    switch (density) {
      AiDesignDensity.quiet => 'quiet: 넉넉한 여백과 간결한 글, 사진의 크기와 호흡으로 변주',
      AiDesignDensity.balanced => 'balanced: 사진·글·소재의 균형과 다양한 펼침면 구성',
      AiDesignDensity.layered => 'layered: 의도적인 소재 겹침과 풍성한 구성, 글의 가독성 유지',
    },
    '특정 사람의 이름·주소·연락처·날짜·장소나 실제 있었던 사건을 지어내지 마세요. 사진은 빈 편집 슬롯으로 두고 사용자가 나중에 기기에서 채웁니다. 기존 유료 레이아웃을 복사하지 말고 각 펼침면을 독창적으로 구성하세요.',
  ].join('\n');
}
