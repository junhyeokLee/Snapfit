part of 'authored_collections.dart';

List<_AtelierPage> _atelierSpread(
  AtelierEdition e,
  CollectionAspect aspect,
  int spread,
  _AtelierStory s,
) {
  final dark = s.layout == _AtelierLayout.darkroom;
  final reverseRight =
      dark ||
      s.layout == _AtelierLayout.portrait ||
      s.layout == _AtelierLayout.closing;
  final swapPaper =
      s.layout == _AtelierLayout.cameo ||
      s.layout == _AtelierLayout.montage ||
      s.layout == _AtelierLayout.panorama;
  final l = _AtelierPage(
    e,
    aspect,
    spread * 2 + 1,
    dark
        ? e.ink
        : swapPaper
        ? e.tint
        : e.paper,
    reverse: dark,
  );
  final r = _AtelierPage(
    e,
    aspect,
    spread * 2 + 2,
    reverseRight
        ? e.ink
        : swapPaper
        ? e.paper
        : e.tint,
    reverse: reverseRight,
  );
  final number = (spread + 1).toString().padLeft(2, '0');
  switch (s.layout) {
    case _AtelierLayout.prologue ||
        _AtelierLayout.specimen ||
        _AtelierLayout.invitation ||
        _AtelierLayout.shelves:
      _atelierConceptSpread(l, r, s, number);
    case _AtelierLayout.darkroom:
      if (e == AtelierEdition.privateCinema) {
        _atelierConceptSpread(l, r, s, number);
      } else {
        _atelierInteriorSpread(l, r, s, number);
      }
    default:
      _atelierInteriorSpread(l, r, s, number);
  }
  return [l, r];
}

/// Each category has its own functional record, not a recoloured generic card.
void _atelierRecord(_AtelierPage p, _AtelierStory s, String number) {
  final e = p.edition;
  p.label('THE RECORD / $number', .08, .065, .84);
  switch (e) {
    case AtelierEdition.nightVows:
      p.txt(
        'At our table',
        .08,
        .17,
        .84,
        .13,
        size: .092,
        font: 'Cormorant Garamond',
      );
      for (final row in ['WELCOME DRINK', 'DINNER', 'A LITTLE TOAST'].indexed) {
        p.rule(.12, .37 + row.$1 * .15, .76, color: e.accent);
        p.label(row.$2, .15, .405 + row.$1 * .15, .70);
        p.txt(
          ['과일 에이드', '계절의 저녁', '건배와 짧은 인사'][row.$1],
          .15,
          .46 + row.$1 * .15,
          .70,
          .05,
          size: .025,
          font: 'NotoSans',
        );
      }
      p.hand('좋아하는 사람들과', .12, .81, .76);
    case AtelierEdition.slowRail:
      p.plate(.08, .18, .83, .29);
      p.label('RAIL JOURNAL / ADMIT ONE', .13, .225, .73);
      p.txt(
        'A  →  B',
        .13,
        .30,
        .72,
        .12,
        size: .095,
        font: 'Cormorant Garamond',
      );
      for (final entry in ['출발역', '도착역', '잠깐 들른 곳'].indexed) {
        p.label(entry.$2, .10, .55 + entry.$1 * .10, .28);
        p.txt(
          ['루체른', '인터라켄', '호숫가의 작은 역'][entry.$1],
          .40,
          .54 + entry.$1 * .10,
          .48,
          .055,
          size: .030,
        );
        p.rule(.40, .61 + entry.$1 * .10, .48, color: e.accent);
      }
    case AtelierEdition.greenHours:
      p.txt(
        'Plant passport',
        .08,
        .16,
        .84,
        .13,
        size: .083,
        font: 'Cormorant Garamond',
      );
      p.pic(s.b, .08, .36, .35, .36, frame: e.frames.first);
      for (final entry in ['이름', '물 주는 날', '빛의 방향', '새잎을 본 날'].indexed) {
        p.label(entry.$2, .50, .37 + entry.$1 * .105, .40);
        p.txt(
          ['스위트 바질', '흙이 마르면', '오전의 햇빛', '6월의 첫 주'][entry.$1],
          .50,
          .415 + entry.$1 * .105,
          .40,
          .055,
          size: .027,
        );
        p.rule(.50, .48 + entry.$1 * .105, .40, color: e.accent);
      }
      p.hand('천천히 자라도 괜찮아', .08, .81, .84);
    case AtelierEdition.firstOrbit:
      p.txt(
        'Little discoveries',
        .08,
        .16,
        .84,
        .13,
        size: .079,
        font: 'Cormorant Garamond',
      );
      for (final entry in ['처음 웃은 날', '처음 잡은 것', '처음 부른 이름'].indexed) {
        p.tag('0${entry.$1 + 1}', .08, .36 + entry.$1 * .16, .11);
        p.txt(entry.$2, .25, .36 + entry.$1 * .16, .64, .06, size: .031);
        p.txt(
          ['2026. 06. 17', '엄마의 손가락', '아빠를 찾던 아침'][entry.$1],
          .25,
          .42 + entry.$1 * .16,
          .63,
          .055,
          size: .025,
          font: 'NotoSans',
        );
        p.rule(.25, .49 + entry.$1 * .16, .63, color: e.accent);
      }
      p.label('작은 처음을 하나씩 기록합니다', .08, .86, .84);
    case AtelierEdition.tableStories:
      p.txt(
        'Recipe no. $number',
        .08,
        .17,
        .84,
        .13,
        size: .085,
        font: 'Cormorant Garamond',
      );
      p.tag('INGREDIENTS', .08, .36, .40);
      p.tag('METHOD', .55, .36, .35);
      for (var i = 0; i < 4; i++) {
        p.txt(
          ['토마토 한 줌', '바질 잎 몇 장', '파스타 2인분', '올리브유와 소금'][i],
          .09,
          .435 + i * .075,
          .38,
          .045,
          size: .023,
          font: 'NotoSans',
        );
        p.txt(
          ['재료를 씻어 썰기', '면을 삶아 건지기', '함께 버무리기', '맛을 보고 나누기'][i],
          .56,
          .435 + i * .075,
          .33,
          .045,
          size: .023,
          font: 'NotoSans',
        );
        p.rule(.08, .48 + i * .075, .40, color: e.accent);
        p.rule(.55, .48 + i * .075, .35, color: e.accent);
      }
      p.hand('다음에는 이것도 넣어 볼까', .08, .81, .84);
    case AtelierEdition.privateCinema:
      p.box(p.uid, .08, .17, .84, .33, e.ink);
      p.label('PRIVATE SCREENING', .13, .215, .74, color: e.paper);
      p.txt(
        'ROW 02 / TWO SEATS',
        .13,
        .31,
        .74,
        .08,
        size: .047,
        color: e.paper,
        font: 'Cormorant Garamond',
      );
      p.label('KEEP THIS TICKET', .13, .425, .74, color: e.accent);
      for (final entry in ['함께 본 영화', '기억에 남은 대사', '끝나고 나눈 이야기'].indexed) {
        p.label(entry.$2, .10, .57 + entry.$1 * .105, .80);
        p.txt(
          ['우리의 첫 영화', '너도 같은 장면을 좋아했구나', '다음에도 이 자리에 앉자'][entry.$1],
          .10,
          .615 + entry.$1 * .105,
          .80,
          .055,
          size: .026,
        );
        p.rule(.10, .675 + entry.$1 * .105, .80, color: e.accent);
      }
    case AtelierEdition.walkMap:
      p.txt(
        'Walking log',
        .08,
        .16,
        .84,
        .13,
        size: .092,
        font: 'Cormorant Garamond',
      );
      const stops = ['집 앞에서 출발', '좋아하는 쉼터', '다시 집으로'];
      for (final entry in stops.indexed) {
        p.tag('0${entry.$1 + 1}', .08, .37 + entry.$1 * .15, .11);
        p.txt(entry.$2, .26, .37 + entry.$1 * .15, .63, .07, size: .032);
        p.rule(.26, .465 + entry.$1 * .15, .62, color: e.accent);
      }
      p.label('걸은 시간 / 날씨 / 다음에 갈 곳', .08, .86, .84);
  }
}
