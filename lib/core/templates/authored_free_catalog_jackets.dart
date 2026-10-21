part of 'authored_collections.dart';

const _additionalFreeJacketRevision = 'storefront-editorial-2026-10-21';

/// Only current catalog jackets change. Source builders and saved albums retain
/// their original layers; publication, identity and every interior stay intact.
Map<String, dynamic> _refineAdditionalFreeCatalogCover(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (!const {
    'lightbound',
    'journey',
    'small-days',
    proseStudyId,
    'alley-afternoon',
    'saturday-together',
    'daily-paw-walk',
    'our-first-promise',
    'little-day-discoveries',
  }.contains(id))
    return document;
  final before = document['cover'] as Map<String, dynamic>;
  final jacket = _AdditionalFreeJacket(id, aspect, before);
  jacket.paint();
  return {
    ...document,
    'coverRevision': _additionalFreeJacketRevision,
    'cover': {
      ...before,
      'coverRevision': _additionalFreeJacketRevision,
      'layers': jacket.p.layers,
    },
  };
}

class _AdditionalFreeJacket {
  _AdditionalFreeJacket(this.id, this.aspect, this.before)
    : colors = switch (id) {
        'lightbound' => ('#F5F0E5', '#293E35'),
        'journey' => ('#D6E2E0', '#173F47'),
        'small-days' => ('#EDCBC2', '#573339'),
        proseStudyId => ('#6A293D', '#FFF4E5'),
        'alley-afternoon' => ('#E4DED0', '#26483D'),
        'saturday-together' => ('#D9DDB7', '#314B36'),
        'daily-paw-walk' => ('#173D8F', '#FFF2AE'),
        'our-first-promise' => ('#E8F0EB', '#264654'),
        _ => ('#F2DD8A', '#283F61'),
      } {
    p = _Sheet('catalog_$id', aspect, 0, colors.$1, ink: colors.$2);
  }
  final String id;
  final CollectionAspect aspect;
  final Map<String, dynamic> before;
  final (String, String) colors;
  late final _Sheet p;
  double get w => aspect.canvas.width;
  double get h => aspect.canvas.height;
  bool get wide => aspect == CollectionAspect.landscape;
  double get margin => wide ? 26 : 32;
  double get inner => w - margin * 2;
  List<Map<String, dynamic>> get originalText => (before['layers'] as List)
      .where((l) => l['type'] == 'text')
      .map((l) => Map<String, dynamic>.from(l as Map))
      .toList();
  Map<String, dynamic> _original(String suffix) =>
      originalText.singleWhere((l) => (l['id'] as String).endsWith('_$suffix'));
  String _value(String suffix) => _original(suffix)['text'] as String;

  TextPainter _measure(
    String value,
    double width,
    double pixels, {
    String font = 'NotoSans',
    int weight = 400,
    double leading = 1.25,
  }) {
    final style = TextStyle(
      fontFamily: font,
      fontSize: pixels,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      height: leading,
      letterSpacing: 0,
    );
    return TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
    )..layout(maxWidth: math.max(1, width - 1));
  }

  double _height(String value, double width, double pixels) {
    final measure = _measure(value, width, pixels);
    final result = measure.height + 2;
    measure.dispose();
    return result;
  }

  void _text(
    String key,
    String value,
    Rect bounds, {
    double pixels = 11,
    double minimum = 8.5,
    String font = 'NotoSans',
    int weight = 400,
    String align = 'left',
    String role = 'caption',
    double leading = 1.25,
    String? originalId,
  }) {
    var size = pixels;
    while (true) {
      final measure = _measure(
        value,
        bounds.width,
        size,
        font: font,
        weight: weight,
        leading: leading,
      );
      final fits = measure.height <= bounds.height - .5;
      measure.dispose();
      if (fits || size <= minimum) break;
      size = math.max(minimum, size * .96);
    }
    p.text(
      key,
      value,
      bounds.left / w,
      bounds.top / h,
      bounds.width / w,
      bounds.height / h,
      size: size / p.unit,
      font: font,
      weight: weight,
      color: colors.$2,
      align: align,
      lineHeight: leading,
    );
    p.layers.last.addAll({
      'typographyRole': role,
      'typographyMinFontSize': minimum,
      if (originalId != null) 'id': originalId,
    });
  }

  void _field(
    String suffix,
    Rect bounds, {
    double pixels = 11,
    String align = 'left',
    String role = 'caption',
  }) => _text(
    suffix,
    _value(suffix),
    bounds,
    pixels: pixels,
    minimum: role == 'body' ? 11 : 8.5,
    align: align,
    role: role,
    originalId: _original(suffix)['id'] as String,
  );

  void _photo(String path, Rect bounds, double ratio) {
    final width = math.min(bounds.width, bounds.height * ratio);
    final height = width / ratio;
    p.photo(
      'signature_photo',
      path,
      (bounds.left + (bounds.width - width) / 2) / w,
      (bounds.top + (bounds.height - height) / 2) / h,
      width / w,
      height / h,
    );
  }

  void _title(
    String value,
    Rect bounds, {
    String font = 'Eulyoo',
    int weight = 400,
    double? pixels,
    String align = 'left',
    String? originalId,
  }) => _text(
    'signature_title',
    value,
    bounds,
    pixels: pixels ?? (wide ? 39 : 46),
    minimum: wide ? 28 : 32,
    font: font,
    weight: weight,
    role: 'signature-title',
    leading: 1.12,
    align: align,
    originalId: originalId,
  );

  void paint() {
    switch (id) {
      case 'lightbound':
        _lightbound();
      case 'journey':
        _journey();
      case 'small-days':
        _smallDays();
      case proseStudyId:
        _prose();
      default:
        _studio();
    }
  }

  void _lightbound() {
    final namesH = _height(_value('cover_names'), inner * .58, 11);
    final dateH = _height(_value('cover_date'), inner * .38, 10);
    final bottom = h - margin - math.max(namesH, dateH);
    if (wide) {
      _title(
        '빛으로\n엮은 우리',
        Rect.fromLTWH(margin, margin + 12, 188, 133),
        pixels: 39,
      );
      _photo(
        '${_editorial}petal_couple.png',
        Rect.fromLTWH(236, margin, 238, bottom - margin - 20),
        1.5,
      );
    } else {
      _title(
        '빛으로\n엮은 우리',
        Rect.fromLTWH(margin, margin, inner, 116),
        pixels: 48,
      );
      _photo(
        '${_editorial}petal_couple.png',
        Rect.fromLTWH(margin, 160, inner, bottom - 180),
        1.5,
      );
    }
    _field(
      'cover_date',
      Rect.fromLTWH(margin, bottom, inner * .38, dateH),
      pixels: 10,
    );
    _field(
      'cover_names',
      Rect.fromLTWH(w - margin - inner * .58, bottom, inner * .58, namesH),
      pixels: 11,
      align: 'right',
    );
  }

  void _journey() {
    final placeH = _height(_value('cover_place'), inner, 11);
    final rowH = math.max(
      _height(_value('cover_period'), inner * .45, 9.5),
      _height(_value('cover_byline'), inner * .51, 10),
    );
    final bottom = h - margin - placeH - rowH - 8;
    if (wide) {
      _title(
        '여행의\n결',
        Rect.fromLTWH(margin, margin + 7, 180, 135),
        font: 'NotoSans',
        weight: 800,
        pixels: 45,
      );
      _photo(
        '${_editorial}travel_cafe.png',
        Rect.fromLTWH(227, margin, 247, bottom - margin - 18),
        1.5,
      );
    } else {
      _title(
        '여행의 결',
        Rect.fromLTWH(margin, margin, inner, 65),
        font: 'NotoSans',
        weight: 800,
        pixels: 53,
      );
      _photo(
        '${_editorial}travel_cafe.png',
        Rect.fromLTWH(0, 116, w, bottom - 137),
        1.5,
      );
    }
    _field(
      'cover_place',
      Rect.fromLTWH(margin, bottom, inner, placeH),
      role: 'body',
    );
    _field(
      'cover_period',
      Rect.fromLTWH(margin, bottom + placeH + 8, inner * .45, rowH),
      pixels: 9.5,
    );
    _field(
      'cover_byline',
      Rect.fromLTWH(
        w - margin - inner * .51,
        bottom + placeH + 8,
        inner * .51,
        rowH,
      ),
      pixels: 10,
      align: 'right',
    );
  }

  void _smallDays() {
    final seasonH = _height(_value('cover_season'), inner, 11);
    final authorH = _height(_value('cover_author'), inner, 10);
    final bottom = h - margin - seasonH - authorH - 8;
    if (wide) {
      _photo(
        '${_editorial}small_days_walk.png',
        Rect.fromLTWH(margin, margin, 260, bottom - margin - 16),
        1.5,
      );
      _title(
        '작은 날의\n기록',
        Rect.fromLTWH(312, margin + 15, 162, 127),
        pixels: 37,
      );
    } else {
      final titleY = bottom - 119;
      _photo(
        '${_editorial}small_days_walk.png',
        Rect.fromLTWH(margin, margin, inner, titleY - margin - 17),
        1.5,
      );
      _title(
        '작은 날의\n기록',
        Rect.fromLTWH(margin, titleY, inner, 108),
        pixels: 47,
      );
    }
    _field(
      'cover_season',
      Rect.fromLTWH(margin, bottom, inner, seasonH),
      role: 'body',
    );
    _field(
      'cover_author',
      Rect.fromLTWH(margin, bottom + seasonH + 8, inner, authorH),
      pixels: 10,
    );
  }

  void _prose() {
    final namesH = _height(_value('cover_names'), inner * .59, 11);
    final dateH = _height(_value('cover_date'), inner * .37, 9.5);
    final footer = h - margin - math.max(namesH, dateH);
    final preline = _value('cover_preline');
    if (wide) {
      _field(
        'cover_heading',
        Rect.fromLTWH(margin, margin, 207, 44),
        pixels: 25,
      );
      _title(
        _value('cover_keyword'),
        Rect.fromLTWH(margin, margin + 54, 207, 84),
        pixels: 55,
        originalId: _original('cover_keyword')['id'] as String,
      );
      _photo(
        'assets/templates/anniversary_days/images/sources/anniversary_sample.png',
        Rect.fromLTWH(255, margin, 219, footer - margin - 14),
        1400 / 1200,
      );
      final prelineH = _height(preline, 207, 11);
      _field(
        'cover_preline',
        Rect.fromLTWH(margin, footer - prelineH - 18, 207, prelineH),
        pixels: 11,
        role: 'body',
      );
      _field(
        'cover_edition',
        Rect.fromLTWH(margin, margin + 149, 207, 21),
        pixels: 9.5,
      );
    } else {
      _field(
        'cover_edition',
        Rect.fromLTWH(margin, margin, inner, 19),
        pixels: 9.5,
      );
      _field(
        'cover_heading',
        Rect.fromLTWH(margin, margin + 34, inner, 40),
        pixels: 28,
      );
      _title(
        _value('cover_keyword'),
        Rect.fromLTWH(margin, margin + 82, inner, 100),
        pixels: 77,
        originalId: _original('cover_keyword')['id'] as String,
      );
      final photoTop = margin + 194;
      final photoBottom = footer - 20;
      _photo(
        'assets/templates/anniversary_days/images/sources/anniversary_sample.png',
        Rect.fromLTWH(w * .41, photoTop, w * .53, photoBottom - photoTop),
        1400 / 1200,
      );
      final prelineW = w * .29;
      final prelineH = _height(preline, prelineW, 11);
      _field(
        'cover_preline',
        Rect.fromLTWH(
          margin,
          photoTop + (photoBottom - photoTop - prelineH) * .64,
          prelineW,
          prelineH,
        ),
        pixels: 11,
        role: 'body',
      );
    }
    _field(
      'cover_names',
      Rect.fromLTWH(margin, footer, inner * .59, namesH),
      pixels: 11,
    );
    _field(
      'cover_date',
      Rect.fromLTWH(w - margin - inner * .37, footer, inner * .37, dateH),
      pixels: 9.5,
      align: 'right',
    );
  }

  void _studio() {
    final edition = StudioEdition.byId(id)!;
    final texts = originalText;
    final eyebrow = texts.first;
    final description = texts.last;
    final titleSource = texts[1];
    final caption = description['text'] as String;
    final footerH = _height(caption, inner, 11);
    final bottom = h - margin - footerH;
    final font = switch (id) {
      'our-first-promise' => 'Eulyoo',
      'little-day-discoveries' => 'Arita',
      _ => 'NotoSans',
    };
    final title = wide
        ? switch (id) {
            'alley-afternoon' => '골목의\n오후',
            'saturday-together' => '같이 보낸\n토요일',
            'daily-paw-walk' => '오늘도\n산책!',
            'our-first-promise' => '우리의\n첫 약속',
            _ => '작은 날의\n발견',
          }
        : edition.title;
    if (wide) {
      _text(
        'signature_eyebrow',
        eyebrow['text'] as String,
        Rect.fromLTWH(margin, margin, 189, 31),
        pixels: 9.5,
        originalId: eyebrow['id'] as String,
      );
      _title(
        title,
        Rect.fromLTWH(margin, margin + 52, 187, 144),
        pixels: id == 'daily-paw-walk' ? 42 : 37,
        font: font,
        weight: font == 'Eulyoo' ? 400 : 800,
        originalId: titleSource['id'] as String,
      );
      _photo(
        edition.coverAsset,
        Rect.fromLTWH(231, margin, 243, bottom - margin - 16),
        1,
      );
    } else {
      _text(
        'signature_eyebrow',
        eyebrow['text'] as String,
        Rect.fromLTWH(margin, margin, inner, 21),
        pixels: 9.5,
        originalId: eyebrow['id'] as String,
      );
      _title(
        title,
        Rect.fromLTWH(margin, margin + 39, inner, 64),
        pixels: id == 'daily-paw-walk' ? 49 : 42,
        font: font,
        weight: font == 'Eulyoo' ? 400 : 800,
        originalId: titleSource['id'] as String,
      );
      _photo(
        edition.coverAsset,
        Rect.fromLTWH(margin, margin + 117, inner, bottom - margin - 132),
        1,
      );
    }
    _text(
      'signature_description',
      caption,
      Rect.fromLTWH(margin, bottom, inner, footerH),
      pixels: 11,
      minimum: 11,
      role: 'body',
      originalId: description['id'] as String,
    );
  }
}
