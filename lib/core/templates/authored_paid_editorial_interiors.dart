part of 'authored_collections.dart';

const _paidInteriorEditorialRevision = 'paid-photo-editorial-2026-10-21';

/// This pass belongs to the shop boundary, never to an authored archive or a
/// customer's saved album. Photographs, editable copy and the book's identity
/// remain the author's; the new compositions give them room on printed paper.
Map<String, dynamic> _refinePaidEditorialInteriors(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  final direction = _PaidInteriorDirection.forEdition(id);
  final sourcePages = document['pages'];
  if (direction == null || sourcePages is! List) return document;
  return {
    ...document,
    'editorialRevision': _paidInteriorEditorialRevision,
    'editorialSeries': direction.series,
    'pages': [
      for (var index = 0; index < sourcePages.length; index++)
        _PaidInteriorPage(
          id,
          aspect,
          index + 1,
          sourcePages.length,
          direction,
          Map<String, dynamic>.from(sourcePages[index] as Map),
        ).compose(),
    ],
  };
}

class _PaidInteriorDirection {
  const _PaidInteriorDirection(
    this.series,
    this.theme,
    this.paper,
    this.ink,
    this.accent,
    this.display,
    this.phase,
    this.materials,
  );
  final String series, theme, paper, ink, accent, display;
  final int phase;
  final List<String> materials;

  static _PaidInteriorDirection? forEdition(String id) {
    final atelier = AtelierEdition.values.where((e) => e.id == id).firstOrNull;
    if (atelier != null) {
      return _PaidInteriorDirection(
        'atelier',
        switch (atelier) {
          AtelierEdition.nightVows => 'garden-vow',
          AtelierEdition.slowRail => 'rail',
          AtelierEdition.greenHours => 'botanical',
          AtelierEdition.firstOrbit => 'orbit',
          AtelierEdition.tableStories => 'recipe',
          AtelierEdition.privateCinema => 'cinema',
          AtelierEdition.walkMap => 'walk',
        },
        atelier.paper,
        atelier.ink,
        atelier.accent,
        atelier.font,
        atelier.index,
        [atelier.signatureMaterial, ...atelier.materials],
      );
    }
    final concept = ConceptVolume.values.where((e) => e.id == id).firstOrNull;
    if (concept != null) {
      return _PaidInteriorDirection(
        'concept',
        switch (concept) {
          ConceptVolume.silkVows => 'silk',
          ConceptVolume.shoreDays => 'coast',
          ConceptVolume.readingRoom => 'reading',
          ConceptVolume.firstWardrobe => 'wardrobe',
          ConceptVolume.sundayPicnic => 'picnic',
          ConceptVolume.sharedSeasons => 'correspondence',
          ConceptVolume.littleCompanion => 'companion',
        },
        switch (concept) {
          ConceptVolume.silkVows => '#F7F5F0',
          ConceptVolume.shoreDays => '#F4F7F2',
          ConceptVolume.readingRoom => '#F6F5EF',
          ConceptVolume.firstWardrobe => '#F7F4EC',
          ConceptVolume.sundayPicnic => '#FAF5E9',
          ConceptVolume.sharedSeasons => '#F6F1EE',
          ConceptVolume.littleCompanion => '#F2F6F1',
        },
        concept.ink,
        concept.ink,
        concept.font,
        concept.index + 2,
        [concept.signatureMaterial],
      );
    }
    final volume = PremiumVolume.values.where((e) => e.id == id).firstOrNull;
    if (volume != null) {
      return _PaidInteriorDirection(
        'heirloom',
        switch (volume) {
          PremiumVolume.wedding => 'vow',
          PremiumVolume.travel => 'postcard',
          PremiumVolume.daily => 'cabinet',
          PremiumVolume.baby => 'first-year',
          PremiumVolume.family => 'table',
          PremiumVolume.couple => 'tickets',
          PremiumVolume.pet => 'walk-ledger',
        },
        switch (volume) {
          PremiumVolume.wedding => '#F6F4EC',
          PremiumVolume.travel => '#F3F4EE',
          PremiumVolume.daily => '#F0F3EE',
          PremiumVolume.baby => '#F7F3E8',
          PremiumVolume.family => '#F4F0E3',
          PremiumVolume.couple => '#F6EEEA',
          PremiumVolume.pet => '#F0F4EC',
        },
        volume.ink,
        volume.ink,
        volume.font,
        volume.index,
        switch (volume) {
          PremiumVolume.wedding => [
            'heirloomVowSeal',
            'studioRoseSilk',
            'heirloomVowEnvelope',
          ],
          PremiumVolume.travel => [
            'studioPostalMark',
            'atelierBoardingStub',
            'travelCafeReceipt',
          ],
          PremiumVolume.daily => [
            'heirloomLibraryCard',
            'studioOlivePress',
            'travelCafeReceipt',
          ],
          PremiumVolume.baby => [
            'heirloomGrowthRuler',
            'lifeBonnet',
            'lifeRattle',
          ],
          PremiumVolume.family => [
            'materialRecipeFoldout',
            'heirloomTableLinen',
            'lifeBasket',
          ],
          PremiumVolume.couple => [
            'heirloomCinemaStub',
            'materialTicketDuo',
            'materialAirLetter',
          ],
          PremiumVolume.pet => [
            'heirloomPetTag',
            'materialWalkLedger',
            'materialNamePatch',
          ],
        },
      );
    }
    final studio = StudioEdition.values
        .where((e) => e.id == id && e.premium)
        .firstOrNull;
    if (studio == null) return null;
    return switch (studio) {
      StudioEdition.cityAfterglow => const _PaidInteriorDirection(
        'studio',
        'after-hours',
        '#F0ECE3',
        '#193C42',
        '#A8493D',
        'BookMyungjo',
        0,
        ['studioPostalMark', 'atelierBoardingStub', 'studioTravelTicket'],
      ),
      StudioEdition.summerKeepsakeBox => const _PaidInteriorDirection(
        'studio',
        'summer-archive',
        '#F7F1E5',
        '#163E40',
        '#A96040',
        'BookMyungjo',
        2,
        ['lifeBasket', 'lifePicnicSlip', 'materialCrossStitchBand'],
      ),
      StudioEdition.companionJournal => const _PaidInteriorDirection(
        'studio',
        'companion-issue',
        '#F4F1EC',
        '#29282D',
        '#88553D',
        'RiaSans',
        4,
        ['lifeRopeBall', 'heirloomPetTag', 'materialNamePatch'],
      ),
      StudioEdition.velvetVowArchive => const _PaidInteriorDirection(
        'studio',
        'velvet-vow',
        '#F8F2EE',
        '#4C2939',
        '#896E57',
        'BookMyungjo',
        1,
        ['studioRoseSilk', 'heirloomVowSeal', 'materialAirLetter'],
      ),
      StudioEdition.littleExplorerBook => const _PaidInteriorDirection(
        'studio',
        'explorer',
        '#F7F3E7',
        '#173B50',
        '#A75D35',
        'NotoSans',
        3,
        ['materialSpecimenPocket', 'studioBotanicalStamp', 'lifeRattle'],
      ),
      _ => null,
    };
  }
}

class _PaidInteriorPage {
  _PaidInteriorPage(
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
      final kind = '${layer['type']}'.toLowerCase();
      if (kind == 'image') photos.add(layer);
      if (kind == 'text') (_isFooter(layer) ? footers : texts).add(layer);
      if (kind == 'decoration' || kind == 'sticker') decorations.add(layer);
    }
    texts.sort(_readingOrder);
    footers.sort(_readingOrder);
  }

  final String collection;
  final CollectionAspect aspect;
  final int number, pageCount;
  final _PaidInteriorDirection direction;
  final Map<String, dynamic> source;
  final photos = <Map<String, dynamic>>[];
  final texts = <Map<String, dynamic>>[];
  final footers = <Map<String, dynamic>>[];
  final decorations = <Map<String, dynamic>>[];
  final positionedPhotos = <String, Map<String, dynamic>>{};
  final positionedTexts = <Map<String, dynamic>>[];
  final furniture = <Map<String, dynamic>>[];
  final types = <String, _PaidInteriorType>{};
  Size get canvas => aspect.canvas;
  bool get wide => aspect == CollectionAspect.landscape;
  bool get left => number.isOdd;
  int get spread => (number - 1) ~/ 2;
  Rect get safe => Rect.fromLTRB(
    left ? 32.5 : 42.5,
    31,
    left ? canvas.width - 42.5 : canvas.width - 32.5,
    canvas.height - 48,
  );
  late final Rect core = _reserveSignature();
  late final String layout = _chooseLayout();
  late final String paper = _paperColor();
  String get ink => _paidInteriorContrast(direction.ink, paper) >= 4.5
      ? direction.ink
      : _paidInteriorContrast('#FFFDF7', paper) >= 4.5
      ? '#FFFDF7'
      : '#000000';

  static double _n(Object? value, [double fallback = 0]) =>
      value is num && value.isFinite ? value.toDouble() : fallback;
  static int _readingOrder(Map<String, dynamic> a, Map<String, dynamic> b) {
    final y = _n(a['y']).compareTo(_n(b['y']));
    return y != 0 ? y : _n(a['x']).compareTo(_n(b['x']));
  }

  static bool _isFooter(Map<String, dynamic> layer) {
    final id = '${layer['id']}'.toLowerCase();
    return id.endsWith('_folio') ||
        id.endsWith('_folio_label') ||
        id.endsWith('_folio_number') ||
        id.endsWith('_folio_date') ||
        id.contains('_running_title') ||
        id.contains('_running_head');
  }

  String _sourceText(Map<String, dynamic> layer) =>
      '${layer['editorialSourceText'] ?? layer['text'] ?? (layer['payload'] is Map ? (layer['payload'] as Map)['text'] : null) ?? ''}';
  Map<String, dynamic>? get background => decorations
      .where(
        (layer) =>
            '${layer['type']}' == 'decoration' &&
            _n(layer['x']).abs() < .001 &&
            _n(layer['y']).abs() < .001 &&
            _n(layer['w'] ?? layer['width']) >= .98 &&
            _n(layer['h'] ?? layer['height']) >= .98,
      )
      .firstOrNull;

  String _paperColor() {
    // Studio books already have a deliberate sequence of lit and dark rooms.
    // Keep that sequence; rebuilding every turn on cream would erase its pace.
    final original = '${background?['fillColor'] ?? ''}';
    if (direction.series == 'studio' &&
        RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(original))
      return original;
    if (direction.theme == 'cinema' && '${source['role']}'.contains('darkroom'))
      return direction.ink;
    if (direction.theme == 'garden-vow' &&
        '${source['role']}'.contains('darkroom'))
      return direction.ink;
    return direction.paper;
  }

  bool _body(Map<String, dynamic> layer) {
    final role = '${layer['typographyRole']}';
    final id = '${layer['id']}'.toLowerCase();
    final value = _sourceText(layer).trim();
    final sourceStyle = layer['style'] is Map
        ? layer['style'] as Map
        : const {};
    final recordValue =
        record &&
        RegExp(r'[가-힣]').hasMatch(value) &&
        _n(sourceStyle['fontSize']) >= 11 &&
        !RegExp(r'label|tag|date|period|byline|index|number').hasMatch(id);
    final koreanSentence =
        value.runes.length >= 18 &&
        RegExp(r'[가-힣]').hasMatch(value) &&
        !RegExp(r'label|tag|date|period|byline|index|number').hasMatch(id) &&
        (RegExp(r'[.!?。…]$|[다요죠게]\s*$').hasMatch(value) ||
            value.contains('\n') && value.runes.length >= 20);
    return role == 'body' ||
        role.contains('caption') && _sourceText(layer).runes.length > 45 ||
        _sourceText(layer).runes.length >= 65 ||
        koreanSentence ||
        recordValue ||
        RegExp(
          r'letter|journal|essay|note|message|memory_value|stop_note',
        ).hasMatch(id);
  }

  bool _headline(Map<String, dynamic> layer) {
    final value = _sourceText(layer).trim();
    if (value.isEmpty ||
        value.runes.length > 100 ||
        RegExp(r'^[0-9\s./:·—–-]+$').hasMatch(value))
      return false;
    final style = layer['style'] is Map ? layer['style'] as Map : const {};
    final id = '${layer['id']}'.toLowerCase();
    return '${layer['typographyRole']}'.contains('title') ||
        RegExp(r'_heading$|_headline|_title$').hasMatch(id) ||
        !_body(layer) && _n(style['fontSize']) >= 20 ||
        '${layer['id']}' == promotedHeadline;
  }

  late final String? promotedHeadline = _promoteHeadline();

  String? _promoteHeadline() {
    // Older heirloom studies expressed a page's only main sentence as a small
    // caption. Recognise its actual hierarchy without treating a person's name,
    // a date, a field label or a personal letter as a new display heading.
    bool declared(Map<String, dynamic> layer) {
      final id = '${layer['id']}'.toLowerCase();
      final style = layer['style'] is Map ? layer['style'] as Map : const {};
      return '${layer['typographyRole']}'.contains('title') ||
          RegExp(r'_heading$|_headline|_title$').hasMatch(id) ||
          !_body(layer) && _n(style['fontSize']) >= 20;
    }

    if (texts.any(declared)) return null;
    final eligible = texts.where((layer) {
      final value = _sourceText(layer).trim();
      final id = '${layer['id']}'.toLowerCase();
      final style = layer['style'] is Map ? layer['style'] as Map : const {};
      return value.runes.length >= 6 &&
          value.runes.length <= 60 &&
          !RegExp(r'^[0-9\s./:·—–-]+$').hasMatch(value) &&
          !RegExp(
            r'byline|names?|date|period|label|tag|index|number|letter|message|note|_record$',
          ).hasMatch(id) &&
          _n(style['fontSize']) >= (direction.series == 'heirloom' ? 12 : 16);
    }).toList();
    eligible.sort((a, b) {
      final sa = a['style'] is Map ? a['style'] as Map : const {};
      final sb = b['style'] is Map ? b['style'] as Map : const {};
      return _n(sb['fontSize']).compareTo(_n(sa['fontSize']));
    });
    return eligible.isEmpty ? null : '${eligible.first['id']}';
  }

  bool get record {
    final role = '${source['role']} ${source['name']}'.toLowerCase();
    return texts.length >= 7 ||
        RegExp(
          r'ledger|inventory|register|directory|receipt|record|calendar|fieldnotes|레시피|관찰|목록|조리법',
        ).hasMatch(role);
  }

  String _chooseLayout() {
    final theme = direction.theme;
    if (photos.isEmpty)
      return '$theme-${record
          ? 'record-sheet'
          : _sourceChars > 180
          ? 'letter'
          : 'statement'}';
    if (record) return '$theme-photo-register';
    if (photos.length >= 3)
      return '$theme-${theme == 'cinema' || theme == 'tickets'
          ? 'film-sequence'
          : theme == 'botanical' || theme == 'explorer'
          ? 'specimen-sequence'
          : 'contact-story'}';
    if (photos.length == 2)
      return '$theme-${(spread + direction.phase).isEven ? 'master-and-detail' : 'two-scene-dialogue'}';
    if (number <= 2) return '$theme-opening';
    if (number >= pageCount - 1) return '$theme-closing';
    return '$theme-${switch ((spread + direction.phase) % 4) {
      0 => 'title-and-scene',
      1 => 'photographic-folio',
      2 => 'margin-story',
      _ => 'scene-and-note',
    }}';
  }

  int get _sourceChars => texts.fold<int>(
    0,
    (total, layer) => total + _sourceText(layer).runes.length,
  );

  Map<String, dynamic>? _signature() {
    final candidates = <(Map<String, dynamic>, StudioDecorationSpec, int)>[];
    for (final layer in decorations) {
      final key = '${layer['style'] ?? ''}';
      final asset = '${layer['imageUrl'] ?? ''}'.replaceFirst(
        RegExp(r'^asset:'),
        '',
      );
      final spec =
          studioDecorationById(key) ??
          studioDecorations
              .where(
                (item) => item.assetPath != null && item.assetPath == asset,
              )
              .firstOrNull;
      if (spec == null || photoCoverShadeStyles.contains(spec.id)) continue;
      final rank = direction.materials.indexOf(spec.id);
      final score = rank >= 0
          ? 100 - rank
          : spec.category == StudioDecorationCategory.sticker
          ? 40
          : spec.category == StudioDecorationCategory.tape
          ? 10
          : 15;
      candidates.add((layer, spec, score));
    }
    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    if (candidates.isEmpty) return null;
    final selected = candidates.first;
    return {
      ...selected.$1,
      'editorialMaterial': selected.$2.id,
      'editorialMaterialAspect': selected.$2.aspectRatio,
    };
  }

  Rect _reserveSignature() {
    // A picture page gets a small independent signature, while record sheets
    // retain a generous specimen of their original ticket, letter or textile.
    final material = _signature();
    if (material == null ||
        photos.isEmpty ||
        texts.length > 6 ||
        _sourceChars > 260)
      return safe;
    final band = Rect.fromLTWH(safe.left, safe.top - 8, safe.width, 29);
    _material(
      material,
      Rect.fromLTWH(
        left ? band.right - 76 : band.left,
        band.top,
        76,
        band.height,
      ),
    );
    _rule(
      Rect.fromLTWH(
        left ? band.left : band.left + 96,
        band.center.dy,
        math.min(52, band.width * .15),
        .8,
      ),
    );
    return Rect.fromLTRB(safe.left, safe.top + 34, safe.right, safe.bottom);
  }

  Map<String, dynamic> compose() {
    // Initialize the reserved band before placing any photographs or text.
    core;
    if (photos.isEmpty) {
      _recordOrLetter();
    } else if (photos.length >= 3) {
      _gallery();
    } else if (record || _sourceChars > 260) {
      _photoRecord();
    } else if (photos.length == 2) {
      _duet();
    } else {
      _single();
    }
    _footer();
    final paperLayer = <String, dynamic>{
      if (background != null) ...background!,
      'id':
          background?['id'] ??
          '${collection}_${aspect.name}_${number}_editorial_paper',
      'type': 'decoration',
      'x': 0,
      'y': 0,
      'w': 1,
      'h': 1,
      'fillColor': paper,
      'cornerRadius': 0,
      'rotation': 0,
      'opacity': 1,
    };
    for (final key in ['style', 'imageUrl', 'payload']) {
      paperLayer.remove(key);
    }
    final layers = <Map<String, dynamic>>[
      paperLayer,
      ...furniture,
      // Source order is significant to batch photo filling and is never sorted
      // to match visual hierarchy. A larger hero can still be the second slot.
      for (final photo in photos) positionedPhotos['${photo['id']}']!,
      ...positionedTexts,
    ];
    for (var index = 0; index < layers.length; index++)
      layers[index]['z'] = index;
    return {
      ...source,
      'strictLayout': true,
      'designWidth': canvas.width,
      'designHeight': canvas.height,
      'editorialRevision': _paidInteriorEditorialRevision,
      'editorialLayout': layout,
      'editorialSeries': direction.series,
      'layers': layers,
    };
  }

  Rect _r(double x, double y, double w, double h) => Rect.fromLTWH(
    core.left + core.width * x,
    core.top + core.height * y,
    core.width * w,
    core.height * h,
  );

  void _single() {
    final ratio = _paidInteriorPhotoAspect(photos.single);
    if ((wide || ratio < 1) && texts.isNotEmpty) {
      final photoShare = ratio < 1 ? .61 : .70;
      final gap = 22.0;
      final copyWidth = core.width * (1 - photoShare) - gap;
      final copy = Rect.fromLTWH(
        left ? core.left + core.width * photoShare + gap : core.left,
        core.top + 6,
        copyWidth,
        core.height - 12,
      );
      if (_minimum(texts, copy.width) <= copy.height) {
        final picture = Rect.fromLTWH(
          left ? core.left : core.right - core.width * photoShare,
          core.top,
          core.width * photoShare,
          core.height,
        );
        _photo(photos.single, picture);
        _flow(texts, copy, spacious: true);
        return;
      }
    }
    final reading = math.max(0.0, _preferred(texts, core.width));
    final minimum = _minimum(texts, core.width);
    final needed = math.min(core.height * .56, math.max(minimum, reading));
    final gap = texts.isEmpty ? 0.0 : 19.0;
    final opening =
        layout.endsWith('-opening') || layout.endsWith('-title-and-scene');
    final copy = Rect.fromLTWH(
      core.left,
      opening ? core.top : core.bottom - needed,
      core.width,
      needed,
    );
    final picture = Rect.fromLTWH(
      core.left,
      opening ? copy.bottom + gap : core.top,
      core.width,
      math.max(30, core.height - needed - gap),
    );
    _photo(photos.single, picture, vertical: opening ? 0 : 1);
    _flow(texts, copy);
  }

  void _duet() {
    final minimum = _minimum(texts, core.width);
    final reading = math.min(
      core.height * .48,
      math.max(minimum, _preferred(texts, core.width)),
    );
    final gallery = Rect.fromLTWH(
      core.left,
      core.top,
      core.width,
      core.height - reading - (texts.isEmpty ? 0 : 20),
    );
    final master = layout.endsWith('master-and-detail');
    if (wide || gallery.height < gallery.width * .72) {
      final firstWidth = (gallery.width - 16) * (master ? .61 : .5);
      _photo(
        photos[0],
        Rect.fromLTWH(gallery.left, gallery.top, firstWidth, gallery.height),
        vertical: master ? 0 : .5,
      );
      _photo(
        photos[1],
        Rect.fromLTWH(
          gallery.left + firstWidth + 16,
          gallery.top,
          gallery.width - firstWidth - 16,
          gallery.height,
        ),
        vertical: master ? 1 : .5,
      );
    } else {
      final firstHeight = (gallery.height - 16) * (master ? .62 : .5);
      _photo(
        photos[0],
        Rect.fromLTWH(
          gallery.left,
          gallery.top,
          gallery.width * (master ? 1 : .88),
          firstHeight,
        ),
        horizontal: left ? 0 : 1,
      );
      _photo(
        photos[1],
        Rect.fromLTWH(
          gallery.left + gallery.width * (master ? .2 : .12),
          gallery.top + firstHeight + 16,
          gallery.width * (master ? .8 : .88),
          gallery.height - firstHeight - 16,
        ),
        horizontal: left ? 1 : 0,
      );
    }
    _flow(
      texts,
      Rect.fromLTWH(core.left, core.bottom - reading, core.width, reading),
    );
  }

  void _gallery() {
    final indexes = texts
        .where(
          (item) =>
              RegExp(r'^\s*\d{1,3}\s*$').hasMatch(_sourceText(item)) &&
              !_headline(item),
        )
        .toList();
    final indexed = indexes.length == photos.length;
    final copy = indexed
        ? texts.where((item) => !indexes.contains(item)).toList()
        : texts;
    final reading = math.min(
      core.height * .55,
      math.max(_minimum(copy, core.width), _preferred(copy, core.width)),
    );
    final area = Rect.fromLTWH(
      core.left,
      core.top,
      core.width,
      core.height - reading - (copy.isEmpty ? 0 : 19),
    );
    const gap = 14.0;
    void cell(int index, Rect rect) {
      final type = indexed ? _type(indexes[index]) : null;
      final labelHeight = type?.height(9, rect.width) ?? 0;
      _photo(
        photos[index],
        Rect.fromLTWH(
          rect.left,
          rect.top,
          rect.width,
          math.max(10, rect.height - (indexed ? labelHeight + 5 : 0)),
        ),
      );
      if (type != null)
        positionedTexts.add(
          _textLayer(
            type,
            Rect.fromLTWH(
              rect.left,
              rect.bottom - labelHeight,
              rect.width,
              labelHeight,
            ),
            9,
          ),
        );
    }

    if (photos.length == 3 && !wide && area.height > 170) {
      // A large establishing scene and two details, rather than three equally
      // small souvenirs. Source order and every independent image stay intact.
      final heroHeight = (area.height - gap) * .59;
      cell(0, Rect.fromLTWH(area.left, area.top, area.width, heroHeight));
      final width = (area.width - gap) / 2;
      for (var i = 1; i < 3; i++)
        cell(
          i,
          Rect.fromLTWH(
            area.left + (i - 1) * (width + gap),
            area.top + heroHeight + gap,
            width,
            area.height - heroHeight - gap,
          ),
        );
    } else {
      final columns = wide && photos.length <= 3
          ? photos.length
          : photos.length >= 5
          ? 3
          : 2;
      final rows = (photos.length / columns).ceil();
      final width = (area.width - gap * (columns - 1)) / columns;
      final height = (area.height - gap * (rows - 1)) / rows;
      for (var i = 0; i < photos.length; i++)
        cell(
          i,
          Rect.fromLTWH(
            area.left + i % columns * (width + gap),
            area.top + i ~/ columns * (height + gap),
            width,
            height,
          ),
        );
    }
    _flow(
      copy,
      Rect.fromLTWH(core.left, core.bottom - reading, core.width, reading),
    );
  }

  void _photoRecord() {
    if (wide && photos.length == 1) {
      final copy = _r(left ? .47 : 0, 0, .53, 1);
      if (_recordRows(texts.map(_type).toList(), copy, spacious: true)) {
        _photo(photos.single, _r(left ? 0 : .59, 0, .41, 1));
        return;
      }
      if (_minimum(texts, copy.width) <= copy.height) {
        _photo(photos.single, _r(left ? 0 : .59, 0, .41, 1));
        _flow(texts, copy, spacious: true, recordColumns: true);
        return;
      }
    }
    final demand = _minimum(texts, core.width);
    final reading = math.min(
      core.height * .76,
      math.max(
        demand + 6,
        math.min(core.height * .58, _preferred(texts, core.width)),
      ),
    );
    final gallery = Rect.fromLTWH(
      core.left,
      core.top,
      core.width,
      math.max(25, core.height - reading - 20),
    );
    final width = (gallery.width - 14 * (photos.length - 1)) / photos.length;
    for (var i = 0; i < photos.length; i++)
      _photo(
        photos[i],
        Rect.fromLTWH(
          gallery.left + i * (width + 14),
          gallery.top,
          width,
          gallery.height,
        ),
      );
    _flow(
      texts,
      Rect.fromLTWH(core.left, core.bottom - reading, core.width, reading),
      spacious: false,
      recordColumns: true,
    );
  }

  void _recordOrLetter() {
    final signature = _signature();
    final min = _minimum(texts, core.width);
    if (signature != null && min < core.height * .64) {
      // The original object remains a readable specimen on a record sheet,
      // separate from the editable rows. No opaque label hides its artwork.
      final available = math.min(
        core.height * .34,
        math.max(55.0, core.height - min - 35),
      );
      final object = Rect.fromLTWH(
        core.left,
        core.bottom - available,
        core.width,
        available,
      );
      _material(signature, object, large: true);
      _flow(
        texts,
        Rect.fromLTRB(core.left, core.top, core.right, object.top - 23),
        spacious: true,
        recordColumns: record,
      );
      return;
    }
    _flow(texts, core, spacious: true, recordColumns: record);
    // Dense registers retain their native material as an independent margin
    // mark, without stealing space from names, quantities or long notes.
    if (signature != null)
      _material(
        signature,
        Rect.fromLTWH(left ? core.right - 45 : core.left, 13, 45, 14),
      );
  }

  void _photo(
    Map<String, dynamic> photo,
    Rect bounds, {
    double horizontal = .5,
    double vertical = .5,
  }) {
    final ratio = _paidInteriorPhotoAspect(photo);
    final width = math.min(bounds.width, bounds.height * ratio);
    final height = width / ratio;
    final rect = Rect.fromLTWH(
      bounds.left + (bounds.width - width) * horizontal,
      bounds.top + (bounds.height - height) * vertical,
      width,
      height,
    );
    positionedPhotos['${photo['id']}'] = {
      ...photo,
      ..._geometry(rect),
      'frame': 'none',
      'rotation': 0,
      'editable': true,
      'editorialPhotoAspectRatio': ratio,
    };
  }

  void _material(
    Map<String, dynamic> material,
    Rect bounds, {
    bool large = false,
  }) {
    final ratio = _n(material['editorialMaterialAspect'], 1);
    final width = math.min(
      bounds.width * (large ? .90 : 1),
      bounds.height * ratio,
    );
    final height = width / ratio;
    furniture.add({
      ...material,
      ..._geometry(
        Rect.fromLTWH(
          bounds.left + (bounds.width - width) * (left ? 0 : 1),
          bounds.top + (bounds.height - height) / 2,
          width,
          height,
        ),
      ),
      'rotation': 0,
      'opacity': 1,
      'editable': true,
    });
  }

  void _rule(Rect rect) => furniture.add({
    'id':
        '${collection}_${aspect.name}_${number}_editorial_rule_${furniture.length}',
    'type': 'decoration',
    ..._geometry(rect),
    'fillColor': direction.accent,
    'cornerRadius': 0,
    'opacity': 1,
  });
  Map<String, double> _geometry(Rect rect) => {
    'x': rect.left / canvas.width,
    'y': rect.top / canvas.height,
    'w': rect.width / canvas.width,
    'h': rect.height / canvas.height,
  };

  _PaidInteriorType _type(Map<String, dynamic> layer) =>
      types.putIfAbsent('${layer['id']}', () {
        final title = _headline(layer);
        final body = !title && _body(layer);
        final originalStyle = layer['style'] is Map
            ? layer['style'] as Map
            : const {};
        final sourceFont = '${originalStyle['fontFamily'] ?? ''}';
        final handwriting = sourceFont == 'NanumPen';
        final latin = !RegExp(r'[가-힣]').hasMatch(_sourceText(layer));
        final preservedFont = const {
          'Eulyoo',
          'BookMyungjo',
          'NotoSans',
          'NanumPen',
          'Cormorant Garamond',
          'Poppins',
          'Raleway',
          'RiaSans',
          'Yeongwol',
          'Arita',
          'SeoulNamsan',
        }.contains(sourceFont);
        final font = preservedFont && (title || handwriting || latin)
            ? sourceFont
            : title
            ? direction.display
            : body && direction.series == 'heirloom'
            ? direction.display
            : 'NotoSans';
        final originalSize = _n(originalStyle['fontSize'], 13);
        final ideal = title
            ? originalSize
                  .clamp(direction.series == 'heirloom' ? 28 : 24, 38)
                  .toDouble()
            : handwriting
            ? 20.0
            : body
            ? 13.5
            : 10.5;
        final weight =
            title &&
                const {
                  'NotoSans',
                  'RiaSans',
                  'Arita',
                  'SeoulNamsan',
                }.contains(font)
            ? FontWeight.w600
            : FontWeight.w400;
        return _PaidInteriorType(
          layer,
          _sourceText(layer),
          font,
          ideal,
          title || body ? 11 : 8.5,
          title
              ? 1.18
              : handwriting
              ? 1.35
              : body
              ? 1.5
              : 1.38,
          weight,
          !title && !body,
          title,
          displayText: _horizontalDisplay(layer),
        );
      });

  String? _horizontalDisplay(Map<String, dynamic> layer) {
    final id = '${layer['id']}';
    if (id == 'shared-seasons_${aspect.name}_11_part_2') return '비 오는 주말';
    if (id == 'little-companion_${aspect.name}_11_part_4') return '간식 시간';
    return null;
  }

  double _minimum(List<Map<String, dynamic>> list, double width) => list.isEmpty
      ? 0
      : list.fold<double>(0, (sum, item) {
              final type = _type(item);
              return sum + type.height(type.minimum, width) + 5;
            }) -
            5;
  double _preferred(List<Map<String, dynamic>> list, double width) =>
      list.isEmpty
      ? 0
      : list.fold<double>(0, (sum, item) {
              final type = _type(item);
              return sum + type.height(type.ideal, width) + 9;
            }) -
            9;

  void _flow(
    List<Map<String, dynamic>> list,
    Rect region, {
    bool spacious = false,
    bool recordColumns = false,
  }) {
    if (list.isEmpty) return;
    var group = list.map(_type).toList();
    final gap = spacious ? 12.0 : 8.0;
    if (recordColumns && _recordRows(group, region, spacious: spacious)) return;
    var columns = 1;
    var width = region.width;
    if (_minimum(list, width) > region.height && group.length >= 4) {
      columns = 2;
      width = (region.width - 22) / 2;
    }
    final groups = <List<_PaidInteriorType>>[[]];
    var height = 0.0;
    for (final type in group) {
      final next = type.height(type.minimum, width) + 5;
      if (columns > 1 &&
          groups.length < columns &&
          height + next > region.height &&
          groups.last.isNotEmpty) {
        groups.add([]);
        height = 0;
      }
      groups.last.add(type);
      height += next;
    }
    for (final column in groups.indexed) {
      group = column.$2;
      var scale = 1.0;
      double used(double selectedGap) =>
          group.fold<double>(
            0,
            (sum, type) =>
                sum +
                type.height(math.max(type.minimum, type.ideal * scale), width) +
                selectedGap,
          ) -
          selectedGap;
      while (used(gap) > region.height && scale > .29) scale *= .95;
      final selectedGap = used(gap) > region.height ? 3.0 : gap;
      final total = used(selectedGap);
      var y =
          region.top +
          (spacious && total < region.height * .72
              ? math.min(18, region.height * .05)
              : 0);
      for (final type in group) {
        final pixels = math.max(type.minimum, type.ideal * scale);
        final h = type.height(pixels, width);
        positionedTexts.add(
          _textLayer(
            type,
            Rect.fromLTWH(region.left + column.$1 * (width + 22), y, width, h),
            pixels,
          ),
        );
        y += h + selectedGap;
      }
    }
  }

  bool _recordRows(
    List<_PaidInteriorType> group,
    Rect region, {
    required bool spacious,
  }) {
    if (group.length < 6 || region.width < 200) return false;
    final headers = group
        .where(
          (type) =>
              _n(type.source['y']) < .34 &&
              (_n(type.source['w']) > .64 || type.headline),
        )
        .toList();
    final tails = group
        .where(
          (type) => _n(type.source['y']) >= .76 && _n(type.source['w']) > .64,
        )
        .toList();
    final body = group
        .where((type) => !headers.contains(type) && !tails.contains(type))
        .toList();
    final xs = body.map((type) => _n(type.source['x'])).toSet().toList()
      ..sort();
    var split = 0.0;
    var largestGap = .119;
    for (var index = 1; index < xs.length; index++) {
      final gap = xs[index] - xs[index - 1];
      if (gap > largestGap) {
        largestGap = gap;
        split = (xs[index] + xs[index - 1]) / 2;
      }
    }
    final fieldPairs =
        largestGap < .12 &&
        body.length >= 4 &&
        body.length.isEven &&
        List<bool>.generate(body.length ~/ 2, (index) {
          final label = body[index * 2], value = body[index * 2 + 1];
          final labelStyle = label.source['style'] is Map
              ? label.source['style'] as Map
              : const {};
          final valueStyle = value.source['style'] is Map
              ? value.source['style'] as Map
              : const {};
          return _n(labelStyle['fontSize']) <= 10.5 &&
              _n(valueStyle['fontSize']) >= 11 &&
              (_n(label.source['x']) - _n(value.source['x'])).abs() < .025 &&
              _n(value.source['y']) - _n(label.source['y']) <= .075;
        }).every((pair) => pair);
    if (largestGap < .12 && !fieldPairs) return false;
    final first = fieldPairs
        ? [for (var index = 0; index < body.length; index += 2) body[index]]
        : body.where((type) => _n(type.source['x']) < split).toList();
    final second = fieldPairs
        ? [for (var index = 1; index < body.length; index += 2) body[index]]
        : body.where((type) => _n(type.source['x']) >= split).toList();
    if (first.length < 2 || second.length < 2) return false;
    final firstExtent = first.fold<double>(
      0,
      (value, type) => math.max(value, _n(type.source['w'])),
    );
    final secondExtent = second.fold<double>(
      0,
      (value, type) => math.max(value, _n(type.source['w'])),
    );
    final share = fieldPairs
        ? .32
        : (firstExtent / (firstExtent + secondExtent)).clamp(.22, .50);
    const gutter = 24.0;
    final widths = [
      (region.width - gutter) * share,
      (region.width - gutter) * (1 - share),
    ];
    final rows = <List<_PaidInteriorType>>[];
    int column(_PaidInteriorType type) => first.contains(type) ? 0 : 1;
    var anchor = -1.0;
    for (final type in body) {
      final y = _n(type.source['y']);
      // Authors offset a label and its value slightly to align their baselines;
      // a nearby source y therefore means one record row, not the next field.
      final previousRight = rows.isEmpty
          ? <_PaidInteriorType>[]
          : rows.last.where((item) => column(item) == 1).toList();
      double sourceSize(_PaidInteriorType item) => _n(
        item.source['style'] is Map
            ? (item.source['style'] as Map)['fontSize']
            : null,
      );
      final nestedValue =
          !fieldPairs &&
          rows.isNotEmpty &&
          column(type) == 1 &&
          y - anchor <= .075 &&
          rows.last.any((item) => column(item) == 0) &&
          previousRight.length == 1 &&
          sourceSize(type) < sourceSize(previousRight.single) * .92;
      if (rows.isEmpty ||
          fieldPairs && column(type) == 0 ||
          !fieldPairs && y - anchor > .026 && !nestedValue) {
        rows.add([]);
        anchor = y;
      }
      rows.last.add(type);
    }
    double pixels(_PaidInteriorType type, double scale) =>
        math.max(type.minimum, type.ideal * scale);
    double sequenceHeight(
      List<_PaidInteriorType> list,
      double width,
      double scale,
      double gap,
    ) => list.isEmpty
        ? 0
        : list.fold<double>(
                0,
                (sum, type) =>
                    sum + type.height(pixels(type, scale), width) + gap,
              ) -
              gap;
    double rowHeight(List<_PaidInteriorType> row, double scale) => math.max(
      sequenceHeight(
        row.where((type) => column(type) == 0).toList(),
        widths[0],
        scale,
        3,
      ),
      sequenceHeight(
        row.where((type) => column(type) == 1).toList(),
        widths[1],
        scale,
        3,
      ),
    );
    final rowGap = spacious ? 12.0 : 9.0;
    double used(double scale) =>
        sequenceHeight(headers, region.width, scale, 6) +
        (headers.isEmpty ? 0 : 16) +
        rows.fold<double>(
          0,
          (sum, row) => sum + rowHeight(row, scale) + rowGap,
        ) -
        rowGap +
        (tails.isEmpty ? 0 : 16) +
        sequenceHeight(tails, region.width, scale, 6);
    if (used(0) > region.height) return false;
    var scale = 1.0;
    while (used(scale) > region.height && scale > .25) scale *= .95;
    var y = region.top;
    void fullWidth(List<_PaidInteriorType> list) {
      for (final type in list) {
        final size = pixels(type, scale);
        final h = type.height(size, region.width);
        positionedTexts.add(
          _textLayer(
            type,
            Rect.fromLTWH(region.left, y, region.width, h),
            size,
          ),
        );
        y += h + 6;
      }
      if (list.isNotEmpty) y -= 6;
    }

    fullWidth(headers);
    if (headers.isNotEmpty) y += 16;
    for (final entry in rows.indexed) {
      final row = entry.$2;
      final height = rowHeight(row, scale);
      for (var index = 0; index < 2; index++) {
        var cellY = y;
        for (final type in row.where((type) => column(type) == index)) {
          final size = pixels(type, scale);
          final h = type.height(size, widths[index]);
          positionedTexts.add(
            _textLayer(
              type,
              Rect.fromLTWH(
                region.left + (index == 0 ? 0 : widths[0] + gutter),
                cellY,
                widths[index],
                h,
              ),
              size,
            ),
          );
          cellY += h + 3;
        }
      }
      if (entry.$1 < rows.length - 1)
        _rule(
          Rect.fromLTWH(region.left, y + height + rowGap / 2, region.width, .6),
        );
      y += height + rowGap;
    }
    y -= rowGap;
    if (tails.isNotEmpty) y += 16;
    fullWidth(tails);
    return true;
  }

  Map<String, dynamic> _textLayer(
    _PaidInteriorType type,
    Rect rect,
    double pixels,
  ) {
    final originalStyle = type.source['style'] is Map
        ? Map<String, dynamic>.from(type.source['style'] as Map)
        : <String, dynamic>{};
    final layer = <String, dynamic>{
      ...type.source,
      ..._geometry(rect),
      'text': type.wrap(pixels, rect.width),
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
    // Earlier studies attached labels to image overlays. In this edition the
    // label is on paper, so that attachment must no longer drive rendering.
    layer.remove('overlayImageId');
    return layer;
  }

  void _footer() {
    if (footers.isEmpty) return;
    final numeric = footers
        .where(
          (layer) => RegExp(r'^\s*\d{1,3}\s*$').hasMatch(_sourceText(layer)),
        )
        .toList();
    final labels = footers.where((layer) => !numeric.contains(layer)).toList();
    final numberWidth = numeric.isEmpty ? 0.0 : 32.0;
    final labelWidth =
        (safe.width -
            numberWidth -
            (numberWidth > 0 ? 12 : 0) -
            10 * math.max(0, labels.length - 1)) /
        math.max(1, labels.length);
    _PaidInteriorType footerType(Map<String, dynamic> layer) =>
        _PaidInteriorType(
          layer,
          _sourceText(layer),
          'NotoSans',
          8.5,
          8.5,
          1.3,
          FontWeight.w400,
          true,
          false,
        );
    final height = footers.fold<double>(
      13.05,
      (value, layer) => math.max(
        value,
        footerType(
          layer,
        ).height(8.5, numeric.contains(layer) ? numberWidth : labelWidth),
      ),
    );
    final y = canvas.height - 12.5 - height;
    for (final layer in numeric)
      positionedTexts.add(
        _textLayer(
          footerType(layer),
          Rect.fromLTWH(
            left ? safe.left : safe.right - numberWidth,
            y,
            numberWidth,
            footerType(layer).height(8.5, numberWidth),
          ),
          8.5,
        ),
      );
    for (final entry in labels.indexed)
      positionedTexts.add(
        _textLayer(
          footerType(entry.$2),
          Rect.fromLTWH(
            safe.left +
                (left && numberWidth > 0 ? numberWidth + 12 : 0) +
                entry.$1 * (labelWidth + 10),
            y,
            labelWidth,
            footerType(entry.$2).height(8.5, labelWidth),
          ),
          8.5,
        ),
      );
  }
}

double _paidInteriorContrast(String foreground, String background) {
  double light(String raw) => Color(
    int.parse(raw.replaceFirst('#', 'FF'), radix: 16),
  ).computeLuminance();
  final a = light(foreground), b = light(background);
  return (math.max(a, b) + .05) / (math.min(a, b) + .05);
}

class _PaidInteriorType {
  _PaidInteriorType(
    this.source,
    this.text,
    this.font,
    this.ideal,
    this.minimum,
    this.leading,
    this.weight,
    this.caption,
    this.headline, {
    this.displayText,
  });
  final Map<String, dynamic> source;
  final String text, font;
  final String? displayText;
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

    final wrapped = (displayText ?? text)
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

/// Physical photograph sizes, read from existing bundled image headers. Keeping
/// each whole source visible removes the old oval/window crop without changing
/// a customer's image source or stored composition controls.
double _paidInteriorPhotoAspect(Map<String, dynamic> photo) {
  final raw =
      photo['originalUrl'] ??
      photo['imageUrl'] ??
      photo['previewUrl'] ??
      photo['asset'];
  final path = '$raw'.replaceFirst(RegExp(r'^asset:'), '');
  if (path.startsWith(_editorial))
    return path.split('/').last.startsWith('cover_') ? 1 : 1.5;
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
    'assets/templates/atelier_editions_2026/companion-play.png': 1.33333333,
    'assets/templates/atelier_editions_2026/companion-window.png': 1.33333333,
    'assets/templates/atelier_editions_2026/daily-paw-path.png': 1.33333333,
    'assets/templates/atelier_editions_2026/city-cafe.png': 1.33333333,
    'assets/templates/atelier_editions_2026/city-crossing.png': 1.5,
    'assets/templates/atelier_editions_2026/city-river.png': 1.5,
    'assets/templates/atelier_editions_2026/city-tram-interior.png': 1.5,
    'assets/templates/atelier_editions_2026/green-hours-leaf-study.png': 1.5,
    'assets/templates/atelier_editions_2026/green-hours-tools.png': 1.5,
    'assets/templates/atelier_editions_2026/green-hours-watering.png': 1.5,
    'assets/templates/atelier_editions_2026/little-explorer-drawing.png': 1.5,
    'assets/templates/atelier_editions_2026/little-explorer-finds.png': 1.5,
    'assets/templates/atelier_editions_2026/little-explorer-play.png':
        1.33333333,
    'assets/templates/atelier_editions_2026/little-explorer-rest.png': 1.5,
    'assets/templates/atelier_editions_2026/little-explorer-walk.png': 1.5,
    'assets/templates/atelier_editions_2026/summer-bench.png': 1.33333333,
    'assets/templates/atelier_editions_2026/summer-evening.png': 1.33333333,
    'assets/templates/atelier_editions_2026/summer-keepsake-box.png': 1.5,
    'assets/templates/atelier_editions_2026/velvet-vow-archive.png': 1.5,
    'assets/templates/atelier_editions_2026/velvet-vow-details.png': 1.5,
    'assets/templates/atelier_editions_2026/velvet-vow-reading.png': 1.5,
    'assets/templates/jeju_travel/images/approved_stock/arrival_station.jpg':
        1.50085763,
    'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg':
        1.73972603,
    'assets/templates/jeju_travel/images/approved_stock/cafe_detail.jpg':
        1.32676270,
    'assets/templates/jeju_travel/images/approved_stock/fruit_detail.jpg':
        1.33333333,
    'assets/templates/jeju_travel/images/approved_stock/guesthouse_detail.jpg':
        1.50021432,
    'assets/templates/jeju_travel/images/approved_stock/photo_dump.jpg':
        1.33333333,
    'assets/templates/jeju_travel/images/approved_stock/road_window.jpg':
        1.40720222,
    'assets/templates/jeju_travel/images/approved_stock/sunset_people.jpg':
        1.48999574,
    'assets/templates/save_the_date/images/approved_stock/closing_couple.jpg':
        1.50021432,
    'assets/templates/save_the_date/images/approved_stock/couple_hero.jpg':
        1.50021432,
    'assets/templates/save_the_date/images/approved_stock/date_card.jpg':
        1.49852507,
    'assets/templates/save_the_date/images/approved_stock/hands_flowers.jpg':
        1.62300319,
    'assets/templates/save_the_date/images/approved_stock/ribbon_detail.jpg':
        1.5,
    'assets/templates/save_the_date/images/approved_stock/rings_detail.jpg':
        1.30841121,
    'assets/templates/save_the_date/images/approved_stock/table_detail.jpg':
        1.38888889,
    'assets/templates/save_the_date/images/approved_stock/veil_detail.jpg':
        1.49852507,
    'assets/templates/soft_babybook/images/approved_stock/baby_detail.jpg':
        1.43098592,
    'assets/templates/soft_babybook/images/approved_stock/book_bed.jpg':
        1.49852507,
    'assets/templates/soft_babybook/images/approved_stock/field_baby.jpg':
        1.69333333,
    'assets/templates/soft_babybook/images/approved_stock/parent_back.jpg':
        1.35828877,
    'assets/templates/soft_babybook/images/approved_stock/parent_hand.jpg':
        1.37669377,
    'assets/templates/soft_babybook/images/approved_stock/soft_clips.jpg':
        1.49852507,
    'assets/templates/wedding_editorial/images/approved_stock/bouquet_hand.jpg':
        1.46525680,
    'assets/templates/wedding_editorial/images/approved_stock/ceremony_group.jpg':
        1.50021432,
    'assets/templates/wedding_editorial/images/approved_stock/closing_shadow.jpg':
        1.50021432,
    'assets/templates/wedding_editorial/images/approved_stock/couple_hero.jpg':
        1.50021432,
    'assets/templates/wedding_editorial/images/approved_stock/ribbon_detail.jpg':
        1.5,
    'assets/templates/wedding_editorial/images/approved_stock/rings_detail.jpg':
        1.30841121,
    'assets/templates/wedding_editorial/images/approved_stock/table_detail.jpg':
        1.38888889,
    'assets/templates/wedding_editorial/images/approved_stock/window_shadow.jpg':
        .75,
  };
  if (exceptions.containsKey(path)) return exceptions[path]!;
  if (path.startsWith('assets/templates/atelier_editions_2026/')) return 1;
  return 1.5;
}
