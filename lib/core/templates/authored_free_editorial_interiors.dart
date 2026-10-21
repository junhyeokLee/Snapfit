part of 'authored_collections.dart';

const _freeInteriorEditorialRevision = 'photo-editorial-2026-10-21';

/// A catalog-only pass. The original authors, saved books and paid editions are
/// never rewritten. Source photographs and every editable sentence keep their
/// layer identity; only presentation and removable decoration change here.
Map<String, dynamic> _refineFreeEditorialInteriors(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (!authoredCollections.any((collection) => collection.id == id)) {
    return document;
  }
  final sourcePages = document['pages'];
  if (sourcePages is! List) return document;
  final direction = _FreeInteriorDirection.forCollection(id);
  final pages = <Map<String, dynamic>>[];
  for (var index = 0; index < sourcePages.length; index++) {
    final page = Map<String, dynamic>.from(sourcePages[index] as Map);
    // These six previously reviewed studies already carry the book's complete
    // photographic, typographic and journal direction. Preserve that work.
    if (id == windAtlasId && const {3, 4, 7, 8, 13, 14}.contains(index + 1)) {
      final layers = (page['layers'] as List)
          .map((raw) => Map<String, dynamic>.from(raw as Map))
          .toList();
      final footers = layers.where(_FreeInteriorPage._isFooter).toList();
      final bottom = footers.fold<double>(
        0,
        (value, layer) => math.max(
          value,
          ((layer['y'] as num).toDouble() +
                  ((layer['h'] ?? layer['height']) as num).toDouble()) *
              aspect.canvas.height,
        ),
      );
      final shift = math.max(0, bottom - aspect.canvas.height + 12.5);
      if (shift > 0) {
        for (final footer in footers) {
          footer['y'] =
              (footer['y'] as num).toDouble() - shift / aspect.canvas.height;
        }
      }
      pages.add({
        ...page,
        'layers': layers,
        'editorialRevision': _freeInteriorEditorialRevision,
        'editorialLayout': 'wind-signature-preserved',
      });
      continue;
    }
    pages.add(
      _FreeInteriorPage(
        id,
        aspect,
        index + 1,
        sourcePages.length,
        direction,
        page,
      ).compose(),
    );
  }
  return {
    ...document,
    'editorialRevision': _freeInteriorEditorialRevision,
    'pages': pages,
  };
}

class _FreeInteriorDirection {
  const _FreeInteriorDirection(
    this.paper,
    this.ink,
    this.accent,
    this.display,
    this.phase,
  );
  final String paper, ink, accent, display;
  final int phase;

  factory _FreeInteriorDirection.forCollection(String id) {
    final volume = FreeCollectionVolume.byId(id);
    if (volume != null) {
      final palette = _freePalettes[volume] ?? _lifePalettes[volume]!;
      final serif = palette.serif;
      final display = serif
          ? volume.index.isEven
                ? 'Eulyoo'
                : 'BookMyungjo'
          : volume.index % 3 == 0
          ? 'BookMyungjo'
          : 'NotoSans';
      return _FreeInteriorDirection(
        palette.paper,
        palette.ink,
        palette.accent,
        display,
        volume.index % 7,
      );
    }
    return switch (id) {
      'lightbound' => const _FreeInteriorDirection(
        '#FBFAF5',
        '#293B36',
        '#87705A',
        'BookMyungjo',
        0,
      ),
      'journey' => const _FreeInteriorDirection(
        '#F7F5ED',
        '#174D50',
        '#A24E3B',
        'Eulyoo',
        2,
      ),
      'small-days' => const _FreeInteriorDirection(
        '#FAF8F3',
        '#413440',
        '#80566D',
        'NotoSans',
        4,
      ),
      windAtlasId => const _FreeInteriorDirection(
        '#F5F2E9',
        '#243A34',
        '#8B4534',
        'Eulyoo',
        1,
      ),
      proseStudyId => const _FreeInteriorDirection(
        '#FAFAF6',
        '#233D35',
        '#842B3D',
        'BookMyungjo',
        3,
      ),
      'alley-afternoon' => const _FreeInteriorDirection(
        '#F8F5EC',
        '#183C44',
        '#A95740',
        'NotoSans',
        5,
      ),
      'saturday-together' => const _FreeInteriorDirection(
        '#FFF9EE',
        '#3B4836',
        '#B56537',
        'BookMyungjo',
        1,
      ),
      'daily-paw-walk' => const _FreeInteriorDirection(
        '#FAFBF7',
        '#203D73',
        '#A36F1D',
        'NotoSans',
        6,
      ),
      'our-first-promise' => const _FreeInteriorDirection(
        '#FAFCFA',
        '#254B51',
        '#7F6757',
        'Eulyoo',
        2,
      ),
      'little-day-discoveries' => const _FreeInteriorDirection(
        '#FFFBF4',
        '#4C4935',
        '#9F573B',
        'NotoSans',
        4,
      ),
      _ => const _FreeInteriorDirection(
        '#FAFAF6',
        '#243A34',
        '#8B4534',
        'Eulyoo',
        0,
      ),
    };
  }
}

class _FreeInteriorPage {
  _FreeInteriorPage(
    this.collection,
    this.aspect,
    this.number,
    this.pageCount,
    this.direction,
    this.source,
  ) {
    for (final raw in source['layers'] as List? ?? const []) {
      if (raw is! Map) continue;
      final layer = Map<String, dynamic>.from(raw);
      final type = '${layer['type']}'.toLowerCase();
      if (type == 'image') photos.add(_freeInteriorCorrectSample(layer));
      if (type == 'text') {
        (_isFooter(layer) ? footers : texts).add(layer);
      }
    }
    photos.sort((a, b) => _sourceArea(b).compareTo(_sourceArea(a)));
    texts.sort(_readingOrder);
    footers.sort(_readingOrder);
  }

  final String collection;
  final CollectionAspect aspect;
  final int number, pageCount;
  final _FreeInteriorDirection direction;
  final Map<String, dynamic> source;
  final photos = <Map<String, dynamic>>[];
  final texts = <Map<String, dynamic>>[];
  final footers = <Map<String, dynamic>>[];
  final placedPhotos = <Map<String, dynamic>>[];
  final placedTexts = <Map<String, dynamic>>[];
  Size get canvas => aspect.canvas;
  bool get wide => aspect == CollectionAspect.landscape;
  bool get tall => aspect == CollectionAspect.portrait;
  bool get left => number.isOdd;
  int get spread => (number - 1) ~/ 2;
  Rect get safe => Rect.fromLTRB(
    canvas.width * (left ? .065 : .085),
    canvas.height * .075,
    canvas.width * (left ? .915 : .935),
    math.min(canvas.height * .89, canvas.height - 47),
  );
  late final String layout = _chooseLayout();
  late final bool dark =
      photos.length <= 2 &&
      texts.length <= 4 &&
      (layout == 'photographic-pause' || layout == 'closing-portrait') &&
      (spread + direction.phase) % 4 == 2;
  String get paper => dark ? direction.ink : direction.paper;
  String get ink => dark ? direction.paper : direction.ink;

  static bool _isFooter(Map<String, dynamic> layer) {
    final id = '${layer['id']}'.toLowerCase();
    return id.endsWith('_folio') ||
        id.contains('_folio_') ||
        id.contains('_running_title') ||
        id.contains('_running_head');
  }

  static double _number(Object? value, [double fallback = 0]) =>
      value is num && value.isFinite ? value.toDouble() : fallback;

  static int _readingOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final y = _number(a['y']).compareTo(_number(b['y']));
    return y != 0 ? y : _number(a['x']).compareTo(_number(b['x']));
  }

  static double _sourceArea(Map<String, dynamic> layer) =>
      _number(layer['w'] ?? layer['width']) *
      _number(layer['h'] ?? layer['height']);

  String _sourceText(Map<String, dynamic> layer) =>
      '${layer['editorialSourceText'] ?? layer['text'] ?? (layer['payload'] is Map ? (layer['payload'] as Map)['text'] : null) ?? ''}';

  bool _body(Map<String, dynamic> layer) {
    final id = '${layer['id']}'.toLowerCase();
    final text = _sourceText(layer);
    return '${layer['typographyRole']}' == 'body' ||
        text.runes.length >= 75 ||
        RegExp(
          r'letter|journal|essay|note|message|memory_value|stop_note|list',
        ).hasMatch(id);
  }

  bool _headline(Map<String, dynamic> layer) {
    final text = _sourceText(layer).trim();
    if (text.isEmpty ||
        text.runes.length > 100 ||
        RegExp(r'^[0-9\s./:·—–-]+$').hasMatch(text))
      return false;
    final id = '${layer['id']}'.toLowerCase();
    final style = layer['style'] is Map ? layer['style'] as Map : const {};
    return RegExp(r'_title$|_heading$|_headline|quality_title').hasMatch(id) ||
        !_body(layer) && _number(style['fontSize']) >= 21;
  }

  String _chooseLayout() {
    final role = '${source['role']} ${source['name']}'.toLowerCase();
    final words = texts.fold<int>(
      0,
      (sum, item) => sum + _sourceText(item).runes.length,
    );
    if (photos.isEmpty)
      return words > 200 ? 'reading-room' : 'statement-register';
    if (photos.length >= 4) return 'contact-gallery';
    if (photos.length == 3) return 'three-scene-sequence';
    if (words > 260 ||
        texts.length >= 7 ||
        RegExp(
          r'letter|journal|ledger|register|inventory|timeline',
        ).hasMatch(role)) {
      return 'photo-journal';
    }
    if (number >= pageCount - 1) return 'closing-portrait';
    if (number <= 2) return left ? 'opening-statement' : 'opening-photograph';
    if (photos.length == 2)
      return (spread + direction.phase).isEven
          ? 'asymmetric-duet'
          : 'paired-gallery';
    if (RegExp(
      r'panorama|landscape|sea|coast|still|portrait|gallery',
    ).hasMatch(role)) {
      return 'photographic-pause';
    }
    return switch ((spread + direction.phase) % 4) {
      0 => 'headline-and-scene',
      1 => 'photographic-pause',
      2 => 'margin-essay',
      _ => 'scene-and-caption',
    };
  }

  Map<String, dynamic> compose() {
    if (photos.isEmpty) {
      _textOnly();
    } else if (photos.length >= 3) {
      _gallery();
    } else if (layout == 'photo-journal') {
      _journal();
    } else if (photos.length == 2) {
      _duet();
    } else {
      _single();
    }
    _footer();
    final original = (source['layers'] as List? ?? const []).whereType<Map>();
    final background = original
        .where(
          (layer) =>
              '${layer['type']}'.toLowerCase() == 'decoration' &&
              _number(layer['x']).abs() < .001 &&
              _number(layer['y']).abs() < .001 &&
              _number(layer['w'] ?? layer['width']) >= .98 &&
              _number(layer['h'] ?? layer['height']) >= .98,
        )
        .firstOrNull;
    final paperLayer = <String, dynamic>{
      if (background != null) ...Map<String, dynamic>.from(background),
      'id':
          background?['id'] ??
          '${collection}_${aspect.name}_${number}_editorial_paper',
      'type': 'decoration',
      'x': 0,
      'y': 0,
      'w': 1,
      'h': 1,
      'z': 0,
      'fillColor': paper,
      'cornerRadius': 0,
      'rotation': 0,
      'opacity': 1,
    };
    paperLayer.remove('style');
    paperLayer.remove('imageUrl');
    paperLayer.remove('payload');
    final layers = <Map<String, dynamic>>[
      paperLayer,
      if (layout == 'statement-register' || layout == 'reading-room')
        {
          'id': '${collection}_${aspect.name}_${number}_editorial_rule',
          'type': 'decoration',
          'x': safe.left / canvas.width,
          'y': .051,
          'w': math.min(.20, safe.width / canvas.width),
          'h': 1 / canvas.height,
          'fillColor': direction.accent,
          'cornerRadius': 0,
        },
      ...placedPhotos,
      ...placedTexts,
    ];
    for (var i = 0; i < layers.length; i++) layers[i]['z'] = i;
    return {
      ...source,
      'strictLayout': true,
      'designWidth': canvas.width,
      'designHeight': canvas.height,
      'editorialRevision': _freeInteriorEditorialRevision,
      'editorialLayout': layout,
      'layers': layers,
    };
  }

  Rect _rect(double x, double y, double w, double h) => Rect.fromLTWH(
    safe.left + safe.width * x,
    safe.top + safe.height * y,
    safe.width * w,
    safe.height * h,
  );

  void _single() {
    Rect picture, copy;
    final textCount = texts.length;
    final bodyChars = texts.fold<int>(
      0,
      (n, text) => n + _sourceText(text).runes.length,
    );
    if (wide &&
        (textCount >= 3 || layout == 'margin-essay' || bodyChars > 105)) {
      picture = _rect(left ? 0 : .40, .02, .60, .92);
      copy = _rect(left ? .66 : 0, .08, .34, .78);
    } else if (layout == 'opening-statement' ||
        layout == 'headline-and-scene') {
      copy = _rect(0, .015, 1, tall ? .36 : .32);
      picture = _rect(0, tall ? .43 : .38, 1, tall ? .57 : .62);
    } else if (layout == 'closing-portrait') {
      picture = _rect(.035, 0, .93, tall ? .60 : .64);
      copy = _rect(.035, tall ? .67 : .72, .93, tall ? .33 : .28);
    } else {
      picture = _rect(0, 0, 1, textCount <= 2 ? .77 : .65);
      copy = _rect(
        0,
        textCount <= 2 ? .82 : .71,
        1,
        textCount <= 2 ? .18 : .29,
      );
    }
    // A long personal note receives enough reading space instead of shrinking
    // its font below the body floor or painting it over the photograph.
    final demand = _minimumFlowHeight(texts, copy.width);
    if (demand > copy.height) {
      final needed = math.min(safe.height * .64, demand + 8);
      copy = Rect.fromLTWH(safe.left, safe.bottom - needed, safe.width, needed);
      picture = Rect.fromLTWH(
        safe.left,
        safe.top,
        safe.width,
        math.max(35, copy.top - safe.top - 18),
      );
    }
    _photo(photos.single, picture, center: layout != 'opening-statement');
    _flow(texts, copy);
  }

  void _duet() {
    if (wide) {
      final reading = math.min(
        safe.height * .5,
        _minimumFlowHeight(texts, safe.width) + 12,
      );
      final photoHeight = safe.height - reading - 18;
      final firstWidth = safe.width * (layout == 'asymmetric-duet' ? .61 : .48);
      final secondWidth = safe.width - firstWidth - 16;
      _photo(
        photos[0],
        Rect.fromLTWH(safe.left, safe.top, firstWidth, photoHeight),
      );
      _photo(
        photos[1],
        Rect.fromLTWH(
          safe.left + firstWidth + 16,
          safe.top + (layout == 'asymmetric-duet' ? photoHeight * .18 : 0),
          secondWidth,
          photoHeight * (layout == 'asymmetric-duet' ? .82 : 1),
        ),
      );
      _flow(
        texts,
        Rect.fromLTWH(safe.left, safe.bottom - reading, safe.width, reading),
      );
      return;
    }
    final needs = math.min(
      safe.height * .55,
      _minimumFlowHeight(texts, safe.width) + 12,
    );
    final available = safe.height - needs - 18;
    final upper = available * .57;
    _photo(
      photos[0],
      Rect.fromLTWH(safe.left, safe.top, safe.width * .95, upper),
      center: false,
    );
    _photo(
      photos[1],
      Rect.fromLTWH(
        safe.left + safe.width * .27,
        safe.top + upper + 12,
        safe.width * .73,
        available - upper - 12,
      ),
      center: false,
    );
    _flow(
      texts,
      Rect.fromLTWH(safe.left, safe.bottom - needs, safe.width, needs),
    );
  }

  void _gallery() {
    final indexes = texts
        .where(
          (item) =>
              !'${item['id']}'.contains('chapter') &&
              RegExp(r'^\s*\d{1,3}\s*$').hasMatch(_sourceText(item)),
        )
        .toList();
    final indexed = indexes.length == photos.length;
    final copy = indexed
        ? texts.where((item) => !indexes.contains(item)).toList()
        : texts;
    final needs = math.min(
      safe.height * .65,
      _minimumFlowHeight(copy, safe.width) + 12,
    );
    final gallery = Rect.fromLTWH(
      safe.left,
      safe.top,
      safe.width,
      safe.height - needs - 18,
    );
    const gap = 12.0;
    void cell(int index, Rect box, {bool center = true}) {
      final label = indexed ? _type(indexes[index]) : null;
      final labelHeight = label?.height(9, box.width) ?? 0;
      _photo(
        photos[index],
        Rect.fromLTWH(
          box.left,
          box.top,
          box.width,
          box.height - (indexed ? labelHeight + 5 : 0),
        ),
        center: center,
      );
      if (label != null) {
        placedTexts.add(
          _textLayer(
            label,
            Rect.fromLTWH(
              box.left,
              box.bottom - labelHeight,
              box.width,
              labelHeight,
            ),
            9,
          ),
        );
      }
    }

    if (photos.length == 3 && !wide) {
      final first = gallery.height * .57;
      cell(
        0,
        Rect.fromLTWH(gallery.left, gallery.top, gallery.width, first),
        center: false,
      );
      final width = (gallery.width - gap) / 2;
      for (var i = 1; i < 3; i++) {
        cell(
          i,
          Rect.fromLTWH(
            gallery.left + (i - 1) * (width + gap),
            gallery.top + first + gap,
            width,
            gallery.height - first - gap,
          ),
        );
      }
    } else {
      final columns = wide && photos.length <= 3 ? photos.length : 2;
      final rows = (photos.length / columns).ceil();
      final width = (gallery.width - gap * (columns - 1)) / columns;
      final height = (gallery.height - gap * (rows - 1)) / rows;
      for (var i = 0; i < photos.length; i++) {
        cell(
          i,
          Rect.fromLTWH(
            gallery.left + i % columns * (width + gap),
            gallery.top + i ~/ columns * (height + gap),
            width,
            height,
          ),
        );
      }
    }
    _flow(
      copy,
      Rect.fromLTWH(safe.left, safe.bottom - needs, safe.width, needs),
    );
  }

  void _journal() {
    if (wide) {
      final picture = _rect(left ? 0 : .55, 0, .45, .92);
      final copy = _rect(left ? .51 : 0, 0, .49, 1);
      final each = (picture.height - 12 * (photos.length - 1)) / photos.length;
      for (var i = 0; i < photos.length; i++) {
        _photo(
          photos[i],
          Rect.fromLTWH(
            picture.left,
            picture.top + i * (each + 12),
            picture.width,
            each,
          ),
        );
      }
      if (_minimumFlowHeight(texts, copy.width) <= copy.height) {
        _flow(texts, copy);
        return;
      }
      placedPhotos.clear();
    }
    final desired = _minimumFlowHeight(texts, safe.width) + 10;
    final reading = math.min(
      safe.height * .73,
      math.max(safe.height * .44, desired),
    );
    final pictureHeight = safe.height - reading - 18;
    final width = (safe.width - 12 * (photos.length - 1)) / photos.length;
    for (var i = 0; i < photos.length; i++) {
      _photo(
        photos[i],
        Rect.fromLTWH(
          safe.left + i * (width + 12),
          safe.top,
          width,
          pictureHeight,
        ),
      );
    }
    _flow(
      texts,
      Rect.fromLTWH(safe.left, safe.bottom - reading, safe.width, reading),
    );
  }

  void _textOnly() {
    final broad = Rect.fromLTWH(
      safe.left,
      safe.top + safe.height * .035,
      safe.width,
      safe.height * .92,
    );
    _flow(texts, broad, spacious: true);
  }

  void _photo(
    Map<String, dynamic> sourcePhoto,
    Rect bounds, {
    bool center = true,
  }) {
    final ratio = _freeInteriorPhotoAspect(sourcePhoto);
    final width = math.min(bounds.width, bounds.height * ratio);
    final height = width / ratio;
    final box = Rect.fromLTWH(
      bounds.left +
          (bounds.width - width) *
              (center
                  ? .5
                  : left
                  ? 0
                  : 1),
      bounds.top + (bounds.height - height) * (center ? .5 : 0),
      width,
      height,
    );
    placedPhotos.add({
      ...sourcePhoto,
      ..._geometry(box),
      'frame': 'none',
      'rotation': 0,
      'editable': true,
      'editorialPhotoAspectRatio': ratio,
    });
  }

  Map<String, double> _geometry(Rect box) => {
    'x': box.left / canvas.width,
    'y': box.top / canvas.height,
    'w': box.width / canvas.width,
    'h': box.height / canvas.height,
  };

  _FreeInteriorType _type(Map<String, dynamic> layer) {
    final title = _headline(layer);
    final body = !title && _body(layer);
    final text = _sourceText(layer);
    final caption = !title && !body;
    return _FreeInteriorType(
      layer,
      text,
      title ? direction.display : 'NotoSans',
      title
          ? 30
          : body
          ? 13
          : 10.5,
      caption ? 8.5 : 11,
      title
          ? 1.22
          : body
          ? 1.48
          : 1.38,
      title && direction.display == 'NotoSans'
          ? FontWeight.w600
          : FontWeight.w400,
      caption,
      title,
    );
  }

  double _minimumFlowHeight(List<Map<String, dynamic>> list, double width) {
    if (list.isEmpty) return 0;
    return list.fold<double>(0, (sum, item) {
      final type = _type(item);
      return sum + type.height(type.minimum, width) + 5;
    });
  }

  void _flow(
    List<Map<String, dynamic>> list,
    Rect region, {
    bool spacious = false,
  }) {
    if (list.isEmpty) return;
    final types = list.map(_type).toList();
    var columns = 1;
    var width = region.width;
    var minTotal = types.fold<double>(
      0,
      (sum, item) => sum + item.height(item.minimum, width) + 5,
    );
    if (minTotal > region.height && types.length >= 4) {
      columns = 2;
      width = (region.width - 20) / 2;
    }
    final groups = <List<_FreeInteriorType>>[[]];
    var currentHeight = 0.0;
    for (final type in types) {
      final height = type.height(type.minimum, width) + 5;
      if (columns > 1 &&
          groups.length < columns &&
          currentHeight + height > region.height &&
          groups.last.isNotEmpty) {
        groups.add([]);
        currentHeight = 0;
      }
      groups.last.add(type);
      currentHeight += height;
    }
    for (var column = 0; column < groups.length; column++) {
      final group = groups[column];
      var scale = 1.0;
      double used() => group.fold<double>(
        0,
        (sum, item) =>
            sum +
            item.height(math.max(item.minimum, item.ideal * scale), width) +
            (spacious ? 12 : 8),
      );
      final initial = used();
      if (initial > region.height)
        scale = math.max(.35, region.height / initial * .97);
      while (used() > region.height && scale > .35) scale *= .95;
      final gap = used() > region.height
          ? 2.0
          : spacious
          ? 12.0
          : 8.0;
      final full =
          group.fold<double>(
            0,
            (sum, item) =>
                sum +
                item.height(math.max(item.minimum, item.ideal * scale), width) +
                gap,
          ) -
          gap;
      var y =
          region.top +
          (spacious && full < region.height * .7 ? region.height * .06 : 0);
      for (final type in group) {
        final pixels = math.max(type.minimum, type.ideal * scale);
        final height = type.height(pixels, width);
        final box = Rect.fromLTWH(
          region.left + column * (width + 20),
          y,
          width,
          height,
        );
        placedTexts.add(_textLayer(type, box, pixels));
        y += height + gap;
      }
    }
  }

  Map<String, dynamic> _textLayer(
    _FreeInteriorType type,
    Rect box,
    double pixels,
  ) {
    final originalStyle = type.source['style'] is Map
        ? Map<String, dynamic>.from(type.source['style'] as Map)
        : <String, dynamic>{};
    return {
      ...type.source,
      ..._geometry(box),
      'text': type.wrap(pixels, box.width),
      'editorialSourceText': type.text,
      'align': 'left',
      'rotation': 0,
      'editable': true,
      'textFillMode': 'solid',
      'textFillImageUrl': null,
      'typographyRole': type.caption ? 'caption' : 'body',
      'typographyMinFontSize': type.minimum,
      'editorialTextRole': type.headline
          ? 'headline'
          : type.caption
          ? 'caption'
          : 'body',
      'style': {
        ...originalStyle,
        'fontFamily': type.font,
        'fontSize': pixels,
        'fontWeight': type.weight.value,
        'color': ink,
        'letterSpacing': 0,
        'height': type.leading,
      },
    };
  }

  void _footer() {
    if (footers.isEmpty) return;
    final numeric = footers
        .where((item) => RegExp(r'^\s*\d{1,3}\s*$').hasMatch(_sourceText(item)))
        .toList();
    final labels = footers.where((item) => !numeric.contains(item)).toList();
    final numberWidth = numeric.isEmpty ? 0.0 : canvas.width * .07;
    final width =
        (safe.width -
            numberWidth -
            (numberWidth > 0 ? 12 : 0) -
            10 * math.max(0, labels.length - 1)) /
        math.max(1, labels.length);
    final maxLabelHeight = labels.fold<double>(13.05, (height, item) {
      final type = _FreeInteriorType(
        item,
        _sourceText(item),
        'NotoSans',
        8.5,
        8.5,
        1.3,
        FontWeight.w400,
        true,
        false,
      );
      return math.max(height, type.height(8.5, width));
    });
    final y = canvas.height - 12 - maxLabelHeight;
    for (final item in numeric) {
      final type = _FreeInteriorType(
        item,
        _sourceText(item),
        'NotoSans',
        8.5,
        8.5,
        1.3,
        FontWeight.w500,
        true,
        false,
      );
      final box = Rect.fromLTWH(
        left ? safe.left : safe.right - numberWidth,
        y,
        numberWidth,
        type.height(8.5, numberWidth),
      );
      placedTexts.add(_textLayer(type, box, 8.5));
    }
    for (var i = 0; i < labels.length; i++) {
      final type = _FreeInteriorType(
        labels[i],
        _sourceText(labels[i]),
        'NotoSans',
        8.5,
        8.5,
        1.3,
        FontWeight.w400,
        true,
        false,
      );
      final box = Rect.fromLTWH(
        safe.left +
            (left ? numberWidth + (numberWidth > 0 ? 12 : 0) : 0) +
            i * (width + 10),
        y,
        width,
        type.height(8.5, width),
      );
      placedTexts.add(_textLayer(type, box, 8.5));
    }
  }
}

class _FreeInteriorType {
  _FreeInteriorType(
    this.source,
    this.text,
    this.font,
    this.ideal,
    this.minimum,
    this.leading,
    this.weight,
    this.caption,
    this.headline,
  );
  final Map<String, dynamic> source;
  final String text, font;
  final double ideal, minimum, leading;
  final FontWeight weight;
  final bool caption, headline;
  final _wrapCache = <(double, double), String>{};
  final _heightCache = <(double, double), double>{};
  final _widthCache = <(double, String), double>{};

  TextStyle style(double pixels) => TextStyle(
    fontFamily: font,
    fontSize: pixels,
    fontWeight: weight,
    height: leading,
    letterSpacing: 0,
  );

  String wrap(double pixels, double width) {
    final cached = _wrapCache[(pixels, width)];
    if (cached != null) return cached;
    final selectedStyle = style(pixels);
    double measure(String value) {
      final cached = _widthCache[(pixels, value)];
      if (cached != null) return cached;
      final painter = TextPainter(
        text: TextSpan(text: value, style: selectedStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = painter.width;
      painter.dispose();
      _widthCache[(pixels, value)] = result;
      return result;
    }

    final wrapped = text
        .split('\n')
        .map((paragraph) {
          if (paragraph.trim().isEmpty) return '';
          final lines = <String>[];
          var line = '';
          for (final word in paragraph.trim().split(RegExp(r'\s+'))) {
            final next = line.isEmpty ? word : '$line $word';
            if (line.isNotEmpty && measure(next) > width - 2) {
              lines.add(line);
              line = word;
            } else {
              line = next;
            }
          }
          if (line.isNotEmpty) lines.add(line);
          if (lines.length > 1 && lines.last.runes.length <= 3) {
            final previous = lines[lines.length - 2].split(' ');
            if (previous.length > 1) {
              final moved = previous.removeLast();
              final rebalanced = '$moved ${lines.last}';
              if (measure(rebalanced) <= width - 2) {
                lines[lines.length - 2] = previous.join(' ');
                lines[lines.length - 1] = rebalanced;
              }
            }
          }
          return lines.join('\n');
        })
        .join('\n');
    _wrapCache[(pixels, width)] = wrapped;
    return wrapped;
  }

  double height(double pixels, double width) {
    final cached = _heightCache[(pixels, width)];
    if (cached != null) return cached;
    final selectedStyle = style(pixels);
    final painter = TextPainter(
      text: TextSpan(text: wrap(pixels, width), style: selectedStyle),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(
        selectedStyle,
        forceStrutHeight: true,
      ),
    )..layout(maxWidth: math.max(1, width - 1));
    final result = math.max(pixels * leading, painter.height) + 2;
    painter.dispose();
    _heightCache[(pixels, width)] = result;
    return result;
  }
}

/// Correct a mislabeled sample only in the new catalog presentation.
Map<String, dynamic> _freeInteriorCorrectSample(Map<String, dynamic> photo) {
  const original = 'asset:assets/frame_preview/quiet_room.jpg';
  if (photo['imageUrl'] != original) return photo;
  // This misleading filename contains a studio portrait, not a living room.
  // Keep its slot and history identity; only the current catalog sample changes.
  return {
    ...photo,
    'imageUrl': 'asset:${_editorial}daily_book.png',
    'editorialSourceImageUrl': original,
  };
}

/// Dimensions were read from existing bundled image headers. Most authored
/// interior photographs are exactly 3:2; only exceptions need a stored ratio.
double _freeInteriorPhotoAspect(Map<String, dynamic> photo) {
  final raw =
      photo['originalUrl'] ??
      photo['imageUrl'] ??
      photo['previewUrl'] ??
      photo['asset'];
  final path = '$raw'.replaceFirst(RegExp(r'^asset:'), '');
  if (path.startsWith(_editorial)) {
    return path.split('/').last.startsWith('cover_') ? 1 : 1.5;
  }
  const exceptions = <String, double>{
    'assets/frame_preview/alpine_lake.jpg': 1.49925037,
    'assets/frame_preview/artist_palette.jpg': 1.49925037,
    'assets/frame_preview/celebration.jpg': 1.49925037,
    'assets/frame_preview/city_skyline.jpg': 1.62601626,
    'assets/frame_preview/concert_lights.jpg': 1.49925037,
    'assets/frame_preview/desert_walk.jpg': .66666667,
    'assets/frame_preview/forest_trail.jpg': 1.49925037,
    'assets/frame_preview/misty_hills.jpg': 1.67785235,
    'assets/frame_preview/mountain_light.jpg': 1.50602410,
    'assets/frame_preview/night_city.jpg': .79936051,
    'assets/frame_preview/ocean_shore.jpg': 1.50375940,
    'assets/frame_preview/quiet_room.jpg': 1.49700599,
    'assets/frame_preview/spring_flowers.jpg': 1.49925037,
    'assets/frame_preview/studio_laptop.jpg': 1.50150150,
    'assets/frame_preview/wardrobe.jpg': 1.49925037,
    'assets/templates/jeju_travel/images/approved_stock/cafe_detail.jpg':
        1.32676270,
    'assets/templates/jeju_travel/images/approved_stock/sunset_people.jpg':
        1.48999574,
    'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg':
        1.73972603,
    'assets/templates/soft_babybook/images/approved_stock/parent_hand.jpg':
        1.37669377,
    'assets/templates/atelier_editions_2026/alley-afternoon.png': 1,
    'assets/templates/atelier_editions_2026/saturday-together.png': 1,
    'assets/templates/atelier_editions_2026/daily-paw-walk.png': 1,
    'assets/templates/atelier_editions_2026/daily-paw-path.png': 1.33333333,
    'assets/templates/atelier_editions_2026/our-first-promise.png': 1,
    'assets/templates/atelier_editions_2026/little-day-discoveries.png': 1,
    'assets/templates/wedding_editorial/images/approved_stock/window_shadow.jpg':
        .75,
    'assets/templates/wedding_editorial/images/approved_stock/rings_detail.jpg':
        1.30841121,
    'assets/templates/wedding_editorial/images/approved_stock/table_detail.jpg':
        1.38888889,
  };
  return exceptions[path] ?? 1.5;
}
