part of 'authored_collections.dart';

// All activity samples are independent 3:2 photographs. Group frames use their
// full source bounds, so changing the book's shape never removes a member.
Rect _activityPhoto(
  _StoryPage p,
  int photo,
  Rect bounds, {
  bool contain = true,
  String frame = 'none',
}) {
  if (!contain) {
    p.image(photo, bounds, frame: frame);
    return bounds;
  }
  // Fit the actual inner photo window, including a mount's asymmetric margins.
  // Keeping only the outer layer at 3:2 would crop people inside a padded frame.
  final insets = StudioMaterial.photoInsets(frame, const Size(1.5, 1));
  final outerRatio = 1.5 * (1 - insets.vertical) + insets.horizontal;
  final width = math.min(bounds.width, bounds.height * outerRatio / p.ratio);
  final height = width * p.ratio / outerRatio;
  final rect = Rect.fromLTWH(
    bounds.left + (bounds.width - width) / 2,
    bounds.top + (bounds.height - height) / 2,
    width,
    height,
  );
  p.image(photo, rect, frame: frame);
  p.layers.last['activityPhotoComposition'] = 'whole-source-3:2';
  return rect;
}

void _activityPhotoOnPaper(_StoryPage p, int photo, Rect bounds) {
  final spec = studioDecorationById(p.edition.paperId)!;
  final w = math.min(bounds.width, bounds.height * spec.aspectRatio / p.ratio);
  final h = w * p.ratio / spec.aspectRatio;
  final paper = Rect.fromLTWH(
    bounds.center.dx - w / 2,
    bounds.center.dy - h / 2,
    w,
    h,
  );
  p.piece(p.edition.paperId, paper);
  _activityPhoto(
    p,
    photo,
    Rect.fromLTWH(paper.left + w * .065, paper.top + h * .10, w * .87, h * .68),
    frame: p.edition.photoFrames.last,
  );
}

void _activityStoryCover(_StoryPage p) {
  final e = p.edition;
  final club = e.category == '동아리';
  void label(String text, Rect r, {String? color}) =>
      p.type(text, r, size: .017, color: color ?? e.accent, font: 'Poppins');
  void title(Rect r, {String? color}) =>
      p.type(e.title, r, size: .033, color: color, role: 'headline');
  void english(Rect r, {String? color, double size = .10, String? font}) =>
      p.type(
        e.englishTitle,
        r,
        size: size,
        font: font ?? (club ? 'Cormorant Garamond' : 'Raleway'),
        color: color,
        role: 'headline',
      );
  if (club && p.wide) {
    // A landscape book uses a side column instead of shrinking the group to
    // a short horizontal strip. The entire source, including edge members,
    // stays visible at a useful size.
    final dark = e.coverStyle == 21 || e.coverStyle == 24;
    final reverse = e.coverStyle == 21 || e.coverStyle == 24;
    final foreground = dark ? '#F7F5F2' : e.ink;
    p.box(p.uid, 0, 0, 1, 1, dark ? e.ink : e.tint);
    final photoX = reverse ? .365 : .035;
    final textX = reverse ? .055 : .700;
    final main = e.coverStyle == 23 ? 2 : 0;
    final photoBounds = switch (e.coverStyle) {
      22 => const Rect.fromLTWH(.04, .07, .62, .78),
      23 => const Rect.fromLTWH(.035, .20, .605, .66),
      24 => const Rect.fromLTWH(.37, .08, .595, .76),
      _ => Rect.fromLTWH(photoX, .14, .60, .70),
    };
    _activityPhoto(p, main, photoBounds);
    label(
      'OUR CLUB / OUR DAYS',
      Rect.fromLTWH(textX, .07, .25, .055),
      color: dark ? '#A5D9D5' : e.accent,
    );
    english(
      Rect.fromLTWH(textX, .24, .25, .35),
      color: foreground,
      size: e.coverStyle == 22 ? .068 : .072,
    );
    title(Rect.fromLTWH(textX, .73, .25, .14), color: foreground);
    p.line(Rect.fromLTWH(textX, .93, .14, .003));
    if (e.coverStyle == 23) {
      _activityPhoto(p, 1, const Rect.fromLTWH(.79, .55, .15, .16));
    }
    return;
  }
  switch (e.coverStyle) {
    case 20: // Running crew: an unbroken group panorama with a mint colophon.
      p.box(p.uid, 0, 0, 1, 1, e.tint);
      label('OUR RUNNING CIRCLE', const Rect.fromLTWH(.07, .055, .86, .035));
      _activityPhoto(p, 0, const Rect.fromLTWH(.04, .14, .92, .49));
      english(const Rect.fromLTWH(.07, .66, .86, .17), size: .096);
      title(const Rect.fromLTWH(.075, .89, .85, .055));
      p.line(const Rect.fromLTWH(.075, .96, .13, .003));
    case 21: // Climbing club: a loose team photograph, small chalk detail.
      label('HOLD / HELP / TOGETHER', const Rect.fromLTWH(.07, .045, .86, .03));
      english(const Rect.fromLTWH(.07, .11, .86, .17), size: .095);
      _activityPhoto(p, 0, const Rect.fromLTWH(.05, .33, .90, .40));
      _activityPhoto(
        p,
        1,
        const Rect.fromLTWH(.75, .78, .18, .12),
        frame: e.photoFrames.last,
      );
      title(const Rect.fromLTWH(.075, .825, .64, .08));
      p.line(const Rect.fromLTWH(.075, .945, .85, .002));
    case 22: // Golf club: soft clubhouse paper and a large companion scene.
      p.box(p.uid, 0, 0, 1, 1, '#EFF3EB');
      english(const Rect.fromLTWH(.08, .055, .84, .17), size: .102);
      label(
        'GOOD COMPANY / A SHARED ROUND',
        const Rect.fromLTWH(.08, .27, .84, .03),
      );
      _activityPhoto(
        p,
        0,
        const Rect.fromLTWH(.04, .34, .92, .44),
        frame: e.photoFrames.first,
      );
      title(const Rect.fromLTWH(.08, .85, .84, .06));
      p.type(
        '모임 이름 · 라운드 날짜',
        const Rect.fromLTWH(.08, .935, .78, .027),
        size: .016,
      );
    case 23: // Badminton club: two wide team views, never portrait slivers.
      english(const Rect.fromLTWH(.07, .045, .86, .17), size: .09);
      _activityPhoto(p, 0, const Rect.fromLTWH(.045, .255, .91, .32));
      _activityPhoto(p, 2, const Rect.fromLTWH(.15, .59, .80, .23));
      p.line(const Rect.fromLTWH(.065, .60, .004, .20));
      title(const Rect.fromLTWH(.075, .885, .84, .055));
    case 24: // Cycling circle: dark cloth, generous light photograph, no masks.
      p.box(p.uid, 0, 0, 1, 1, e.ink);
      label(
        'OUR RIDING JOURNAL',
        const Rect.fromLTWH(.07, .05, .86, .03),
        color: '#A5D9D5',
      );
      english(
        const Rect.fromLTWH(.07, .12, .86, .17),
        color: '#F7F5F2',
        size: .102,
      );
      _activityPhoto(p, 0, const Rect.fromLTWH(.04, .36, .92, .43));
      title(const Rect.fromLTWH(.075, .865, .85, .06), color: '#F7F5F2');
      p.line(const Rect.fromLTWH(.075, .96, .85, .002));
    case 25: // Personal running: immersed in the track, quiet top typography.
      _activityPhoto(p, 0, const Rect.fromLTWH(0, .30, 1, .70), contain: false);
      p.box(p.uid, 0, 0, 1, .30, e.tint);
      label(
        'A PERSONAL TRAINING JOURNAL',
        const Rect.fromLTWH(.06, .035, .88, .025),
      );
      english(const Rect.fromLTWH(.055, .078, .89, .16), size: .103);
      title(const Rect.fromLTWH(.06, .25, .89, .035));
    case 26: // Personal bouldering: a dark technical spread with one full body.
      p.box(p.uid, 0, 0, 1, 1, '#163B42');
      label(
        'BOULDER / OBSERVE / REPEAT',
        const Rect.fromLTWH(.07, .05, .86, .03),
        color: '#A5D9D5',
      );
      _activityPhoto(p, 0, const Rect.fromLTWH(.05, .12, .90, .53));
      english(
        const Rect.fromLTWH(.07, .69, .86, .17),
        color: '#F7F5F2',
        size: .105,
      );
      title(const Rect.fromLTWH(.075, .92, .85, .045), color: '#F7F5F2');
    case 27: // Personal golf: editorial scorecard with a broad photo window.
      label(
        'PRACTICE / NOT PERFECTION',
        const Rect.fromLTWH(.07, .055, .86, .03),
      );
      english(
        const Rect.fromLTWH(.07, .13, .86, .18),
        size: .10,
        font: 'Cormorant Garamond',
      );
      p.line(const Rect.fromLTWH(.07, .345, .86, .002));
      _activityPhoto(
        p,
        0,
        const Rect.fromLTWH(.07, .40, .86, .40),
        frame: e.photoFrames.first,
      );
      title(const Rect.fromLTWH(.075, .865, .85, .06));
      p.type(
        '오늘의 감각을 기록합니다',
        const Rect.fromLTWH(.075, .945, .85, .026),
        size: .016,
      );
    case 28: // Personal tennis: asymmetric action + grip, no team yearbook grid.
      p.box(p.uid, 0, 0, 1, 1, e.tint);
      label(
        'BASELINE / A PRACTICE STUDY',
        const Rect.fromLTWH(.06, .045, .88, .03),
      );
      english(const Rect.fromLTWH(.06, .105, .88, .17), size: .11);
      _activityPhoto(p, 2, const Rect.fromLTWH(.03, .32, .94, .39));
      _activityPhoto(
        p,
        1,
        const Rect.fromLTWH(.72, .735, .23, .135),
        frame: e.photoFrames.last,
      );
      title(const Rect.fromLTWH(.06, .815, .61, .09));
      p.line(const Rect.fromLTWH(.06, .945, .42, .003));
    default: // Swimming: panoramic water, restrained breath marks in the margin.
      p.box(p.uid, 0, 0, 1, 1, '#E0F1F1');
      _activityPhoto(p, 0, const Rect.fromLTWH(0, .05, 1, .55));
      english(const Rect.fromLTWH(.07, .66, .86, .16), size: .087);
      title(const Rect.fromLTWH(.075, .875, .85, .06));
      label(
        'SWIM / BREATHE / RETURN',
        const Rect.fromLTWH(.075, .95, .85, .025),
      );
  }
}

String _activityFields(StoryEdition e) => switch (e.activity!) {
  StoryActivity.running =>
    e.category == '동아리' ? '코스 · 거리 · 함께 뛴 사람' : '거리 · 시간 · 페이스 · 컨디션',
  StoryActivity.climbing =>
    e.category == '동아리' ? '암장 · 함께 푼 루트 · 응원 한마디' : '루트 · 시도 · 발의 위치 · 다음 동작',
  StoryActivity.golf =>
    e.category == '동아리' ? '코스 · 동반자 · 기억에 남는 홀' : '클럽 · 그립 · 방향 · 오늘의 감각',
  StoryActivity.badminton => '코트 · 복식 파트너 · 함께한 게임',
  StoryActivity.cycling => '코스 · 거리 · 쉼터 · 함께 탄 사람',
  StoryActivity.tennis => '서브 · 랠리 · 풋워크 · 다음 연습',
  StoryActivity.swimming => '거리 · 시간 · 호흡 · 회복 메모',
};

void _activityWordArt(_StoryPage p) {
  final e = p.edition;
  final art = studioWordArts.singleWhere((a) => a.id == e.wordArtId);
  for (final layer in art.buildLayers(p.aspect.canvas)) {
    final raw = LayerExportMapper.toJson(layer, canvasSize: p.aspect.canvas);
    raw['type'] = layer.type.name;
    raw['id'] = '${e.id}_${p.aspect.name}_${p.index}_word_${p.layers.length}';
    raw['z'] = p.layers.length;
    raw['wordArtId'] = e.wordArtId;
    raw['templateContent'] = true;
    p.layers.add(raw);
  }
}

List<_StoryPage> _activityStorySpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final layout = _storySequence(e)[i];
  final club = e.category == '동아리';
  final left = _StoryPage(
    e,
    aspect,
    i * 2 + 1,
    layout == 5 ? e.tint : '#F7F5F2',
  );
  final right = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    layout == 8 ? e.tint : '#F7F5F2',
  );
  final title = e.chapters[i];
  void heading(_StoryPage p, {String? label}) {
    p.type(
      label ?? (club ? 'OUR CLUB / SHARED DAYS' : 'PERSONAL / TRAINING NOTES'),
      const Rect.fromLTWH(.075, .055, .85, .035),
      size: .017,
      font: 'Poppins',
      color: e.accent,
    );
    p.heading(title, const Rect.fromLTWH(.075, .125, .85, .12), size: .048);
  }

  void note(_StoryPage p, Rect r) =>
      p.type(e.notes[i], r, size: .026, role: 'body');
  void photo(_StoryPage p, int n, Rect bounds, {int? mount}) => _activityPhoto(
    p,
    n,
    bounds,
    frame: mount == null ? 'none' : e.photoFrames[mount],
  );
  switch (layout) {
    case 0:
      heading(left);
      left.line(const Rect.fromLTWH(.08, .34, .13, .004));
      note(left, const Rect.fromLTWH(.08, .46, .82, .19));
      left.type(
        club ? '모임 이름 · 기록 기간' : '이름 · 훈련 기간',
        const Rect.fromLTWH(.08, .79, .82, .07),
        size: .023,
      );
      photo(right, 0, const Rect.fromLTWH(.04, .12, .92, .68));
      right.type(
        club ? '함께 시작한 오늘' : '오늘의 출발점',
        const Rect.fromLTWH(.075, .86, .85, .05),
        size: .023,
      );
    case 1:
      heading(left);
      photo(left, 1, const Rect.fromLTWH(.08, .33, .84, .41), mount: 0);
      note(left, const Rect.fromLTWH(.08, .82, .82, .10));
      photo(right, 4, const Rect.fromLTWH(.08, .16, .84, .52), mount: 1);
      right.type(
        club ? '모이기 전 챙긴 것들' : '나에게 익숙해진 준비물',
        const Rect.fromLTWH(.08, .76, .84, .07),
        size: .031,
      );
      right.line(const Rect.fromLTWH(.08, .87, .84, .0015), color: '#B9CECC');
    case 2:
      heading(left, label: club ? 'PEOPLE / OUR CIRCLE' : 'FOCUS / ONE THING');
      photo(
        left,
        club ? 0 : 2,
        const Rect.fromLTWH(.04, .33, .92, .39),
        mount: 0,
      );
      note(left, const Rect.fromLTWH(.08, .81, .82, .11));
      right.heading(
        club ? '함께한 사람들' : '오늘 집중할 한 가지',
        const Rect.fromLTWH(.08, .09, .84, .10),
        size: .040,
      );
      if (club) {
        // Four to six editable names; no misleading portrait crops from a group.
        final rows = (e.memberSlots / 2).ceil();
        for (var n = 0; n < e.memberSlots; n++) {
          final x = .08 + (n % 2) * .46;
          final y = .30 + (n ~/ 2) * (.56 / rows);
          right.type(
            '${n + 1}'.padLeft(2, '0'),
            Rect.fromLTWH(x, y, .10, .035),
            size: .018,
            font: 'Poppins',
            color: e.accent,
          );
          right.type(
            '이름을 입력해 주세요',
            Rect.fromLTWH(x, y + .05, .37, .065),
            size: .022,
          );
          right.type(
            '함께한 날 · 한마디',
            Rect.fromLTWH(x, y + .12, .37, .040),
            size: .017,
          );
          right.line(Rect.fromLTWH(x, y + .17, .37, .0015), color: '#B9CECC');
        }
      } else {
        for (var n = 0; n < 3; n++) {
          final y = .30 + n * .20;
          right.type(
            ['시작 전의 몸 상태', '바꿔 볼 한 가지', '끝난 뒤 남길 느낌'][n],
            Rect.fromLTWH(.08, y, .84, .065),
            size: .027,
          );
          right.line(
            Rect.fromLTWH(.08, y + .115, .84, .0015),
            color: '#B9CECC',
          );
        }
      }
    case 3:
      heading(left);
      photo(left, club ? 2 : 0, const Rect.fromLTWH(.035, .29, .93, .48));
      note(left, const Rect.fromLTWH(.08, .83, .82, .10));
      if (club) {
        photo(right, 3, const Rect.fromLTWH(0, 0, 1, 1));
      } else {
        photo(right, 3, const Rect.fromLTWH(.07, .09, .86, .48));
        right.type(
          club ? '서로의 속도를 기다리며' : '사진으로 다시 본 움직임',
          const Rect.fromLTWH(.08, .65, .84, .08),
          size: .034,
        );
        right.type(
          _activityFields(e),
          const Rect.fromLTWH(.08, .79, .84, .09),
          size: .023,
        );
      }
    case 4:
      photo(
        left,
        club ? 3 : 2,
        const Rect.fromLTWH(.02, .035, .96, .69),
        mount: 1,
      );
      note(left, const Rect.fromLTWH(.08, .82, .82, .11));
      _activityWordArt(right);
    case 5:
      heading(left);
      // Photo-compatible paper is kept behind one quiet note field, not faces.
      left.piece(e.paperId, const Rect.fromLTWH(.08, .36, .84, .44));
      left.type(
        club ? '오늘 함께한 장면' : '오늘 달라진 감각',
        const Rect.fromLTWH(.15, .44, .69, .055),
        size: .030,
      );
      note(left, const Rect.fromLTWH(.15, .55, .67, .15));
      photo(right, 2, const Rect.fromLTWH(.04, .14, .92, .66));
      right.piece(e.motifId, const Rect.fromLTWH(.78, .84, .13, .10));
    case 6:
      heading(left);
      photo(left, club ? 3 : 4, const Rect.fromLTWH(.055, .32, .89, .39));
      note(left, const Rect.fromLTWH(.08, .81, .82, .11));
      // One print-friendly paper backing under the mounted detail photograph;
      // other large photographs stay open, so the book is not over-decorated.
      _activityPhotoOnPaper(right, 4, const Rect.fromLTWH(.045, .07, .91, .45));
      right.heading(
        club ? '잠깐의 쉼도 함께' : '회복을 위한 작은 시간',
        const Rect.fromLTWH(.08, .57, .84, .13),
        size: .039,
      );
      right.type(
        club ? '쉬었던 자리 · 나눈 이야기' : '수분 · 휴식 · 몸이 보낸 신호',
        const Rect.fromLTWH(.08, .78, .84, .08),
        size: .024,
      );
    case 7:
      heading(left);
      photo(left, 2, const Rect.fromLTWH(.035, .30, .93, .47));
      note(left, const Rect.fromLTWH(.08, .84, .82, .09));
      if (club) {
        photo(right, 0, const Rect.fromLTWH(0, 0, 1, 1));
      } else {
        photo(right, 0, const Rect.fromLTWH(.035, .08, .93, .47));
        right.type(
          club ? '같은 활동, 서로 다른 장면' : '한 동작의 전과 후',
          const Rect.fromLTWH(.08, .65, .84, .07),
          size: .032,
        );
        right.type(
          club ? '활동 이름 · 함께한 사람 · 기억할 순간' : '좋았던 점 · 다음에 바꿀 점',
          const Rect.fromLTWH(.08, .78, .84, .09),
          size: .023,
        );
      }
    case 8:
      heading(left, label: club ? 'MEETINGS / OUR LOG' : 'PRACTICE / MY LOG');
      photo(left, 1, const Rect.fromLTWH(.08, .33, .84, .34), mount: 1);
      note(left, const Rect.fromLTWH(.08, .78, .82, .12));
      for (var n = 0; n < 4; n++) {
        final y = .11 + n * .195;
        right.type(
          '0${n + 1}',
          Rect.fromLTWH(.08, y, .10, .04),
          size: .020,
          font: 'Poppins',
          color: e.accent,
        );
        right.type('날짜 · 장소', Rect.fromLTWH(.23, y, .68, .055), size: .027);
        right.type(
          _activityFields(e),
          Rect.fromLTWH(.23, y + .074, .68, .075),
          size: .020,
        );
        right.line(Rect.fromLTWH(.23, y + .16, .68, .0015), color: '#B9CECC');
      }
    case 9:
      heading(left);
      photo(left, 4, const Rect.fromLTWH(.075, .32, .85, .39), mount: 0);
      left.piece(e.motifId, const Rect.fromLTWH(.79, .735, .12, .06));
      note(left, const Rect.fromLTWH(.08, .81, .82, .11));
      right.heading(
        club ? '다음에도 함께할 약속' : '다음 훈련에 가져갈 메모',
        const Rect.fromLTWH(.08, .10, .84, .15),
        size: .044,
      );
      for (var n = 0; n < 3; n++) {
        final y = .36 + n * .175;
        right.type(
          (club
              ? ['다음에 만날 날짜', '해 보고 싶은 활동', '함께 챙길 준비물']
              : ['다음 연습의 목표', '다시 확인할 한 동작', '몸을 위해 지킬 것'])[n],
          Rect.fromLTWH(.08, y, .84, .06),
          size: .026,
        );
        right.line(Rect.fromLTWH(.08, y + .11, .84, .0015), color: '#B9CECC');
      }
    case 10:
      heading(
        left,
        label: club ? 'VOICES / EVERYONE COUNTS' : 'REFLECTION / SMALL CHANGES',
      );
      photo(left, 3, const Rect.fromLTWH(.035, .32, .93, .41));
      note(left, const Rect.fromLTWH(.08, .82, .82, .10));
      right.heading(
        club ? '오늘의 한마디를 모아' : '숫자 밖의 변화',
        const Rect.fromLTWH(.08, .10, .84, .13),
        size: .043,
      );
      for (var n = 0; n < 3; n++) {
        final y = .32 + n * .19;
        right.type(
          club ? '이름 · 기억에 남는 한마디' : ['잘된 순간', '어려웠던 순간', '다음의 나에게'][n],
          Rect.fromLTWH(.08, y, .84, .07),
          size: .026,
        );
        right.line(Rect.fromLTWH(.08, y + .13, .84, .0015), color: '#B9CECC');
      }
    default:
      photo(
        left,
        club ? 0 : 3,
        const Rect.fromLTWH(.035, .10, .93, .64),
        mount: 1,
      );
      note(left, const Rect.fromLTWH(.08, .82, .82, .11));
      right.type(
        e.englishTitle,
        const Rect.fromLTWH(.08, .18, .84, .24),
        size: .090,
        font: club ? 'Cormorant Garamond' : 'Raleway',
        role: 'headline',
      );
      right.line(const Rect.fromLTWH(.08, .51, .14, .003));
      right.type(
        club ? '오늘 함께한 사람들에게' : '오늘의 나에게',
        const Rect.fromLTWH(.08, .63, .84, .06),
        size: .030,
      );
      right.type(
        club ? '모임 이름 · 기록한 사람 · 도움을 준 사람들' : '기록한 날짜 · 이름 · 다음에 남길 이야기',
        const Rect.fromLTWH(.08, .77, .84, .09),
        size: .023,
      );
  }
  return [left, right];
}
