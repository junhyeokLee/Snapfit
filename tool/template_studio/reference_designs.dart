import 'package:flutter/material.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

// Authored review specimens. Never import these layouts into the AI generator.
const studioDirections = [
  (id: 'island', name: '섬에서 보낸 시간', label: '사진 중심 에디토리얼', color: '#234D3A'),
  (id: 'dear', name: '제주에게 쓰는 편지', label: '엽서와 여행의 문장', color: '#82283F'),
  (id: 'offduty', name: '잠시 쉬어가는 날', label: '컬러 트래블 매거진', color: '#244ECF'),
];

const studioPhotos = {
  'coast': 'assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
  'hill': 'assets/templates/jeju_travel/images/sources/jeju_seongsan.jpg',
  'aerial': 'assets/templates/jeju_travel/images/sources/jeju_aerial.jpg',
  'rock': 'assets/templates/jeju_travel/images/sources/jeju_rocky_coast.jpg',
  'sunset': 'assets/templates/jeju_travel/images/sources/jeju_sunset.jpg',
};

enum StudioAspect {
  portrait(0),
  square(1),
  landscape(2);

  const StudioAspect(this.coverIndex);
  final int coverIndex;
  CoverSize get cover => coverSizes[coverIndex];
  Size get canvas =>
      Size(500, 500 * cover.realSize.height / cover.realSize.width);
}

class StudioDocument {
  StudioDocument(this.direction, this.aspect, this.pages);
  final String direction;
  final StudioAspect aspect;
  final List<Map<String, dynamic>> pages;
  List<LayerModel> layers(int page, {bool photos = true}) =>
      DataTemplateEngine.buildLayersFromJson(pages[page], aspect.canvas)
          .map(
            (layer) => layer.type == LayerType.image
                ? layer.copyWith(
                    clearImage: !photos,
                    imageTemplate: 'free',
                    imageBackground: 'none',
                    decorationFillColor: '#DEE4E1',
                  )
                : layer,
          )
          .toList();

  Map<String, dynamic> toJson() => {
    'id': 'studio_${direction}_${aspect.name}',
    'status': 'authored-review-specimen',
    'aiGenerated': false,
    'catalogPublishable': false,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
  };
}

StudioDocument buildStudioDocument(String direction, StudioAspect aspect) {
  final pages = switch (direction) {
    'island' => _island(aspect),
    'dear' => _dear(aspect),
    'offduty' => _offDuty(aspect),
    _ => throw ArgumentError.value(direction),
  };
  return StudioDocument(direction, aspect, pages.map((p) => p.json).toList());
}

// Coordinates are authored per physical aspect. Text remains editable and uses
// the application's bundled fonts. Helpers only emit existing layer primitives.
class _Page {
  _Page(this.id, this.aspect, String paper) {
    box(0, 0, 1, 1, paper);
  }
  final String id;
  final StudioAspect aspect;
  final List<Map<String, dynamic>> _layers = [];
  bool get wide => aspect == StudioAspect.landscape;
  bool get tall => aspect == StudioAspect.portrait;
  double n(double portrait, double square, double landscape) =>
      switch (aspect) {
        StudioAspect.portrait => portrait,
        StudioAspect.square => square,
        StudioAspect.landscape => landscape,
      };
  Map<String, dynamic> get json => {
    'id': id,
    'strictLayout': true,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layers': _layers,
  };
  void _add(
    String type,
    double x,
    double y,
    double w,
    double h,
    Map<String, dynamic> payload,
  ) {
    _layers.add({
      'id': '${id}_${_layers.length}',
      'type': type,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      'z': _layers.length,
      ...payload,
    });
  }

  void box(double x, double y, double w, double h, String color) => _add(
    'decoration',
    x,
    y,
    w,
    h,
    {'text': 'rect', 'fillColor': color, 'cornerRadius': 0},
  );
  void photo(String asset, double x, double y, double w, double h) =>
      _add('image', x, y, w, h, {
        'imageUrl': 'asset:${studioPhotos[asset]}',
        'imageTemplate': 'free',
        'imageBackground': 'none',
        'decorationFillColor': '#DEE4E1',
      });
  void text(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = 12,
    String font = 'NotoSans',
    String color = '#20251F',
    int weight = 400,
    String align = 'left',
  }) => _add('text', x, y, w, h, {
    'text': value,
    'align': align,
    'style': {
      'fontFamily': font,
      'fontSize': size,
      'fontWeight': weight,
      'color': color,
      'height': 1.15,
      'letterSpacing': 0,
    },
  });
  void footer(String left, String right, {String color = '#20251F'}) {
    text(left, .07, .93, .65, .04, size: 10, color: color);
    text(right, .79, .93, .14, .04, size: 10, color: color, align: 'right');
  }
}

List<_Page> _island(StudioAspect aspect) {
  const ink = '#183B2D', paper = '#FAFBF8', lime = '#DDE993';
  final c = _Page('island_cover', aspect, paper);
  c.text('A SUMMER JOURNAL', .07, .035, .65, .035, size: 10, color: ink);
  c.text('VOL. 01', .76, .035, .17, .035, size: 10, color: ink, align: 'right');
  c.box(.07, .085, .86, .002, ink);
  if (c.wide) {
    c.text(
      'ISLAND',
      .07,
      .105,
      .53,
      .17,
      size: 53,
      font: 'Raleway',
      weight: 800,
      color: ink,
    );
    c.text(
      'HOURS.',
      .07,
      .275,
      .53,
      .17,
      size: 53,
      font: 'Raleway',
      weight: 800,
      color: ink,
    );
    c.text(
      '제주에서, 느리게',
      .07,
      .53,
      .43,
      .07,
      size: 17,
      font: 'Eulyoo',
      color: ink,
    );
    c.text(
      '바다와 바람 사이에 남긴\n우리의 짧고 긴 여름.',
      .07,
      .67,
      .4,
      .12,
      size: 12,
      color: ink,
    );
    c.photo('hill', .61, .12, .32, .72);
  } else {
    c.text(
      'ISLAND',
      .065,
      .095,
      .88,
      c.n(.115, .14, .14),
      size: 76,
      font: 'Raleway',
      weight: 800,
      color: ink,
    );
    c.text(
      'HOURS.',
      .065,
      c.n(.205, .225, .2),
      .88,
      c.n(.115, .14, .14),
      size: 76,
      font: 'Raleway',
      weight: 800,
      color: ink,
    );
    c.photo('hill', .07, c.n(.365, .4, .4), .86, c.n(.465, .43, .4));
    c.box(.07, c.n(.365, .4, .4), .012, c.n(.465, .43, .4), lime);
    c.text(
      '제주에서, 느리게',
      .07,
      .85,
      .86,
      .055,
      size: 17,
      font: 'Eulyoo',
      color: ink,
    );
  }
  c.footer('JEJU ISLAND / 2026', '06.18–21', color: ink);

  final a = _Page('island_1', aspect, paper);
  a.photo('coast', 0, 0, 1, .85);
  a.text(
    '바람이 먼저 도착한 곳',
    .07,
    .88,
    .7,
    .06,
    size: 15,
    font: 'Eulyoo',
    color: ink,
  );
  a.text('01', .85, .9, .08, .04, size: 10, color: ink, align: 'right');

  final b = _Page('island_2', aspect, ink);
  b.text('CHAPTER ONE', .08, .05, .75, .04, size: 10, color: lime);
  if (b.wide) {
    b.text(
      '01',
      .07,
      .12,
      .35,
      .29,
      size: 85,
      font: 'Cormorant Garamond',
      color: lime,
    );
    b.text('서두르지', .08, .45, .55, .12, size: 30, font: 'Eulyoo', color: paper);
    b.text('않는 날들', .08, .57, .55, .12, size: 30, font: 'Eulyoo', color: paper);
    b.photo('rock', .69, .18, .24, .56);
    b.text(
      '정해둔 목적지 없이, 마음이 머무는 쪽으로.',
      .08,
      .79,
      .85,
      .055,
      size: 11,
      color: paper,
    );
  } else {
    b.text(
      '01',
      .07,
      .12,
      .75,
      .22,
      size: 116,
      font: 'Cormorant Garamond',
      color: lime,
    );
    b.text('서두르지', .08, .37, .78, .105, size: 38, font: 'Eulyoo', color: paper);
    b.text(
      '않는 날들',
      .08,
      .475,
      .78,
      .105,
      size: 38,
      font: 'Eulyoo',
      color: paper,
    );
    b.text(
      '정해둔 목적지 없이,\n마음이 머무는 쪽으로 걸었다.',
      .08,
      .64,
      .54,
      .12,
      size: 13,
      color: paper,
    );
    b.photo('rock', .69, .65, .24, .21);
  }
  b.footer('ISLAND HOURS', '02', color: lime);

  final d = _Page('island_3', aspect, paper);
  d.text('FIELD NOTES', .07, .045, .68, .04, size: 10, color: ink);
  d.text('02', .81, .045, .12, .04, size: 10, color: ink, align: 'right');
  d.photo('aerial', .07, .13, .86, d.n(.59, .56, .52));
  d.text(
    '섬의 속도',
    .07,
    d.n(.75, .72, .69),
    .42,
    .10,
    size: d.wide ? 26 : 32,
    font: 'Eulyoo',
    color: ink,
  );
  d.text(
    '아무것도 하지 않아도\n충분했던 오후.',
    .58,
    d.n(.75, .72, .69),
    .35,
    .12,
    size: 12,
    color: ink,
  );
  d.footer('SEONGSAN / JEJU', '03', color: ink);

  final e = _Page('island_4', aspect, '#EFF3E8');
  e.text(
    '작은 장면들의 수집',
    .07,
    .05,
    .84,
    .075,
    size: 22,
    font: 'Eulyoo',
    color: ink,
  );
  if (e.wide) {
    e.photo('hill', .07, .2, .4, .49);
    e.photo('sunset', .54, .31, .39, .43);
    e.text('오래 바라본 초록', .07, .74, .42, .06, size: 11, color: ink);
    e.text('해가 기울 때까지', .54, .79, .39, .055, size: 11, color: ink);
  } else {
    e.photo('hill', .07, .2, .4, .53);
    e.photo('sunset', .54, .35, .39, .43);
    e.text('오래 바라본 초록', .07, .765, .42, .045, size: 11, color: ink);
    e.text('해가 기울 때까지', .54, .815, .39, .045, size: 11, color: ink);
  }
  e.footer('THE LITTLE THINGS', '04', color: ink);
  return [c, a, b, d, e];
}

List<_Page> _dear(StudioAspect aspect) {
  const wine = '#82283F', paper = '#FFFCFA', blush = '#F2E5E7';
  final c = _Page('dear_cover', aspect, wine);
  // An inset keyline is built from editable rectangles, not a baked-in frame.
  c.box(.045, .035, .91, .002, '#C692A0');
  c.box(.045, .963, .91, .002, '#C692A0');
  c.text(
    'LETTERS FROM THE ISLAND',
    .08,
    .065,
    .84,
    .04,
    size: 10,
    color: paper,
    align: 'center',
  );
  if (c.wide) {
    c.text(
      'Dear,',
      .08,
      .21,
      .39,
      .24,
      size: 66,
      font: 'Cormorant Garamond',
      color: paper,
    );
    c.text(
      'Jeju.',
      .08,
      .43,
      .39,
      .24,
      size: 66,
      font: 'Cormorant Garamond',
      color: paper,
    );
    c.box(.51, .19, .39, .58, paper);
    c.photo('aerial', .53, .215, .35, .475);
    c.text(
      '여름이 보낸 편지',
      .08,
      .78,
      .8,
      .07,
      size: 17,
      font: 'Eulyoo',
      color: paper,
    );
  } else {
    c.text(
      'Dear, Jeju.',
      .08,
      .135,
      .84,
      c.n(.13, .16, .16),
      size: 70,
      font: 'Cormorant Garamond',
      color: paper,
      align: 'center',
    );
    c.box(.12, .335, .76, .45, paper);
    c.photo('aerial', .145, .355, .71, .355);
    c.text(
      'a place to return to',
      .145,
      .728,
      .71,
      .037,
      size: 13,
      font: 'Cormorant Garamond',
      color: wine,
      align: 'center',
    );
    c.text(
      '여름이 보낸 편지',
      .08,
      .825,
      .84,
      .07,
      size: 19,
      font: 'Eulyoo',
      color: paper,
      align: 'center',
    );
  }
  c.text(
    'OUR DAYS, KEPT FOREVER / 2026',
    .08,
    .905,
    .84,
    .035,
    size: 9,
    color: paper,
    align: 'center',
  );

  final a = _Page('dear_1', aspect, paper);
  a.text('01 / ARRIVAL', .08, .05, .84, .04, size: 10, color: wine);
  if (a.wide) {
    a.text(
      'Somewhere,',
      .08,
      .17,
      .84,
      .16,
      size: 46,
      font: 'Cormorant Garamond',
      color: wine,
    );
    a.text(
      'with you.',
      .08,
      .32,
      .84,
      .16,
      size: 46,
      font: 'Cormorant Garamond',
      color: wine,
    );
    a.photo('hill', .56, .5, .36, .31);
    a.text(
      '낯선 풍경이\n우리의 기억이 되는 순간.',
      .08,
      .61,
      .42,
      .15,
      size: 13,
      font: 'Eulyoo',
      color: wine,
    );
  } else {
    a.text(
      'Somewhere,',
      .08,
      .13,
      .84,
      .13,
      size: 52,
      font: 'Cormorant Garamond',
      color: wine,
    );
    a.text(
      'with you.',
      .08,
      .25,
      .84,
      .13,
      size: 52,
      font: 'Cormorant Garamond',
      color: wine,
    );
    a.photo('hill', .08, .43, .84, .32);
    a.text(
      '낯선 풍경이 우리의 기억이 되는 순간.',
      .08,
      .81,
      .84,
      .06,
      size: 14,
      font: 'Eulyoo',
      color: wine,
    );
  }
  a.footer('DEAR, JEJU', '01', color: wine);

  final b = _Page('dear_2', aspect, '#F5ECEE');
  b.text(
    'TO. 함께 여행한 우리에게',
    .08,
    .06,
    .84,
    .06,
    size: 13,
    font: 'Eulyoo',
    color: wine,
  );
  b.box(.08, .145, .84, .002, '#BE8C98');
  if (b.wide) {
    b.photo('aerial', .08, .22, .46, .59);
    b.text(
      'June',
      .62,
      .2,
      .28,
      .17,
      size: 42,
      font: 'Cormorant Garamond',
      color: wine,
    );
    b.text(
      '18',
      .62,
      .39,
      .28,
      .25,
      size: 70,
      font: 'Cormorant Garamond',
      color: wine,
    );
    b.text(
      '바다가 보이는 쪽으로\n조금 더 걸어가자.',
      .62,
      .69,
      .3,
      .15,
      size: 12,
      font: 'Eulyoo',
      color: wine,
    );
  } else {
    b.photo('aerial', .08, .205, .84, .38);
    b.text(
      'June 18',
      .08,
      .62,
      .64,
      .10,
      size: 38,
      font: 'Cormorant Garamond',
      color: wine,
    );
    b.text(
      '바다가 보이는 쪽으로 조금 더 걸어가자.\n오늘의 다정한 장면을 오래 기억할 수 있게.',
      .08,
      .755,
      .84,
      .12,
      size: 13,
      font: 'Eulyoo',
      color: wine,
    );
  }
  b.footer('FROM. JEJU ISLAND', '02', color: wine);

  final d = _Page('dear_3', aspect, wine);
  d.text('COLLECTED MOMENTS', .08, .055, .84, .04, size: 10, color: paper);
  d.box(.08, .17, .84, d.n(.53, .49, .46), paper);
  d.photo('sunset', .105, .19, .79, d.n(.43, .39, .34));
  d.text(
    'the light we stayed for',
    .12,
    d.n(.64, .60, .56),
    .76,
    .045,
    size: 14,
    font: 'Cormorant Garamond',
    color: wine,
    align: 'center',
  );
  d.text(
    '빛이 다할 때까지',
    .08,
    d.n(.77, .745, .73),
    .84,
    .1,
    size: 27,
    font: 'Eulyoo',
    color: paper,
    align: 'center',
  );
  d.footer('A NOTE TO REMEMBER', '03', color: paper);

  final e = _Page('dear_4', aspect, paper);
  e.text(
    'P.S.',
    .08,
    .05,
    .84,
    .15,
    size: 58,
    font: 'Cormorant Garamond',
    color: wine,
  );
  if (e.wide) {
    e.text(
      '또, 같은 계절에.',
      .08,
      .29,
      .46,
      .12,
      size: 25,
      font: 'Eulyoo',
      color: wine,
    );
    e.text(
      '돌아온 뒤에도 문득 떠오를\n그날의 바람, 그때의 우리.',
      .08,
      .48,
      .42,
      .17,
      size: 13,
      font: 'Eulyoo',
      color: wine,
    );
    e.box(.57, .18, .35, .62, blush);
    e.photo('rock', .595, .205, .3, .47);
    e.text(
      'see you again',
      .595,
      .7,
      .3,
      .07,
      size: 13,
      font: 'Cormorant Garamond',
      color: wine,
      align: 'center',
    );
  } else {
    e.text(
      '또, 같은 계절에.',
      .08,
      .235,
      .84,
      .09,
      size: 30,
      font: 'Eulyoo',
      color: wine,
    );
    e.text(
      '돌아온 뒤에도 문득 떠오를\n그날의 바람, 그때의 우리.',
      .08,
      .375,
      .84,
      .13,
      size: 14,
      font: 'Eulyoo',
      color: wine,
    );
    e.box(.37, .565, .55, .28, blush);
    e.photo('rock', .395, .585, .5, .21);
    e.text(
      'see you again',
      .395,
      .808,
      .5,
      .033,
      size: 12,
      font: 'Cormorant Garamond',
      color: wine,
      align: 'center',
    );
  }
  e.footer('WITH LOVE, ALWAYS', '04', color: wine);
  return [c, a, b, d, e];
}

List<_Page> _offDuty(StudioAspect aspect) {
  const blue = '#244ECF', lime = '#E3F18B', ink = '#162519', paper = '#FAFCF5';
  final c = _Page('offduty_cover', aspect, blue);
  c.text(
    'OFF DUTY / TRAVEL CLUB',
    .06,
    .04,
    .87,
    .04,
    size: 10,
    weight: 600,
    color: lime,
  );
  if (c.wide) {
    c.text(
      'JEJU',
      .055,
      .1,
      .59,
      .29,
      size: 88,
      font: 'Poppins',
      weight: 700,
      color: lime,
    );
    c.box(0, .62, 1, .38, lime);
    c.photo('hill', .53, .41, .41, .46);
    c.text(
      'OFF',
      .06,
      .43,
      .4,
      .17,
      size: 46,
      font: 'Poppins',
      weight: 700,
      color: paper,
    );
    c.text(
      'DUTY.',
      .06,
      .6,
      .43,
      .19,
      size: 46,
      font: 'Poppins',
      weight: 700,
      color: ink,
    );
    c.text('아무 계획도 없는 여름', .06, .88, .6, .065, size: 14, color: ink);
    c.text(
      '26',
      .78,
      .15,
      .16,
      .16,
      size: 42,
      font: 'Poppins',
      weight: 700,
      color: lime,
      align: 'right',
    );
  } else {
    c.text(
      'JEJU',
      .055,
      .10,
      .89,
      c.n(.2, .24, .2),
      size: 120,
      font: 'Poppins',
      weight: 700,
      color: lime,
    );
    c.box(0, .72, 1, .28, lime);
    c.photo('hill', .06, .36, .62, .48);
    c.text(
      '20',
      .73,
      .385,
      .23,
      .115,
      size: 40,
      font: 'Poppins',
      weight: 700,
      color: paper,
    );
    c.text(
      '26',
      .73,
      .50,
      .23,
      .115,
      size: 40,
      font: 'Poppins',
      weight: 700,
      color: paper,
    );
    c.text(
      'OFF',
      .73,
      .735,
      .23,
      .055,
      size: 18,
      font: 'Poppins',
      weight: 700,
      color: ink,
    );
    c.text(
      'DUTY',
      .73,
      .785,
      .24,
      .055,
      size: 18,
      font: 'Poppins',
      weight: 700,
      color: ink,
    );
    c.text(
      '아무 계획도 없는 여름',
      .06,
      .885,
      .88,
      .065,
      size: 19,
      weight: 700,
      color: ink,
    );
  }

  final a = _Page('offduty_1', aspect, lime);
  a.text(
    'TODAY’S PLAN',
    .07,
    .045,
    .7,
    .045,
    size: 10,
    weight: 600,
    color: ink,
  );
  if (a.wide) {
    a.text(
      'GO',
      .06,
      .16,
      .42,
      .25,
      size: 73,
      font: 'Poppins',
      weight: 700,
      color: blue,
    );
    a.text(
      'SLOW.',
      .06,
      .4,
      .52,
      .25,
      size: 63,
      font: 'Poppins',
      weight: 700,
      color: blue,
    );
    a.photo('coast', .6, .18, .33, .64);
    a.text('일정표 대신 바다.', .07, .735, .5, .07, size: 17, weight: 600, color: ink);
  } else {
    a.text(
      'GO',
      .06,
      .13,
      .86,
      .18,
      size: 91,
      font: 'Poppins',
      weight: 700,
      color: blue,
    );
    a.text(
      'SLOW.',
      .06,
      .30,
      .88,
      .18,
      size: 91,
      font: 'Poppins',
      weight: 700,
      color: blue,
    );
    a.photo('coast', .07, .545, .86, .29);
    a.text(
      '일정표 대신 바다.',
      .07,
      .86,
      .86,
      .045,
      size: 14,
      weight: 600,
      color: ink,
    );
  }
  a.footer('NO PLANS, GOOD DAYS', '01', color: ink);

  final b = _Page('offduty_2', aspect, blue);
  b.photo('aerial', 0, 0, 1, .76);
  b.text(
    'THIS WAY',
    .07,
    .79,
    .86,
    .105,
    size: b.wide ? 27 : 35,
    font: 'Poppins',
    weight: 700,
    color: lime,
  );
  b.footer('오늘은 이쪽으로 가볼까', '02', color: paper);

  final d = _Page('offduty_3', aspect, paper);
  d.text(
    'GOOD FINDS',
    .07,
    .05,
    .87,
    .13,
    size: d.wide ? 35 : 42,
    font: 'Poppins',
    weight: 700,
    color: blue,
  );
  if (d.wide) {
    d.photo('rock', .07, .26, .39, .48);
    d.photo('sunset', .54, .36, .39, .43);
    d.box(.07, .775, .12, .07, blue);
    d.text('01', .07, .775, .12, .07, size: 14, color: paper, align: 'center');
    d.text('02', .54, .82, .12, .07, size: 14, color: blue);
  } else {
    d.photo('rock', .07, .255, .4, .47);
    d.photo('sunset', .54, .39, .39, .40);
    d.box(.07, .745, .12, .065, blue);
    d.text('01', .07, .745, .12, .065, size: 14, color: paper, align: 'center');
    d.text('바람 수집', .23, .745, .28, .065, size: 12, color: ink);
    d.text('02 / 노을 수집', .54, .81, .39, .055, size: 12, color: ink);
  }
  d.footer('TAKE THE LONG WAY HOME', '03', color: ink);

  final e = _Page('offduty_4', aspect, blue);
  e.text(
    'UNTIL NEXT TIME',
    .07,
    .045,
    .86,
    .045,
    size: 10,
    weight: 600,
    color: lime,
  );
  if (e.wide) {
    e.text('다음에도,', .07, .18, .5, .14, size: 36, weight: 700, color: lime);
    e.text('같이.', .07, .34, .5, .14, size: 36, weight: 700, color: lime);
    e.photo('hill', .58, .19, .35, .62);
    e.text('우리의 다음 여행을 위해.', .07, .67, .47, .10, size: 13, color: paper);
  } else {
    e.text('다음에도,', .07, .14, .86, .14, size: 48, weight: 700, color: lime);
    e.text('같이.', .07, .29, .86, .14, size: 48, weight: 700, color: lime);
    e.photo('hill', .07, .515, .86, .29);
    e.text('우리의 다음 여행을 위해.', .07, .84, .86, .065, size: 15, color: paper);
  }
  e.footer('OFF DUTY / JEJU 2026', '04', color: lime);
  return [c, a, b, d, e];
}
