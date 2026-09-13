part of 'authored_collections.dart';

/// Authored sale candidates. Page count never grants approval or publishes a book.
enum PremiumVolume {
  wedding('vow-keepsake', 32, HeirloomStudy.wedding),
  travel('luminous-edition', 36, null),
  daily('daily-cabinet', 24, HeirloomStudy.daily),
  baby('first-year-keepsake', 36, HeirloomStudy.baby),
  family('table-stories', 32, HeirloomStudy.family),
  couple('two-tickets', 32, HeirloomStudy.couple),
  pet('walk-and-nap', 24, HeirloomStudy.pet);

  const PremiumVolume(this.id, this.extendedPages, this.study);
  final String id;
  final int extendedPages;
  final HeirloomStudy? study;
  static const minimumPages = 24;
  String get title => study?.title ?? luminousEditionTitle;
  String get category => study?.category ?? '여행';
  String get ink => study?.ink ?? '#294C4C';
  String get font => study?.font ?? 'Eulyoo';
  List<int> get pageCounts => [24, if (extendedPages != 24) extendedPages];
  static PremiumVolume byId(String id) => values.singleWhere((v) => v.id == id);

  Map<String, dynamic> document(
    CollectionAspect aspect, {
    int? innerPages,
    EditorialCopy? copy,
    LuminousCopy travelCopy = const LuminousCopy(),
  }) {
    final count = innerPages ?? extendedPages;
    if (!pageCounts.contains(count)) {
      throw ArgumentError.value(
        count,
        'innerPages',
        'Unsupported authored edition',
      );
    }
    final base = this == travel
        ? buildLuminousEdition(aspect, copy: travelCopy)
        : this == wedding
        ? buildVowKeepsakeEdition(aspect, copy: copy)
        : study!.document(aspect, copy: copy);
    final author = _VolumeAuthor(
      this,
      aspect,
      count > minimumPages,
      copy ??
          study?.defaultCopy ??
          EditorialCopy(
            place: title,
            period: travelCopy.date,
            byline: travelCopy.names,
            note: '여행에서 가져온 장면들을 한 권에 모았다.',
          ),
    );
    switch (this) {
      case wedding:
        _volumeWedding(author);
      case travel:
        _volumeTravel(author);
      case daily:
        _volumeDaily(author);
      case baby:
        _volumeBaby(author);
      case family:
        _volumeFamily(author);
      case couple:
        _volumeCouple(author);
      case pet:
        _volumePet(author);
    }
    final original = (base['pages'] as List).cast<Map<String, dynamic>>();
    final originalChapters = (base['chapters'] as List)
        .cast<Map<String, dynamic>>();
    final pages = <Map<String, dynamic>>[];
    final chapters = <Map<String, dynamic>>[];
    final baselineMap = <int>[0];
    void append(
      String title,
      List<Map<String, dynamic>> spread, {
      bool baseline = false,
    }) {
      final start = pages.length + 1;
      for (final page in spread) {
        final index = pages.length + 1;
        if (baseline) baselineMap.add(index);
        pages.add({
          ...page,
          'name': '$title $index',
          'side': index.isOdd ? 'left' : 'right',
          'spreadIndex': (index + 1) ~/ 2,
          'layers': [
            for (final layer in page['layers'] as List)
              if ((layer['id'] as String).endsWith('_folio'))
                {
                  ...Map<String, dynamic>.from(layer),
                  'text': index.toString().padLeft(2, '0'),
                }
              else
                Map<String, dynamic>.from(layer),
          ],
        });
      }
      chapters.add({'title': title, 'from': start, 'to': pages.length});
    }

    for (var i = 0; i < originalChapters.length; i++) {
      append(
        originalChapters[i]['title'] as String,
        original.sublist(i * 2, i * 2 + 2),
        baseline: true,
      );
      for (final spread in author.spreads.where((s) => s.after == i + 1)) {
        append(spread.title, spread.pages);
      }
    }
    if (pages.length != count)
      throw StateError('$id: ${pages.length} != $count');
    return {
      ...base,
      'version': 3,
      'editionId': '$id-$count',
      'source': 'snapfit-authored-volume',
      'innerPageCount': count,
      'availableInnerPageCounts': pageCounts,
      'baselinePageMap': baselineMap,
      'approvedBaselinePageMap': [
        for (final index
            in (base['approvedBaselinePageMap'] as List?) ??
                List<int>.generate(original.length + 1, (i) => i))
          baselineMap[index as int],
      ],
      'baselineEdition': this == wedding ? 'vow-keepsake-20' : '$id-8',
      'chapters': chapters,
      'pages': pages,
      'approvedAt': '2026-09-09',
      'approvedBaselineAt': '2026-09-09',
      'approvalStatus': 'approved-volume-design',
      'approvalScope': 'basic-and-extended-designs-only',
      'publicationStatus': 'production-review',
      'studyScope': 'complete-authored-volume',
      'accessTier': 'premium',
      'intendedTier': 'premium',
      'catalogPublishable': false,
      'releaseGates': {
        'baselineDesign': 'approved',
        'extensionDesign': 'approved',
        'printProof': 'pending',
        'distributionRights': 'pending',
        'price': 'launch-price-set-sale-held',
        'commerceIntegration': 'not-published',
      },
    };
  }
}

class _VolumeSpread {
  const _VolumeSpread(this.title, this.after, this.pages);
  final String title;
  final int after;
  final List<Map<String, dynamic>> pages;
}

/// Layer tools only: placement and content are independently authored per page.
class _VolumeAuthor {
  _VolumeAuthor(this.volume, this.aspect, this.extended, this.copy);
  final PremiumVolume volume;
  final CollectionAspect aspect;
  final bool extended;
  final EditorialCopy copy;
  final spreads = <_VolumeSpread>[];
  final _pages = <Map<String, dynamic>>[];
  late _Sheet p;
  late String role;
  double get ratio => aspect.canvas.aspectRatio;
  bool get wide => aspect == CollectionAspect.landscape;
  void spread(
    String title,
    int after,
    void Function() paint, {
    bool extra = false,
    bool reverse = false,
  }) {
    if (extra && !extended) return;
    _pages.clear();
    paint();
    if (_pages.length != 2) throw StateError('$title needs two authored pages');
    spreads.add(
      _VolumeSpread(title, after, List.of(reverse ? _pages.reversed : _pages)),
    );
  }

  void reversedSpread(
    String title,
    int after,
    void Function() paint, {
    bool extra = false,
  }) => spread(title, after, paint, extra: extra, reverse: true);

  void page(String name, String color) {
    role = name;
    p = _Sheet('${volume.id}_volume_$name', aspect, 0, color, ink: volume.ink);
  }

  void end() {
    p.text('folio', '00', .88, .938, .06, .038, size: .017, color: volume.ink);
    text(copy.byline, .07, .938, .63, .038, size: .017, font: 'NotoSans');
    _pages.add({...p.json, 'role': '${volume.id}-$role'});
  }

  void text(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .028,
    String? font,
    String? color,
    double leading = 1.5,
  }) => p.text(
    'text_${p.layers.length}',
    value,
    x,
    y,
    w,
    h,
    size: size,
    font: font ?? volume.font,
    color: color ?? volume.ink,
    lineHeight: leading,
  );
  void stock(
    double x,
    double y,
    double w,
    double h,
    String color, {
    double turn = 0,
  }) {
    p.box('stock_${p.layers.length}', x, y, w, h, color);
    p.layers.last['rotation'] = turn;
  }

  void paperText(
    Rect paper,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .028,
    double leading = 1.5,
  }) => text(
    value,
    paper.left + paper.width * x,
    paper.top + paper.height * y,
    paper.width * w,
    paper.height * h,
    size: size,
    leading: leading,
  );

  Rect paper(
    String key,
    double x,
    double y,
    double w,
    double h, {
    double turn = 0,
  }) {
    final r = studioDecorationById(key)!.aspectRatio;
    final width = math.min(w, h * r / ratio);
    final height = width * ratio / r;
    p.material(
      'material_${p.layers.length}',
      key,
      x,
      y,
      width,
      h: height,
      rotation: turn,
    );
    return Rect.fromLTWH(x, y, width, height);
  }

  Rect photo(
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
    bool natural = true,
    bool mounted = false,
    double turn = 0,
  }) {
    final width = natural ? math.min(w, h * 1.5 / ratio) : w;
    final height = natural ? width * ratio / 1.5 : h;
    final r = Rect.fromLTWH(x + (w - width) / 2, y, width, height);
    if (mounted)
      stock(
        r.left - .012,
        r.top - .012 * ratio,
        r.width + .024,
        r.height + .024 * ratio,
        '#FAFAF5',
        turn: turn,
      );
    p.photo(
      'photo_${p.layers.length}',
      '$_editorial$file.png',
      r.left,
      r.top,
      r.width,
      r.height,
      shape: frame,
      rotation: turn,
    );
    return r;
  }

  void heading(
    String value, {
    double x = .075,
    double y = .06,
    double w = .85,
    double size = .043,
  }) => text(value, x, y, w, .092, size: size, leading: 1.15);
  void caption(
    String value, {
    double x = .09,
    double y = .864,
    double w = .82,
  }) => text(value, x, y, w, .055, size: .025, leading: 1.3);
  void card(
    String material,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .026,
    double turn = 0,
  }) {
    final r = paper(material, x, y, w, h, turn: turn);
    final dx = r.width * .10, dy = r.height * .18;
    text(
      value,
      r.left + dx,
      r.top + dy,
      r.width - dx * 2,
      r.height - dy * 1.5,
      size: size,
    );
  }
}
