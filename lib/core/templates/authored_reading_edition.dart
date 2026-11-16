part of 'authored_collections.dart';

Rect _readingPhoto(_StoryPage p, int photo, Rect region, {int? mount}) {
  if (mount != null) return _storyMountedPhoto(p, photo, region, mount: mount);
  final width = math.min(region.width, region.height * 1.5 / p.ratio);
  final rect = Rect.fromCenter(
    center: region.center,
    width: width,
    height: width * p.ratio / 1.5,
  );
  p.image(photo, rect);
  p.layers.last['storyPhotoSourceAspect'] = 1.5;
  return rect;
}

Rect _readingCard(_StoryPage p, Rect region) {
  final spec = studioDecorationById(p.edition.paperId)!;
  final width = math.min(
    region.width,
    region.height * spec.aspectRatio / p.ratio,
  );
  final rect = Rect.fromCenter(
    center: region.center,
    width: width,
    height: width * p.ratio / spec.aspectRatio,
  );
  p.piece(p.edition.paperId, rect);
  return rect;
}

Rect _readingCardField(Rect card, double y, double h) => Rect.fromLTWH(
  card.left + card.width * .16,
  card.top + card.height * y,
  card.width * .76,
  card.height * h,
);

void _readingCover(_StoryPage p) {
  p.box(p.uid, 0, 0, 1, 1, '#F4F0E6');
  p.type(
    'A ROOM BETWEEN THE PAGES',
    const Rect.fromLTWH(.08, .055, .84, .035),
    size: .017,
    color: p.edition.accent,
    font: 'Poppins',
  );
  p.type(
    '책장 사이의\n오후',
    const Rect.fromLTWH(.075, .13, .64, .19),
    size: .078,
    font: 'BookMyungjo',
    role: 'headline',
  );
  p.piece(p.edition.motifId, const Rect.fromLTWH(.77, .15, .17, .16));
  _readingPhoto(p, 0, const Rect.fromLTWH(.055, .36, .89, .48));
  p.type(
    '읽고, 머물고, 나의 말로 남기다',
    const Rect.fromLTWH(.08, .885, .84, .045),
    size: .024,
    font: 'BookMyungjo',
  );
}

List<_StoryPage> _readingSpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final l = _StoryPage(e, aspect, i * 2 + 1, i == 2 ? '#E8EBDD' : '#F7F3EA');
  final r = _StoryPage(e, aspect, i * 2 + 2, i == 7 ? '#E8EBDD' : '#FAF7F0');
  void title(_StoryPage p, Rect region, {double size = .043}) => p.type(
    e.chapters[i],
    region,
    size: size,
    font: 'BookMyungjo',
    role: 'headline',
  );
  void note(_StoryPage p, Rect region) =>
      p.type(e.notes[i], region, size: .026, font: 'BookMyungjo', role: 'body');
  void label(_StoryPage p) => p.type(
    '${(i + 1).toString().padLeft(2, '0')} / THE READING ROOM',
    const Rect.fromLTWH(.08, .065, .84, .035),
    size: .015,
    font: 'Poppins',
    color: e.accent,
  );
  switch (i) {
    case 0: // A quiet opening opposite the full library scene.
      label(l);
      title(l, const Rect.fromLTWH(.08, .24, .84, .15), size: .060);
      note(l, const Rect.fromLTWH(.09, .50, .79, .15));
      l.piece(e.motifId, const Rect.fromLTWH(.65, .70, .25, .20));
      _readingPhoto(r, 0, const Rect.fromLTWH(.045, .10, .91, .66));
      r.type(
        '오늘의 첫 장',
        const Rect.fromLTWH(.08, .82, .84, .05),
        font: 'BookMyungjo',
      );
    case 1: // Desktop still life and an editable title assembly.
      _readingPhoto(l, 1, const Rect.fromLTWH(.06, .10, .88, .60), mount: 0);
      title(l, const Rect.fromLTWH(.08, .78, .84, .08));
      _sensoryArt(r, e.wordArtId, const Rect.fromLTWH(.08, .19, .84, .51));
      note(r, const Rect.fromLTWH(.09, .78, .82, .10));
    case 2: // A detail opposite original reflective writing, never a book quote.
      label(l);
      _readingPhoto(l, 4, const Rect.fromLTWH(.06, .19, .88, .51));
      note(l, const Rect.fromLTWH(.09, .77, .82, .11));
      title(r, const Rect.fromLTWH(.08, .13, .84, .10));
      r.type(
        '읽는 시간은\n나의 속도를\n되찾는 시간.',
        const Rect.fromLTWH(.10, .37, .80, .30),
        size: .064,
        font: 'BookMyungjo',
        role: 'headline',
      );
      r.line(const Rect.fromLTWH(.10, .75, .12, .003));
      r.type(
        '오늘 내가 남긴 문장',
        const Rect.fromLTWH(.10, .80, .80, .05),
        size: .024,
        font: 'BookMyungjo',
      );
    case 3: // At home: one generous scene with a small companion photo.
      title(l, const Rect.fromLTWH(.08, .06, .84, .08));
      _readingPhoto(l, 3, const Rect.fromLTWH(.055, .24, .89, .57));
      _readingPhoto(r, 1, const Rect.fromLTWH(.09, .12, .56, .38), mount: 1);
      r.piece(e.motifId, const Rect.fromLTWH(.73, .15, .20, .18));
      r.type(
        '빛이 들어오는 쪽으로',
        const Rect.fromLTWH(.09, .58, .80, .08),
        size: .034,
        font: 'BookMyungjo',
      );
      note(r, const Rect.fromLTWH(.09, .73, .80, .13));
    case 4: // Preserve the whole group photograph and room for a conversation.
      _readingPhoto(l, 2, const Rect.fromLTWH(.045, .09, .91, .65));
      title(l, const Rect.fromLTWH(.08, .81, .84, .07), size: .035);
      title(r, const Rect.fromLTWH(.09, .10, .82, .13), size: .051);
      note(r, const Rect.fromLTWH(.10, .32, .80, .14));
      _readingPhoto(r, 4, const Rect.fromLTWH(.08, .57, .56, .32), mount: 0);
      r.piece(e.motifId, const Rect.fromLTWH(.72, .63, .20, .17));
    case 5: // Staggered detail photographs opposite a shared reading scene.
      _readingPhoto(l, 1, const Rect.fromLTWH(.06, .10, .42, .32));
      _readingPhoto(l, 4, const Rect.fromLTWH(.53, .28, .41, .32));
      title(l, const Rect.fromLTWH(.08, .68, .84, .08));
      note(l, const Rect.fromLTWH(.09, .80, .82, .09));
      _readingPhoto(r, 2, const Rect.fromLTWH(.06, .17, .88, .59), mount: 1);
      r.type(
        '서로의 시선으로 한 번 더',
        const Rect.fromLTWH(.08, .83, .84, .05),
        size: .025,
        font: 'BookMyungjo',
      );
    case 6: // A functional reading card with generous writing space.
      title(l, const Rect.fromLTWH(.08, .09, .84, .10));
      _readingPhoto(l, 1, const Rect.fromLTWH(.06, .27, .88, .54));
      label(r);
      final card = _readingCard(r, const Rect.fromLTWH(.08, .24, .84, .61));
      r.type(
        '제목 / 읽은 날짜',
        _readingCardField(card, .15, .10),
        size: .025,
        font: 'BookMyungjo',
      );
      r.type(
        '오늘 나에게 남은 생각을\n여기에 적어 주세요.',
        _readingCardField(card, .38, .28),
        size: .032,
        font: 'BookMyungjo',
        role: 'body',
      );
      r.type(
        '장소 · 함께 읽은 사람 · 다시 펼칠 이유',
        _readingCardField(card, .74, .08),
        size: .019,
        font: 'BookMyungjo',
      );
    case 7: // A collected detail and an oversize print motif.
      _readingPhoto(l, 4, const Rect.fromLTWH(.08, .11, .84, .51), mount: 0);
      title(l, const Rect.fromLTWH(.08, .70, .84, .08));
      note(l, const Rect.fromLTWH(.09, .81, .82, .08));
      r.piece(e.motifId, const Rect.fromLTWH(.24, .17, .52, .43));
      r.type(
        '여기까지 읽은 오늘',
        const Rect.fromLTWH(.10, .68, .80, .08),
        size: .037,
        font: 'BookMyungjo',
      );
      r.type(
        '멈춘 페이지도 기록이 된다.',
        const Rect.fromLTWH(.10, .82, .80, .05),
        size: .024,
        font: 'BookMyungjo',
      );
    case 8: // Two places in the same book: home and the library.
      _readingPhoto(l, 3, const Rect.fromLTWH(.055, .09, .89, .62));
      note(l, const Rect.fromLTWH(.09, .79, .82, .11));
      title(r, const Rect.fromLTWH(.09, .11, .82, .10));
      _readingPhoto(r, 0, const Rect.fromLTWH(.10, .33, .80, .47), mount: 1);
      r.type(
        '책이 머무는 서로 다른 자리',
        const Rect.fromLTWH(.10, .85, .80, .04),
        size: .023,
        font: 'BookMyungjo',
      );
    case 9: // A personal response card, paired with the blank notebook scene.
      label(l);
      title(l, const Rect.fromLTWH(.08, .21, .84, .11), size: .055);
      note(l, const Rect.fromLTWH(.09, .42, .81, .16));
      l.piece(e.motifId, const Rect.fromLTWH(.65, .68, .24, .21));
      _readingPhoto(r, 1, const Rect.fromLTWH(.06, .10, .88, .54), mount: 0);
      r.type(
        '좋아한 이유 / 달라진 생각',
        const Rect.fromLTWH(.10, .72, .80, .06),
        size: .029,
        font: 'BookMyungjo',
      );
      r.line(const Rect.fromLTWH(.10, .84, .80, .002));
    case 10: // The last page has room to breathe.
      _readingPhoto(l, 4, const Rect.fromLTWH(.06, .18, .88, .58), mount: 1);
      r.type(
        'after\nthe last page',
        const Rect.fromLTWH(.09, .15, .82, .25),
        size: .087,
        font: 'Cormorant Garamond',
      );
      title(r, const Rect.fromLTWH(.10, .51, .80, .10));
      note(r, const Rect.fromLTWH(.10, .71, .78, .16));
    default: // Closing index for the next book and the next meeting.
      title(l, const Rect.fromLTWH(.08, .09, .84, .10));
      _readingPhoto(l, 0, const Rect.fromLTWH(.06, .30, .88, .51));
      label(r);
      final card = _readingCard(r, const Rect.fromLTWH(.08, .23, .84, .62));
      r.type(
        '다음에 펼칠 책',
        _readingCardField(card, .15, .12),
        size: .034,
        font: 'BookMyungjo',
      );
      r.type(
        '책 제목\n다시 만날 날짜\n함께 나누고 싶은 이야기',
        _readingCardField(card, .38, .31),
        size: .029,
        font: 'BookMyungjo',
        role: 'body',
      );
      r.type(
        '계속 읽어 가는 나의 이야기',
        _readingCardField(card, .74, .08),
        size: .021,
        font: 'BookMyungjo',
      );
  }
  return [l, r];
}
