part of 'authored_collections.dart';

/// The catalog cover is a separate jacket. The original cover is built first
/// so its photo-use ledger, and therefore every existing interior, stays intact.
Map<String, dynamic> _buildFreeSignatureCover(
  _FreeBook book,
  Map<String, dynamic> before,
) {
  final jacket = _FreeSignatureJacket(book);
  jacket.paint();
  return {...before, 'layers': jacket.p.layers};
}

enum _FreeJacketLayout {
  masthead,
  gallery,
  split,
  band,
  archive,
  field,
  inset,
  horizon,
}

class _FreeJacketDirection {
  const _FreeJacketDirection(
    this.title,
    this.layout,
    this.paper,
    this.ink,
    this.accent, {
    this.font = 'Eulyoo',
    this.weight = 400,
    this.centered = false,
  });
  final String title, paper, ink, accent, font;
  final _FreeJacketLayout layout;
  final int weight;
  final bool centered;
}

// These are jackets with distinct silhouettes, rather than an interior frame
// repeated around a small image. All photography and lettering stays editable.
const _freeJacketDirections = <FreeCollectionVolume, _FreeJacketDirection>{
  FreeCollectionVolume.vows: _FreeJacketDirection(
    '우리의\n서약',
    _FreeJacketLayout.masthead,
    '#F7F3E9',
    '#283D36',
    '#52694C',
  ),
  FreeCollectionVolume.garden: _FreeJacketDirection(
    '정원에서의\n약속',
    _FreeJacketLayout.inset,
    '#DBE6CF',
    '#293D29',
    '#526646',
    centered: true,
  ),
  FreeCollectionVolume.cinema: _FreeJacketDirection(
    '영화 같던\n하루',
    _FreeJacketLayout.band,
    '#25262A',
    '#FFF9EE',
    '#C8AE7B',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.letters: _FreeJacketDirection(
    '사랑의\n편지',
    _FreeJacketLayout.gallery,
    '#F6EEE9',
    '#742E40',
    '#742E40',
  ),
  FreeCollectionVolume.seaside: _FreeJacketDirection(
    '바다를\n건너',
    _FreeJacketLayout.horizon,
    '#F3EFE2',
    '#143D48',
    '#143D48',
  ),
  FreeCollectionVolume.city: _FreeJacketDirection(
    '도시의\n수집가',
    _FreeJacketLayout.field,
    '#E8EADD',
    '#252E2D',
    '#A3312F',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.walking: _FreeJacketDirection(
    '느리게\n걷는 길',
    _FreeJacketLayout.gallery,
    '#E7E6D9',
    '#384B37',
    '#384B37',
  ),
  FreeCollectionVolume.postcards: _FreeJacketDirection(
    '여행의\n우편함',
    _FreeJacketLayout.split,
    '#EEE5D5',
    '#214B50',
    '#A83C31',
    font: 'NotoSans',
    weight: 600,
  ),
  FreeCollectionVolume.table: _FreeJacketDirection(
    '계절의\n식탁',
    _FreeJacketLayout.band,
    '#314F3F',
    '#FFF9E8',
    '#D8A96D',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.objects: _FreeJacketDirection(
    '취향\n보관함',
    _FreeJacketLayout.archive,
    '#E8EBE6',
    '#263C5C',
    '#263C5C',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.together: _FreeJacketDirection(
    '함께라서\n좋은 날',
    _FreeJacketLayout.masthead,
    '#DAD3E6',
    '#3B2C50',
    '#3B2C50',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.weekend: _FreeJacketDirection(
    '주말의\n온도',
    _FreeJacketLayout.gallery,
    '#EEE4D6',
    '#304A45',
    '#304A45',
  ),
  FreeCollectionVolume.firstYear: _FreeJacketDirection(
    '너의 첫해',
    _FreeJacketLayout.inset,
    '#EBE7F2',
    '#3C385D',
    '#3C385D',
    centered: true,
  ),
  FreeCollectionVolume.littleSteps: _FreeJacketDirection(
    '작은 걸음의\n기록',
    _FreeJacketLayout.archive,
    '#E0EAF0',
    '#25465A',
    '#25465A',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.babyBloom: _FreeJacketDirection(
    '너라는 봄',
    _FreeJacketLayout.gallery,
    '#F0DDE2',
    '#653D47',
    '#653D47',
    centered: true,
  ),
  FreeCollectionVolume.playroom: _FreeJacketDirection(
    '알록달록\n자라는 날',
    _FreeJacketLayout.archive,
    '#F3D86F',
    '#273D68',
    '#A83E2F',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.birthday: _FreeJacketDirection(
    '처음 맞는\n생일',
    _FreeJacketLayout.split,
    '#DDE1EF',
    '#41446E',
    '#41446E',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.homeYear: _FreeJacketDirection(
    '우리 집의\n사계절',
    _FreeJacketLayout.masthead,
    '#E4E9DF',
    '#2D4C3D',
    '#2D4C3D',
  ),
  FreeCollectionVolume.familyTable: _FreeJacketDirection(
    '한 식탁의\n이야기',
    _FreeJacketLayout.archive,
    '#EED8C8',
    '#593D33',
    '#593D33',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.friendsUs: _FreeJacketDirection(
    '우리의\n좋은 사이',
    _FreeJacketLayout.archive,
    '#E4DEF0',
    '#41375E',
    '#41375E',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.generations: _FreeJacketDirection(
    '세대를 잇는\n사진',
    _FreeJacketLayout.gallery,
    '#EBE7DE',
    '#343D37',
    '#343D37',
    centered: true,
  ),
  FreeCollectionVolume.familyOuting: _FreeJacketDirection(
    '함께 떠난\n소풍',
    _FreeJacketLayout.field,
    '#DFE8CF',
    '#30492D',
    '#965139',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.usDays: _FreeJacketDirection(
    '너와 나의\n날짜들',
    _FreeJacketLayout.archive,
    '#F1E3E3',
    '#643847',
    '#643847',
  ),
  FreeCollectionVolume.dateFilm: _FreeJacketDirection(
    '둘만의\n장면',
    _FreeJacketLayout.band,
    '#233B49',
    '#FFF5E9',
    '#D6B085',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.loveSeason: _FreeJacketDirection(
    '사랑이 머문\n계절',
    _FreeJacketLayout.inset,
    '#E1E6D5',
    '#364C39',
    '#364C39',
    centered: true,
  ),
  FreeCollectionVolume.anniversary: _FreeJacketDirection(
    '오래도록\n우리',
    _FreeJacketLayout.split,
    '#6C3445',
    '#FFF4E9',
    '#D9B392',
    centered: true,
  ),
  FreeCollectionVolume.twoTickets: _FreeJacketDirection(
    '둘이 모은\n조각',
    _FreeJacketLayout.archive,
    '#DFEBE8',
    '#285854',
    '#285854',
    font: 'NotoSans',
    weight: 600,
  ),
  FreeCollectionVolume.pawDiary: _FreeJacketDirection(
    '너의 하루를\n따라',
    _FreeJacketLayout.field,
    '#DDE8C9',
    '#304B36',
    '#304B36',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.catNap: _FreeJacketDirection(
    '낮잠의\n모양',
    _FreeJacketLayout.gallery,
    '#DDDDE9',
    '#424162',
    '#424162',
  ),
  FreeCollectionVolume.walkClub: _FreeJacketDirection(
    '산책이라는\n약속',
    _FreeJacketLayout.masthead,
    '#D4E2CA',
    '#28452E',
    '#28452E',
    font: 'NotoSans',
    weight: 800,
  ),
  FreeCollectionVolume.petHome: _FreeJacketDirection(
    '우리 집\n작은 가족',
    _FreeJacketLayout.archive,
    '#EFDCCB',
    '#70472F',
    '#70472F',
    font: 'Arita',
    weight: 800,
  ),
  FreeCollectionVolume.petPortrait: _FreeJacketDirection(
    '가장 다정한\n얼굴',
    _FreeJacketLayout.inset,
    '#DCE7E5',
    '#284A50',
    '#284A50',
    centered: true,
  ),
};

class _FreeSignatureJacket {
  _FreeSignatureJacket(this.book)
    : direction = _freeJacketDirections[book.volume]!,
      p = _Sheet(
        book.volume.id,
        book.aspect,
        0,
        _freeJacketDirections[book.volume]!.paper,
      );
  final _FreeBook book;
  final _FreeJacketDirection direction;
  final _Sheet p;
  Size get canvas => book.aspect.canvas;
  double get width => canvas.width;
  double get height => canvas.height;
  bool get wide => book.aspect == CollectionAspect.landscape;
  double get margin => wide ? 25 : 32;
  double get gap => 14;
  double get innerWidth => width - margin * 2;
  String get title =>
      !wide &&
          const {
            FreeCollectionVolume.cinema,
            FreeCollectionVolume.together,
            FreeCollectionVolume.generations,
          }.contains(book.volume)
      ? direction.title.replaceAll('\n', ' ')
      : direction.title;
  double get footerTop => height - margin - footerHeight;
  double get footerHeight {
    final place = _textHeight(book.copy.place, innerWidth, 11);
    final author = _textHeight(book.copy.byline, innerWidth * .54, 10);
    final period = _textHeight(book.copy.period, innerWidth * .42, 9.5);
    return place + 9 + math.max(author, period);
  }

  TextPainter _measure(
    String value,
    double available,
    double pixels, {
    String font = 'NotoSans',
    int weight = 400,
    double leading = 1.3,
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
    )..layout(maxWidth: math.max(1, available - 1));
  }

  double _textHeight(String value, double available, double pixels) {
    final measure = _measure(value, available, pixels);
    final result = measure.height;
    measure.dispose();
    return result;
  }

  void _type(
    String id,
    String value,
    Rect region, {
    required double pixels,
    String? font,
    int? weight,
    String? color,
    String align = 'left',
    double minimum = 8.5,
    double leading = 1.2,
    int? maxLines,
  }) {
    var size = pixels;
    final family = font ?? 'NotoSans';
    final fontWeight = weight ?? 400;
    while (true) {
      final measure = _measure(
        value,
        region.width,
        size,
        font: family,
        weight: fontWeight,
        leading: leading,
      );
      final fits =
          measure.height <= region.height - .5 &&
          (maxLines == null || measure.computeLineMetrics().length <= maxLines);
      measure.dispose();
      if (fits || size <= minimum) break;
      size = math.max(minimum, size * .96);
    }
    p.text(
      id,
      value,
      region.left / width,
      region.top / height,
      region.width / width,
      region.height / height,
      size: size / p.unit,
      font: family,
      weight: fontWeight,
      color: color ?? direction.ink,
      align: align,
      lineHeight: leading,
    );
    p.layers.last['typographyRole'] = id == 'signature_title'
        ? 'signature-title'
        : id == 'signature_place'
        ? 'body'
        : 'caption';
    p.layers.last['typographyMinFontSize'] = minimum;
  }

  double _headline(Rect bounds, {String? align, double? pixels}) {
    final lines = title.split('\n').length;
    final size = pixels ?? (wide ? 37.0 : 45.0);
    final measure = _measure(
      title,
      bounds.width,
      size,
      font: direction.font,
      weight: direction.weight,
      leading: 1.12,
    );
    final used = math.min(bounds.height, measure.height + 5);
    measure.dispose();
    _type(
      'signature_title',
      title,
      Rect.fromLTWH(bounds.left, bounds.top, bounds.width, used),
      pixels: size,
      font: direction.font,
      weight: direction.weight,
      align: align ?? (direction.centered ? 'center' : 'left'),
      minimum: wide ? 28 : 32,
      leading: 1.12,
      maxLines: lines,
    );
    return bounds.top + used;
  }

  void _photo(Rect region, {String id = 'signature_photo', String? file}) {
    final source = file ?? _freeCoverPhotos[book.volume]!;
    // Fit the actual source aspect into the window. The three square portraits
    // must keep their complete composition, just like the wider photographs.
    final ratio = switch (source) {
      'cover_cinema_dance.png' ||
      'cover_friends_evening.png' ||
      'cover_generations_home.png' => 1.0,
      '${_samplePhotoRoot}ocean_shore.jpg' => 1000 / 665,
      '${_samplePhotoRoot}city_skyline.jpg' => 1000 / 615,
      '${_samplePhotoRoot}misty_hills.jpg' => 1000 / 596,
      '${_samplePhotoRoot}artist_palette.jpg' ||
      '${_samplePhotoRoot}spring_flowers.jpg' ||
      '${_samplePhotoRoot}celebration.jpg' => 1000 / 667,
      '${_samplePhotoRoot}studio_laptop.jpg' => 1000 / 666,
      'assets/templates/soft_babybook/images/approved_stock/parent_hand.jpg' =>
        508 / 369,
      'assets/templates/soft_babybook/images/approved_stock/soft_clips.jpg' =>
        508 / 339,
      'assets/templates/jeju_travel/images/approved_stock/sunset_people.jpg' =>
        3500 / 2349,
      _ => 1.5,
    };
    final w = math.min(region.width, region.height * ratio);
    final h = w / ratio;
    final x = region.left + (region.width - w) / 2;
    final y = region.top + (region.height - h) / 2;
    p.photo(
      id,
      _freePhotoPath(source),
      x / width,
      y / height,
      w / width,
      h / height,
    );
  }

  void _box(String id, Rect r, String color) => p.box(
    id,
    r.left / width,
    r.top / height,
    r.width / width,
    r.height / height,
    color,
  );

  void _footer() {
    final placeHeight = _textHeight(book.copy.place, innerWidth, 11) + 1;
    _type(
      'signature_place',
      book.copy.place,
      Rect.fromLTWH(margin, footerTop, innerWidth, placeHeight),
      pixels: 11,
      minimum: 11,
      leading: 1.3,
    );
    final rowY = footerTop + placeHeight + 8;
    final rowHeight = height - margin - rowY + 2;
    _type(
      'signature_byline',
      book.copy.byline,
      Rect.fromLTWH(margin, rowY, innerWidth * .54, rowHeight),
      pixels: 10,
      minimum: 8.5,
      leading: 1.3,
    );
    _type(
      'signature_period',
      book.copy.period,
      Rect.fromLTWH(
        width - margin - innerWidth * .42,
        rowY,
        innerWidth * .42,
        rowHeight,
      ),
      pixels: 9.5,
      minimum: 8.5,
      leading: 1.3,
      align: 'right',
    );
  }

  void paint() {
    switch (direction.layout) {
      case _FreeJacketLayout.masthead:
        _masthead();
      case _FreeJacketLayout.gallery:
        _gallery();
      case _FreeJacketLayout.split:
        _split();
      case _FreeJacketLayout.band:
        _band();
      case _FreeJacketLayout.archive:
        _archive();
      case _FreeJacketLayout.field:
        _field();
      case _FreeJacketLayout.inset:
        _inset();
      case _FreeJacketLayout.horizon:
        _horizon();
    }
    _footer();
  }

  void _masthead() {
    if (wide) {
      _headline(Rect.fromLTWH(margin, margin + 8, 188, 132), pixels: 40);
      _photo(Rect.fromLTWH(234, margin, 241, footerTop - margin - gap));
      _box(
        'signature_rule',
        Rect.fromLTWH(margin, footerTop - 16, innerWidth, 1),
        direction.ink,
      );
    } else {
      final bottom = _headline(
        Rect.fromLTWH(margin, margin, innerWidth, 119),
        pixels: book.volume == FreeCollectionVolume.vows ? 48 : 45,
      );
      _photo(
        Rect.fromLTWH(
          margin,
          bottom + gap,
          innerWidth,
          footerTop - bottom - gap * 2,
        ),
      );
    }
  }

  void _gallery() {
    if (wide) {
      _photo(Rect.fromLTWH(margin, margin, 270, footerTop - margin - gap));
      _headline(
        Rect.fromLTWH(322, margin + 18, 153, footerTop - margin - 30),
        pixels: 37,
      );
    } else {
      final titleHeight = title.contains('\n') ? 108.0 : 59.0;
      final titleTop = footerTop - gap - titleHeight;
      _photo(
        Rect.fromLTWH(margin, margin, innerWidth, titleTop - margin - gap),
      );
      _headline(
        Rect.fromLTWH(margin, titleTop, innerWidth, titleHeight),
        pixels: title.contains('\n') ? 45 : 47,
      );
      if (book.volume == FreeCollectionVolume.walking) {
        _box(
          'signature_spine',
          Rect.fromLTWH(0, 0, 12, height),
          direction.accent,
        );
      }
    }
  }

  void _split() {
    if (wide) {
      _headline(Rect.fromLTWH(margin, margin + 10, 188, 125), pixels: 40);
      _photo(Rect.fromLTWH(234, margin, 241, footerTop - margin - gap));
    } else {
      final bottom = _headline(
        Rect.fromLTWH(margin, margin, innerWidth, 114),
        pixels: 47,
      );
      _box(
        'signature_color_edge',
        Rect.fromLTWH(0, bottom + gap, 18, footerTop - bottom - gap * 2),
        direction.accent,
      );
      _photo(
        Rect.fromLTWH(
          margin + 9,
          bottom + gap,
          innerWidth - 9,
          footerTop - bottom - gap * 2,
        ),
      );
    }
  }

  void _band() {
    if (wide) {
      _photo(Rect.fromLTWH(0, margin, 298, footerTop - margin - gap));
      _headline(Rect.fromLTWH(322, margin + 10, 153, 135), pixels: 38);
    } else {
      final bottom = _headline(
        Rect.fromLTWH(margin, margin, innerWidth, 111),
        pixels: 46,
      );
      _photo(
        Rect.fromLTWH(0, bottom + gap, width, footerTop - bottom - gap * 2),
      );
    }
  }

  void _archive() {
    final companion = _freeCoverCompanionPhotos[book.volume];
    if (wide) {
      _headline(Rect.fromLTWH(margin, margin + 8, 186, 134), pixels: 38);
      final left = 236.0;
      if (companion == null) {
        _photo(Rect.fromLTWH(left, margin, 239, footerTop - margin - gap));
      } else {
        _photo(Rect.fromLTWH(left, margin, 239, 159));
        _photo(
          Rect.fromLTWH(
            left + 128,
            margin + 130,
            111,
            math.max(74, footerTop - margin - 130 - gap),
          ),
          file: companion,
          id: 'signature_companion',
        );
      }
    } else {
      final bottom = _headline(
        Rect.fromLTWH(margin, margin, innerWidth, 112),
        pixels: 46,
      );
      final available = footerTop - bottom - gap * 2;
      if (companion == null) {
        _photo(Rect.fromLTWH(margin, bottom + gap, innerWidth, available));
      } else {
        final mainWidth = innerWidth * .74;
        final mainHeight = mainWidth / 1.5;
        final secondWidth = innerWidth * .40;
        final secondHeight = secondWidth / 1.5;
        final totalHeight = mainHeight + secondHeight * .70;
        final scale = math.min(1.0, available / totalHeight);
        final top = bottom + gap + (available - totalHeight * scale) / 2;
        _photo(
          Rect.fromLTWH(margin, top, mainWidth * scale, mainHeight * scale),
        );
        final second = Rect.fromLTWH(
          width - margin - secondWidth * scale,
          top + mainHeight * scale - secondHeight * scale * .30,
          secondWidth * scale,
          secondHeight * scale,
        );
        _box('signature_companion_mount', second.inflate(6), direction.paper);
        _photo(second, file: companion, id: 'signature_companion');
      }
    }
  }

  void _field() {
    if (wide) {
      _headline(Rect.fromLTWH(margin, margin + 8, 188, 133), pixels: 41);
      _photo(Rect.fromLTWH(236, margin, 239, footerTop - margin - gap));
      _box(
        'signature_index',
        Rect.fromLTWH(margin, footerTop - 18, 42, 4),
        direction.accent,
      );
    } else {
      _box(
        'signature_top_edge',
        Rect.fromLTWH(0, 0, width, 12),
        direction.accent,
      );
      final bottom = _headline(
        Rect.fromLTWH(margin, margin + 8, innerWidth, 117),
        pixels: 47,
      );
      _photo(
        Rect.fromLTWH(
          margin,
          bottom + gap,
          innerWidth,
          footerTop - bottom - gap * 2,
        ),
      );
    }
  }

  void _inset() {
    if (wide) {
      _headline(Rect.fromLTWH(margin, margin + 10, 188, 132), pixels: 38);
      _photo(Rect.fromLTWH(234, margin, 241, footerTop - margin - gap));
    } else {
      final bottom = _headline(
        Rect.fromLTWH(
          margin,
          margin + 8,
          innerWidth,
          title.contains('\n') ? 113 : 64,
        ),
        pixels: 44,
      );
      _photo(
        Rect.fromLTWH(
          margin + 10,
          bottom + gap,
          innerWidth - 20,
          footerTop - bottom - gap * 2,
        ),
      );
    }
  }

  void _horizon() {
    // The sea has no faces to crop. This is the collection's sole full-bleed
    // photograph, with an opaque title stock that survives any replacement.
    p.photo(
      'signature_photo',
      _freePhotoPath(_freeCoverPhotos[book.volume]!),
      0,
      0,
      1,
      1,
    );
    final titleWidth = wide ? 211.0 : 224.0;
    final titleHeight = wide ? 145.0 : 157.0;
    _box(
      'signature_title_stock',
      Rect.fromLTWH(margin - 12, margin - 9, titleWidth + 24, titleHeight + 16),
      direction.paper,
    );
    _headline(
      Rect.fromLTWH(margin, margin, titleWidth, titleHeight),
      pixels: wide ? 45 : 51,
    );
    _box(
      'signature_information_stock',
      Rect.fromLTWH(0, footerTop - 17, width, height - footerTop + 17),
      direction.paper,
    );
  }
}
