part of 'authored_collections.dart';

/// Compensate the actual photo aperture for each frame's asymmetric stock.
/// The new 3:2 samples keep their complete bounds in all three print ratios.
Rect _sensoryPhoto(_StoryPage p, int n, Rect bounds, {String frame = 'none'}) {
  final padding = StudioMaterial.photoInsets(frame, const Size(1.5, 1));
  final outerRatio = 1.5 * (1 - padding.vertical) + padding.horizontal;
  final w = math.min(bounds.width, bounds.height * outerRatio / p.ratio);
  final h = w * p.ratio / outerRatio;
  final rect = Rect.fromCenter(center: bounds.center, width: w, height: h);
  p.image(n, rect, frame: frame);
  p.layers.last['sensoryPhotoComposition'] = 'whole-source-3:2';
  return rect;
}

void _sensoryArt(_StoryPage p, String id, Rect region) {
  final art = studioWordArtById(id)!;
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
    final scaled = layer.copyWith(
      position: origin + layer.position * scale,
      width: layer.width * scale,
      height: layer.height * scale,
      textStyle: layer.textStyle?.copyWith(
        fontSize: layer.textStyle!.fontSize! * scale,
      ),
    );
    final raw = LayerExportMapper.toJson(scaled, canvasSize: canvas);
    raw.addAll({
      'type': layer.type.name,
      'id':
          '${p.edition.id}_${p.aspect.name}_${p.index}_word_${p.layers.length}',
      'z': p.layers.length,
      'wordArtId': id,
      'templateContent': true,
    });
    p.layers.add(raw);
  }
}

void _sensoryCover(_StoryPage p) {
  final night = p.edition.isPremium;
  p.box(p.uid, 0, 0, 1, 1, night ? '#17243B' : '#F7F0E4');
  if (night) {
    _sensoryPhoto(p, 0, const Rect.fromLTWH(.045, .045, .91, .56));
    p.type(
      'AFTER HOURS / CITY ARCHIVE',
      const Rect.fromLTWH(.065, .635, .87, .035),
      size: .018,
      font: 'Poppins',
      color: '#AFC5F5',
    );
    p.type(
      '밤의 도시\n수집',
      const Rect.fromLTWH(.06, .69, .70, .22),
      size: .092,
      font: 'Arirang2',
      color: '#F5F2E9',
      role: 'headline',
    );
    p.piece(p.edition.motifId, const Rect.fromLTWH(.78, .74, .18, .19));
    p.type(
      '빛 · 걸음 · 남겨 둔 주소',
      const Rect.fromLTWH(.07, .935, .75, .035),
      size: .022,
      font: 'BookMyungjo',
      color: '#D7E0F0',
    );
  } else {
    p.type(
      'a cup, a little pause',
      const Rect.fromLTWH(.08, .065, .84, .045),
      size: .033,
      font: 'Cormorant Garamond',
      color: '#936044',
    );
    p.type(
      '커피가 식기 전에',
      const Rect.fromLTWH(.075, .14, .83, .12),
      size: .068,
      font: 'BookMyungjo',
      role: 'headline',
    );
    _sensoryPhoto(p, 0, const Rect.fromLTWH(.055, .32, .89, .50));
    p.line(const Rect.fromLTWH(.08, .87, .12, .003));
    p.type(
      '나의 오후를 천천히 모으다',
      const Rect.fromLTWH(.24, .85, .68, .055),
      size: .025,
      font: 'NanumPen',
    );
  }
}

List<_StoryPage> _sensorySpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final night = e.isPremium;
  final l = _StoryPage(e, aspect, i * 2 + 1, night ? '#ECF0F6' : '#FAF5EC');
  final r = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    night && i % 6 == 3 ? '#DFE7F2' : '#F7F3EC',
  );
  final n = (night
      ? const [0, 1, 2, 3, 4, 2, 0, 4, 1, 3, 1, 0]
      : const [0, 1, 2, 0, 4, 3, 1, 0, 3, 4, 1, 4])[i];
  void title(_StoryPage p, {double y = .07}) => p.type(
    e.chapters[i],
    Rect.fromLTWH(.08, y, .84, .10),
    size: .043,
    font: night ? 'Tenada' : 'BookMyungjo',
    role: 'headline',
  );
  void note(_StoryPage p, Rect region) =>
      p.type(e.notes[i], region, size: .026, font: 'BookMyungjo', role: 'body');
  void label(_StoryPage p) => p.type(
    '${(i + 1).toString().padLeft(2, '0')} / ${night ? 'CITY FIELD NOTES' : 'AN AFTERNOON JOURNAL'}',
    const Rect.fromLTWH(.08, .055, .84, .04),
    size: .015,
    font: 'Poppins',
    color: e.accent,
  );
  switch (i % 6) {
    case 0:
      _sensoryPhoto(l, n, const Rect.fromLTWH(.055, .10, .89, .68));
      note(l, const Rect.fromLTWH(.09, .80, .82, .07));
      _sensoryArt(r, e.wordArtId, const Rect.fromLTWH(.08, .18, .84, .52));
      r.type(
        e.chapters[i],
        const Rect.fromLTWH(.10, .78, .80, .08),
        size: .030,
        font: 'BookMyungjo',
      );
    case 1:
      title(l);
      _sensoryPhoto(
        l,
        n,
        const Rect.fromLTWH(.06, .23, .88, .57),
        frame: e.photoFrames[0],
      );
      label(r);
      _sensoryPhoto(r, n + 1, const Rect.fromLTWH(.08, .18, .84, .46));
      note(r, const Rect.fromLTWH(.10, .70, .53, .12));
      r.piece(
        night ? 'nocturneGlassine' : 'cafeRoastedLeaf',
        const Rect.fromLTWH(.69, .65, .27, .25),
      );
    case 2:
      _sensoryPhoto(
        l,
        n,
        const Rect.fromLTWH(.05, .085, .90, .53),
        frame: e.photoFrames[1],
      );
      title(l, y: .67);
      note(l, const Rect.fromLTWH(.09, .81, .80, .07));
      r.piece(e.paperId, const Rect.fromLTWH(.08, .23, .84, .48));
      _sensoryArt(
        r,
        night ? 'sensory-night-index' : 'sensory-coffee-note',
        const Rect.fromLTWH(.12, .28, .70, .32),
      );
      r.piece(e.motifId, const Rect.fromLTWH(.73, .09, .22, .20));
      r.type(
        night ? '출발 · 환승 · 기억할 주소' : '이름 · 맛 · 다시 찾을 이유',
        const Rect.fromLTWH(.10, .77, .80, .06),
        size: .023,
        font: 'BookMyungjo',
      );
    case 3:
      label(l);
      _sensoryPhoto(l, n, const Rect.fromLTWH(.045, .16, .91, .53));
      l.type(
        e.chapters[i],
        const Rect.fromLTWH(.09, .75, .82, .08),
        size: .036,
        font: 'BookMyungjo',
      );
      title(r, y: .13);
      note(r, const Rect.fromLTWH(.10, .30, .78, .12));
      _sensoryPhoto(r, n + 2, const Rect.fromLTWH(.10, .50, .54, .35));
      r.piece(
        night ? e.motifId : 'cafeRoastedLeaf',
        const Rect.fromLTWH(.69, .56, .27, .31),
      );
    case 4:
      title(l);
      _sensoryPhoto(
        l,
        n,
        const Rect.fromLTWH(.07, .23, .86, .55),
        frame: e.photoFrames[2],
      );
      l.type(
        night ? '사진 밖의 도시도 함께 기억한다.' : '사진 밖의 오후도 함께 기억한다.',
        const Rect.fromLTWH(.09, .83, .82, .035),
        size: .021,
        font: 'BookMyungjo',
      );
      _sensoryPhoto(r, n + 1, const Rect.fromLTWH(.08, .08, .84, .43));
      r.line(const Rect.fromLTWH(.10, .57, .11, .004));
      note(r, const Rect.fromLTWH(.10, .64, .73, .13));
      r.piece(e.motifId, const Rect.fromLTWH(.78, .74, .16, .14));
    default:
      label(l);
      _sensoryPhoto(l, n, const Rect.fromLTWH(.07, .17, .86, .47));
      note(l, const Rect.fromLTWH(.10, .72, .80, .11));
      title(r, y: .12);
      _sensoryPhoto(r, n + 2, const Rect.fromLTWH(.08, .34, .84, .44));
      r.type(
        night ? 'NEXT ADDRESS / 다음에 걷고 싶은 곳' : 'UNTIL NEXT TIME / 다음의 한 잔',
        const Rect.fromLTWH(.10, .84, .80, .04),
        size: .020,
        font: 'BookMyungjo',
      );
  }
  return [l, r];
}
