part of 'authored_collections.dart';

/// Fresh compositions and photographs belong only to this edition. Keeping
/// these separate also freezes the already-published story books' geometry.
void _exclusiveStoryCover(_StoryPage p) {
  final e = p.edition;
  final wide = p.wide;
  void english(Rect r, double size, {String? color, String align = 'left'}) =>
      p.type(
        e.englishTitle,
        r,
        size: size,
        font: 'Cormorant Garamond',
        color: color,
        align: align,
        role: 'headline',
      );
  switch (e.coverStyle) {
    case 5: // Cinematic photograph with a small, quiet mint spine marker.
      p.image(0, const Rect.fromLTWH(0, 0, 1, 1));
      p._add(p.uid, 'decoration', 0, .53, 1, .47, {
        'style': 'photoCoverShadeBottom',
      });
      p.line(const Rect.fromLTWH(.065, .07, .008, .095));
      p.type(
        'A PERSONAL RECORD',
        const Rect.fromLTWH(.095, .078, .62, .03),
        size: .017,
        font: 'Poppins',
        color: '#FFFFFF',
      );
      english(
        const Rect.fromLTWH(.065, .60, .87, .23),
        wide ? .10 : .13,
        color: '#FFFFFF',
      );
      p.type(
        e.title,
        const Rect.fromLTWH(.07, .875, .82, .05),
        size: .028,
        color: '#FFFFFF',
      );
    case 6: // A photographic window and a generous uncoated-paper title.
      if (wide) {
        p.image(0, const Rect.fromLTWH(.38, .055, .565, .89));
        english(const Rect.fromLTWH(.055, .19, .29, .36), .105);
        p.type(e.title, const Rect.fromLTWH(.06, .69, .28, .12), size: .028);
        p.line(const Rect.fromLTWH(.06, .865, .12, .004));
      } else {
        p.image(0, const Rect.fromLTWH(.055, .055, .89, .59));
        english(const Rect.fromLTWH(.075, .69, .85, .17), .105);
        p.type(e.title, const Rect.fromLTWH(.08, .89, .84, .047), size: .028);
        p.line(const Rect.fromLTWH(.08, .955, .12, .003));
      }
    case 7: // Gallery diptych, a small detail beside the broad hero scene.
      p.box(p.uid, 0, 0, 1, 1, '#E4F4F3');
      english(const Rect.fromLTWH(.07, .055, .86, .255), wide ? .10 : .125);
      p.image(0, const Rect.fromLTWH(.07, .35, .59, .47));
      p.image(1, const Rect.fromLTWH(.70, .53, .23, .29));
      p.type(
        '01 / IN THE MAKING',
        const Rect.fromLTWH(.70, .365, .23, .11),
        size: .016,
        font: 'Poppins',
        color: '#207A79',
      );
      p.type(e.title, const Rect.fromLTWH(.075, .88, .84, .055), size: .030);
    case 8: // Tall print floated into a broad editorial margin.
      p.image(0, const Rect.fromLTWH(.055, .055, .65, .89));
      p.box(p.uid, .56, .59, .40, .32, '#F7F5F2');
      english(const Rect.fromLTWH(.60, .63, .34, .19), wide ? .074 : .083);
      p.type(e.title, const Rect.fromLTWH(.60, .835, .34, .06), size: .021);
      p.line(const Rect.fromLTWH(.76, .12, .15, .004));
      p.type(
        'COLLECTED\nMOMENTS',
        const Rect.fromLTWH(.76, .16, .16, .13),
        size: .016,
        font: 'Poppins',
        color: e.accent,
      );
    default: // Dark cloth-like border, a luminous print and small colophon.
      p.box(p.uid, 0, 0, 1, 1, e.ink);
      p.image(0, const Rect.fromLTWH(.045, .045, .91, .66));
      english(
        const Rect.fromLTWH(.075, .735, .85, .15),
        wide ? .078 : .09,
        color: '#F7F5F2',
      );
      p.type(
        e.title,
        const Rect.fromLTWH(.08, .90, .78, .043),
        size: .026,
        color: '#F7F5F2',
      );
      p.line(const Rect.fromLTWH(.88, .91, .035, .004));
  }
}

List<_StoryPage> _exclusiveStorySpread(
  StoryEdition e,
  CollectionAspect aspect,
  int i,
) {
  final layout = _storySequence(e)[i];
  final left = _StoryPage(
    e,
    aspect,
    i * 2 + 1,
    layout == 6 || layout == 8 ? e.tint : '#F7F5F2',
  );
  final right = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    layout == 2 || layout == 10 ? e.tint : '#F7F5F2',
  );
  // Only these five exclusive sources are used, including every interior.
  final photo = i % 5;
  final title = e.chapters[i];
  final shift =
      (e.category == '동아리' ? e.coverStyle % 5 : e.coverStyle - 5) * .009;
  void note(_StoryPage p, Rect r) =>
      p.type(e.notes[i], r, size: .026, role: 'body');
  void label(_StoryPage p, {double y = .07}) {
    p.type(
      '${(i + 1).toString().padLeft(2, '0')} / ${e.category}',
      Rect.fromLTWH(.075, y, .85, .035),
      size: .017,
      font: e.category == '동아리' ? 'NotoSans' : 'Poppins',
      color: e.accent,
    );
    p.heading(title, Rect.fromLTWH(.075, y + .07, .85, .11), size: .048);
  }

  switch (layout) {
    case 0: // Opener / a generous unbroken photograph.
      label(left, y: .16);
      left.line(const Rect.fromLTWH(.08, .47, .13, .004));
      note(left, const Rect.fromLTWH(.08, .59, .78, .18));
      right.image(0, const Rect.fromLTWH(0, .055, .945, .83));
    case 1: // Wide movement paired with a quiet tactile detail.
      left.image(photo, const Rect.fromLTWH(0, .15, 1, .57));
      left.heading(title, const Rect.fromLTWH(.08, .78, .84, .10), size: .040);
      _storyMountedPhoto(
        right,
        photo + 1,
        Rect.fromLTWH(.16 + shift, .13, .66 - shift, .44),
      );
      if (e.photoFrames.isNotEmpty)
        right.piece(e.motifId, const Rect.fromLTWH(.79, .595, .10, .055));
      note(right, const Rect.fromLTWH(.16, .68, .70, .18));
    case 2: // Portrait and small observational inset.
      left.image(photo, const Rect.fromLTWH(.08, .10, .66, .71));
      left.image(photo + 1, const Rect.fromLTWH(.66, .57, .27, .28));
      label(right, y: .18);
      note(right, const Rect.fromLTWH(.08, .51, .79, .21));
      right.piece(e.motifId, const Rect.fromLTWH(.72, .76, .15, .13));
    case 3: // Airy contact sheet using four different sources.
      label(left);
      for (var n = 0; n < 4; n++) {
        left.image(
          photo + n,
          Rect.fromLTWH(.075 + n % 2 * .44, .31 + n ~/ 2 * .245, .40, .205),
        );
      }
      right.image(photo + 4, const Rect.fromLTWH(.12, .12, .76, .56));
      note(right, const Rect.fromLTWH(.12, .76, .75, .13));
    case 4: // Photo / actual editable title composition, no bitmap type.
      left.image(photo, const Rect.fromLTWH(0, 0, 1, .88));
      final art = studioWordArts.singleWhere((a) => a.id == e.wordArtId);
      for (final layer in art.buildLayers(aspect.canvas)) {
        final raw = LayerExportMapper.toJson(layer, canvasSize: aspect.canvas);
        raw['type'] = layer.type.name;
        raw['id'] =
            '${e.id}_${aspect.name}_${right.index}_word_${right.layers.length}';
        raw['z'] = right.layers.length;
        raw['wordArtId'] = e.wordArtId;
        raw['templateContent'] = true;
        right.layers.add(raw);
      }
      right.type(title, const Rect.fromLTWH(.10, .12, .80, .08), size: .030);
      note(right, const Rect.fromLTWH(.10, .78, .80, .12));
    case 5: // Narrow writing margin and a large photo; companion full scene.
      left.type(title, const Rect.fromLTWH(.08, .10, .84, .08), size: .033);
      left.image(photo, Rect.fromLTWH(.25 + shift, .25, .67 - shift, .59));
      left.line(const Rect.fromLTWH(.08, .27, .006, .31));
      right.image(photo + 1, const Rect.fromLTWH(.08, .10, .84, .45));
      note(right, const Rect.fromLTWH(.10, .69, .77, .19));
    case 6: // Calm two-frame rhythm with one intentionally large image.
      left.image(photo, const Rect.fromLTWH(.08, .08, .84, .65));
      left.heading(title, const Rect.fromLTWH(.08, .79, .83, .10), size: .039);
      _storyMountedPhoto(
        right,
        photo + 1,
        const Rect.fromLTWH(.08, .12, .52, .37),
      );
      _storyMountedPhoto(
        right,
        photo + 2,
        const Rect.fromLTWH(.42, .54, .50, .30),
        mount: 1,
      );
    case 7: // Paper backing is physically subtle and stays below the photo.
      if (e.photoFrames.isEmpty) {
        left.piece(e.paperId, const Rect.fromLTWH(.05, .12, .90, .68));
        left.image(photo, const Rect.fromLTWH(.13, .23, .70, .37));
        left.type(title, const Rect.fromLTWH(.15, .63, .68, .06), size: .027);
      } else {
        _storyStationeryPhoto(
          left,
          photo,
          const Rect.fromLTWH(.05, .12, .90, .68),
          title,
        );
      }
      right.image(photo + 1, const Rect.fromLTWH(.10, .10, .80, .46));
      right.piece(e.motifId, const Rect.fromLTWH(.74, .59, .13, .12));
      note(right, const Rect.fromLTWH(.10, .75, .76, .14));
    case 8: // Minimal two-moment chronology, editable dates in the margin.
      label(left);
      note(left, const Rect.fromLTWH(.08, .45, .78, .21));
      left.piece(e.motifId, const Rect.fromLTWH(.09, .75, .15, .13));
      for (var n = 0; n < 2; n++) {
        right.image(photo + n, Rect.fromLTWH(.09, .11 + n * .38, .65, .30));
        right.type(
          '0${n + 1}',
          Rect.fromLTWH(.79, .23 + n * .38, .13, .05),
          size: .023,
          font: 'Poppins',
          color: e.accent,
        );
      }
    case 9: // A personal note opposite a full portrait, no fake handwriting.
      left.piece(e.paperId, const Rect.fromLTWH(.06, .11, .87, .68));
      left.heading(title, const Rect.fromLTWH(.15, .23, .70, .13), size: .043);
      note(left, const Rect.fromLTWH(.15, .44, .68, .21));
      right.image(photo, Rect.fromLTWH(.12 - shift, .10, .76 + shift, .74));
    case 10: // Gallery-sized landscape / close detail and reflection.
      left.image(photo, const Rect.fromLTWH(.06, .13, .88, .49));
      left.heading(title, const Rect.fromLTWH(.08, .74, .84, .12), size: .041);
      _storyMountedPhoto(
        right,
        photo + 1,
        const Rect.fromLTWH(.20, .12, .62, .48),
      );
      note(right, const Rect.fromLTWH(.12, .73, .76, .16));
    default: // A soft closing photograph and a short final sentence.
      left.image(4, const Rect.fromLTWH(.10, .13, .80, .57));
      left.piece(e.motifId, const Rect.fromLTWH(.72, .76, .14, .12));
      right.type(
        e.englishTitle,
        const Rect.fromLTWH(.09, .13, .82, .27),
        size: .10,
        font: 'Cormorant Garamond',
      );
      right.heading(title, const Rect.fromLTWH(.10, .49, .80, .12), size: .046);
      note(right, const Rect.fromLTWH(.10, .71, .80, .16));
  }
  return [left, right];
}
