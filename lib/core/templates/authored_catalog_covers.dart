part of 'authored_collections.dart';

const catalogCoverRevision = 'distinct-photography-2026-10-07';

const baselineCoverRevision = 'photo-led-baselines-2026-10-07';

// Draft builders and saved album layers stay untouched. Only the current
// catalog receives the new covers; original editable bylines are carried over.
Map<String, dynamic> _refineBaselineCatalogCover(
  String id,
  CollectionAspect aspect,
  Map<String, dynamic> document,
) {
  if (!const {'lightbound', 'journey', 'small-days'}.contains(id)) {
    return document;
  }
  final before = document['cover'] as Map<String, dynamic>;
  final layers = before['layers'] as List;
  String text(String suffix) =>
      layers.singleWhere(
            (l) =>
                l['type'] == 'text' && (l['id'] as String).endsWith('_$suffix'),
          )['text']
          as String;
  final photo =
      (layers.singleWhere((l) => l['type'] == 'image')['imageUrl'] as String)
          .substring(6);
  final p = _Sheet(
    'catalog_$id',
    aspect,
    0,
    id == 'small-days' ? '#ECE4F0' : '#EFF4F2',
    ink: id == 'small-days' ? '#473348' : '#174D50',
    display: 'NotoSans',
    displayWeight: 600,
  );
  switch (id) {
    case 'lightbound':
      p.photo('cover_photo', photo, 0, 0, 1, 1);
      _coverShade(p, top: true, strength: .55);
      _coverShade(p, strength: .48);
      p.text(
        'title',
        '빛으로\n엮은 우리',
        .075,
        .07,
        .85,
        .265,
        size: .096,
        color: '#FFFFFF',
        font: 'Eulyoo',
        lineHeight: 1.15,
      );
      p.box('cover_rule', .075, .352, .12, .002, '#FFFFFF');
      p.text(
        'cover_date',
        text('cover_date'),
        .075,
        .907,
        .37,
        .047,
        size: .024,
        color: '#FFFFFF',
      );
      p.text(
        'cover_names',
        text('cover_names'),
        .46,
        .907,
        .465,
        .047,
        size: .026,
        color: '#FFFFFF',
        align: 'right',
      );
    case 'journey':
      p.photo('cover_harbor', photo, 0, 0, 1, .78);
      p.box('title_stock', 0, .78, 1, .22, '#EDF3ED');
      p.title('여행의 결', x: .065, y: .815, w: .87, h: .102, size: .079);
      p.text(
        'cover_place',
        text('cover_place'),
        .065,
        .058,
        .87,
        .05,
        size: .025,
        color: '#174D50',
      );
      p.text(
        'cover_period',
        text('cover_period'),
        .065,
        .944,
        .39,
        .035,
        size: .021,
        color: '#174D50',
      );
      p.text(
        'cover_byline',
        text('cover_byline'),
        .49,
        .944,
        .445,
        .035,
        size: .021,
        color: '#174D50',
        align: 'right',
      );
    case 'small-days':
      p.title('작은 날의 기록', x: .075, y: .04, w: .85, h: .10, size: .083);
      p.photo('cover_walk', photo, 0, .17, 1, .64);
      p.text(
        'cover_season',
        text('cover_season'),
        .075,
        .85,
        .85,
        .04,
        size: .026,
        color: '#473348',
      );
      p.box('cover_rule', .075, .913, .12, .002, '#8B587A');
      p.text(
        'cover_author',
        text('cover_author'),
        .255,
        .904,
        .67,
        .052,
        size: .025,
        color: '#473348',
        align: 'right',
      );
  }
  return {
    ...document,
    'version': (document['version'] as int) + 1,
    'coverRevision': baselineCoverRevision,
    'coverReview': 'pending-visual-approval',
    'cover': {...before, ...p.json, 'coverRevision': baselineCoverRevision},
  };
}

const _conceptCatalogCoverPhotos = {
  ConceptVolume.silkVows: '${_editorial}lightbound_cake.png',
  ConceptVolume.shoreDays: '${_editorial}travel_coast.png',
  ConceptVolume.readingRoom:
      'assets/templates/jeju_travel/images/approved_stock/guesthouse_detail.jpg',
  ConceptVolume.firstWardrobe: '${_editorial}cover_little_wardrobe.png',
  ConceptVolume.sundayPicnic: '${_editorial}daily_fruit.png',
  ConceptVolume.sharedSeasons: '${_editorial}cover_shared_rain.png',
  ConceptVolume.littleCompanion: '${_editorial}cover_cat_cobalt.png',
};

void _coverShade(_Sheet p, {bool top = false, double strength = .55}) => p._add(
  'cover_shade_${p.layers.length}',
  'decoration',
  0,
  top ? 0 : .5,
  1,
  .5,
  {
    'style': top ? 'photoCoverShadeTop' : 'photoCoverShadeBottom',
    'opacity': strength,
  },
);

void _paintConceptCover(_ConceptPage p, EditorialCopy copy) {
  const white = '#FFFFFF';
  p.photo('catalog_photo', _conceptCatalogCoverPhotos[p.volume]!, 0, 0, 1, 1);
  final custom = copy.place != p.volume.title;
  switch (p.volume) {
    case ConceptVolume.silkVows:
      _coverShade(p, top: true, strength: .55);
      p.txt(
        'THE VOWS',
        .10,
        .07,
        .80,
        .07,
        size: .03,
        color: white,
        align: 'center',
        font: 'NotoSans',
      );
      p.txt(
        copy.place,
        .08,
        .17,
        .84,
        .15,
        size: .093,
        color: white,
        align: 'center',
      );
      p.rule(.38, .35, .24, color: white);
      _coverShade(p, strength: .45);
      p.txt(
        copy.byline,
        .08,
        .855,
        .84,
        .055,
        size: .026,
        color: white,
        align: 'center',
      );
      p.txt(
        copy.period,
        .08,
        .925,
        .84,
        .04,
        size: .018,
        color: white,
        align: 'center',
      );
    case ConceptVolume.shoreDays:
      _coverShade(p, top: true, strength: .32);
      p.label(copy.period, .075, .06, .85, color: white);
      _coverShade(p, strength: .74);
      p.txt(
        'By the sea',
        .065,
        .65,
        .87,
        .16,
        size: .13,
        font: 'Cormorant Garamond',
        lineHeight: 1,
        color: white,
      );
      p.txt(copy.place, .075, .818, .85, .085, size: .046, color: white);
      p.label(copy.byline, .075, .925, .85, color: white);
    case ConceptVolume.readingRoom:
      _coverShade(p, top: true, strength: .76);
      p.label('IN THE MARGINS', .075, .065, .85, color: white);
      p.txt(
        custom ? copy.place : '문장을\n모으는 생활',
        .075,
        .15,
        .85,
        .29,
        size: .089,
        color: white,
        lineHeight: 1.35,
      );
      _coverShade(p, strength: .60);
      p.label(copy.byline, .075, .90, .52, color: white);
      p.label(copy.period, .65, .90, .28, color: white);
    case ConceptVolume.firstWardrobe:
      const ink = '#F9FBF4';
      _coverShade(p, top: true, strength: .27);
      p.label('LITTLE WARDROBE', .075, .062, .85, color: ink);
      p.txt(
        custom ? copy.place : '너의 작은\n옷장',
        .075,
        .15,
        .80,
        .265,
        size: .080,
        color: ink,
      );
      _coverShade(p, strength: .55);
      p.label(copy.byline, .075, .90, .52, color: ink);
      p.label(copy.period, .65, .90, .28, color: ink);
    case ConceptVolume.sundayPicnic:
      _coverShade(p, top: true, strength: .50);
      p.txt(
        'Sunday',
        .07,
        .065,
        .86,
        .17,
        size: .15,
        font: 'Cormorant Garamond',
        align: 'center',
        lineHeight: 1,
        color: white,
      );
      p.txt(
        'TOGETHER, OUTSIDE',
        .10,
        .25,
        .80,
        .05,
        size: .023,
        font: 'NotoSans',
        align: 'center',
        color: white,
      );
      _coverShade(p, strength: .67);
      p.txt(
        copy.place,
        .075,
        .775,
        .85,
        .12,
        size: .062,
        color: white,
        align: 'center',
      );
      p.txt(
        '${copy.period} / ${copy.byline}',
        .08,
        .917,
        .84,
        .04,
        size: .018,
        font: 'NotoSans',
        align: 'center',
        color: white,
      );
    case ConceptVolume.sharedSeasons:
      p.label('AT HOME, WITH YOU', .075, .065, .85, color: white);
      p.txt(
        custom ? copy.place : '같이 사는\n계절',
        .075,
        .15,
        .72,
        .27,
        size: .094,
        color: white,
      );
      p.rule(.075, .455, .20, color: white);
      _coverShade(p, strength: .60);
      p.label(copy.byline, .075, .90, .52, color: white);
      p.label(copy.period, .65, .90, .28, color: white);
    case ConceptVolume.littleCompanion:
      const ink = '#153D70';
      p.label('A LITTLE COMPANION', .075, .06, .85, color: ink);
      p.txt(
        custom ? copy.place : '작은\n동거인',
        .075,
        .16,
        .65,
        .26,
        size: .096,
        color: ink,
        font: 'NotoSans',
        weight: 600,
      );
      _coverShade(p, strength: .65);
      p.txt(
        'Side by side',
        .075,
        .825,
        .85,
        .083,
        size: .062,
        color: white,
        font: 'Cormorant Garamond',
      );
      p.label(copy.byline, .075, .925, .52, color: white);
      p.label(copy.period, .65, .925, .28, color: white);
  }
}

const _premiumCatalogCoverPhotos = {
  PremiumVolume.wedding: '${_editorial}cover_wedding_mono.png',
  PremiumVolume.travel: '${_samplePhotoRoot}alpine_lake.jpg',
  PremiumVolume.daily: '${_editorial}daily_desk.png',
  PremiumVolume.baby: '${_editorial}growth_keepsakes.png',
  PremiumVolume.family: '${_editorial}cover_family_supper.png',
  PremiumVolume.couple:
      'assets/templates/wedding_editorial/images/sources/hands_bw.png',
  PremiumVolume.pet: '${_editorial}cover_dog_rose.png',
};

Map<String, dynamic> _refinePremiumCatalogCover(
  PremiumVolume volume,
  CollectionAspect aspect,
  EditorialCopy copy,
  Map<String, dynamic> document,
) {
  final p = _Sheet(
    volume.id,
    aspect,
    0,
    '#FFFFFF',
    ink: volume.ink,
    display: volume.font,
  );
  p.photo('catalog_photo', _premiumCatalogCoverPhotos[volume]!, 0, 0, 1, 1);
  void title(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .082,
    String color = '#FFFFFF',
    String align = 'left',
  }) => p.text(
    'catalog_title',
    value,
    x,
    y,
    w,
    h,
    size: size,
    font: volume.font,
    color: color,
    align: align,
    lineHeight: 1.3,
  );
  void label(
    String id,
    String value,
    double x,
    double y,
    double w, {
    String color = '#FFFFFF',
    String align = 'left',
  }) => p.text(
    id,
    value,
    x,
    y,
    w,
    .048,
    size: .019,
    font: 'NotoSans',
    color: color,
    align: align,
  );
  final custom = copy.place != volume.title;
  switch (volume) {
    case PremiumVolume.wedding:
      const ink = '#242C2D';
      label('edition', 'A WEDDING JOURNAL', .075, .06, .85, color: ink);
      title(
        custom ? copy.place : '약속을\n묶은 책',
        .075,
        .15,
        .80,
        .27,
        size: .091,
        color: ink,
      );
      label('byline', copy.byline, .075, .90, .52, color: ink);
      label('period', copy.period, .65, .90, .28, color: ink);
    case PremiumVolume.travel:
      _coverShade(p, top: true, strength: .68);
      label('edition', 'AWAY TOGETHER', .08, .06, .84);
      title(copy.place, .08, .155, .84, .17, size: .090);
      _coverShade(p, strength: .58);
      label('byline', copy.byline, .08, .90, .52);
      label('period', copy.period, .66, .90, .26);
    case PremiumVolume.daily:
      const ink = '#273E43';
      label('edition', 'COLLECT THE EVERYDAY', .08, .06, .84, color: ink);
      _coverShade(p, strength: .65);
      title(custom ? copy.place : '하루의\n수집함', .08, .67, .84, .24, size: .082);
      label('byline', copy.byline, .08, .925, .52);
      label('period', copy.period, .66, .925, .26);
    case PremiumVolume.baby:
      const ink = '#3E6175';
      title(
        custom ? copy.place : '너의\n첫 계절',
        .08,
        .075,
        .84,
        .24,
        size: .086,
        color: ink,
      );
      label(
        'edition',
        'LITTLE THINGS, BIG MEMORIES',
        .08,
        .335,
        .84,
        color: ink,
      );
      label('byline', copy.byline, .08, .90, .52, color: ink);
      label('period', copy.period, .66, .90, .26, color: ink);
    case PremiumVolume.family:
      label('edition', 'AT OUR TABLE', .08, .058, .84, align: 'center');
      title(copy.place, .08, .15, .84, .16, size: .083, align: 'center');
      _coverShade(p, strength: .65);
      label('byline', copy.byline, .08, .92, .52);
      label('period', copy.period, .66, .92, .26);
    case PremiumVolume.couple:
      _coverShade(p, top: true, strength: .62);
      title(custom ? copy.place : '둘이 모은\n장면', .08, .08, .84, .26, size: .095);
      label('edition', 'TWO PEOPLE / ONE STORY', .08, .35, .84);
      _coverShade(p, strength: .55);
      label('byline', copy.byline, .08, .915, .52);
      label('period', copy.period, .66, .915, .26);
    case PremiumVolume.pet:
      const ink = '#562B32';
      title(
        custom ? copy.place : '산책하고\n낮잠',
        .08,
        .075,
        .84,
        .24,
        size: .082,
        color: ink,
      );
      label('edition', 'A WALK, A NAP, A GOOD DAY', .08, .335, .84, color: ink);
      _coverShade(p, strength: .50);
      label('byline', copy.byline, .08, .915, .52);
      label('period', copy.period, .66, .915, .26);
  }
  final photoId = p.layers.singleWhere((l) => l['type'] == 'image')['id'];
  for (final layer in p.layers.where((l) => l['type'] == 'text')) {
    layer['overlayImageId'] = photoId;
  }
  return {
    ...document,
    'coverRevision': catalogCoverRevision,
    'coverReview': 'pending-visual-approval',
    'cover': {
      ...document['cover'] as Map<String, dynamic>,
      ...p.json,
      'coverRevision': catalogCoverRevision,
    },
  };
}
