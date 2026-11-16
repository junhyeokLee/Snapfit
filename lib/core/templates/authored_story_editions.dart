part of 'authored_collections.dart';

/// Only authored on demand or by the font-aware snapshot exporter. Store
/// workers consume the exported snapshots, never TextPainter on an isolate.
Map<String, dynamic> storyEditionDocument(
  StoryEdition edition,
  CollectionAspect aspect,
) {
  final cover = storyEditionCover(edition, aspect);
  final pages = <Map<String, dynamic>>[];
  for (var i = 0; i < edition.innerPages ~/ 2; i++) {
    final pair = _storySpread(edition, aspect, i);
    for (final p in pair) {
      p.folio(edition.title, color: p.ink);
      for (final layer in p.layers) {
        if (layer['type'] == 'text' || layer['type'] == 'image') {
          layer['templateContent'] = true;
        }
      }
      pages.add({
        ...p.json,
        'name': edition.chapters[i],
        'role': 'story-${_storySequence(edition)[i]}',
        'spreadIndex': i + 1,
        'side': p.index.isOdd ? 'left' : 'right',
      });
    }
  }
  final document = <String, dynamic>{
    'id': 'snapfit_${edition.id}_${aspect.name}',
    'collectionId': edition.id,
    'title': edition.title,
    'category': edition.category,
    'source': 'snapfit-authored-story',
    'version': 1,
    'qualityRevision':
        edition.qualityRevision ??
        (edition.exclusivePhotography
            ? exclusiveStoryEditionRevision
            : storyEditionRevision),
    'aiGenerated': false,
    'samplePhotography': edition.exclusivePhotography
        ? 'exclusive-generated-editorial-samples'
        : 'bundled-editorial-samples',
    if (edition.exclusivePhotography) 'photoReusePolicy': 'edition-exclusive',
    'accessTier': edition.isPremium ? 'premium' : 'free',
    'catalogPublishable': edition.qualityRevision == premiumQuartetRevision,
    'publicationStatus':
        edition.qualityRevision == premiumQuartetRevision ||
            edition.activity != null ||
            edition.qualityRevision == sensoryEditionRevision
        ? 'bundled'
        : edition.isPremium
        ? 'local-design-review'
        : 'bundled',
    if (edition.activity != null) ...{
      'activity': edition.activity!.name,
      'activityFormat': edition.category == '동아리'
          ? 'group-journal'
          : 'personal-training',
      if (edition.memberSlots > 0) 'memberSlots': edition.memberSlots,
      'samplePhotoAspectRatio': 1.5,
    },
    if (!edition.isPremium)
      'materialPolicyRevision': freeTemplateMaterialPolicyRevision,
    'includedMaterialKeys': edition.includedMaterialKeys,
    'innerPageCount': edition.innerPages,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'chapters': [
      for (var i = 0; i < edition.innerPages ~/ 2; i++)
        {'title': edition.chapters[i], 'from': i * 2 + 1, 'to': i * 2 + 2},
    ],
    'cover': cover,
    'pages': pages,
  };
  if (!edition.isPremium) validateFreeTemplateMaterials(document);
  return document;
}

Map<String, dynamic> storyEditionCatalogDocument(StoryEdition e) => {
  ...storyEditionDocument(e, CollectionAspect.square),
  'variants': {
    for (final a in CollectionAspect.printable)
      a.name: storyEditionDocument(e, a),
  },
};

/// Selecting an editor cover does not author the other 24 pages or variants.
Map<String, dynamic> storyEditionCover(
  StoryEdition e,
  CollectionAspect aspect,
) {
  final page = _StoryPage(e, aspect, 0, '#F7F5F2');
  _storyCover(page);
  return {
    ...page.json,
    'name': e.title,
    'side': 'cover',
    'role': 'story-cover',
  };
}

class _StoryPage extends _Sheet {
  _StoryPage(this.edition, CollectionAspect aspect, int index, String paper)
    : super(edition.id, aspect, index, paper, ink: edition.ink);
  final StoryEdition edition;
  String get uid => 'element_${layers.length}';
  void type(
    String value,
    Rect r, {
    double size = .027,
    String? color,
    String font = 'NotoSans',
    String align = 'left',
    String role = 'caption',
  }) {
    _fittedEditorialType(
      this,
      uid,
      value,
      r,
      size: size,
      color: color ?? ink,
      font: font,
      leading: 1.35,
      align: align,
    );
    layers.last['editorialTextRole'] = role;
    layers.last['templateContent'] = true;
  }

  void image(int n, Rect r, {String frame = 'none', double turn = 0}) {
    photo(
      uid,
      edition.photoAssets[n % edition.photoAssets.length],
      r.left,
      r.top,
      r.width,
      r.height,
      shape: frame,
      rotation: turn,
    );
    if (edition.category == '동아리' &&
        n % edition.photoAssets.length != 1 &&
        r.width * ratio / r.height > 1.2) {
      // Group scenes retain headroom in wide photo windows. The ordinary
      // close-up detail remains centered. This editable crop is shared by
      // preview, editor, save/restore and print, without another bitmap.
      layers.last['imageOffsetRatio'] = {'x': 0.0, 'y': .5};
    }
    layers.last['templateContent'] = true;
  }

  void heading(String value, Rect r, {double size = .056}) =>
      type(value, r, size: size, font: 'BookMyungjo', role: 'headline');
  void line(Rect r, {String? color}) =>
      box(uid, r.left, r.top, r.width, r.height, color ?? edition.accent);
  void piece(String key, Rect bounds) {
    final spec = studioDecorationById(key)!;
    final w = math.min(bounds.width, bounds.height * spec.aspectRatio / ratio);
    material(
      uid,
      key,
      bounds.left,
      bounds.top,
      w,
      h: w * ratio / spec.aspectRatio,
    );
  }
}

void _storyCover(_StoryPage p) {
  final e = p.edition;
  if (e.qualityRevision == premiumQuartetRevision) {
    _premiumQuartetCover(p);
    return;
  }
  if (e.qualityRevision == hobbyExpansionRevision) {
    _hobbyExpansionCover(p);
    return;
  }
  if (e.qualityRevision == milestoneExpansionRevision) {
    _milestoneExpansionCover(p);
    return;
  }
  if (e.qualityRevision == readingEditionRevision) {
    _readingCover(p);
    return;
  }
  if (e.qualityRevision == sensoryEditionRevision) {
    _sensoryCover(p);
    return;
  }
  if (e.activity != null) {
    _activityStoryCover(p);
    return;
  }
  if (e.category == '동아리') {
    _clubStoryCover(p);
    return;
  }
  if (e.exclusivePhotography) {
    _exclusiveStoryCover(p);
    return;
  }
  final wide = p.wide;
  final topic = templateTopicOrder.indexOf(e.category);
  // Topic-dependent inset/column choices change the composition, not just ink.
  final offset = topic * .007;
  switch (e.coverStyle) {
    case 0:
      p.image(0, const Rect.fromLTWH(0, 0, 1, 1));
      p._add(p.uid, 'decoration', 0, .48, 1, .52, {
        'style': 'photoCoverShadeBottom',
      });
      p.type(
        e.englishTitle,
        Rect.fromLTWH(.075, .60, .85, .22),
        size: wide ? .11 : .135,
        font: 'Cormorant Garamond',
        color: '#FFFFFF',
      );
      p.type(
        e.title,
        const Rect.fromLTWH(.08, .845, .78, .045),
        size: .029,
        color: '#FFFFFF',
      );
      p.line(const Rect.fromLTWH(.08, .92, .13, .006), color: '#14AAA8');
    case 1:
      if (wide) {
        p.image(0, Rect.fromLTWH(.40 + offset, .07, .53 - offset, .86));
        p.type(
          e.englishTitle,
          const Rect.fromLTWH(.065, .18, .32, .37),
          size: .095,
          font: 'Cormorant Garamond',
        );
        p.type(e.title, const Rect.fromLTWH(.065, .69, .30, .10), size: .028);
      } else {
        p.type(
          e.englishTitle,
          Rect.fromLTWH(.075, .06, .85, .25 - offset),
          size: .12,
          font: 'Cormorant Garamond',
        );
        p.image(0, Rect.fromLTWH(.075 + offset, .34, .85 - offset, .52));
        p.type(e.title, const Rect.fromLTWH(.075, .89, .83, .05), size: .027);
      }
      p.line(const Rect.fromLTWH(.075, .945, .15, .004), color: '#14AAA8');
    case 2:
      p.box(p.uid, 0, 0, 1, 1, e.ink);
      p.type(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(.065, .065, .87, .13),
        size: .083,
        font: 'Cormorant Garamond',
        color: '#F7F5F2',
      );
      p.image(0, Rect.fromLTWH(.07, .255 + offset, .55, .49 - offset));
      p.piece(e.paperId, Rect.fromLTWH(.65, .26, .28, .24 + offset));
      p.piece(e.motifId, const Rect.fromLTWH(.69, .55, .20, .17));
      p.type(
        e.title,
        const Rect.fromLTWH(.07, .80, .85, .065),
        size: .035,
        color: '#F7F5F2',
      );
      p.type(
        '01 / A PHOTO COLLECTION',
        const Rect.fromLTWH(.07, .91, .85, .035),
        size: .018,
        color: '#8DD9D3',
        font: 'Poppins',
      );
    case 3:
      p.box(p.uid, 0, 0, 1, 1, '#E4F4F3');
      p.image(
        0,
        Rect.fromLTWH(.10 + offset, .11, .80 - 2 * offset, .57),
        frame: topic.isEven ? 'studioArch' : 'studioOvalMat',
      );
      p.type(
        e.englishTitle.replaceAll('\n', ' '),
        const Rect.fromLTWH(.08, .72, .84, .10),
        font: 'Cormorant Garamond',
        size: .078,
        align: 'center',
      );
      p.type(
        e.title,
        const Rect.fromLTWH(.12, .86, .76, .05),
        size: .027,
        align: 'center',
      );
      p.piece(e.motifId, const Rect.fromLTWH(.79, .04, .13, .12));
    default:
      p.box(p.uid, 0, 0, 1, 1, e.tint);
      p.type(
        e.englishTitle,
        const Rect.fromLTWH(.07, .065, .85, .28),
        size: .123,
        font: 'Cormorant Garamond',
      );
      p.image(0, Rect.fromLTWH(.28 + offset, .38, .64 - offset, .41));
      p.piece(e.motifId, const Rect.fromLTWH(.06, .64, .16, .15));
      p.type(e.title, const Rect.fromLTWH(.07, .86, .86, .055), size: .029);
      p.line(const Rect.fromLTWH(.07, .945, .16, .004), color: '#14AAA8');
  }
}

// Each book has a different sequence and density. Opening/closing remain bookends.
List<int> _storySequence(StoryEdition e) => e.spreadOrder.isNotEmpty
    ? e.spreadOrder
    : switch (e.coverStyle) {
        20 || 25 => const [0, 1, 2, 3, 5, 6, 7, 8, 4, 10, 9, 11],
        21 || 26 => const [0, 5, 2, 6, 3, 1, 7, 8, 4, 10, 9, 11],
        22 || 27 => const [0, 1, 2, 7, 5, 6, 3, 8, 4, 10, 9, 11],
        23 || 28 => const [0, 6, 2, 1, 3, 5, 7, 8, 4, 10, 9, 11],
        24 || 29 => const [0, 1, 2, 5, 7, 6, 3, 8, 4, 10, 9, 11],
        10 || 15 => const [0, 1, 2, 6, 7, 5, 3, 8, 4, 10, 9, 11],
        11 || 16 => const [0, 2, 7, 5, 1, 6, 9, 3, 4, 8, 10, 11],
        12 || 17 => const [0, 6, 1, 3, 5, 2, 8, 7, 4, 9, 10, 11],
        13 || 18 => const [0, 5, 3, 1, 6, 2, 7, 9, 4, 10, 8, 11],
        14 || 19 => const [0, 7, 6, 2, 1, 5, 3, 10, 4, 8, 9, 11],
        0 => const [0, 1, 4, 2, 7, 5, 3, 6, 8, 9, 10, 11],
        1 => const [0, 4, 2, 6, 1, 9, 5, 3, 10, 7, 8, 11],
        2 => const [0, 3, 1, 7, 6, 2, 8, 4, 5, 10, 9, 11],
        3 => const [0, 5, 4, 1, 9, 6, 2, 8, 7, 3, 10, 11],
        5 => const [0, 1, 5, 2, 7, 6, 3, 4, 8, 10, 9, 11],
        6 => const [0, 2, 6, 1, 5, 7, 4, 3, 10, 8, 9, 11],
        7 => const [0, 5, 1, 3, 6, 2, 7, 8, 4, 9, 10, 11],
        8 => const [0, 6, 2, 5, 1, 4, 8, 7, 9, 3, 10, 11],
        9 => const [0, 7, 3, 1, 2, 5, 6, 9, 4, 10, 8, 11],
        _ => const [0, 7, 6, 9, 2, 4, 10, 5, 3, 8, 1, 11],
      };

List<_StoryPage> _storySpread(StoryEdition e, CollectionAspect aspect, int i) {
  if (e.qualityRevision == premiumQuartetRevision)
    return _premiumQuartetSpread(e, aspect, i);
  if (e.qualityRevision == hobbyExpansionRevision)
    return _hobbyExpansionSpread(e, aspect, i);
  if (e.qualityRevision == milestoneExpansionRevision)
    return _milestoneExpansionSpread(e, aspect, i);
  if (e.qualityRevision == readingEditionRevision)
    return _readingSpread(e, aspect, i);
  if (e.qualityRevision == sensoryEditionRevision)
    return _sensorySpread(e, aspect, i);
  if (e.activity != null) return _activityStorySpread(e, aspect, i);
  if (e.category == '동아리') return _clubStorySpread(e, aspect, i);
  if (e.exclusivePhotography) return _exclusiveStorySpread(e, aspect, i);
  final layout = _storySequence(e)[i];
  final left = _StoryPage(
    e,
    aspect,
    i * 2 + 1,
    layout == 3 || layout == 8 ? e.tint : '#F7F5F2',
  );
  final right = _StoryPage(
    e,
    aspect,
    i * 2 + 2,
    layout == 5 || layout == 10 ? e.tint : '#F9F7F4',
  );
  final title = e.chapters[i];
  final photo = i + 1;
  final shift =
      templateTopicOrder.indexOf(e.category) * .005 + e.coverStyle * .006;
  void note(_StoryPage p, Rect r) =>
      p.type(_storyNotes[e.category]![i], r, size: .026, role: 'body');
  void label(_StoryPage p) => p.type(
    title,
    const Rect.fromLTWH(.08, .07, .84, .09),
    size: .035,
    role: 'headline',
  );
  switch (layout) {
    case 0: // Quiet chapter opening / one generous photograph.
      left.type(
        '01 / ${e.category}',
        const Rect.fromLTWH(.09, .13, .82, .05),
        size: .019,
        font: 'Poppins',
        color: e.accent,
      );
      left.heading(title, const Rect.fromLTWH(.09, .25, .80, .22), size: .072);
      note(left, const Rect.fromLTWH(.10, .57, .76, .20));
      right.image(photo, Rect.fromLTWH(.07, .08 + shift, .86, .75 - shift));
    case 1: // Landscape with a companion detail and caption.
      left.image(photo, Rect.fromLTWH(0, .12 + shift, 1, .65 - shift));
      left.type(title, const Rect.fromLTWH(.08, .82, .84, .06), size: .032);
      _storyMountedPhoto(
        right,
        photo + 1,
        Rect.fromLTWH(.16 + shift, .13, .64 - shift, .48),
      );
      right.piece(e.motifId, const Rect.fromLTWH(.79, .625, .10, .055));
      note(right, const Rect.fromLTWH(.16, .70, .68, .16));
    case 2: // Two portraits against a narrow narrative column.
      label(left);
      left.image(photo, Rect.fromLTWH(.08, .22, .39 + shift, .59));
      left.image(photo + 1, Rect.fromLTWH(.51 + shift, .32, .40 - shift, .49));
      right.heading(title, const Rect.fromLTWH(.13, .15, .74, .15));
      right.image(
        photo + 2,
        const Rect.fromLTWH(.13, .38, .74, .34),
        frame: 'studioGallery',
      );
      note(right, const Rect.fromLTWH(.13, .77, .72, .11));
    case 3: // Contact sheet, larger image opposite; never six tiny cards.
      label(left);
      for (var n = 0; n < 4; n++) {
        left.image(
          photo + n,
          Rect.fromLTWH(
            .08 + n % 2 * .44,
            .22 + n ~/ 2 * .31,
            .39,
            .25 + shift / 2,
          ),
        );
      }
      right.image(photo + 4, Rect.fromLTWH(.10, .12, .80, .58 - shift));
      note(right, const Rect.fromLTWH(.10, .76, .80, .11));
    case 4: // Full photograph / editable title assembly and note.
      left.image(photo, const Rect.fromLTWH(0, 0, 1, .88));
      final art = studioWordArts.singleWhere((a) => a.id == e.wordArtId);
      final models = art.buildLayers(aspect.canvas);
      // Exporting through the same mapper keeps insertion and preview identical.
      for (final layer in models) {
        final raw = LayerExportMapper.toJson(layer, canvasSize: aspect.canvas);
        raw['type'] = layer.type.name;
        raw['id'] =
            '${e.id}_${aspect.name}_${right.index}_word_${right.layers.length}';
        raw['z'] = right.layers.length;
        raw['wordArtId'] = e.wordArtId;
        raw['templateContent'] = true;
        right.layers.add(raw);
      }
      right.type(title, const Rect.fromLTWH(.13, .15, .74, .08), size: .029);
      note(right, const Rect.fromLTWH(.13, .76, .74, .12));
    case 5: // Offset portrait with a typographic observation.
      left.image(
        photo,
        Rect.fromLTWH(.11 + shift, .10, .70 - shift, .74),
        frame: 'studioDoubleMat',
      );
      right.heading(title, const Rect.fromLTWH(.10, .12, .80, .16));
      right.image(photo + 1, Rect.fromLTWH(.24, .38, .59, .32 + shift));
      note(right, const Rect.fromLTWH(.11, .77, .77, .11));
    case 6: // Detail rhythm: one tall and two wide photographs.
      label(left);
      left.image(photo, Rect.fromLTWH(.08, .24, .84, .56 + shift / 2));
      _storyMountedPhoto(
        right,
        photo + 1,
        const Rect.fromLTWH(.11, .10, .78, .31),
      );
      _storyMountedPhoto(
        right,
        photo + 2,
        Rect.fromLTWH(.19 + shift, .46, .70 - shift, .29),
        mount: 1,
      );
      right.type(title, const Rect.fromLTWH(.11, .82, .78, .055), size: .026);
    case 7: // Stationery-backed collage, text never rasterized into paper.
      _storyStationeryPhoto(
        left,
        photo,
        const Rect.fromLTWH(.06, .14, .86, .68),
        title,
      );
      right.image(photo + 1, Rect.fromLTWH(.09 + shift, .10, .72, .43));
      right.piece(e.motifId, const Rect.fromLTWH(.70, .53, .17, .15));
      note(right, const Rect.fromLTWH(.13, .72, .74, .14));
    case 8: // Three moments with dates/labels kept editable.
      label(left);
      left.image(photo, const Rect.fromLTWH(.08, .25, .84, .36));
      note(left, const Rect.fromLTWH(.08, .71, .78, .15));
      for (var n = 0; n < 3; n++) {
        right.image(
          photo + n + 1,
          Rect.fromLTWH(.10 + shift, .10 + n * .255, .54, .20),
        );
        right.type(
          '${n + 1}'.padLeft(2, '0'),
          Rect.fromLTWH(.73, .15 + n * .255, .16, .05),
          size: .024,
          font: 'Poppins',
          color: e.accent,
        );
      }
    case 9: // A letter and portrait with genuine writing fields.
      left.piece(e.paperId, const Rect.fromLTWH(.08, .12, .84, .66));
      left.heading(title, const Rect.fromLTWH(.15, .23, .70, .12), size: .047);
      note(left, const Rect.fromLTWH(.15, .42, .68, .23));
      right.image(photo, Rect.fromLTWH(.16 - shift / 2, .15, .68 + shift, .66));
    case 10: // Gallery pairing, two different aspect choices.
      left.image(
        photo,
        Rect.fromLTWH(.09, .12 + shift, .82, .52 - shift),
        frame: 'studioGallery',
      );
      left.heading(title, const Rect.fromLTWH(.10, .73, .80, .12), size: .040);
      _storyMountedPhoto(
        right,
        photo + 1,
        Rect.fromLTWH(.22 + shift, .13, .56 - shift, .58),
      );
      note(right, const Rect.fromLTWH(.12, .79, .76, .10));
    default: // Closure differs from the opener and leaves space for handwriting.
      left.image(photo, Rect.fromLTWH(.06, .12, .88, .55 - shift));
      left.piece(e.motifId, const Rect.fromLTWH(.71, .71, .14, .13));
      right.type(
        e.englishTitle,
        const Rect.fromLTWH(.10, .15, .80, .25),
        size: .10,
        font: 'Cormorant Garamond',
      );
      right.heading(title, const Rect.fromLTWH(.10, .49, .80, .12), size: .047);
      note(right, const Rect.fromLTWH(.10, .69, .80, .18));
  }
  return [left, right];
}

const _storyNotes = <String, List<String>>{
  '웨딩': [
    '사진 밖의 목소리도\n이 책에 함께 남겨 두고 싶다.',
    '준비하던 손과 서로를 찾던 눈빛.\n작은 장면부터 천천히 기억한다.',
    '함께해 준 사람들의 표정을\n한 장씩 오래 바라보았다.',
    '그날의 말과 마음을\n우리의 문장으로 다시 적는다.',
    '사진 뒤에 남아 있는 이야기를\n여백에 조금 더 써 두었다.',
    '다음에도 꺼내 읽고 싶은 날.\n이날의 마음을 오래 간직하기로.',
    "함께 웃은 사람들의 이름을\n한 사람씩 기억하며 적어 본다.",
    "서로를 기다리던 시간과\n마주 보며 대답한 순간.",
    "축하가 오가던 자리에는\n작은 친절이 여러 번 놓였다.",
    "하루가 끝나 갈수록\n고맙다는 말이 더 많아졌다.",
    "장소보다 먼저 떠오르는 것은\n이날의 표정과 목소리.",
    "이 책의 마지막 장에도\n우리의 이야기는 이어진다.",
  ],
  '여행': [
    '도착하기 전부터 시작된 이야기.\n우리의 속도로 한 장씩 모았다.',
    '계획보다 오래 머문 자리에서\n뜻밖의 장면을 만났다.',
    '멀리 보이는 풍경과 가까운 것들.\n그 사이에 우리의 하루가 있었다.',
    '지도를 잠시 접어 두고\n눈에 들어오는 방향으로 걸었다.',
    '사진만으로는 담기지 않는 것을\n짧은 문장으로 적어 두었다.',
    '돌아온 뒤에도 다시 펼쳐 볼 풍경.\n다음에 걷고 싶은 길이 생겼다.',
    "길 위에서 바뀐 계획도\n지금은 여행의 일부가 되었다.",
    "잠깐 내려놓은 짐 곁에서\n다음 풍경을 함께 골랐다.",
    "마음에 남은 색과 소리.\n사진 옆의 작은 여백에 모은다.",
    "주머니에서 꺼낸 종이 한 장이\n오늘 지나온 길을 알려 준다.",
    "처음 왔을 때와 달라진 눈으로\n다시 같은 곳을 바라보았다.",
    "집에 돌아와 펼친 사진에서\n또 한 번 여행이 시작된다.",
  ],
  '일상': [
    '좋아하는 것을 조금 더 자세히.\n오늘의 장면을 천천히 모았다.',
    '익숙해서 지나쳤던 부분을\n한 번 더 바라보는 시간.',
    '손에 남은 감각과 그날의 빛을\n사진 옆에 작게 적어 두었다.',
    '남에게는 평범해 보여도\n나에게는 오래 기억할 순간.',
    '오늘 고른 것과 남겨 둔 것.\n조금씩 나의 취향이 되었다.',
    '별일 없는 날도 한 권이 된다.\n다음 장에는 또 다른 오늘을.',
    "빛의 방향이 달라지면\n익숙한 것도 새롭게 보인다.",
    "한 번 더 해 보고 싶은 일과\n오늘 처음 알게 된 취향.",
    "찍어 두지 않았다면 잊었을\n아주 작고 구체적인 장면들.",
    "잠깐 멈춘 사이에도\n주변의 모양은 조금씩 바뀌었다.",
    "잘 보이는 곳에 꺼내 두고\n자주 좋아해 주기로 했다.",
    "빈칸은 다음 날을 위해 남긴다.\n이 기록은 천천히 계속된다.",
  ],
  '성장·육아': [
    '어제와 조금 달라진 오늘.\n너의 눈높이에서 함께 바라본다.',
    '작은 손이 먼저 찾아낸 것.\n그 이유도 잊지 않고 적어 둔다.',
    '서두르지 않고 기다리는 동안\n새로운 표정이 하나 더 생겼다.',
    '잘해도 서툴러도 괜찮아.\n함께한 과정까지 남겨 두고 싶다.',
    '지금의 질문과 귀여운 말투를\n사진 옆에 그대로 적어 본다.',
    '조금씩 넓어지는 너의 세상.\n다음의 발견도 함께할게.',
    "스스로 고른 방법을 보며\n조금 뒤에서 조용히 응원했다.",
    "되풀이하는 일에도\n매번 새로운 발견이 숨어 있다.",
    "아이가 가리킨 방향으로\n고개를 낮춰 함께 바라보았다.",
    "지금은 작은 변화 같지만\n다시 보면 큰 걸음이겠지.",
    "날짜와 함께 적어 두는\n오늘만의 말과 표정.",
    "더 자란 네가 이 책을 펼치면\n얼마나 사랑받았는지 알기를.",
  ],
  '가족·친구': [
    '함께한 사람들의 목소리로\n오늘의 사진을 다시 읽는다.',
    '별다른 준비 없이 모여도\n우리에게는 좋은 하루가 된다.',
    '누군가 건넨 작은 말 한마디.\n웃음 뒤에 그 마음이 남았다.',
    '사진을 찍어 준 사람도\n한 장의 이야기 속에 함께.',
    '각자의 기억이 조금 달라도\n같이 웃었던 순간은 선명하다.',
    '다음에도 이렇게 만나자.\n오늘의 자리를 오래 기억하며.',
    "누가 먼저 웃었는지는 몰라도\n금세 모두의 얼굴이 닮았다.",
    "각자 가져온 것들을 펼치니\n함께한 자리의 모양이 생겼다.",
    "늘 하던 이야기에도\n오늘만의 작은 장면이 있다.",
    "서로 찍어 준 사진을 바꾸어 보며\n다른 눈으로 하루를 만났다.",
    "흩어지기 전에 한 장 더.\n이번에는 모두 함께 담았다.",
    "약속을 하나 더 남겨 두고\n책의 마지막 장을 접는다.",
  ],
  '커플·기념일': [
    '같은 하루를 함께 보냈다는 것.\n우리의 기억을 한 권으로 모았다.',
    '서로 다른 취향을 고르다가\n함께 좋아하는 것을 발견했다.',
    '사진 속 표정만큼 기억하고 싶은\n그날의 대화와 작은 습관.',
    '크게 특별하지 않아도 좋아.\n너와 함께한 장면이니까.',
    '말로 미처 전하지 못한 마음을\n여기에 조금 더 적어 둔다.',
    '다음 계절에도 우리만의 속도로.\n함께 쓸 이야기는 아직 많다.',
    "내가 보지 못한 장면을\n네가 찍은 사진에서 발견했다.",
    "둘이 나누어 고른 것들이\n천천히 우리다운 하루가 된다.",
    "서로의 속도를 기다려 주며\n함께 지나온 시간을 세어 본다.",
    "사진을 보며 떠오른 말을\n오늘의 목소리로 남겨 둔다.",
    "오래 간직하고 싶은 마음은\n작고 구체적인 장면에 있다.",
    "다음에 이 책을 다시 펼칠 때도\n네가 내 옆에 있으면 좋겠다.",
  ],
  '반려동물': [
    '말 대신 표정으로 건네준 하루.\n너의 작은 신호를 기억한다.',
    '네가 먼저 고른 자리와 방향.\n오늘도 천천히 따라가 본다.',
    '좋아하는 것 앞에서 달라지는 눈빛.\n그 순간을 한 장 더 남겼다.',
    '조용히 쉬는 시간도\n우리에게는 소중한 장면.',
    '늘 같은 듯 조금씩 다른 모습.\n오늘 발견한 습관을 적는다.',
    '내일도 같이 놀고 같이 쉬자.\n가장 편안한 너의 하루가 되도록.',
    "가까이 다가왔다가 멀어지는 발걸음.\n기분 좋은 거리를 함께 찾는다.",
    "네가 쉬는 동안에는\n주변도 조금 조용해졌다.",
    "귀와 발끝, 작은 몸짓 하나에도\n너만의 이야기가 담겨 있다.",
    "사진을 다시 넘겨 보니\n오늘의 기분이 조금 더 보인다.",
    "함께 보낸 시간을 적으며\n내가 받은 다정함도 돌아본다.",
    "책을 덮고 네 이름을 부른다.\n다음 장면도 함께하자.",
  ],
};
