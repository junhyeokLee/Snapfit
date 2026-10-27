part of 'authored_collections.dart';

/// Documentary club books: generous group photographs and usable records,
/// rather than glamorous portraits or decoration covering people's faces.
void _clubStoryCover(_StoryPage p) {
  final e = p.edition;
  final wide = p.wide;
  void english(Rect r, double size, {String? color, String align = 'left'}) =>
      p.type(
        e.englishTitle,
        r,
        size: size,
        font: 'Cormorant Garamond',
        color: color,
        align: align,
        role: 'headline',
      );
  void title(Rect r, {String? color, double size = .031}) =>
      p.type(e.title, r, size: size, color: color, role: 'headline');
  switch (e.coverStyle) {
    case 10: // Unbroken photo, type in the lower photographic quiet space.
      if (p.aspect == CollectionAspect.portrait) {
        // A wide group cannot survive a full-height portrait crop. Keep the
        // complete square source and let the quiet cloth border carry type.
        p.box(p.uid, 0, 0, 1, 1, e.ink);
        p.image(0, Rect.fromLTWH(0, .06, 1, p.ratio));
        p._add(p.uid, 'decoration', 0, .54, 1, .30, {
          'style': 'photoCoverShadeBottom',
        });
        english(const Rect.fromLTWH(.07, .62, .86, .18), .11, color: '#FFFFFF');
        title(const Rect.fromLTWH(.075, .88, .85, .05), color: '#FFFFFF');
        p.line(const Rect.fromLTWH(.075, .95, .15, .004));
        break;
      }
      p.image(0, const Rect.fromLTWH(0, 0, 1, 1));
      p._add(p.uid, 'decoration', 0, .57, 1, .43, {
        'style': 'photoCoverShadeBottom',
      });
      english(
        const Rect.fromLTWH(.07, .65, .86, .18),
        wide ? .095 : .11,
        color: '#FFFFFF',
      );
      title(const Rect.fromLTWH(.075, .875, .85, .05), color: '#FFFFFF');
      p.line(const Rect.fromLTWH(.075, .95, .15, .004));
    case 11: // A bookish photographic window with a centered colophon.
      if (wide) {
        p.image(0, const Rect.fromLTWH(.055, .08, .60, .84));
        english(const Rect.fromLTWH(.71, .20, .24, .32), .083);
        title(const Rect.fromLTWH(.70, .70, .25, .12), size: .028);
        p.line(const Rect.fromLTWH(.71, .87, .12, .003));
        break;
      }
      english(const Rect.fromLTWH(.075, .04, .85, .17), .10, align: 'center');
      p.image(0, const Rect.fromLTWH(.075, .25, .85, .59));
      p.line(const Rect.fromLTWH(.44, .85, .12, .003));
      title(const Rect.fromLTWH(.10, .895, .80, .05));
    case 12: // A wide landscape print and a mint field-note margin.
      p.box(p.uid, 0, 0, 1, 1, e.tint);
      p.image(0, const Rect.fromLTWH(.055, .08, .89, .58));
      english(const Rect.fromLTWH(.075, .70, .85, .16), wide ? .085 : .095);
      title(const Rect.fromLTWH(.08, .895, .82, .05), size: .029);
    case 13: // Rehearsal-room photograph and the rhythm of small type.
      p.box(p.uid, 0, 0, 1, 1, e.ink);
      if (wide) {
        p.image(0, const Rect.fromLTWH(.055, .08, .60, .84));
        english(
          const Rect.fromLTWH(.71, .18, .24, .39),
          .076,
          color: '#F7F5F2',
        );
        title(
          const Rect.fromLTWH(.70, .73, .25, .11),
          color: '#F7F5F2',
          size: .027,
        );
        break;
      }
      p.image(0, const Rect.fromLTWH(.05, .055, .90, .61));
      english(
        const Rect.fromLTWH(.075, .70, .85, .17),
        wide ? .078 : .093,
        color: '#F7F5F2',
      );
      title(
        const Rect.fromLTWH(.08, .90, .76, .045),
        color: '#F7F5F2',
        size: .028,
      );
      p.line(const Rect.fromLTWH(.87, .91, .045, .004));
    case 14: // Modest photo pair, a small detail acts as a visual footnote.
      english(const Rect.fromLTWH(.07, .055, .86, .22), wide ? .085 : .10);
      p.image(0, const Rect.fromLTWH(.07, .34, .66, .46));
      p.image(1, const Rect.fromLTWH(.77, .57, .16, .23));
      title(const Rect.fromLTWH(.075, .88, .84, .06));
      p.line(const Rect.fromLTWH(.77, .36, .15, .004));
    case 15: // An exhibition catalogue: large wall scene, restrained index.
      p.type(
        'A YEAR / OUR PHOTO CLUB',
        const Rect.fromLTWH(.065, .055, .87, .035),
        size: .017,
        font: 'Poppins',
        color: e.accent,
      );
      p.image(0, const Rect.fromLTWH(.06, .14, .88, .52));
      english(const Rect.fromLTWH(.075, .70, .85, .15), wide ? .088 : .10);
      title(const Rect.fromLTWH(.08, .89, .80, .05));
      p.line(const Rect.fromLTWH(.08, .96, .84, .002));
    case 16: // Theatre programme: generous photo plus a vertical margin.
      if (wide) {
        p.image(0, const Rect.fromLTWH(.04, .06, .61, .88));
        english(const Rect.fromLTWH(.70, .19, .25, .38), .081);
        title(const Rect.fromLTWH(.70, .73, .25, .11), size: .026);
      } else {
        p.image(0, const Rect.fromLTWH(.06, .06, .88, .58));
        english(const Rect.fromLTWH(.075, .68, .85, .17), .105);
        title(const Rect.fromLTWH(.08, .89, .84, .05));
      }
      p.line(const Rect.fromLTWH(.075, .96, .13, .003));
    case 17: // A photographic dance journal with a broad, quiet mint footer.
      if (wide) {
        p.box(p.uid, 0, 0, 1, 1, e.tint);
        p.image(0, const Rect.fromLTWH(.035, .055, .585, .89));
        english(const Rect.fromLTWH(.68, .20, .27, .33), .078);
        title(const Rect.fromLTWH(.68, .72, .27, .12), size: .025);
        break;
      }
      p.image(0, const Rect.fromLTWH(0, 0, 1, .72));
      p.box(p.uid, 0, .72, 1, .28, e.tint);
      english(const Rect.fromLTWH(.07, .74, .86, .15), wide ? .085 : .093);
      title(const Rect.fromLTWH(.075, .915, .85, .045), size: .028);
    case 18: // Camping yearbook, warm photo against dark ink.
      p.box(p.uid, 0, 0, 1, 1, e.ink);
      if (wide) {
        english(
          const Rect.fromLTWH(.055, .15, .27, .38),
          .082,
          color: '#F7F5F2',
        );
        // Keep the original square group scene, including the member at the
        // right edge, instead of taking another portrait crop from it.
        p.image(0, Rect.fromLTWH(.38, .12, .57, .57 * p.ratio));
        title(
          const Rect.fromLTWH(.06, .70, .26, .14),
          color: '#F7F5F2',
          size: .026,
        );
        p.line(const Rect.fromLTWH(.06, .90, .13, .004));
        break;
      }
      if (p.aspect == CollectionAspect.square) {
        p.type(
          e.englishTitle.replaceAll('\n', ' '),
          const Rect.fromLTWH(.07, .045, .86, .09),
          size: .075,
          font: 'Cormorant Garamond',
          color: '#F7F5F2',
        );
        p.image(0, const Rect.fromLTWH(.14, .18, .72, .72));
        title(
          const Rect.fromLTWH(.08, .935, .84, .035),
          color: '#F7F5F2',
          size: .026,
        );
        break;
      }
      english(const Rect.fromLTWH(.07, .045, .86, .17), .10, color: '#F7F5F2');
      p.image(0, Rect.fromLTWH(.08, .24, .84, .84 * p.ratio));
      title(
        const Rect.fromLTWH(.075, .91, .80, .05),
        color: '#F7F5F2',
        size: .030,
      );
      p.line(const Rect.fromLTWH(.88, .905, .035, .004));
    default: // Craft catalogue; the second print describes the making.
      p.box(p.uid, 0, 0, 1, 1, '#F1EEE6');
      english(const Rect.fromLTWH(.07, .05, .86, .25), wide ? .088 : .11);
      p.image(0, const Rect.fromLTWH(.07, .36, .66, .45));
      p.image(1, const Rect.fromLTWH(.70, .62, .23, .22));
      title(const Rect.fromLTWH(.075, .89, .84, .06), size: .030);
      p.line(const Rect.fromLTWH(.80, .37, .13, .004));
  }
}

List<_StoryPage> _clubStorySpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final layout = _storySequence(e)[i];
  if (!const {0, 2, 8, 10}.contains(layout)) {
    return _exclusiveStorySpread(e, aspect, i);
  }
  final left = _StoryPage(e, aspect, i * 2 + 1, '#F7F5F2');
  final right = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    layout == 8 ? e.tint : '#F7F5F2',
  );
  final title = e.chapters[i];
  void heading(_StoryPage p, String label) {
    p.type(
      label,
      const Rect.fromLTWH(.075, .06, .85, .035),
      size: .017,
      color: e.accent,
      font: 'NotoSans',
    );
    p.heading(title, const Rect.fromLTWH(.075, .13, .85, .12), size: .049);
  }

  void note(_StoryPage p, Rect r) =>
      p.type(e.notes[i], r, size: .026, role: 'body');
  switch (layout) {
    case 0:
      heading(
        left,
        e.isPremium ? 'OUR CLUB / ACTIVITY ARCHIVE' : 'OUR CLUB / DAILY RECORD',
      );
      left.line(const Rect.fromLTWH(.08, .43, .13, .004));
      note(left, const Rect.fromLTWH(.08, .53, .79, .18));
      left.type(
        '모임 이름 · 기록 기간',
        const Rect.fromLTWH(.08, .79, .78, .07),
        size: .024,
      );
      right.image(0, const Rect.fromLTWH(.045, .06, .91, .79));
    case 2: // Roster stays editable, without pretending group crops are portraits.
      heading(left, 'PEOPLE / 함께한 사람들');
      left.image(2, const Rect.fromLTWH(.075, .31, .85, .46));
      note(left, const Rect.fromLTWH(.08, .82, .81, .09));
      right.type(
        e.isPremium ? '함께 만든 사람들' : '우리 모임의 이름들',
        const Rect.fromLTWH(.08, .10, .84, .08),
        size: .039,
        font: 'BookMyungjo',
      );
      for (var n = 0; n < 3; n++) {
        final y = .29 + n * .205;
        right.type(
          '0${n + 1}',
          Rect.fromLTWH(.08, y, .10, .045),
          size: .020,
          color: e.accent,
          font: 'Poppins',
        );
        right.type('이름을 입력해 주세요', Rect.fromLTWH(.23, y, .66, .06), size: .028);
        right.type(
          e.isPremium ? '맡은 역할 · 기억에 남는 한마디' : '좋아하는 활동 · 함께한 날',
          Rect.fromLTWH(.23, y + .075, .66, .05),
          size: .021,
        );
        right.line(Rect.fromLTWH(.23, y + .15, .66, .0015), color: '#B9CECC');
      }
    case 8: // A real activity log, all labels and dates are editable.
      heading(left, e.isPremium ? 'PROCESS / 준비에서 결과까지' : 'MEETINGS / 함께한 시간');
      left.image(1, const Rect.fromLTWH(.075, .32, .85, .35));
      note(left, const Rect.fromLTWH(.08, .76, .80, .13));
      final count = e.isPremium ? 4 : 3;
      for (var n = 0; n < count; n++) {
        final y = .12 + n * (e.isPremium ? .185 : .25);
        right.type(
          '0${n + 1}',
          Rect.fromLTWH(.08, y, .10, .05),
          size: .022,
          color: e.accent,
          font: 'Poppins',
        );
        right.type('날짜 · 장소', Rect.fromLTWH(.24, y, .65, .055), size: .027);
        right.type(
          e.isPremium ? '준비한 일 · 결과 · 다음에 바꿀 점' : '활동 이름 · 오늘 남기고 싶은 말',
          Rect.fromLTWH(.24, y + .075, .65, .055),
          size: .021,
        );
        right.line(Rect.fromLTWH(.24, y + .145, .65, .0015), color: '#B9CECC');
      }
    default: // Outcomes and credits; two generous photographs still lead.
      heading(left, e.isPremium ? 'OUTCOMES / 우리의 결과물' : 'SCENES / 오래 남길 장면');
      left.image(i % 5, const Rect.fromLTWH(.075, .31, .85, .42));
      note(left, const Rect.fromLTWH(.08, .80, .80, .11));
      right.image((i + 1) % 5, const Rect.fromLTWH(.10, .09, .80, .43));
      right.type(
        e.isPremium ? '활동명 · 만든 사람들' : '이날의 활동 · 함께한 사람들',
        const Rect.fromLTWH(.10, .59, .80, .07),
        size: .030,
      );
      right.type(
        e.isPremium ? '장소 · 기간 · 참여자 · 도움을 준 사람들' : '사진 설명을 적어 주세요',
        const Rect.fromLTWH(.10, .71, .80, .10),
        size: .024,
      );
      right.line(const Rect.fromLTWH(.10, .86, .80, .0015), color: '#B9CECC');
  }
  return [left, right];
}
