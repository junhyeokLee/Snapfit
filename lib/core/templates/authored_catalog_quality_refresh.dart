part of 'authored_collections.dart';

const _catalogQualityCoverRevision = 'photo-led-lettering-2026-10-25';
const walkingCatalogTitle = '너랑 걷는 오후';
const _letteringCoverIds = {
  'small-days',
  'journey',
  'city-collector',
  'scenes-for-two',
  'our-walking-promise',
};
const _qualityCoverIds = {
  'small-days',
  'alley-afternoon',
  'journey',
  'city-collector',
  'scenes-for-two',
  'collected-by-two',
  'our-walking-promise',
  'little-companion',
};

/// Publication-only art direction. The customer document and original authoring
/// factories are never rewritten. Native exports freeze these measured layers;
/// no font measurement, new artwork assets or compositing work enters scrolling.
Map<String, dynamic> _refineCatalogQualityCover(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (_storeTemplateQualityIds.contains(id) &&
      CollectionAspect.printable.contains(aspect)) {
    return _refineStoreTemplateQuality(id, aspect, document);
  }
  if (!_qualityCoverIds.contains(id)) return document;
  final source = Map<String, dynamic>.from(document['cover'] as Map);
  final original = (source['layers'] as List).cast<Map>();
  final texts = original.where((l) => l['type'] == 'text').toList();
  final title = texts.reduce(
    (a, b) =>
        _QualityCoverType.pixels(a) >= _QualityCoverType.pixels(b) ? a : b,
  );
  final type = _QualityCoverType(id, aspect);
  final layers = <Map<String, dynamic>>[
    for (final layer in original)
      if (layer['type'] != 'text') Map<String, dynamic>.from(layer),
  ];
  type.compose(title, texts.where((l) => l != title).toList(), layers);
  layers.sort((a, b) => (a['z'] as num).compareTo(b['z'] as num));
  return {
    ...document,
    if (id == 'our-walking-promise') ...{
      'title': walkingCatalogTitle,
      'originalCatalogTitle': document['title'],
    },
    if (_letteringCoverIds.contains(id))
      'coverLetteringRevision': 'expressive-lettering-2026-10-25',
    'coverArtDirection': _catalogQualityCoverRevision,
    'cover': {
      ...source,
      'coverArtDirection': _catalogQualityCoverRevision,
      if (_letteringCoverIds.contains(id))
        'coverLetteringRevision': 'expressive-lettering-2026-10-25',
      'layers': layers,
    },
  };
}

class _QualityCoverType {
  _QualityCoverType(this.id, this.aspect);
  final String id;
  final CollectionAspect aspect;
  bool get wide => aspect.isLandscape;
  Size get canvas => aspect.canvas;
  static double pixels(Map layer) =>
      ((layer['style'] as Map?)?['fontSize'] as num?)?.toDouble() ?? 10;
  static String copy(Map layer) => '${layer['text'] ?? ''}';

  void place(
    List<Map<String, dynamic>> output,
    Map source,
    Rect box, {
    required double size,
    required String ink,
    String font = 'NotoSans',
    int weight = 400,
    double tracking = 0,
    String align = 'left',
    String? text,
    double leading = 1.12,
  }) {
    final value = text ?? copy(source);
    final width = box.width * canvas.width;
    final height = box.height * canvas.height;
    var fitted = size;
    for (var attempt = 0; attempt < 70; attempt++) {
      final style = TextStyle(
        fontFamily: font,
        fontSize: fitted,
        fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
        letterSpacing: tracking,
        height: leading,
      );
      final measure = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      )..layout(maxWidth: width - 1);
      final fits =
          measure.height + 1 <= height &&
          measure.computeLineMetrics().length <= value.split('\n').length;
      measure.dispose();
      if (fits) break;
      fitted *= .97;
    }
    output.add({
      ...source,
      'x': box.left,
      'y': box.top,
      'w': box.width,
      'h': box.height,
      'text': value,
      if (value != copy(source))
        'editorialSourceText': source['editorialSourceText'] ?? copy(source),
      'align': align,
      'rotation': 0,
      'opacity': 1,
      'textFillMode': 'solid',
      'style': <String, dynamic>{
        if (source['style'] is Map) ...source['style'] as Map,
        'fontFamily': font,
        'fontSize': fitted,
        'fontWeight': weight,
        'color': ink,
        'letterSpacing': tracking,
        'height': leading,
        'shadows': [
          {
            'color': '#18000000',
            'blurRadius': 1.2,
            'offset': {'dx': 0.0, 'dy': .25},
          },
        ],
      },
    });
  }

  void compose(Map title, List<Map> details, List<Map<String, dynamic>> out) {
    // Each photograph has its own negative space. These positions deliberately
    // avoid faces, the cat's ears, the bouquet and the shared walking scene.
    final (box, size, ink, align, font) = switch (id) {
      'small-days' => (
        const Rect.fromLTWH(.50, .61, .445, .32),
        wide ? 54.0 : 68.0,
        '#4D3549',
        'right',
        'Maker',
      ),
      'alley-afternoon' => (
        Rect.fromLTWH(.065, .125, .84, .40),
        wide ? 63.0 : 76.0,
        '#4F2725',
        'left',
        'RiaSans',
      ),
      'journey' => (
        Rect.fromLTWH(.064, .075, .60, .40),
        wide ? 69.0 : 88.0,
        '#214B47',
        'left',
        'Arirang2',
      ),
      'city-collector' => (
        Rect.fromLTWH(.06, .045, .88, .19),
        wide ? 44.0 : 57.0,
        '#172E43',
        'left',
        'Paece',
      ),
      'scenes-for-two' => (
        Rect.fromLTWH(.06, .12, .88, .22),
        wide ? 62.0 : 76.0,
        '#2F4B55',
        'center',
        'Yeongwol',
      ),
      'collected-by-two' => (
        Rect.fromLTWH(.064, wide ? .53 : .58, .84, .25),
        wide ? 63.0 : 76.0,
        '#FFF5DF',
        'left',
        'SeoulNamsan',
      ),
      'our-walking-promise' => (
        Rect.fromLTWH(.47, .065, .47, .38),
        wide ? 55.0 : 69.0,
        '#FFF4DB',
        'right',
        'Doldam',
      ),
      _ => (
        const Rect.fromLTWH(.18, .13, .24, .32),
        wide ? 40.0 : 46.0,
        '#173845',
        'left',
        'RiaSans',
      ),
    };
    final display = switch (id) {
      'alley-afternoon' => '골목의\n오후',
      'journey' => '여행의\n결',
      'city-collector' => '도시의 수집가',
      'scenes-for-two' => '둘만의 장면',
      'our-walking-promise' => '너랑 걷는\n오후',
      _ => copy(title),
    };
    place(
      out,
      title,
      box,
      size: size,
      ink: ink,
      font: font,
      weight: font == 'SeoulNamsan' ? 400 : 800,
      tracking: _letteringCoverIds.contains(id)
          ? 0
          : font == 'RiaSans'
          ? -1.5
          : -.5,
      align: align,
      text: display,
      leading: _letteringCoverIds.contains(id) ? 1.12 : 1.04,
    );

    // Keep every editable place, name, date and original label. Small details
    // form a deliberate colophon rather than competing with the main title.
    for (final (index, detail) in details.indexed) {
      final key = '${detail['id']}';
      final date = key.endsWith('period') || key.endsWith('part_7');
      final eye = key.endsWith('piece_2') || key.endsWith('part_2');
      final subtitle = id == 'little-companion' && key.endsWith('part_5');
      if (id == 'small-days') {
        place(
          out,
          detail,
          Rect.fromLTWH(.06, index == 0 ? .065 : .91, .40, .04),
          size: index == 0 ? 12.5 : 10.5,
          ink: '#FFF9EF',
          tracking: .5,
        );
      } else if (id == 'little-companion' && (eye || subtitle)) {
        place(
          out,
          detail,
          Rect.fromLTWH(.065, eye ? .065 : .57, .48, .05),
          size: eye ? 9.5 : 15,
          ink: '#173845',
          font: 'Poppins',
          weight: eye ? 600 : 400,
          tracking: eye ? 1.0 : .2,
        );
      } else if (eye) {
        place(
          out,
          detail,
          const Rect.fromLTWH(.065, .06, .86, .04),
          size: 10,
          ink: '#482E29',
          font: 'Poppins',
          weight: 600,
          tracking: 1.4,
        );
      } else {
        final pale = const {
          'collected-by-two',
          'city-collector',
          'little-companion',
        }.contains(id);
        final y = date ? .913 : .855 + index * .045;
        place(
          out,
          detail,
          Rect.fromLTWH(
            date ? .63 : .065,
            y,
            date ? .305 : .54,
            date ? .037 : .043,
          ),
          size: date
              ? 10
              : index == 0
              ? 12
              : 10.5,
          ink: pale
              ? '#FFF9EC'
              : id == 'our-walking-promise'
              ? '#463F35'
              : id == 'journey'
              ? '#183A3B'
              : '#243B48',
          align: date ? 'right' : 'left',
          weight: index == 0 ? 600 : 400,
          tracking: .2,
        );
      }
    }
  }
}

/// Four paid collections lead the material upgrade. Existing objects grow into
/// the negative space already present on their page; photographs and copy never
/// move or shrink. No new paid material key or decoded bitmap is introduced.
Map<String, dynamic> _refinePaidMaterialPresence(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (!const {
    'shore-days',
    'reading-room',
    'shared-seasons',
    'little-companion',
  }.contains(id))
    return document;
  final canvas = aspect.canvas;
  Map<String, dynamic> page(Map source) {
    if (source == (document['pages'] as List).first) {
      return _paidMaterialOpening(id, aspect, source);
    }
    final layers = (source['layers'] as List)
        .map((l) => Map<String, dynamic>.from(l as Map))
        .toList();
    final objects = layers
        .where((l) => l['editorialMaterial'] != null)
        .toList();
    if (objects.isEmpty) return Map<String, dynamic>.from(source);
    Rect rect(Map l) => Rect.fromLTWH(
      (l['x'] as num).toDouble() * canvas.width,
      (l['y'] as num).toDouble() * canvas.height,
      (l['w'] as num).toDouble() * canvas.width,
      (l['h'] as num).toDouble() * canvas.height,
    );
    final photos = layers.where((l) => l['type'] == 'image').toList();
    // Safe trim and binding gutters are inherited from the editorial book.
    final safe = Rect.fromLTRB(
      42.5,
      31,
      canvas.width - 42.5,
      canvas.height - 48,
    );
    for (final object in objects) {
      final original = rect(object);
      final obstacles = layers
          .where(
            (l) =>
                l != object &&
                (l['type'] == 'text' ||
                    l['type'] == 'image' ||
                    l['editorialMaterial'] != null),
          )
          .map((l) => rect(l).inflate(12))
          .toList();
      final ratio = (object['editorialMaterialAspect'] as num).toDouble();
      final maxWidth = photos.isEmpty ? canvas.width * .57 : canvas.width * .22;
      var best = original;
      // Enumerate obstacle edges, not an unbounded pixel search. This runs only
      // in authoring/export tools; the app consumes the resulting coordinates.
      final xs = {
        safe.left,
        safe.right,
        for (final r in obstacles) r.left,
        for (final r in obstacles) r.right,
      };
      final ys = {
        safe.top,
        safe.bottom,
        for (final r in obstacles) r.top,
        for (final r in obstacles) r.bottom,
      };
      for (final x in xs) {
        for (final y in ys) {
          if (x < safe.left ||
              x > safe.right ||
              y < safe.top ||
              y > safe.bottom) {
            continue;
          }
          for (final right in [false, true]) {
            for (final bottom in [false, true]) {
              var width = math.min(
                maxWidth,
                math.min(
                  right ? x - safe.left : safe.right - x,
                  (bottom ? y - safe.top : safe.bottom - y) * ratio,
                ),
              );
              for (final r in obstacles) {
                final farX = right ? x - r.left : r.right - x;
                final farY = bottom ? y - r.top : r.bottom - y;
                if (farX <= 0 || farY <= 0) continue;
                final nearX = right ? x - r.right : r.left - x;
                final nearY = bottom ? y - r.bottom : r.top - y;
                width = math.min(width, math.max(nearX, nearY * ratio));
                if (width <= best.width + .5) break;
              }
              if (width <= best.width + .5) continue;
              final candidate = Rect.fromLTWH(
                right ? x - width : x,
                bottom ? y - width / ratio : y,
                width,
                width / ratio,
              );
              if (!obstacles.any(candidate.deflate(.01).overlaps))
                best = candidate;
            }
          }
        }
      }
      if (best.width > original.width * 1.15) {
        object.addAll({
          'x': best.left / canvas.width,
          'y': best.top / canvas.height,
          'w': best.width / canvas.width,
          'h': best.height / canvas.height,
          'materialPresenceRevision': 'collected-objects-2026-10-25',
        });
      }
    }
    return {...source, 'layers': layers};
  }

  return {
    ...document,
    'pages': [for (final p in document['pages'] as List) page(p as Map)],
  };
}

Map<String, dynamic> _paidMaterialOpening(
  String id,
  CollectionAspect aspect,
  Map source,
) {
  final original = (source['layers'] as List).cast<Map>();
  final sourceMaterial = original
      .where((l) => l['editorialMaterial'] != null)
      .single;
  // A blank stock sample is a weak opening. The couple book already contains
  // this pressed flower; feature it here while retaining its paper elsewhere.
  // The book's material inventory and ownership bundle therefore stay fixed.
  final material = <String, dynamic>{
    ...sourceMaterial,
    if (id == 'shared-seasons') ...{
      'imageUrl':
          'asset:${studioDecorationById('studioPressedCosmos')!.assetPath}',
      'editorialMaterial': 'studioPressedCosmos',
      'editorialMaterialAspect': 2 / 3,
    },
  };
  final texts = original.where((l) => l['type'] == 'text').toList();
  final content = texts
      .where((l) => !'${l['id']}'.contains('_folio_'))
      .toList();
  final heading = content.singleWhere(
    (l) => (l['style'] as Map)['fontFamily'] == 'Cormorant Garamond',
  );
  final label = content.first;
  final korean = content
      .where((l) => l != heading && l != label)
      .reduce(
        (a, b) =>
            _QualityCoverType.pixels(a) >= _QualityCoverType.pixels(b) ? a : b,
      );
  final notes = content
      .where((l) => l != heading && l != label && l != korean)
      .toList();
  final (paper, ink) = switch (id) {
    'shore-days' => ('#183F45', '#FFF7E7'),
    'reading-room' => ('#EEE8D2', '#213F77'),
    'shared-seasons' => ('#344B41', '#FFF4E1'),
    _ => ('#DCE7DE', '#234B48'),
  };
  final canvas = aspect.canvas;
  final objectWidth = id == 'shared-seasons'
      ? math.min(145.0, canvas.height * .30)
      : math.min(240.0, canvas.height * .48);
  final ratio = (material['editorialMaterialAspect'] as num).toDouble();
  final objectHeight = objectWidth / ratio;
  final output = <Map<String, dynamic>>[
    for (final l in original.where((l) => l['type'] != 'text'))
      if (l == sourceMaterial)
        {
          ...material,
          'x': (canvas.width - 42.5 - objectWidth) / canvas.width,
          'y': (canvas.height - 58 - objectHeight) / canvas.height,
          'w': objectWidth / canvas.width,
          'h': objectHeight / canvas.height,
          'materialPresenceRevision': 'collected-objects-2026-10-25',
        }
      else
        {
          ...l,
          if (l['x'] == 0 && l['y'] == 0 && l['w'] == 1) 'fillColor': paper,
        },
  ];
  final type = _QualityCoverType(id, aspect);
  type.place(
    output,
    label,
    const Rect.fromLTWH(.085, .065, .83, .04),
    size: 10.5,
    ink: ink,
    tracking: .8,
  );
  type.place(
    output,
    heading,
    const Rect.fromLTWH(.085, .14, .83, .19),
    size: aspect.isLandscape ? 66 : 83,
    ink: ink,
    font: 'Cormorant Garamond',
    weight: 800,
    tracking: -1.1,
    leading: 1.04,
  );
  type.place(
    output,
    korean,
    const Rect.fromLTWH(.085, .375, .32, .235),
    size: aspect.isLandscape ? 25 : 30,
    ink: ink,
    font: 'RiaSans',
    weight: 800,
    tracking: -.6,
    leading: 1.16,
  );
  for (final (index, note) in notes.indexed) {
    type.place(
      output,
      note,
      Rect.fromLTWH(.085, .655 + index * .105, .32, .095),
      size: 12,
      ink: ink,
      leading: 1.4,
    );
  }
  for (final l in texts.where((l) => !content.contains(l))) {
    output.add({
      ...l,
      'style': <String, dynamic>{...l['style'] as Map, 'color': ink},
    });
  }
  for (final (index, l) in output.indexed) {
    l['z'] = index;
    if (l['type'] == 'text') (l['style'] as Map)['shadows'] = <Object>[];
  }
  return {
    ...source,
    'layers': output,
    'materialStoryOpeningRevision': 'collected-objects-2026-10-25',
  };
}

const _storeTemplateQualityRevision = 'objects-company-dates-2026-11-02';
const _storeTemplateQualityIds = {
  'taste-archive',
  'our-good-company',
  'dates-of-us',
};

/// Three existing books receive a complete opening spread as well as a cover.
/// This pass only publishes new catalog samples: source factories and customer
/// documents retain their original IDs, photos, text and saved geometry.
Map<String, dynamic> _refineStoreTemplateQuality(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  final art = _StoreTemplateQuality(id, aspect);
  final pages = (document['pages'] as List).cast<Map>();
  return {
    ...document,
    'coverArtDirection': _storeTemplateQualityRevision,
    'editorialArtDirection': _storeTemplateQualityRevision,
    'cover': art.cover(document['cover'] as Map),
    'pages': [
      for (final (index, page) in pages.indexed)
        if (index == 2 || index == 3) art.spread(page, index + 1) else page,
    ],
  };
}

class _StoreTemplateQuality {
  _StoreTemplateQuality(this.id, this.aspect)
    : type = _QualityCoverType(id, aspect);
  final String id;
  final CollectionAspect aspect;
  final _QualityCoverType type;
  bool get wide => aspect.isLandscape;
  double get ratio => aspect.canvas.aspectRatio;
  String get ink => id == 'taste-archive'
      ? '#492E49'
      : id == 'our-good-company'
      ? '#223E48'
      : '#503C3B';
  String get paper => id == 'taste-archive'
      ? '#F5F1EB'
      : id == 'our-good-company'
      ? '#F6F7F0'
      : '#FBF4EB';

  Map<String, dynamic> image(Map source, Rect box, {String? asset}) => {
    ...source,
    'x': box.left,
    'y': box.top,
    'w': box.width,
    'h': box.height,
    'rotation': 0,
    'frame': 'none',
    if (asset != null) ...{
      'imageUrl': 'asset:$asset',
      'editorialSourcePhoto':
          source['editorialSourcePhoto'] ?? source['imageUrl'],
      'editorialPhotoAspectRatio': 1.5,
    },
  };

  /// A photograph is fitted by its physical ratio, not by normalized page units.
  /// Group portraits consequently retain every person in all three sale sizes.
  Rect landscape(double x, double y, double width) =>
      Rect.fromLTWH(x, y, width, width * ratio / 1.5);

  void text(
    List<Map<String, dynamic>> out,
    Map source,
    Rect box, {
    required double size,
    String font = 'NotoSans',
    int weight = 400,
    String? copy,
    String align = 'left',
    double leading = 1.15,
  }) => type.place(
    out,
    source,
    box,
    size: size,
    ink: ink,
    font: font,
    weight: weight,
    text: copy,
    align: align,
    leading: leading,
  );

  Map<String, dynamic> cover(Map source) {
    final original = (source['layers'] as List).cast<Map>();
    final photos = original.where((l) => l['type'] == 'image').toList();
    final texts = original.where((l) => l['type'] == 'text').toList();
    final title = texts.singleWhere((l) => '${l['id']}'.endsWith('_title'));
    final out = <Map<String, dynamic>>[
      for (final layer in original)
        if (layer['type'] != 'text' && layer['type'] != 'image')
          {...layer, 'fillColor': paper},
    ];
    late Rect hero;
    if (id == 'taste-archive') {
      hero = const Rect.fromLTWH(0, 0, 1, 1);
      out.add(image(photos.first, hero));
      text(
        out,
        title,
        const Rect.fromLTWH(.055, .33, .43, .43),
        size: wide ? 66 : 82,
        font: 'Arirang2',
        copy: '취향\n보관함',
        leading: 1.04,
      );
    } else if (id == 'our-good-company') {
      final width = math.min(
        wide ? .91 : .85,
        (wide ? .64 : .565) * 1.5 / ratio,
      );
      hero = landscape((1 - width) / 2, wide ? .205 : .285, width);
      out.add(image(photos.first, hero));
      text(
        out,
        title,
        Rect.fromLTWH(.06, wide ? .065 : .055, .74, wide ? .13 : .215),
        size: wide ? 44 : 62,
        font: 'Doldam',
        copy: wide ? '우리의 좋은 사이' : '우리의\n좋은 사이',
        leading: 1.04,
      );
    } else {
      hero = const Rect.fromLTWH(0, 0, 1, .665);
      out.add(image(photos.first, hero));
      text(
        out,
        title,
        const Rect.fromLTWH(.06, .765, .74, .14),
        size: wide ? 35 : 43,
        font: 'BookMyungjo',
        copy: '너와 나의 날짜들',
      );
    }
    for (final detail in texts.where((t) => t != title)) {
      final key = '${detail['id']}';
      final date = key.endsWith('_period');
      final place = key.endsWith('_place');
      final y = id == 'dates-of-us' && place
          ? .70
          : place
          ? .865
          : .927;
      text(
        out,
        detail,
        Rect.fromLTWH(date ? .60 : .06, y, date ? .345 : .54, .038),
        size: place ? 11.5 : 9.5,
        weight: place ? 500 : 400,
        align: date ? 'right' : 'left',
      );
    }
    out.sort((a, b) => (a['z'] as num).compareTo(b['z'] as num));
    return {
      ...source,
      'coverArtDirection': _storeTemplateQualityRevision,
      'coverTextTreatment': id == 'taste-archive'
          ? 'open-photographic-type'
          : id == 'our-good-company'
          ? 'uncropped-company-mat'
          : 'literary-photo-colophon',
      'heroCoverageFraction': hero.width * hero.height,
      'layers': out,
    };
  }

  Map<String, dynamic> spread(Map source, int page) {
    final original = (source['layers'] as List).cast<Map>();
    final photos = original.where((l) => l['type'] == 'image').toList();
    final texts = original.where((l) => l['type'] == 'text').toList();
    final folio = texts.singleWhere((l) => '${l['id']}'.endsWith('_folio'));
    final copy = texts.where((l) => l != folio).toList();
    final out = <Map<String, dynamic>>[
      for (final layer in original)
        if (layer['type'] != 'text' && layer['type'] != 'image')
          {...layer, 'fillColor': paper},
      Map<String, dynamic>.from(folio),
    ];
    if (id == 'taste-archive') {
      if (page == 3) {
        text(
          out,
          copy[0],
          const Rect.fromLTWH(.065, .065, .85, .05),
          size: 10,
          weight: 600,
        );
        final photo = landscape(.065, .17, wide ? .69 : .85);
        out.add(
          image(
            photos.single,
            photo,
            asset: 'assets/frame_preview/studio_laptop.jpg',
          ),
        );
        text(
          out,
          copy[1],
          Rect.fromLTWH(
            .065,
            photo.bottom + (wide ? .04 : .065),
            .85,
            wide ? .085 : .11,
          ),
          size: wide ? 22 : 27,
          font: 'BookMyungjo',
        );
      } else {
        final first = landscape(.085, .09, .53);
        final second = landscape(.635, .405, .28);
        out.add(
          image(
            photos[0],
            first,
            asset: 'assets/frame_preview/artist_palette.jpg',
          ),
        );
        out.add(
          image(photos[1], second, asset: 'assets/frame_preview/wardrobe.jpg'),
        );
        text(
          out,
          copy[0],
          Rect.fromLTWH(.085, wide ? .72 : .68, .85, .17),
          size: wide ? 22 : 27,
          font: 'BookMyungjo',
          leading: 1.2,
        );
        text(
          out,
          copy[1],
          const Rect.fromLTWH(.665, .09, .25, .15),
          size: 11,
          leading: 1.3,
        );
      }
    } else if (id == 'our-good-company') {
      if (page == 3) {
        text(
          out,
          copy[0],
          const Rect.fromLTWH(.065, .065, .85, .05),
          size: 10,
          weight: 600,
        );
        final photo = landscape(.065, wide ? .15 : .19, wide ? .71 : .87);
        out.add(
          image(
            photos.single,
            photo,
            asset:
                'assets/templates/original_editorial/images/daily_friends.png',
          ),
        );
        text(
          out,
          copy[1],
          Rect.fromLTWH(.065, photo.bottom + .045, .87, wide ? .08 : .10),
          size: wide ? 20 : 25,
          font: 'Yeongwol',
        );
      } else {
        text(
          out,
          copy[0],
          const Rect.fromLTWH(.085, .07, .85, .19),
          size: wide ? 30 : 38,
          font: 'Doldam',
          leading: 1.12,
        );
        final photo = landscape(.085, .29, .51 * 1.5 / ratio);
        out.add(
          image(
            photos.single,
            photo,
            asset:
                'assets/templates/original_editorial/images/family_friends.png',
          ),
        );
        text(
          out,
          copy[1],
          Rect.fromLTWH(.085, photo.bottom + .035, .85, .04),
          size: 11,
          weight: 600,
        );
        text(
          out,
          copy[2],
          Rect.fromLTWH(.085, photo.bottom + .085, .85, .035),
          size: 10,
        );
      }
    } else {
      if (page == 3) {
        text(
          out,
          copy[0],
          const Rect.fromLTWH(.065, .065, .85, .05),
          size: 10,
          weight: 600,
        );
        final photo = landscape(.065, wide ? .13 : .17, wide ? .65 : .85);
        out.add(
          image(
            photos.single,
            photo,
            asset: 'assets/templates/original_editorial/images/couple_cafe.png',
          ),
        );
        text(
          out,
          copy[1],
          Rect.fromLTWH(.065, photo.bottom + .035, .87, wide ? .16 : .17),
          size: wide ? 26 : 31,
          font: 'BookMyungjo',
          copy: '짧은 인사가\n긴 이야기가 돼.',
          leading: 1.25,
        );
      } else {
        // No face is cropped in the narrow companion scene: this page records
        // the shared table instead of repeating another posed couple portrait.
        final photo = Rect.fromLTWH(.26, .095, .655, wide ? .66 : .69);
        out.add(
          image(
            photos.single,
            photo,
            asset: 'assets/templates/original_editorial/images/travel_cafe.png',
          ),
        );
        text(
          out,
          copy.single,
          const Rect.fromLTWH(.085, .825, .83, .065),
          size: wide ? 17 : 20,
          font: 'Eulyoo',
          align: 'right',
        );
      }
    }
    out.sort((a, b) => (a['z'] as num).compareTo(b['z'] as num));
    return {
      ...source,
      'editorialArtDirection': _storeTemplateQualityRevision,
      'editorialLayout': '$id-${page == 3 ? 'scene' : 'collection'}',
      'layers': out,
    };
  }
}
