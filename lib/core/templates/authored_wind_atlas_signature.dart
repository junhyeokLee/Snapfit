part of 'authored_collections.dart';

/// The selected opening, sea and archive studies share an editorial grid.
/// Photographs and type remain independent editable layers.
class _WindAtlasSignaturePage extends _Sheet {
  _WindAtlasSignaturePage(
    CollectionAspect aspect,
    int index, {
    bool dark = false,
  }) : super(
         windAtlasId,
         aspect,
         index,
         dark ? signatureInk : signaturePaper,
         ink: dark ? signaturePaper : signatureInk,
       );

  static const signaturePaper = '#F5F2E9';
  static const signatureInk = '#243A34';
  static const accent = '#8B4534';
  static const ruleColor = '#B9B7A9';
  static const harbor = '${_editorial}travel_harbor.png';
  static const coast = '${_editorial}travel_coast.png';
  static const street = '${_editorial}travel_street.png';

  bool get portrait => aspect == CollectionAspect.portrait;
  bool get square => aspect == CollectionAspect.square;

  /// Fit the supplied editable copy with the bundled font, retaining a readable
  /// floor. Longer copy is left intact for explicit preflight and editing.
  void type(
    String id,
    String value,
    Rect rect, {
    double size = .030,
    String font = 'NotoSans',
    String? color,
    int weight = 400,
    double leading = 1.45,
    double minPixels = 11,
    String align = 'left',
    int? maxLines,
    bool signature = false,
  }) {
    final available = Size(
      rect.width * aspect.canvas.width,
      rect.height * aspect.canvas.height,
    );
    var pixels = math.max(unit * size, minPixels);
    for (var attempt = 0; attempt < 60; attempt++) {
      final style = TextStyle(
        fontFamily: font,
        fontSize: pixels,
        fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
        height: leading,
        letterSpacing: 0,
      );
      final measure = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      )..layout(maxWidth: math.max(1, available.width - 1));
      final metrics = measure.computeLineMetrics();
      final fits =
          measure.height <= available.height - .5 &&
          (maxLines == null || metrics.length <= maxLines) &&
          metrics.every((line) => line.width <= available.width);
      measure.dispose();
      if (fits || pixels <= minPixels) break;
      pixels = math.max(minPixels, pixels * .96);
    }
    text(
      id,
      value,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
      size: pixels / unit,
      font: font,
      color: color ?? ink,
      weight: weight,
      lineHeight: leading,
      align: align,
    );
    layers.last['typographyRole'] = signature
        ? 'signature-title'
        : minPixels >= 11
        ? 'body'
        : 'caption';
    layers.last['typographyMinFontSize'] = minPixels;
    if (signature) {
      layers.last['typographyStyle'] = 'wind-atlas-editorial';
      if (maxLines != null) layers.last['typographyMaxLines'] = maxLines;
    }
  }

  void heading(String id, String value, Rect rect, {double size = .082}) =>
      type(
        id,
        value,
        rect,
        font: 'Eulyoo',
        size: size,
        leading: 1.22,
        maxLines: value.split('\n').length,
        signature: true,
      );

  void label(String id, String value, Rect rect, {String? color}) => type(
    id,
    value,
    rect,
    size: .023,
    minPixels: 8.5,
    color: color,
    leading: 1.35,
  );

  /// Korean prose wraps at spaces first; explicit paragraph breaks are kept.
  /// Only exceptionally long, unbroken words fall back to native character wrap.
  String _journalLines(String value, double pixels, double maxWidth) {
    final style = TextStyle(
      fontFamily: 'NotoSans',
      fontSize: pixels,
      fontWeight: FontWeight.w400,
      height: 1.48,
      letterSpacing: 0,
    );
    double width(String text) {
      final measure = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final result = measure.width;
      measure.dispose();
      return result;
    }

    return value
        .split('\n')
        .map((paragraph) {
          final trimmed = paragraph.trim();
          if (trimmed.isEmpty) return '';
          final lines = <List<String>>[];
          var line = <String>[];
          for (final word in trimmed.split(RegExp(r'\s+'))) {
            if (line.isNotEmpty &&
                width([...line, word].join(' ')) > maxWidth) {
              lines.add(line);
              line = <String>[];
            }
            line.add(word);
          }
          if (line.isNotEmpty) lines.add(line);
          if (lines.length >= 2) {
            final last = lines.last;
            final letters = last
                .join()
                .replaceAll(RegExp(r'[^\w가-힣一-龥ぁ-ゔァ-ヴー]'), '')
                .runes
                .length;
            // Rebalance a tiny final line instead of leaving a final particle or
            // short verb on its own. Do not split or reorder the source words.
            if (letters <= 2 || (last.length == 1 && letters <= 4)) {
              final previous = lines[lines.length - 2];
              if (previous.length > 1) {
                final moved = previous.last;
                if (width([moved, ...last].join(' ')) <= maxWidth) {
                  previous.removeLast();
                  last.insert(0, moved);
                }
              }
            }
          }
          return lines.map((words) => words.join(' ')).join('\n');
        })
        .join('\n');
  }

  void journal(String id, String value, Rect rect) {
    const minPixels = 11.0;
    final available = Size(
      rect.width * aspect.canvas.width,
      rect.height * aspect.canvas.height,
    );
    final maxWidth = math.max(1.0, available.width - 1);
    var pixels = math.max(unit * .030, minPixels);
    var wrapped = value;
    for (var attempt = 0; attempt < 60; attempt++) {
      // A smaller fitted font changes line endings, so wrap afresh at each size.
      wrapped = _journalLines(value, pixels, maxWidth);
      final style = TextStyle(
        fontFamily: 'NotoSans',
        fontSize: pixels,
        fontWeight: FontWeight.w400,
        height: 1.48,
        letterSpacing: 0,
      );
      final measure = TextPainter(
        text: TextSpan(text: wrapped, style: style),
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
      )..layout(maxWidth: maxWidth);
      final fits = measure.height <= available.height - .5;
      measure.dispose();
      if (fits || pixels <= minPixels) break;
      pixels = math.max(minPixels, pixels * .96);
    }
    type(id, wrapped, rect, size: pixels / unit, leading: 1.48);
    layers.last['editorialSourceText'] = value;
    layers.last['typographyStyle'] = 'wind-atlas-journal-word-wrap';
  }

  void rule(String id, double x, double y, double w, {String? color}) =>
      box(id, x, y, w, .0012, color ?? ruleColor);

  /// Preserve a landscape photograph rather than filling every page with an
  /// arbitrary crop. All image windows stay outside the existing binding zone.
  Rect picture(
    String id,
    String source,
    Rect bounds, {
    Alignment alignment = Alignment.topLeft,
  }) {
    const imageRatio = 3 / 2;
    final width = math.min(bounds.width, bounds.height * imageRatio / ratio);
    final height = width * ratio / imageRatio;
    final rect = Rect.fromLTWH(
      bounds.left + (bounds.width - width) * (alignment.x + 1) / 2,
      bounds.top + (bounds.height - height) * (alignment.y + 1) / 2,
      width,
      height,
    );
    photo(id, source, rect.left, rect.top, rect.width, rect.height);
    return rect;
  }

  void folios(int page) {
    final left = page.isOdd;
    type(
      'folio',
      page.toString().padLeft(2, '0'),
      Rect.fromLTWH(left ? .08 : .82, .946, .10, .038),
      size: .023,
      minPixels: 8.5,
      leading: 1.35,
      align: left ? 'left' : 'right',
    );
    type(
      'running_head',
      '바람의 기록',
      Rect.fromLTWH(left ? .57 : .12, .946, .30, .038),
      size: .020,
      minPixels: 8.5,
      leading: 1.35,
      align: left ? 'right' : 'left',
    );
  }

  void cover(EditorialCopy copy) {
    label(
      'edition',
      '여행 수집실 · 사진과 문장',
      Rect.fromLTWH(.08, square ? .035 : .055, .84, square ? .035 : .05),
      color: accent,
    );
    if (square) {
      label(
        'cover_period',
        copy.period,
        const Rect.fromLTWH(.08, .082, .84, .032),
      );
    }
    heading(
      'heading',
      wide ? '바람을\n수집한\n여행' : '바람을\n수집한 여행',
      wide
          ? const Rect.fromLTWH(.08, .205, .35, .46)
          : square
          ? const Rect.fromLTWH(.08, .125, .84, .17)
          : const Rect.fromLTWH(.08, .145, .84, .22),
      size: square ? .069 : .111,
    );
    picture(
      'cover_photo',
      harbor,
      wide
          ? const Rect.fromLTWH(.48, .235, .44, .50)
          : portrait
          ? const Rect.fromLTWH(.08, .405, .84, .42)
          : const Rect.fromLTWH(.08, .315, .84, .56),
    );
    rule(
      'imprint_rule',
      .08,
      square
          ? .89
          : wide
          ? .80
          : .84,
      .84,
    );
    final footerY = square
        ? .90
        : wide
        ? .825
        : .86;
    type(
      'cover_place',
      copy.place,
      Rect.fromLTWH(
        .08,
        footerY,
        .49,
        square
            ? .061
            : wide
            ? .09
            : .085,
      ),
      size: .027,
      leading: 1.35,
      maxLines: 2,
    );
    type(
      'cover_byline',
      copy.byline,
      Rect.fromLTWH(.63, footerY, .29, square ? .061 : .075),
      size: .024,
      leading: 1.35,
      minPixels: 8.5,
      maxLines: 2,
      align: 'right',
    );
    if (!square) {
      label(
        'cover_period',
        copy.period,
        Rect.fromLTWH(.08, wide ? .925 : .945, .84, .035),
      );
    }
  }

  void arrivalChapter(EditorialCopy copy) {
    label(
      'arrival_section',
      '첫 번째 장 / 도착의 감각',
      const Rect.fromLTWH(.08, .065, .80, .05),
      color: accent,
    );
    rule('arrival_rule', .08, .135, .80);
    heading(
      'heading',
      '마침내,\n여기.',
      wide
          ? const Rect.fromLTWH(.08, .23, .46, .39)
          : const Rect.fromLTWH(.08, .225, .80, .30),
      size: .138,
    );
    picture(
      'arrival_detail',
      street,
      wide
          ? const Rect.fromLTWH(.61, .25, .27, .30)
          : Rect.fromLTWH(.08, .66, .30, portrait ? .16 : .20),
    );
    final x = wide ? .08 : .45;
    final y = wide ? .72 : .665;
    label('ticket_label', '도착한 곳', Rect.fromLTWH(x, y, wide ? .20 : .43, .05));
    type(
      'ticket_place',
      copy.place,
      Rect.fromLTWH(
        wide ? .34 : .45,
        wide ? y : .735,
        wide ? .54 : .43,
        wide ? .14 : .16,
      ),
      size: .033,
      maxLines: 3,
    );
  }

  void arrivalPhoto(EditorialCopy copy) {
    label(
      'arrival_imprint',
      '도착해서 처음 남긴 장면',
      const Rect.fromLTWH(.12, .065, .80, .05),
      color: accent,
    );
    if (wide) {
      heading(
        'arrival_word',
        '첫인상',
        const Rect.fromLTWH(.12, .225, .18, .12),
        size: .060,
      );
      type(
        'arrival_note',
        '우리는\n잠깐 말을 멈추고,\n바다를\n오래 바라보았다.',
        const Rect.fromLTWH(.12, .45, .20, .35),
        size: .030,
      );
      final photo = picture(
        'arrival_full',
        harbor,
        const Rect.fromLTWH(.36, .20, .56, .54),
      );
      label(
        'arrival_location',
        copy.place,
        Rect.fromLTWH(.36, photo.bottom + .045, .56, .12),
      );
    } else {
      final photo = picture(
        'arrival_full',
        harbor,
        Rect.fromLTWH(.12, .185, .80, portrait ? .46 : .54),
      );
      final y = photo.bottom + (portrait ? .07 : .055);
      heading(
        'arrival_word',
        '첫인상',
        Rect.fromLTWH(.12, y, .28, .11),
        size: .061,
      );
      type(
        'arrival_note',
        '우리는 잠깐 말을 멈추고\n오래 바다를 바라보았다.',
        Rect.fromLTWH(.49, y, .43, portrait ? .15 : .17),
        size: .030,
      );
    }
  }

  void seaHorizon() {
    label(
      'sea_section',
      '바다의 두 가지 온도',
      const Rect.fromLTWH(.08, .065, .80, .05),
      color: accent,
    );
    rule('sea_rule', .08, .135, .80);
    if (wide) {
      heading(
        'heading',
        '바다의\n두 가지\n온도',
        const Rect.fromLTWH(.08, .235, .18, .36),
        size: .068,
      );
      final photo = picture(
        'sea_horizon',
        coast,
        const Rect.fromLTWH(.31, .235, .57, .51),
      );
      label(
        'caption_sea',
        '멀리서 보면 고요하고,',
        Rect.fromLTWH(.31, photo.bottom + .055, .57, .07),
      );
    } else {
      heading(
        'heading',
        '바다의\n두 가지 온도',
        const Rect.fromLTWH(.08, .18, .80, .18),
        size: .079,
      );
      final photo = picture(
        'sea_horizon',
        coast,
        Rect.fromLTWH(.08, .42, .80, portrait ? .36 : .41),
      );
      label(
        'caption_sea',
        '멀리서 보면 고요하고,',
        Rect.fromLTWH(.08, photo.bottom + .045, .80, .06),
      );
    }
  }

  void seaClose() {
    label(
      'sea_detail_label',
      '가까이에서 발견한 바다',
      const Rect.fromLTWH(.12, .065, .80, .05),
    );
    picture(
      'sea_close',
      harbor,
      wide
          ? const Rect.fromLTWH(.12, .21, .36, .36)
          : Rect.fromLTWH(.12, .205, .44, portrait ? .23 : .30),
    );
    heading(
      'heading',
      '가까이서는\n반짝이던.',
      wide
          ? const Rect.fromLTWH(.56, .255, .36, .31)
          : const Rect.fromLTWH(.12, .565, .80, .20),
      size: .087,
    );
    type(
      'sea_detail_note',
      '파도 가까이 서면\n같은 바다도 다르게 보였다.',
      wide
          ? const Rect.fromLTWH(.56, .66, .36, .18)
          : const Rect.fromLTWH(.12, .815, .80, .105),
      size: .028,
    );
  }

  void ephemeraPocket(EditorialCopy copy) {
    label(
      'chapter_name',
      '주머니 속 수집품',
      const Rect.fromLTWH(.08, .065, .80, .05),
      color: accent,
    );
    rule('chapter_rule', .08, .135, .80);
    heading(
      'heading',
      '주머니에서 꺼낸 하루',
      const Rect.fromLTWH(.08, .185, .80, .105),
      size: .060,
    );
    picture(
      'saved_postcard',
      coast,
      wide
          ? const Rect.fromLTWH(.08, .33, .48, .43)
          : Rect.fromLTWH(.08, .33, .54, portrait ? .29 : .36),
    );
    picture(
      'kept_journey',
      '${_editorial}journey_train.png',
      wide
          ? const Rect.fromLTWH(.64, .33, .24, .23)
          : const Rect.fromLTWH(.70, .33, .18, .13),
    );
    label(
      'ticket_title',
      '머물렀던 곳',
      wide
          ? const Rect.fromLTWH(.64, .58, .24, .05)
          : const Rect.fromLTWH(.70, .50, .18, .05),
    );
    type(
      'ticket_destination',
      _journalLines(
        copy.place,
        math.max(unit * .023, 8.5),
        (wide ? .24 : .18) * aspect.canvas.width - 1,
      ),
      wide
          ? const Rect.fromLTWH(.64, .65, .24, .13)
          : const Rect.fromLTWH(.70, .565, .18, .17),
      size: .023,
      minPixels: 8.5,
      leading: 1.35,
      maxLines: 4,
    );
    final entries = [
      ('01', '돌아오는 기차표', '차창 밖 바다까지 함께'),
      ('02', '카페의 작은 영수증', '오래 앉아 있던 오후'),
      ('03', '보내지 못한 엽서', '쓸 말이 너무 많아서'),
    ];
    for (final entry in entries.indexed) {
      final i = entry.$1;
      final value = entry.$2;
      if (wide) {
        final x = .08 + i * .28;
        label(
          'archive_n_$i',
          value.$1,
          Rect.fromLTWH(x, .81, .24, .035),
          color: accent,
        );
        type(
          'archive_title_$i',
          value.$2,
          Rect.fromLTWH(x, .855, .24, .055),
          size: .029,
          leading: 1.35,
        );
      } else {
        final y = .755 + i * .055;
        label(
          'archive_n_$i',
          value.$1,
          Rect.fromLTWH(.08, y, .065, .04),
          color: accent,
        );
        type(
          'archive_title_$i',
          value.$2,
          Rect.fromLTWH(.18, y, .42, .04),
          size: .024,
          minPixels: 11,
          leading: 1.35,
        );
        label('archive_note_$i', value.$3, Rect.fromLTWH(.64, y, .24, .04));
      }
    }
  }

  void ephemeraIndex(EditorialCopy copy) {
    label(
      'archive_imprint',
      '수집품과 하루 기록',
      const Rect.fromLTWH(.12, .065, .80, .05),
      color: accent,
    );
    rule('archive_journal_rule', .12, .135, .80);
    heading(
      'heading',
      '작은 것들의\n긴 기억',
      const Rect.fromLTWH(.12, .18, .80, .165),
      size: .077,
    );
    journal(
      'archive_journal',
      copy.note,
      const Rect.fromLTWH(.12, .375, .80, .51),
    );
    type(
      'archive_signature',
      copy.byline,
      const Rect.fromLTWH(.12, .90, .80, .035),
      size: .023,
      minPixels: 8.5,
      leading: 1.35,
      align: 'right',
    );
  }
}
