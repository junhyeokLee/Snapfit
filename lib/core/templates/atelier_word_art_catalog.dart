part of 'studio_word_art_catalog.dart';

const atelierWordArts = [
  StudioWordArt(
    'atelier-vow',
    '압인 청첩장 타이틀',
    '우리의\n첫 장',
    canvasSize: Size(500, 360),
  ),
  StudioWordArt(
    'atelier-promise',
    '엇갈린 명조 서약',
    '이날부터,\n함께.',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-ribbon',
    '실크 리본 시그니처',
    '함께한 계절',
    canvasSize: Size(500, 260),
  ),
  StudioWordArt(
    'atelier-boarding',
    '탑승권 타이포',
    '여행의\n기록',
    canvasSize: Size(500, 312),
  ),
  StudioWordArt(
    'atelier-route',
    '노선도 에디토리얼',
    '떠난 날,\n돌아온 날',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-postcard',
    '도시 엽서 레터링',
    '서울에서\n보낸 편지',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-diary',
    '손글씨 다이어리',
    '자주 꺼내\n보고 싶은 날',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-index',
    '색인형 기록 제목',
    '한 장씩\n모아 둔 일상',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-archive',
    '타원 인장 북타이틀',
    '오래도록\n간직할 장면',
    canvasSize: Size(500, 380),
  ),
  StudioWordArt(
    'atelier-first-year',
    '첫돌 숫자 포스터',
    '너의 첫\n열두 달',
    canvasSize: Size(500, 360),
  ),
  StudioWordArt(
    'atelier-first-time',
    '첫 순간 기록지',
    '처음으로\n해낸 일',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-weekend',
    '주말 레시피 타이틀',
    '우리 집의\n주말',
    canvasSize: Size(500, 320),
  ),
  StudioWordArt(
    'atelier-anniversary',
    '기념일 숫자 조판',
    '우리가 함께한',
    canvasSize: Size(500, 350),
  ),
  StudioWordArt(
    'atelier-walk',
    '산책 저널 레터링',
    '오늘도\n같이 걷자',
    canvasSize: Size(500, 340),
  ),
  StudioWordArt(
    'atelier-laughter',
    '컬러 컷페이퍼 조판',
    '웃다가\n찍힌 사진',
    canvasSize: Size(500, 350),
  ),
  StudioWordArt(
    'atelier-cinema',
    '시네마 크레딧 타이틀',
    '이 장면을\n기억해',
    canvasSize: Size(500, 340),
  ),
];

List<LayerModel> _atelierWordArtLayers(StudioWordArt art) {
  final layers = <LayerModel>[];
  void paper(String key, Rect r) => layers.add(
    LayerModel(
      id: '${art.id}-${layers.length}',
      type: LayerType.decoration,
      position: r.topLeft,
      width: r.width,
      height: r.height,
      imageBackground: key,
      zIndex: layers.length,
    ),
  );
  void text(
    String value,
    Rect r,
    double size,
    Color color, {
    String font = 'NotoSans',
    TextAlign align = TextAlign.center,
    FontWeight weight = FontWeight.normal,
    String? fill,
  }) {
    TextStyle style(double size) => TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.16,
      letterSpacing: 0,
    );
    // Leave the same horizontal breathing room that the native editor uses.
    late TextPainter measure;
    var fitted = size;
    while (true) {
      measure = TextPainter(
        text: TextSpan(text: value, style: style(fitted)),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: r.width - 40);
      if (measure.height <= r.height &&
              measure.computeLineMetrics().every(
                (l) => l.width <= r.width - 40,
              ) ||
          fitted <= 8)
        break;
      measure.dispose();
      fitted -= .5;
    }
    final height = measure.height;
    measure.dispose();
    layers.add(
      LayerModel(
        id: '${art.id}-${layers.length}',
        type: LayerType.text,
        position: Offset(r.left, r.top + (r.height - height) / 2),
        width: r.width,
        height: height,
        text: value,
        textStyle: style(fitted),
        textAlign: align,
        textStyleType: TextStyleType.none,
        textFillMode: fill,
        zIndex: layers.length,
      ),
    );
  }

  const ink = Color(0xFF283934),
      forest = Color(0xFF3D6253),
      burgundy = Color(0xFF784757);
  const blue = Color(0xFF315FAB), muted = Color(0xFF6D776E);
  void caption(String value, Rect r, {Color color = muted}) =>
      text(value, r, 12, color);
  switch (art.id) {
    case 'atelier-vow':
      paper('atelierTitlePlate', const Rect.fromLTWH(22, 12, 456, 336));
      caption('THE WEDDING JOURNAL', const Rect.fromLTWH(58, 55, 384, 25));
      text(
        art.text,
        const Rect.fromLTWH(64, 96, 372, 164),
        61,
        forest,
        font: 'BookMyungjo',
      );
      caption('2026. 05. 24', const Rect.fromLTWH(80, 285, 340, 25));
    case 'atelier-promise':
      caption('01 / OUR BEGINNING', const Rect.fromLTWH(8, 8, 265, 26));
      text(
        art.text,
        const Rect.fromLTWH(12, 48, 436, 218),
        76,
        burgundy,
        font: 'BookMyungjo',
        align: TextAlign.left,
      );
      text(
        '그리고, 오래오래',
        const Rect.fromLTWH(195, 261, 296, 40),
        25,
        ink,
        font: 'Yeongwol',
      );
      caption(
        'TOGETHER, FROM THIS DAY',
        const Rect.fromLTWH(104, 312, 386, 23),
      );
    case 'atelier-ribbon':
      caption('OUR SEASONS / 2026', const Rect.fromLTWH(70, 12, 360, 26));
      paper('atelierRibbonPlate', const Rect.fromLTWH(0, 55, 500, 156));
      text(
        art.text,
        const Rect.fromLTWH(65, 86, 370, 58),
        44,
        ink,
        font: 'BookMyungjo',
      );
      text(
        '다음 계절에도, 함께',
        const Rect.fromLTWH(70, 216, 360, 35),
        23,
        forest,
        font: 'Yeongwol',
      );
    case 'atelier-boarding':
      paper('atelierBoardingStub', const Rect.fromLTWH(0, 0, 500, 312));
      caption(
        'BOARDING / SEOUL TO PARIS',
        const Rect.fromLTWH(24, 13, 340, 26),
        color: forest,
      );
      text(
        art.text,
        const Rect.fromLTWH(22, 68, 341, 164),
        67,
        ink,
        font: 'RiaSans',
        align: TextAlign.left,
      );
      caption(
        '03 JUN - 12 JUN / 2026',
        const Rect.fromLTWH(24, 274, 337, 23),
        color: forest,
      );
    case 'atelier-route':
      text(
        '01',
        const Rect.fromLTWH(5, 18, 137, 112),
        94,
        blue,
        font: 'BookMyungjo',
        fill: 'outline',
      );
      text(
        art.text,
        const Rect.fromLTWH(148, 42, 344, 196),
        54,
        ink,
        font: 'RiaSans',
        align: TextAlign.left,
      );
      paper('atelierPostalBand', const Rect.fromLTWH(18, 264, 464, 30));
      caption('SEOUL / LISBON / SEOUL', const Rect.fromLTWH(38, 306, 424, 25));
    case 'atelier-postcard':
      paper('atelierPostalBand', const Rect.fromLTWH(25, 8, 450, 35));
      caption('POSTCARD NO. 06', const Rect.fromLTWH(30, 63, 265, 24));
      text(
        art.text,
        const Rect.fromLTWH(30, 103, 440, 164),
        57,
        blue,
        font: 'Yeongwol',
        align: TextAlign.left,
      );
      caption('TO. 내가 아끼는 사람에게', const Rect.fromLTWH(160, 299, 320, 24));
    case 'atelier-diary':
      paper('atelierGridLeaf', const Rect.fromLTWH(12, 5, 476, 330));
      caption('SUNDAY, SEPTEMBER 06', const Rect.fromLTWH(34, 25, 350, 23));
      text(
        art.text,
        const Rect.fromLTWH(30, 80, 437, 174),
        61,
        ink,
        font: 'Yeongwol',
        align: TextAlign.left,
      );
      caption('여기, 오늘의 기록', const Rect.fromLTWH(190, 280, 262, 28));
    case 'atelier-index':
      text(
        '07',
        const Rect.fromLTWH(8, 25, 157, 110),
        90,
        burgundy,
        font: 'BookMyungjo',
      );
      caption('RECORDS / VOL. 01', const Rect.fromLTWH(183, 23, 310, 30));
      text(
        art.text,
        const Rect.fromLTWH(171, 95, 322, 163),
        48,
        ink,
        font: 'BookMyungjo',
        align: TextAlign.left,
      );
      text(
        '01. 사진  /  02. 메모  /  03. 기억',
        const Rect.fromLTWH(82, 285, 397, 32),
        13,
        burgundy,
      );
    case 'atelier-archive':
      paper('atelierArchiveSeal', const Rect.fromLTWH(0, 0, 500, 370));
      caption(
        'THE PERSONAL ARCHIVE',
        const Rect.fromLTWH(93, 68, 314, 25),
        color: forest,
      );
      text(
        art.text,
        const Rect.fromLTWH(72, 121, 356, 125),
        39,
        forest,
        font: 'BookMyungjo',
      );
      caption(
        'COLLECTED WITH LOVE / 2026',
        const Rect.fromLTWH(95, 277, 310, 24),
        color: forest,
      );
    case 'atelier-first-year':
      text(
        '1',
        const Rect.fromLTWH(5, 7, 157, 268),
        225,
        const Color(0xFFBA8468),
        font: 'BookMyungjo',
      );
      caption('TWELVE LITTLE CHAPTERS', const Rect.fromLTWH(176, 24, 324, 32));
      text(
        art.text,
        const Rect.fromLTWH(175, 104, 320, 161),
        51,
        ink,
        font: 'BookMyungjo',
        align: TextAlign.left,
      );
      text(
        '처음부터 지금까지',
        const Rect.fromLTWH(135, 291, 358, 49),
        31,
        forest,
        font: 'Yeongwol',
      );
    case 'atelier-first-time':
      paper('atelierGridLeaf', const Rect.fromLTWH(12, 5, 476, 330));
      caption('FIRST STEPS / 001', const Rect.fromLTWH(25, 20, 312, 32));
      text(
        art.text,
        const Rect.fromLTWH(20, 92, 399, 149),
        59,
        forest,
        font: 'RiaSans',
        align: TextAlign.left,
      );
      caption(
        '날짜  2026. 09. 06    장소  우리 집',
        const Rect.fromLTWH(28, 276, 417, 27),
      );
    case 'atelier-weekend':
      paper('atelierCornerBrackets', const Rect.fromLTWH(12, 6, 476, 307));
      caption('THE WEEKEND TABLE', const Rect.fromLTWH(61, 30, 378, 27));
      text(
        art.text,
        const Rect.fromLTWH(48, 88, 404, 142),
        58,
        ink,
        font: 'BookMyungjo',
      );
      text(
        '함께 먹고, 웃고, 쉬는 날',
        const Rect.fromLTWH(49, 251, 402, 38),
        27,
        forest,
        font: 'Yeongwol',
      );
    case 'atelier-anniversary':
      text(
        art.text,
        const Rect.fromLTWH(35, 5, 430, 49),
        28,
        burgundy,
        font: 'BookMyungjo',
      );
      text(
        '100',
        const Rect.fromLTWH(12, 61, 334, 178),
        146,
        burgundy,
        font: 'BookMyungjo',
      );
      text(
        '일',
        const Rect.fromLTWH(358, 160, 118, 69),
        40,
        burgundy,
        font: 'BookMyungjo',
      );
      paper('atelierPostalBand', const Rect.fromLTWH(54, 268, 392, 24));
      caption(
        '2026. 02. 14 - 2026. 05. 24',
        const Rect.fromLTWH(34, 312, 432, 24),
      );
    case 'atelier-walk':
      caption(
        'THE WALKING JOURNAL',
        const Rect.fromLTWH(17, 12, 346, 26),
        color: forest,
      );
      text(
        art.text,
        const Rect.fromLTWH(18, 63, 440, 181),
        68,
        forest,
        font: 'Yeongwol',
        align: TextAlign.left,
      );
      paper('atelierRibbonPlate', const Rect.fromLTWH(193, 265, 288, 61));
      caption(
        '우리 동네 / 17:30',
        const Rect.fromLTWH(213, 277, 248, 25),
        color: ink,
      );
    case 'atelier-laughter':
      paper('atelierColorSlips', const Rect.fromLTWH(5, 3, 490, 342));
      caption(
        'OUTTAKES / THE GOOD ONES',
        const Rect.fromLTWH(46, 43, 408, 25),
        color: burgundy,
      );
      text(
        art.text,
        const Rect.fromLTWH(32, 102, 436, 163),
        63,
        burgundy,
        font: 'RiaSans',
        fill: 'papercut',
      );
      caption(
        '이 사진은 꼭 남겨 두기',
        const Rect.fromLTWH(50, 285, 400, 27),
        color: burgundy,
      );
    case 'atelier-cinema':
      caption('SCENE 04 / TAKE 01', const Rect.fromLTWH(9, 5, 315, 29));
      text(
        art.text,
        const Rect.fromLTWH(14, 59, 472, 182),
        69,
        ink,
        font: 'RiaSans',
        align: TextAlign.left,
      );
      text(
        'STARRING US',
        const Rect.fromLTWH(20, 266, 300, 27),
        16,
        burgundy,
        align: TextAlign.left,
      );
      caption(
        'DIRECTED BY OUR EVERYDAY',
        const Rect.fromLTWH(17, 305, 469, 25),
      );
  }
  return layers;
}
