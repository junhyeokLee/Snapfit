part of 'authored_collections.dart';

class _FreePalette {
  const _FreePalette(
    this.paper,
    this.ink,
    this.accent,
    this.soft,
    this.frame, {
    this.serif = false,
  });
  final String paper, ink, accent, soft, frame;
  final bool serif;
}

const _freePalettes = {
  FreeCollectionVolume.vows: _FreePalette(
    '#FAFCFB',
    '#293C39',
    '#637F73',
    '#E4EDE7',
    'studioGallery',
    serif: true,
  ),
  FreeCollectionVolume.garden: _FreePalette(
    '#FCFDF8',
    '#355142',
    '#8B5775',
    '#E6EFDA',
    'studioArch',
    serif: true,
  ),
  FreeCollectionVolume.cinema: _FreePalette(
    '#F7F7F5',
    '#252426',
    '#A53F50',
    '#E8E5E6',
    'studioFilm',
  ),
  FreeCollectionVolume.letters: _FreePalette(
    '#FFFDFD',
    '#603D4D',
    '#A05B73',
    '#F4E6EB',
    'studioDeckle',
    serif: true,
  ),
  FreeCollectionVolume.seaside: _FreePalette(
    '#FAFDFD',
    '#1F5961',
    '#D25B48',
    '#DFEFF1',
    'studioWave',
  ),
  FreeCollectionVolume.city: _FreePalette(
    '#F8FAF7',
    '#292E2E',
    '#B34437',
    '#E7EEDB',
    'none',
  ),
  FreeCollectionVolume.walking: _FreePalette(
    '#FBFCFA',
    '#3D5846',
    '#6C6680',
    '#E5E9DD',
    'studioRounded',
    serif: true,
  ),
  FreeCollectionVolume.postcards: _FreePalette(
    '#FDFCFA',
    '#35585D',
    '#AE473E',
    '#E8EFF0',
    'studioTicket',
  ),
  FreeCollectionVolume.table: _FreePalette(
    '#FFFDF8',
    '#445540',
    '#B55944',
    '#F6E4CE',
    'studioScallop',
  ),
  FreeCollectionVolume.objects: _FreePalette(
    '#FAFBFD',
    '#324965',
    '#596D43',
    '#E7EBD6',
    'studioGallery',
  ),
  FreeCollectionVolume.together: _FreePalette(
    '#FDFCFF',
    '#5D4268',
    '#6D7336',
    '#EEE8F3',
    'studioInstant',
  ),
  FreeCollectionVolume.weekend: _FreePalette(
    '#FBFCFF',
    '#434B62',
    '#497166',
    '#EAE7F3',
    'studioCapsule',
  ),
};

const _weddingPhotos = [
  'petal_couple.png',
  'petal_table.png',
  'petal_veil.png',
  'petal_details.png',
  'petal_bouquet.png',
  'lightbound_ceremony.png',
  'lightbound_guests.png',
  'lightbound_twilight.png',
];
const _travelPhotos = [
  'travel_harbor.png',
  'travel_street.png',
  'travel_coast.png',
  'travel_cafe.png',
  'journey_train.png',
  'journey_market.png',
];
const _dailyPhotos = [
  'small_days_breakfast.png',
  'daily_picnic.png',
  'daily_book.png',
  'daily_desk.png',
  'daily_fruit.png',
  'daily_friends.png',
  'small_days_walk.png',
];

class _FreeBook {
  _FreeBook(this.volume, this.aspect, this.copy)
    : palette = _freePalettes[volume] ?? _lifePalettes[volume]!;
  final FreeCollectionVolume volume;
  final CollectionAspect aspect;
  final EditorialCopy copy;
  final _FreePalette palette;
  final pages = <Map<String, dynamic>>[];
  List<String> get photos =>
      _lifePhotos(volume) ??
      switch (volume.category) {
        '웨딩' => _weddingPhotos,
        '여행' => _travelPhotos,
        _ => _dailyPhotos,
      };

  _Sheet sheet({bool tinted = false}) => _Sheet(
    volume.id,
    aspect,
    pages.length,
    tinted ? palette.soft : palette.paper,
    ink: palette.ink,
    display: palette.serif ? 'Cormorant Garamond' : 'NotoSans',
    displayWeight: palette.serif ? 400 : 600,
  );

  void photo(
    _Sheet p,
    String id,
    int source,
    double x,
    double y,
    double w,
    double h, {
    String? frame,
  }) {
    var index = source % photos.length;
    final used = p.layers
        .where((l) => l['type'] == 'image')
        .map((l) => l['imageUrl'])
        .toSet();
    while (used.contains('asset:$_editorial${photos[index]}') &&
        used.length < photos.length) {
      index = (index + 1) % photos.length;
    }
    final file = photos[index];
    final group =
        file == 'daily_friends.png' ||
        file == 'lightbound_guests.png' ||
        const {
          'family_picnic.png',
          'family_kitchen.png',
          'family_friends.png',
          'couple_cafe.png',
          'couple_anniversary.png',
          'growth_birthday.png',
        }.contains(file);
    final people =
        group ||
        file.startsWith('growth_') ||
        file.startsWith('couple_') ||
        file.startsWith('pet_') ||
        const {
          'petal_couple.png',
          'lightbound_ceremony.png',
          'lightbound_twilight.png',
          'small_days_walk.png',
        }.contains(file);
    // Avoid head crops in shallow landscape slots. This only art-directs sample
    // images; users still receive an editable, normally fillable photo frame.
    if (group || (people && w * p.ratio / h > 1.8)) {
      final width = math.min(w, h * 1.5 / p.ratio);
      final height = width * p.ratio / 1.5;
      x += (w - width) / 2;
      y += (h - height) / 2;
      w = width;
      h = height;
      if (group) frame = 'none';
    }
    p.photo(id, '$_editorial$file', x, y, w, h, shape: frame ?? palette.frame);
  }

  void title(
    _Sheet p,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .071,
  }) => p.title(value, x: x, y: y, w: w, h: h, size: size);
  void text(
    _Sheet p,
    String id,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .027,
    String? color,
    String align = 'left',
  }) => p.text(
    id,
    value,
    x,
    y,
    w,
    h,
    size: size,
    color: color ?? palette.ink,
    align: align,
    lineHeight: 1.5,
  );
  void rule(_Sheet p, double x, double y, double w, {String? color}) =>
      p.box('rule_${p.layers.length}', x, y, w, .0015, color ?? palette.accent);

  void motif(_Sheet p) {
    switch (volume) {
      case FreeCollectionVolume.vows:
        rule(p, .07, .055, .86);
        p.box('vow_mark', .49, .048, .02, .014, palette.accent);
      case FreeCollectionVolume.garden:
        p.material(
          'pressed_flower',
          'studioPressedCosmos',
          .02,
          .915,
          .05,
          h: .047,
        );
        rule(p, .13, .91, .74, color: '#C8D5BA');
      case FreeCollectionVolume.cinema:
        for (var i = 0; i < 7; i++) {
          p.box('film_mark_$i', .105 + i * .126, .038, .022, .009, palette.ink);
        }
      case FreeCollectionVolume.letters:
        p.material(
          'letter_paper',
          'studioBlushPaper',
          .032,
          .035,
          .17,
          h: .032,
        );
        rule(p, .80, .055, .13);
      case FreeCollectionVolume.seaside:
        for (var i = 0; i < 3; i++)
          rule(p, .80, .039 + i * .012, .13, color: palette.accent);
      case FreeCollectionVolume.city:
        p.box('catalog_tab', .028, .077, .016, .14, palette.accent);
        rule(p, .07, .91, .86);
      case FreeCollectionVolume.walking:
        p.box('trail_marker', .045, .035, .035, .011, palette.accent);
        p.box('trail_marker_small', .093, .035, .015, .011, palette.accent);
      case FreeCollectionVolume.postcards:
        for (var i = 0; i < 12; i++) {
          p.box(
            'airmail_$i',
            .07 + i * .073,
            .04,
            .036,
            .006,
            i.isEven ? palette.accent : palette.ink,
          );
        }
      case FreeCollectionVolume.table:
        for (var i = 0; i < 14; i++) {
          p.box(
            'table_check_$i',
            .08 + i * .06,
            .036,
            .027,
            .015,
            i.isEven ? palette.accent : '#9DAF88',
          );
        }
      case FreeCollectionVolume.objects:
        rule(p, .055, .055, .89);
        p.box('index_square', .88, .075, .035, .025, palette.accent);
      case FreeCollectionVolume.together:
        p.material(
          'little_ribbon',
          'studioSageRibbon',
          .862,
          .035,
          .060,
          h: .040,
        );
      case FreeCollectionVolume.weekend:
        p.material(
          'weekend_tape',
          'studioWashiIndigo',
          .405,
          .027,
          .19,
          h: .024,
        );
      default:
        _lifeMotif(this, p);
    }
  }

  void add(_Sheet p, String name, String role) {
    text(
      p,
      'folio',
      '${p.index}'.padLeft(2, '0'),
      p.index.isOdd ? .07 : .83,
      .948,
      .1,
      .029,
      size: .017,
      align: p.index.isOdd ? 'left' : 'right',
    );
    pages.add({
      ...p.json,
      'name': name,
      'role': role,
      'spreadIndex': p.index == 0 ? 0 : (p.index + 1) ~/ 2,
      'side': p.index == 0
          ? 'cover'
          : p.index.isOdd
          ? 'left'
          : 'right',
    });
  }

  Map<String, dynamic> get document => {
    'id': 'snapfit_free_${volume.id}_${aspect.name}',
    'title': volume.title,
    'category': volume.category,
    'source': 'snapfit-authored-free',
    'aiGenerated': false,
    'accessTier': 'free',
    'publicationStatus': 'bundled',
    'catalogPublishable': false,
    'version': 1,
    'innerPageCount': 24,
    'aspect': aspect.name,
    'designWidth': aspect.canvas.width,
    'designHeight': aspect.canvas.height,
    'layoutSafety': {'insetFraction': .06, 'printVerified': false},
    'artDirection': volume.id,
    'chapters': [
      for (final entry in volume._spreads.indexed)
        {
          'title': entry.$2.title,
          'from': entry.$1 * 2 + 1,
          'to': entry.$1 * 2 + 2,
        },
    ],
    'cover': pages.first,
    'pages': pages.skip(1).toList(),
  };
}

Map<String, dynamic> _buildFreeCollection(
  FreeCollectionVolume volume,
  CollectionAspect aspect,
  EditorialCopy copy,
) {
  final b = _FreeBook(volume, aspect, copy);
  _freeCover(b);
  for (final spread in volume._spreads) _freeSpread(b, spread);
  return b.document;
}

void _freeCover(_FreeBook b) {
  if (_lifePalettes.containsKey(b.volume)) {
    _lifeCover(b);
    return;
  }
  final p = b.sheet();
  final a = b.palette;
  final title = b.volume.title;
  final c = b.copy;
  switch (b.volume) {
    case FreeCollectionVolume.vows:
      b.rule(p, .17, .10, .66);
      b.text(
        p,
        'vows_date',
        c.period,
        .12,
        .135,
        .76,
        .045,
        size: .023,
        align: 'center',
      );
      p.title(
        title,
        x: .08,
        y: .235,
        w: .84,
        h: .12,
        size: .088,
        align: 'center',
      );
      b.photo(
        p,
        'vows_portrait',
        0,
        .28,
        .415,
        .44,
        .31,
        frame: 'studioGallery',
      );
      b.text(
        p,
        'vows_names',
        c.byline,
        .12,
        .785,
        .76,
        .055,
        size: .030,
        align: 'center',
      );
      b.text(
        p,
        'vows_place',
        c.place,
        .10,
        .865,
        .80,
        .04,
        size: .021,
        align: 'center',
      );
    case FreeCollectionVolume.garden:
      p.box('garden_stock', .06, .06, .88, .88, a.soft);
      p.title(
        '정원에서의\n약속',
        x: .13,
        y: .11,
        w: .74,
        h: .20,
        size: .071,
        align: 'center',
      );
      b.photo(p, 'garden_arch', 0, .23, .36, .54, .38, frame: 'studioArch');
      p.material(
        'garden_bloom',
        'studioPressedCosmos',
        .10,
        .565,
        .105,
        h: .18,
      );
      p.material('garden_ribbon', 'studioSageRibbon', .79, .69, .11, h: .11);
      b.text(
        p,
        'garden_names',
        c.byline,
        .16,
        .785,
        .68,
        .055,
        size: .028,
        align: 'center',
      );
      b.text(
        p,
        'garden_date',
        c.period,
        .12,
        .858,
        .76,
        .04,
        size: .021,
        align: 'center',
      );
    case FreeCollectionVolume.cinema:
      p.box('film_board', 0, 0, 1, 1, '#262527');
      b.text(
        p,
        'film_title',
        title,
        .08,
        .105,
        .84,
        .13,
        size: .082,
        color: '#FAF9F7',
      );
      b.text(
        p,
        'film_byline',
        c.byline,
        .08,
        .257,
        .84,
        .055,
        size: .025,
        color: '#E6DADC',
      );
      b.photo(p, 'film_wide', 0, .07, .38, .86, .31, frame: 'studioFilm');
      b.text(
        p,
        'film_caption',
        '우리의 첫 번째 영화',
        .08,
        .755,
        .84,
        .05,
        size: .025,
        color: '#FAF9F7',
      );
      b.text(
        p,
        'film_date',
        c.period,
        .08,
        .848,
        .84,
        .04,
        size: .022,
        color: '#E6DADC',
      );
    case FreeCollectionVolume.letters:
      p.box('letter_stock', .055, .05, .89, .89, a.soft);
      p.material('letter_sheet', 'studioCottonRag', .095, .08, .81, h: .83);
      b.text(p, 'letter_to', '사랑하는 우리에게', .15, .145, .7, .05, size: .024);
      p.title(title, x: .15, y: .25, w: .7, h: .11, size: .082);
      b.photo(p, 'letter_photo', 2, .15, .445, .45, .31, frame: 'studioDeckle');
      p.material('letter_flower', 'studioPressedCosmos', .69, .45, .14, h: .24);
      b.text(p, 'letter_names', c.byline, .15, .80, .70, .05, size: .025);
    case FreeCollectionVolume.seaside:
      p.box('sea_stock', 0, 0, 1, 1, a.soft);
      p.title('바다를\n건너', x: .08, y: .105, w: .56, h: .26, size: .102);
      b.text(p, 'sea_period', c.period, .08, .382, .84, .04, size: .022);
      b.photo(p, 'sea_wave', 2, .08, .48, .84, .32, frame: 'studioWave');
      b.text(p, 'sea_names', c.byline, .08, .856, .84, .048, size: .026);
      for (var i = 0; i < 4; i++) b.rule(p, .76, .16 + i * .025, .16);
    case FreeCollectionVolume.city:
      p.box('city_tab', .045, .07, .017, .21, a.accent);
      p.title('도시의\n수집가', x: .095, y: .10, w: .56, h: .23, size: .092);
      b.photo(p, 'city_window', 1, .66, .10, .26, .25, frame: 'none');
      b.rule(p, .08, .415, .84);
      b.photo(p, 'city_wide', 0, .08, .46, .61, .30, frame: 'none');
      b.photo(p, 'city_detail', 5, .735, .52, .185, .24, frame: 'none');
      b.text(p, 'city_place', c.place, .08, .82, .84, .042, size: .025);
      b.text(p, 'city_byline', c.byline, .08, .886, .84, .035, size: .021);
    case FreeCollectionVolume.walking:
      b.photo(
        p,
        'path_landscape',
        2,
        .13,
        .10,
        .74,
        .37,
        frame: 'studioRounded',
      );
      p.title('느리게\n걷는 길', x: .13, y: .555, w: .74, h: .20, size: .077);
      b.text(p, 'path_period', c.period, .13, .805, .74, .04, size: .023);
      b.text(p, 'path_names', c.byline, .13, .868, .74, .04, size: .021);
    case FreeCollectionVolume.postcards:
      p.box('post_label', .075, .07, .85, .20, a.soft);
      p.title(title, x: .105, y: .11, w: .70, h: .10, size: .075);
      p.material('post_stamp', 'studioBotanicalStamp', .82, .105, .062, h: .10);
      b.photo(
        p,
        'postcard_cover',
        0,
        .11,
        .34,
        .78,
        .36,
        frame: 'studioTicket',
      );
      b.rule(p, .11, .75, .78);
      b.text(p, 'post_address', c.place, .11, .796, .78, .047, size: .028);
      b.text(p, 'post_sender', c.byline, .11, .866, .78, .04, size: .023);
    case FreeCollectionVolume.table:
      for (var i = 0; i < 12; i++) {
        p.box(
          'table_edge_$i',
          .06 + .074 * i,
          .062,
          .035,
          .025,
          i.isEven ? a.accent : '#9DAF88',
        );
      }
      p.title(
        title,
        x: .1,
        y: .155,
        w: .8,
        h: .12,
        size: .085,
        align: 'center',
      );
      b.photo(p, 'table_plate', 0, .18, .36, .64, .35, frame: 'studioScallop');
      b.text(
        p,
        'table_names',
        c.byline,
        .12,
        .795,
        .76,
        .05,
        size: .027,
        align: 'center',
      );
      b.text(
        p,
        'table_season',
        c.place,
        .12,
        .866,
        .76,
        .045,
        size: .022,
        align: 'center',
      );
    case FreeCollectionVolume.objects:
      p.box('archive_band', .065, .065, .87, .16, a.soft);
      p.title(title, x: .10, y: .10, w: .8, h: .11, size: .082);
      b.photo(
        p,
        'archive_large',
        3,
        .08,
        .30,
        .50,
        .37,
        frame: 'studioGallery',
      );
      b.photo(
        p,
        'archive_small',
        2,
        .635,
        .43,
        .285,
        .24,
        frame: 'studioGallery',
      );
      b.rule(p, .08, .74, .84);
      b.text(
        p,
        'archive_label',
        '사진과 문장으로 모은 취향',
        .08,
        .785,
        .84,
        .05,
        size: .027,
      );
      b.text(p, 'archive_names', c.byline, .08, .87, .84, .04, size: .022);
    case FreeCollectionVolume.together:
      p.box('together_stock', 0, 0, 1, 1, a.soft);
      p.title(
        '함께라서\n좋은 날',
        x: .10,
        y: .10,
        w: .8,
        h: .21,
        size: .085,
        align: 'center',
      );
      b.photo(p, 'together_faces', 5, .08, .395, .84, .35, frame: 'none');
      b.text(
        p,
        'together_date',
        c.period,
        .10,
        .797,
        .80,
        .046,
        size: .024,
        align: 'center',
      );
      b.text(
        p,
        'together_names',
        c.byline,
        .10,
        .863,
        .80,
        .045,
        size: .024,
        align: 'center',
      );
    case FreeCollectionVolume.weekend:
      p.title('주말의\n온도', x: .10, y: .095, w: .8, h: .25, size: .098);
      b.photo(
        p,
        'weekend_capsule',
        6,
        .39,
        .365,
        .51,
        .38,
        frame: 'studioCapsule',
      );
      b.photo(
        p,
        'weekend_book',
        2,
        .10,
        .505,
        .235,
        .24,
        frame: 'studioRounded',
      );
      b.text(p, 'weekend_period', c.period, .10, .813, .80, .045, size: .023);
      b.text(p, 'weekend_names', c.byline, .10, .877, .80, .038, size: .021);
    default:
      throw StateError('Missing free cover: ${b.volume.id}');
  }
  // Cover has its own typographic hierarchy, not an interior folio.
  b.pages.add({
    ...p.json,
    'name': '${b.volume.title} / 표지',
    'role': '${b.volume.id}-cover',
    'side': 'cover',
    'spreadIndex': 0,
  });
}

void _freeSpread(_FreeBook b, _FreeSpread s) {
  final chapter = (b.pages.length + 1) ~/ 2;
  final left = b.sheet();
  final right = _Sheet(
    b.volume.id,
    b.aspect,
    b.pages.length + 1,
    switch (s.layout) {
      _FreeLayout.window ||
      _FreeLayout.letter ||
      _FreeLayout.keepsake ||
      _FreeLayout.closing => b.palette.soft,
      _ => b.palette.paper,
    },
    ink: b.palette.ink,
    display: b.palette.serif ? 'Cormorant Garamond' : 'NotoSans',
    displayWeight: b.palette.serif ? 400 : 600,
  );
  b.motif(left);
  b.motif(right);
  void label(
    _Sheet p,
    String value,
    double x,
    double y,
    double w, {
    double h = .05,
  }) => b.text(
    p,
    'label_${p.layers.length}',
    value,
    x,
    y,
    w,
    h,
    size: .023,
    color: b.palette.accent,
  );
  void headline(
    _Sheet p,
    double x,
    double y,
    double w,
    double h, {
    double size = .065,
  }) => b.title(p, s.line, x, y, w, h, size: size);
  void caption(_Sheet p, double x, double y, double w, double h) =>
      b.text(p, 'caption', s.caption, x, y, w, h, size: .028);
  void photo(
    _Sheet p,
    int source,
    double x,
    double y,
    double w,
    double h, {
    String? frame,
  }) =>
      b.photo(p, 'photo_${p.layers.length}', source, x, y, w, h, frame: frame);
  final title = '${chapter.toString().padLeft(2, '0')} / ${s.title}';

  switch (s.layout) {
    case _FreeLayout.opening:
      label(left, title, .08, .09, .84);
      headline(left, .08, .25, .84, .23, size: .081);
      caption(left, .08, .635, .39, .18);
      photo(left, s.detail, .57, .58, .35, .25);
      photo(right, s.photo, .085, .125, .83, .635);
      label(right, '이 장면에서 시작합니다.', .10, .815, .80);
    case _FreeLayout.gallery:
      photo(left, s.photo, .075, .10, .85, .64, frame: 'none');
      label(left, title, .085, .795, .83);
      caption(left, .085, .855, .83, .045);
      photo(right, s.detail, .08, .12, .40, .29);
      b.text(right, 'gallery_note', s.line, .55, .17, .37, .18, size: .043);
      photo(right, s.photo + 2, .26, .56, .66, .295, frame: 'none');
      b.rule(right, .08, .48, .84);
    case _FreeLayout.paired:
      label(left, title, .08, .115, .84);
      photo(left, s.photo, .08, .26, .84, .405, frame: 'none');
      b.text(left, 'pair_line', s.line, .08, .755, .84, .15, size: .046);
      photo(right, s.detail, .17, .14, .66, .59);
      caption(right, .17, .803, .66, .075);
    case _FreeLayout.window:
      label(left, title, .09, .10, .82);
      photo(
        left,
        s.detail,
        .255,
        .23,
        .49,
        .36,
        frame: b.palette.frame == 'none' ? 'studioRounded' : b.palette.frame,
      );
      headline(left, .12, .715, .76, .17, size: .052);
      photo(right, s.photo, .08, .17, .84, .50, frame: 'none');
      caption(right, .10, .755, .80, .10);
    case _FreeLayout.contact:
      label(left, title, .07, .105, .86);
      for (var i = 0; i < 4; i++) {
        photo(
          left,
          s.photo + i,
          .07 + (i % 2) * .445,
          .23 + (i ~/ 2) * .295,
          .405,
          .25,
          frame: b.volume == FreeCollectionVolume.cinema
              ? 'studioFilm'
              : 'none',
        );
      }
      caption(left, .07, .843, .86, .052);
      headline(right, .10, .155, .80, .22, size: .069);
      photo(right, s.detail, .17, .51, .66, .33);
    case _FreeLayout.ledger:
      label(left, title, .08, .10, .84);
      headline(left, .08, .215, .84, .19, size: .058);
      for (final entry in ['기억하고 싶은 것', '함께 나누고 싶은 말', '다시 남겨 둘 순간'].indexed) {
        final y = .47 + entry.$1 * .135;
        label(left, '${entry.$1 + 1}', .08, y, .05);
        b.text(
          left,
          'register_${entry.$1}',
          entry.$2,
          .18,
          y,
          .69,
          .055,
          size: .027,
        );
        b.rule(left, .18, y + .074, .69, color: '#BCC8C1');
      }
      photo(right, s.photo, .08, .16, .39, .42);
      photo(right, s.detail, .535, .33, .385, .42);
      caption(right, .08, .824, .84, .063);
    case _FreeLayout.letter:
      label(left, title, .10, .10, .80);
      headline(left, .10, .205, .80, .22, size: .061);
      b.text(
        left,
        'personal_letter',
        b.copy.note,
        .10,
        .49,
        .80,
        .38,
        size: .027,
      );
      photo(right, s.photo, .14, .19, .72, .50);
      caption(right, .14, .771, .72, .10);
    case _FreeLayout.postcard:
      label(left, title, .08, .10, .84);
      photo(left, s.photo, .08, .22, .84, .405, frame: 'studioTicket');
      b.rule(left, .08, .704, .84);
      caption(left, .08, .77, .84, .10);
      photo(right, s.detail, .08, .25, .38, .38, frame: 'none');
      _freeVerticalRule(right, .51, .20, .46, b.palette.accent);
      b.text(right, 'postcard_note', s.line, .565, .295, .355, .24, size: .041);
      label(right, b.copy.byline, .565, .565, .355, h: .08);
      b.text(
        right,
        'postcard_place',
        b.copy.place,
        .08,
        .78,
        .84,
        .07,
        size: .023,
      );
      right.material(
        'postcard_stamp',
        'studioBotanicalStamp',
        .805,
        .08,
        .085,
        h: .13,
      );
    case _FreeLayout.mosaic:
      photo(left, s.photo, .075, .13, .85, .365, frame: 'none');
      photo(left, s.detail, .075, .55, .40, .265);
      photo(left, s.photo + 2, .525, .55, .40, .265);
      label(left, title, .075, .855, .85);
      photo(right, s.photo + 1, .08, .19, .49, .58);
      b.text(
        right,
        'mosaic_line',
        s.line,
        .64,
        .195,
        .28,
        .265,
        size: _lifePalettes.containsKey(b.volume) ? .034 : .046,
      );
      caption(right, .64, .58, .28, .23);
    case _FreeLayout.stillLife:
      label(left, title, .10, .10, .80);
      photo(
        left,
        s.photo,
        .20,
        .26,
        .60,
        .365,
        frame: b.palette.frame == 'none' ? 'studioOval' : b.palette.frame,
      );
      caption(left, .10, .757, .80, .10);
      photo(right, s.detail, .08, .15, .40, .32, frame: 'none');
      b.text(right, 'still_line', s.line, .55, .16, .37, .23, size: .045);
      photo(right, s.photo + 2, .555, .525, .365, .285);
      b.text(
        right,
        'still_note',
        '작은 장면을\n오래 기억하기.',
        .08,
        .655,
        .40,
        .15,
        size: .032,
      );
    case _FreeLayout.panorama:
      label(left, title, .07, .10, .86);
      photo(left, s.photo, .07, .26, .86, .465, frame: 'none');
      caption(left, .07, .81, .86, .067);
      headline(right, .10, .14, .80, .235, size: .073);
      photo(right, s.detail, .10, .56, .46, .28, frame: 'none');
      photo(right, s.detail + 2, .62, .64, .28, .20);
    case _FreeLayout.timeline:
      label(left, title, .08, .10, .84);
      headline(left, .08, .21, .84, .20, size: .060);
      final captions = ['처음의 마음', '함께한 장면', '오래 남을 기억'];
      for (var i = 0; i < captions.length; i++) {
        final y = .49 + i * .127;
        label(left, '0${i + 1}', .08, y, .09);
        b.text(left, 'time_$i', captions[i], .245, y, .675, .06, size: .029);
        b.rule(left, .245, y + .075, .675, color: '#C1C8C5');
      }
      for (var i = 0; i < 3; i++) {
        photo(
          right,
          s.photo + i,
          .10,
          .095 + i * .275,
          .80,
          .225,
          frame: 'none',
        );
      }
    case _FreeLayout.keepsake:
      label(left, title, .09, .10, .82);
      left.material(
        'keepsake_paper',
        'studioCottonRag',
        .065,
        .255,
        .87,
        h: .58,
      );
      photo(left, s.photo, .17, .32, .66, .34, frame: 'studioDeckle');
      caption(left, .17, .713, .66, .10);
      right.material(
        'keepsake_tape',
        b.volume.category == '웨딩' ? 'studioWashiRose' : 'studioWashiSage',
        .12,
        .098,
        .29,
        h: .032,
      );
      photo(right, s.detail, .08, .185, .455, .34);
      b.text(right, 'keepsake_line', s.line, .61, .185, .31, .24, size: .043);
      photo(right, s.photo + 2, .535, .585, .385, .255, frame: 'studioInstant');
      b.text(
        right,
        'keepsake_note',
        '책 사이에\n남겨 둡니다.',
        .08,
        .66,
        .365,
        .145,
        size: .031,
      );
    case _FreeLayout.closing:
      label(left, title, .10, .10, .80);
      headline(left, .10, .26, .80, .24, size: .073);
      b.text(
        left,
        'closing_letter',
        b.copy.note,
        .10,
        .585,
        .80,
        .285,
        size: .024,
      );
      photo(right, s.photo, .19, .15, .62, .45);
      b.text(
        right,
        'closing_names',
        b.copy.byline,
        .10,
        .725,
        .80,
        .063,
        size: .033,
        align: 'center',
      );
      b.text(
        right,
        'closing_period',
        b.copy.period,
        .10,
        .827,
        .80,
        .042,
        size: .022,
        align: 'center',
      );
    case _FreeLayout.milestone:
    case _FreeLayout.ribbonPair:
    case _FreeLayout.pinboard:
    case _FreeLayout.fieldNotes:
    case _FreeLayout.portraitEssay:
      _lifeSpread(b, s, left, right, chapter);
  }
  b.add(left, '${s.title} / 왼쪽', '${b.volume.id}-$chapter-left');
  b.add(right, '${s.title} / 오른쪽', '${b.volume.id}-$chapter-right');
}

void _freeVerticalRule(_Sheet p, double x, double y, double h, String color) =>
    p.box('vertical_rule', x, y, .0015, h, color);
