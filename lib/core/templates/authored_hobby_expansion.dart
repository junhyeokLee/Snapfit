part of 'authored_collections.dart';

/// Photo apertures preserve all five exclusive3:2 sources; no face crop is added.
Rect _hobbyPhoto(_StoryPage p, int n, Rect region, {bool framed = false}) {
  if (framed) return _storyMountedPhoto(p, n, region, mount: 0);
  final w = math.min(region.width, region.height * 1.5 / p.ratio);
  final rect = Rect.fromCenter(
    center: region.center,
    width: w,
    height: w * p.ratio / 1.5,
  );
  p.image(n, rect);
  p.layers.last['storyPhotoSourceAspect'] = 1.5;
  return rect;
}

Rect _hobbyPaper(_StoryPage p, Rect region) {
  final spec = studioDecorationById(p.edition.paperId)!;
  final w = math.min(region.width, region.height * spec.aspectRatio / p.ratio);
  final rect = Rect.fromCenter(
    center: region.center,
    width: w,
    height: w * p.ratio / spec.aspectRatio,
  );
  p.piece(p.edition.paperId, rect);
  p.layers.last['hobbyRecordCard'] = true;
  return rect;
}

/// Native hinting is applied at the final printed size. A scaled source box
/// alone can clip the real ascenders of Eulyoo and the handwritten faces.
void _diversityWordArt(_StoryPage p, Rect region) {
  final art = studioWordArtById(p.edition.wordArtId)!;
  final source = art.sourceSize;
  final canvas = p.aspect.canvas;
  final scale = math.min(
    region.width * canvas.width / source.width,
    region.height * canvas.height / source.height,
  );
  final origin =
      Offset(region.left * canvas.width, region.top * canvas.height) +
      Offset(
        (region.width * canvas.width - source.width * scale) / 2,
        (region.height * canvas.height - source.height * scale) / 2,
      );
  for (final layer in art.previewLayers()) {
    var scaled = layer.copyWith(
      position: origin + layer.position * scale,
      width: layer.width * scale,
      height: layer.height * scale,
      textStyle: layer.textStyle?.copyWith(
        fontSize: layer.textStyle!.fontSize! * scale,
      ),
    );
    if (layer.type.name == 'text') {
      final painter = TextPainter(
        text: TextSpan(text: scaled.text, style: scaled.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: scaled.textAlign ?? TextAlign.left,
      )..layout(maxWidth: scaled.width);
      final measuredHeight = painter.height + .5;
      painter.dispose();
      scaled = scaled.copyWith(
        position:
            scaled.position + Offset(0, (scaled.height - measuredHeight) / 2),
        height: measuredHeight,
      );
    }
    final raw = LayerExportMapper.toJson(scaled, canvasSize: canvas);
    raw.addAll({
      'type': layer.type.name,
      'id':
          '${p.edition.id}_${p.aspect.name}_${p.index}_word_${p.layers.length}',
      'z': p.layers.length,
      'wordArtId': p.edition.wordArtId,
      'templateContent': true,
    });
    p.layers.add(raw);
  }
}

void _hobbyExpansionCover(_StoryPage p) {
  final e = p.edition;
  final mode = e.coverStyle - 40;
  final spec = hobbyExpansionSpecs[e.id]!;
  void ko(Rect r, {double size = .080, String align = 'left'}) {
    final value = studioWordArtById(e.wordArtId)!.text;
    final available = Size(
      r.width * p.aspect.canvas.width,
      r.height * p.aspect.canvas.height,
    );
    var pixels = p.unit * size;
    // These nine new jackets measure the same natural glyph metrics used by
    // the renderer. Forced struts underestimate NanumPen/Maker ascenders.
    for (var attempt = 0; attempt < 36; attempt++) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: spec.font,
            fontSize: pixels,
            height: 1.35,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align == 'center' ? TextAlign.center : TextAlign.left,
      )..layout(maxWidth: available.width - 1);
      final measuredHeight = painter.height;
      final fits =
          measuredHeight <= available.height - 1 &&
          painter.computeLineMetrics().every(
            (line) => line.width <= available.width - 1,
          );
      painter.dispose();
      if (fits) break;
      pixels *= math.min(.97, (available.height - 1) / measuredHeight * .985);
    }
    p.text(
      p.uid,
      value,
      r.left,
      r.top,
      r.width,
      r.height,
      size: pixels / p.unit,
      font: spec.font,
      weight: 400,
      color: mode == 2 ? '#F4F0E7' : e.ink,
      align: align,
      lineHeight: 1.35,
    );
    p.layers.last['editorialTextRole'] = 'headline';
    p.layers.last['templateContent'] = true;
  }

  void en(Rect r, {double size = .025, String align = 'left'}) => p.type(
    e.englishTitle.replaceAll('\n', ' '),
    r,
    size: size,
    font: 'Cormorant Garamond',
    color: mode == 2 ? '#DFB79B' : e.accent,
    align: align,
  );
  p.box(
    p.uid,
    0,
    0,
    1,
    1,
    mode == 2
        ? '#222C33'
        : mode == 3
        ? '#F5E8D4'
        : '#F6F2E9',
  );
  switch (mode) {
    case 0:
      ko(const Rect.fromLTWH(.07, .07, .70, .23), size: .084);
      p.piece(e.motifId, const Rect.fromLTWH(.78, .09, .18, .18));
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.045, .35, .91, .48));
      en(const Rect.fromLTWH(.07, .87, .72, .045), size: .036);
      p.type(
        '손의 속도로 만든 기록',
        const Rect.fromLTWH(.07, .94, .86, .03),
        size: .020,
        font: 'BookMyungjo',
      );
    case 1:
      ko(const Rect.fromLTWH(.08, .055, .84, .16), size: .067, align: 'center');
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.13, .27, .74, .51), framed: true);
      en(const Rect.fromLTWH(.08, .83, .84, .06), size: .035, align: 'center');
      p.type(
        '빛 · 물 · 자라는 시간',
        const Rect.fromLTWH(.11, .94, .72, .035),
        size: .020,
        font: 'BookMyungjo',
        align: 'center',
      );
    case 2:
      p.type(
        'WEEKEND\nNEGATIVES',
        const Rect.fromLTWH(.065, .06, .87, .18),
        size: .066,
        font: 'Poppins',
        color: '#F4F0E7',
        role: 'headline',
      );
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.04, .30, .92, .48), framed: true);
      ko(const Rect.fromLTWH(.07, .815, .86, .11), size: .047);
      p.type(
        '35 MM / PERSONAL CONTACT BOOK',
        const Rect.fromLTWH(.07, .945, .86, .025),
        size: .014,
        font: 'Poppins',
        color: '#DFB79B',
      );
    case 3:
      en(
        const Rect.fromLTWH(.08, .045, .84, .045),
        size: .035,
        align: 'center',
      );
      ko(const Rect.fromLTWH(.08, .125, .84, .17), size: .072, align: 'center');
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.055, .35, .89, .49), framed: true);
      p.type(
        '굽고 · 나누고 · 다시 만들다',
        const Rect.fromLTWH(.08, .91, .84, .05),
        size: .025,
        font: 'BookMyungjo',
        align: 'center',
      );
    case 4:
      en(const Rect.fromLTWH(.06, .055, .88, .05), size: .031);
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.045, .21, .59, .49), framed: true);
      _hobbyPhoto(p, 1, const Rect.fromLTWH(.66, .40, .30, .26));
      p.piece(e.motifId, const Rect.fromLTWH(.72, .15, .22, .20));
      ko(const Rect.fromLTWH(.07, .73, .86, .23), size: .092);
    case 5:
      for (var n = 0; n < 3; n++)
        p.line(Rect.fromLTWH(.07, .06 + n * .014, .86, .0014));
      ko(const Rect.fromLTWH(.07, .16, .86, .23), size: .088);
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.055, .46, .89, .44), framed: true);
      p.type(
        '작은 변화까지 듣고 남기는 시간',
        const Rect.fromLTWH(.07, .94, .86, .03),
        size: .020,
        font: 'BookMyungjo',
      );
    case 6:
      ko(const Rect.fromLTWH(.07, .045, .86, .23), size: .087);
      p.piece(e.motifId, const Rect.fromLTWH(.09, .30, .21, .19));
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.45, .29, .49, .35), framed: true);
      _hobbyPhoto(p, 1, const Rect.fromLTWH(.055, .52, .39, .34));
      p.line(const Rect.fromLTWH(.55, .75, .30, .002));
      en(const Rect.fromLTWH(.55, .81, .38, .06), size: .025);
      p.type(
        '모은 조각으로 쓰는 나의 순서',
        const Rect.fromLTWH(.07, .94, .86, .03),
        size: .020,
        font: 'BookMyungjo',
      );
    case 7:
      p.type(
        'A PERSONAL EXHIBITION ARCHIVE',
        const Rect.fromLTWH(.06, .04, .88, .03),
        size: .015,
        font: 'Poppins',
        color: e.accent,
      );
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.045, .13, .91, .46), framed: true);
      ko(const Rect.fromLTWH(.07, .67, .86, .21), size: .077);
      en(const Rect.fromLTWH(.07, .925, .86, .04), size: .028);
    default:
      p.box(p.uid, .035, .035, .93, .93, e.tint);
      en(const Rect.fromLTWH(.07, .06, .86, .04), size: .029);
      _hobbyPhoto(p, 0, const Rect.fromLTWH(.055, .16, .89, .48), framed: true);
      ko(const Rect.fromLTWH(.07, .71, .70, .19), size: .084);
      p.piece(e.motifId, const Rect.fromLTWH(.79, .75, .16, .16));
      p.type(
        '밖에서 찾은 나의 속도',
        const Rect.fromLTWH(.07, .94, .86, .03),
        size: .020,
        font: 'BookMyungjo',
      );
  }
}

/// Each surface asks for a different part of its hobby, never repeated filler.
const _hobbyRecordCopies = <String, Map<int, (String, String, String)>>{
  'story-hobby-clay': {
    2: ("건조 날짜 · 표면 상태", "마르기 전후의 모양과\n금이 간 곳을 살펴 적어요.", "건조하며 발견한 변화"),
    8: ("흙 종류 · 물의 양", "흙과 물을 어떻게 섞었나요?\n손에 닿은 느낌을 남겨요.", "다음 배합의 기준"),
    16: ("유약 색 · 굽는 온도", "고른 유약과 구운 뒤의 색을\n작은 시편처럼 기록해요.", "가마 뒤에서 배운 것"),
    11: ("다음에 빚을 모양", "새로 시도할 형태와\n바꾸고 싶은 과정을 적어요.", "다음 작업의 첫 손길"),
  },
  'story-hobby-leaf': {
    2: ("잎 색 · 크기 · 새순", "어제와 다른 잎의 표정은?\n새로 발견한 부분을 적어요.", "가까이에서 본 초록"),
    8: ("물 준 날 · 햇빛 · 자리", "흙의 마름과 빛의 길이를\n식물의 자리와 함께 남겨요.", "나에게 맞는 돌봄 조건"),
    16: ("오늘 한 돌봄 · 반응", "분갈이와 가지 정리 뒤\n식물이 어떻게 달라졌나요?", "손을 보탠 날의 기록"),
    11: ("다음 계절 · 바꿀 자리", "다음 계절에 필요한 돌봄과\n기다리는 변화를 적어요.", "새잎과 다음 계절"),
  },
  'story-hobby-film': {
    2: ("장소 · 빛 · 노출", "어떤 빛에서 찍었나요?\n셔터와 조리개를 남겨요.", "촬영 순간의 조건"),
    8: ("롤 번호 · 장소 · 노출", "한 롤의 장소와 순서를\n기억할 단서로 정리해요.", "한 롤을 다시 찾는 색인"),
    16: ("현상 날짜 · 색의 느낌", "기대한 색과 실제 색은?\n마음에 남은 컷을 골라요.", "현상 뒤의 작은 회고"),
    11: ("다음 필름 · 걷고 싶은 곳", "다음 롤로 만나고 싶은 빛과\n다시 찍을 장면을 적어요.", "새 롤의 출발점"),
  },
  'story-hobby-bake': {
    2: ("재료 · 무게 · 바꾼 양", "무엇을 얼마나 넣었나요?\n대신 쓴 재료도 남겨요.", "반죽의 시작을 정확하게"),
    8: ("휴지 시간 · 온도 · 분", "기다린 시간과 오븐 온도를\n익은 색과 함께 적어요.", "다시 굽기 위한 조건"),
    16: (
      "향 · 식감 · 함께 맛본 말",
      "바삭함과 촉촉함은 어땠나요?\n첫 한 입의 반응을 남겨요.",
      "나누어 먹은 맛의 메모",
    ),
    11: ("다음 메뉴 · 바꿔 볼 점", "다음에는 어떤 모양과 맛을?\n새 레시피의 시작을 적어요.", "다음 오븐 앞에서"),
  },
  'story-hobby-knit': {
    2: ("실 이름 · 굵기 · 바늘", "실의 색과 만져 본 느낌,\n선택한 바늘을 기록해요.", "손에 맞춘 재료와 도구"),
    8: ("코 수 · 단 수 · 스와치", "정해진 길이에 몇 코였나요?\n힘을 바꾼 결과도 적어요.", "나만의 게이지 기준"),
    16: ("오늘 뜬 곳 · 풀어 본 곳", "어디까지 이어 왔나요?\n배운 무늬와 실수를 남겨요.", "한 코씩 쌓인 진도"),
    11: ("다음 작품 · 남은 실", "남은 실로 무엇을 만들까요?\n새로 익힐 무늬를 적어요.", "다음 계절을 짓는 계획"),
  },
  'story-hobby-music': {
    2: ("곡 · 구간 · 손의 위치", "어디에서 멈추었나요?\n손과 호흡의 느낌을 남겨요.", "한 소절을 자세히 듣기"),
    8: ("빠르기 · 박자 · 반복 수", "어떤 속도로 나누어 쳤나요?\n반복한 구간을 표시해요.", "연습을 다시 찾는 표"),
    16: ("좋았던 소리 · 바꿀 소리", "오늘 자연스러웠던 한 음과\n다시 들을 부분을 적어요.", "귀로 확인한 작은 변화"),
    11: (
      "다음 곡 · 연습할 한 구간",
      "다음에는 무엇부터 해 볼까요?\n먼저 듣고 싶은 소리를 적어요.",
      "다음 연습의 첫 음",
    ),
  },
  'story-hobby-paper': {
    2: ("조각 · 모은 곳 · 날짜", "어디서 만난 종이인가요?\n주머니 속 단서를 적어요.", "작은 조각의 출처"),
    8: ("색 · 질감 · 붙일 순서", "어떤 색끼리 어울리나요?\n붙이기 전의 순서를 남겨요.", "조각을 잇는 배치 노트"),
    16: ("붙인 것 · 비워 둔 곳", "무엇을 남기고 덜었나요?\n완성 뒤의 느낌을 적어요.", "한 장을 완성한 기록"),
    11: ("다음 조각 · 모으고 싶은 색", "다음에는 무엇을 모을까요?\n빈자리에 놓을 단서를 적어요.", "다음 페이지의 수집"),
  },
  'story-hobby-gallery': {
    2: ("멈춘 작품 · 바라본 거리", "어떤 장면 앞에 오래 섰나요?\n가까이 본 부분을 남겨요.", "한 작품과 나눈 시간"),
    8: ("전시 이름 · 공간 · 동선", "어떤 순서로 걸었나요?\n다시 찾을 방을 표시해요.", "관람을 되짚는 색인"),
    16: (
      "남은 질문 · 달라진 생각",
      "보기 전과 무엇이 달라졌나요?\n나의 감상을 문장으로 적어요.",
      "작품을 지나 남은 생각",
    ),
    11: ("다음 전시 · 새로 볼 것", "어떤 공간을 더 만나고 싶나요?\n이어 갈 질문을 적어요.", "다음 관람의 여백"),
  },
  'story-hobby-camp': {
    2: ("장비 · 설치 순서 · 자리", "설치하며 어려웠던 점은?\n편했던 배치를 남겨요.", "텐트가 서는 과정"),
    8: ("함께 먹은 것 · 밤의 소리", "오늘 바깥에서 무엇을 느꼈나요?\n랜턴 아래의 기억을 적어요.", "야외에서 보낸 하루"),
    16: ("바람 · 그늘 · 가까운 길", "어느 쪽이 편안했나요?\n머문 자리의 조건을 그려요.", "다시 찾아올 캠프 지도"),
    11: ("다음 장소 · 챙길 준비물", "다음에는 어디에 머물까요?\n가볍게 바꿀 짐을 적어요.", "다음 주말을 위한 약속"),
  },
};

/// Explicit semantic breaks prevent isolated final syllables in display type.
const _hobbyDisplayPhrases = <String, String>{
  'story-hobby-clay': "조금 다른 모양도,\n내가 만든 기록.",
  'story-hobby-leaf': "자라는 속도에\n나의 하루를 맞추다.",
  'story-hobby-film': "우연까지 한 롤에\n남기는 주말.",
  'story-hobby-bake': "조금 서툴러도\n따뜻하게 구워지는 하루.",
  'story-hobby-knit': "서두르지 않고 한 코씩,\n나의 계절을 짓다.",
  'story-hobby-music': "잘된 한 소절과\n다시 해 볼 한 소절.",
  'story-hobby-paper': "그날의 색과 조각을\n나의 순서로 모으다.",
  'story-hobby-gallery': "작품 앞에서\n잠시 달라진\n나의 시선.",
  'story-hobby-camp': "하루의 속도를 낮추고\n바깥의 시간을 켜다.",
};

/// Eighteen composition roles are sequenced differently for all nine books.
/// Large uncut scenes alternate with process details, collected material and
/// writing surfaces. This does not retain a generated book or decoded photos.
List<_StoryPage> _hobbyExpansionSpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final spec = hobbyExpansionSpecs[e.id]!;
  final mode = e.coverStyle - 40;
  final layout = spec.spreadOrder[i];
  final l = _StoryPage(
    e,
    aspect,
    i * 2 + 1,
    (i + mode) % 5 == 2 ? e.tint : '#F7F3EB',
  );
  final r = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    (i + mode) % 7 == 4 ? e.tint : '#FAF7F0',
  );
  final n = (i * 3 + mode) % 5;
  void photo(_StoryPage p, int index, Rect area, {bool framed = false}) =>
      _hobbyPhoto(p, index, area, framed: framed);
  void title(_StoryPage p, Rect area, {double size = .045}) => p.type(
    e.chapters[i],
    area,
    size: size,
    font: spec.font,
    role: 'headline',
  );
  void note(_StoryPage p, Rect area, {double size = .026}) =>
      p.type(e.notes[i], area, size: size, font: 'BookMyungjo', role: 'body');
  void label(_StoryPage p) => p.type(
    '${(i + 1).toString().padLeft(2, '0')} / ${e.englishTitle.replaceAll('\n', ' ').toUpperCase()}',
    const Rect.fromLTWH(.08, .05, .84, .04),
    size: .014,
    font: 'Poppins',
    color: e.accent,
  );
  void motif(_StoryPage p, Rect area) => p.piece(e.motifId, area);
  void phrase(_StoryPage p, Rect area) => _diversityWordArt(p, area);
  void card(_StoryPage p, Rect area) {
    final (label, prompt, footer) = _hobbyRecordCopies[e.id]![layout]!;
    final fitted = _hobbyPaper(p, area);
    Rect field(double y, double h) => Rect.fromLTWH(
      fitted.left + fitted.width * .13,
      fitted.top + fitted.height * y,
      fitted.width * .74,
      fitted.height * h,
    );
    p.type(label, field(.18, .13), size: .023, font: 'BookMyungjo');
    p.layers.last['hobbyRecordField'] = true;
    p.type(prompt, field(.38, .35), size: .027, font: 'BookMyungjo');
    p.layers.last['hobbyRecordField'] = true;
    p.type(footer, field(.78, .06), size: .017, font: 'BookMyungjo');
    p.layers.last['hobbyRecordField'] = true;
  }

  switch (layout) {
    case 0: // Opening photograph opposite a native lettering composition.
      photo(l, n, const Rect.fromLTWH(.045, .11, .91, .62));
      note(l, const Rect.fromLTWH(.09, .80, .82, .11));
      phrase(r, const Rect.fromLTWH(.08, .19, .84, .52));
      r.type(
        e.chapters[i],
        const Rect.fromLTWH(.10, .81, .80, .06),
        size: .028,
        font: spec.font,
      );
    case 1: // One broad hero and a different two-photo rhythm opposite.
      title(l, const Rect.fromLTWH(.07, .065, .86, .10), size: .052);
      photo(l, n, const Rect.fromLTWH(.055, .25, .89, .56), framed: true);
      photo(r, n + 1, const Rect.fromLTWH(.07, .08, .58, .35));
      photo(r, n + 3, const Rect.fromLTWH(.35, .44, .58, .35));
      note(r, const Rect.fromLTWH(.09, .84, .82, .08), size: .024);
    case 2: // A specimen detail and a clear, fitted writing card.
      label(l);
      photo(l, n + 1, const Rect.fromLTWH(.07, .19, .86, .52), framed: true);
      title(l, const Rect.fromLTWH(.08, .79, .84, .08));
      card(r, const Rect.fromLTWH(.08, .19, .84, .62));
      note(r, const Rect.fromLTWH(.10, .85, .80, .08), size: .023);
    case 3: // Staggered detail pair and a large scene on its own page.
      photo(l, n, const Rect.fromLTWH(.055, .09, .43, .32), framed: true);
      photo(l, n + 2, const Rect.fromLTWH(.53, .29, .42, .32));
      title(l, const Rect.fromLTWH(.08, .70, .84, .08));
      photo(r, n + 3, const Rect.fromLTWH(.045, .14, .91, .59));
      note(r, const Rect.fromLTWH(.10, .81, .80, .10));
    case 4: // A contact row and original first-person commentary.
      label(l);
      for (var j = 0; j < 3; j++)
        photo(
          l,
          n + j,
          Rect.fromLTWH(.055 + j * .303, .26, .284, .30),
          framed: true,
        );
      title(l, const Rect.fromLTWH(.08, .69, .84, .12));
      r.type(
        _hobbyDisplayPhrases[e.id]!,
        const Rect.fromLTWH(.10, .16, .80, .28),
        size: .058,
        font: spec.font,
        role: 'headline',
      );
      note(r, const Rect.fromLTWH(.10, .57, .78, .15));
      motif(r, const Rect.fromLTWH(.68, .75, .25, .19));
    case 5: // The material has a full page-scale role, not only a corner mark.
      title(l, const Rect.fromLTWH(.08, .08, .84, .11));
      motif(l, const Rect.fromLTWH(.20, .29, .60, .41));
      note(l, const Rect.fromLTWH(.10, .80, .80, .10));
      photo(r, n, const Rect.fromLTWH(.06, .08, .88, .44), framed: true);
      photo(r, n + 1, const Rect.fromLTWH(.32, .58, .60, .32));
    case 6: // A mounted process still and a measured annotated detail page.
      photo(l, n + 1, const Rect.fromLTWH(.055, .12, .89, .58), framed: true);
      title(l, const Rect.fromLTWH(.08, .80, .84, .09));
      label(r);
      photo(r, n + 4, const Rect.fromLTWH(.10, .20, .58, .38));
      motif(r, const Rect.fromLTWH(.74, .25, .19, .19));
      note(r, const Rect.fromLTWH(.10, .71, .80, .16));
    case 7: // Shared experience: an intact scene and room for its story.
      photo(l, 2, const Rect.fromLTWH(.045, .10, .91, .64));
      title(l, const Rect.fromLTWH(.08, .82, .84, .08), size: .037);
      title(r, const Rect.fromLTWH(.09, .11, .82, .13), size: .055);
      note(r, const Rect.fromLTWH(.10, .35, .80, .14));
      photo(r, 4, const Rect.fromLTWH(.09, .61, .54, .29), framed: true);
      motif(r, const Rect.fromLTWH(.73, .65, .19, .18));
    case 8: // A technical or collecting index, paired with one broad photograph.
      label(l);
      card(l, const Rect.fromLTWH(.08, .23, .84, .63));
      photo(r, n, const Rect.fromLTWH(.045, .13, .91, .61), framed: true);
      title(r, const Rect.fromLTWH(.08, .81, .84, .09));
    case 9: // A visual field and spacious caption below, opposite a narrow inset.
      photo(l, n, const Rect.fromLTWH(.045, .08, .91, .59));
      title(l, const Rect.fromLTWH(.08, .76, .84, .10));
      photo(r, n + 1, const Rect.fromLTWH(.27, .12, .64, .43), framed: true);
      r.line(const Rect.fromLTWH(.10, .64, .14, .002));
      note(r, const Rect.fromLTWH(.10, .72, .80, .16));
    case 10: // Close observations and a second, independent native title piece.
      photo(l, n + 1, const Rect.fromLTWH(.07, .09, .58, .34));
      photo(l, n + 4, const Rect.fromLTWH(.35, .49, .58, .34), framed: true);
      phrase(r, const Rect.fromLTWH(.09, .17, .82, .51));
      note(r, const Rect.fromLTWH(.10, .80, .80, .11));
    case 11: // Closing photograph and a functional next-session card.
      title(l, const Rect.fromLTWH(.08, .07, .84, .12), size: .051);
      photo(l, 0, const Rect.fromLTWH(.06, .30, .88, .50));
      r.type(
        '다음의 한 걸음',
        const Rect.fromLTWH(.10, .085, .80, .10),
        size: .041,
        font: spec.font,
      );
      card(r, const Rect.fromLTWH(.08, .28, .84, .56));
      r.type(
        '계속 만들어 가는 나의 이야기',
        const Rect.fromLTWH(.10, .89, .80, .04),
        size: .022,
        font: 'BookMyungjo',
      );
    case 12: // Process sequence, with images and labels occupying separate bands.
      label(l);
      for (var j = 0; j < 2; j++) {
        photo(
          l,
          n + j,
          Rect.fromLTWH(.06, .18 + j * .34, .66, .29),
          framed: j == 0,
        );
        l.type(
          '${j + 1}',
          Rect.fromLTWH(.80, .27 + j * .34, .12, .07),
          size: .044,
          font: 'Cormorant Garamond',
          color: e.accent,
        );
      }
      title(r, const Rect.fromLTWH(.10, .12, .80, .12), size: .052);
      note(r, const Rect.fromLTWH(.10, .34, .80, .15));
      photo(r, n + 3, const Rect.fromLTWH(.29, .61, .62, .31));
    case 13: // A quiet landscape and a smaller observation facing it.
      photo(l, n, const Rect.fromLTWH(.04, .20, .92, .54));
      title(l, const Rect.fromLTWH(.08, .82, .84, .08));
      label(r);
      photo(r, n + 2, const Rect.fromLTWH(.16, .19, .68, .39), framed: true);
      note(r, const Rect.fromLTWH(.12, .72, .76, .15));
    case 14: // A deliberately asymmetric mini gallery: no repeated card grid.
      photo(l, n, const Rect.fromLTWH(.06, .10, .56, .35), framed: true);
      photo(l, n + 1, const Rect.fromLTWH(.50, .50, .44, .28));
      title(l, const Rect.fromLTWH(.08, .84, .84, .07), size: .034);
      photo(r, n + 3, const Rect.fromLTWH(.09, .14, .82, .48), framed: true);
      note(r, const Rect.fromLTWH(.10, .74, .80, .15));
    case 15: // Minimal ambient scene and a tactile sign, with ample white space.
      photo(l, n + 3, const Rect.fromLTWH(.055, .16, .89, .58));
      title(r, const Rect.fromLTWH(.10, .13, .80, .14), size: .061);
      r.line(const Rect.fromLTWH(.10, .36, .11, .002));
      note(r, const Rect.fromLTWH(.10, .45, .80, .17));
      motif(r, const Rect.fromLTWH(.64, .73, .26, .20));
    case 16: // A standalone notebook opening and a full-size collected record.
      title(l, const Rect.fromLTWH(.08, .08, .84, .10));
      photo(l, n + 1, const Rect.fromLTWH(.055, .27, .89, .50), framed: true);
      note(l, const Rect.fromLTWH(.10, .84, .80, .08), size: .023);
      label(r);
      card(r, const Rect.fromLTWH(.07, .23, .86, .64));
    default: // Working table diptych, followed by a different-size detail.
      photo(l, n + 1, const Rect.fromLTWH(.055, .11, .42, .34), framed: true);
      photo(l, n + 4, const Rect.fromLTWH(.52, .25, .42, .34));
      title(l, const Rect.fromLTWH(.08, .69, .84, .10), size: .046);
      note(l, const Rect.fromLTWH(.10, .84, .80, .08), size: .023);
      photo(r, n + 2, const Rect.fromLTWH(.07, .20, .86, .49), framed: true);
      motif(r, const Rect.fromLTWH(.69, .75, .24, .19));
  }
  for (final p in [l, r]) {
    p.layers.first['hobbyComposition'] = layout;
  }
  return [l, r];
}
