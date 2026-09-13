part of 'authored_collections.dart';

const approvedConceptVolumes = {
  ConceptVolume.silkVows,
  ConceptVolume.shoreDays,
  ConceptVolume.readingRoom,
  ConceptVolume.sharedSeasons,
};
const lifeConceptVolumes = [
  ConceptVolume.firstWardrobe,
  ConceptVolume.sundayPicnic,
  ConceptVolume.sharedSeasons,
  ConceptVolume.littleCompanion,
];

void _lifeConceptCover(_ConceptBook b) =>
    b.add('full-photo-cover', '#FFFFFF', (p) {
      p.pic(b.volume.coverPhoto, 0, 0, 1, 1);
      p.box('cover_scrim', 0, 0, 1, 1, '#132124');
      p.layers.last['opacity'] = .25;
      final (eyebrow, title, subtitle, top) = switch (b.volume) {
        ConceptVolume.firstWardrobe => (
          'A LITTLE WARDROBE / 04',
          '너의\n작은 옷장',
          '금세 자라 버린 너의 첫 계절',
          .12,
        ),
        ConceptVolume.sundayPicnic => (
          'SUNDAY PICNIC / 05',
          '일요일의\n피크닉',
          '함께 앉아 오래 웃은 날',
          .12,
        ),
        ConceptVolume.sharedSeasons => (
          'OUR SHARED SEASONS / 06',
          '같이 사는\n계절',
          '둘이서 채워 가는 평범한 날들',
          .58,
        ),
        ConceptVolume.littleCompanion => (
          'A LITTLE COMPANION / 07',
          '작은\n동거인',
          '너와 나의 생활 관찰집',
          .57,
        ),
        _ => throw StateError('Not a life concept'),
      };
      p.label(eyebrow, .075, .045, .85, color: '#FFFFFF');
      p.rule(.075, .106, .85, color: '#FFFFFF');
      p.txt(
        b.copy.place == b.volume.title ? title : b.copy.place,
        .075,
        top,
        .85,
        .24,
        size: .082,
        color: '#FFFFFF',
      );
      if (top < .5)
        p.txt(
          subtitle,
          .08,
          .39,
          .8,
          .085,
          size: .028,
          font: 'NotoSans',
          color: '#FFFFFF',
        );
      p.label(b.copy.byline, .08, .85, .83, color: '#FFFFFF');
      p.label(b.copy.period, .08, .92, .83, color: '#FFFFFF');
    }, cover: true);

extension _LifeConceptLayers on _ConceptPage {
  /// Layered photographic board with an independent caption strip.
  void board(
    String file,
    double x,
    double y,
    double w,
    double h, {
    String stock = '#F8F7F2',
    String edge = '#52645F',
    String? caption,
    bool groupPhoto = false,
  }) {
    box(uid, x + .008, y + .009, w, h, '#BBC1BB');
    box(uid, x, y, w, h, edge);
    box(uid, x + .007, y + .007, w - .014, h - .014, stock);
    final captionHeight = caption == null ? .02 : .10;
    final px = x + .025, py = y + .025;
    final pw = w - .05, ph = h - .025 - captionHeight;
    if (groupPhoto) {
      group(file, px, py, pw, ph);
    } else {
      pic(file, px, py, pw, ph);
    }
    if (caption != null) {
      label(caption, x + .035, y + h - .072, w - .07, color: edge);
    }
  }

  void ledger(
    String key,
    String value,
    double x,
    double y,
    double w, {
    String? color,
  }) {
    label(key, x, y, w * .31, color: color);
    txt(
      value,
      x + w * .35,
      y,
      w * .65,
      .065,
      size: .025,
      color: color,
      font: 'NotoSans',
    );
    rule(x, y + .081, w, color: color);
  }

  void edgeStitches(double x, double y, double w, double h, String color) {
    for (var t = .012; t < w - .012; t += .028) {
      box(uid, x + t, y, .012, .0014 * ratio, color);
      box(uid, x + t, y + h, .012, .0014 * ratio, color);
    }
    for (var t = .014; t < h - .014; t += .026) {
      box(uid, x, y + t, .0014, .010, color);
      box(uid, x + w, y + t, .0014, .010, color);
    }
  }

  /// Opaque paper label over a photograph; overlap is explicitly recorded.
  void photoLabel(
    String value,
    double x,
    double y,
    double w,
    double h, {
    String paper = '#FAF9F4',
    String? color,
    double size = .028,
  }) {
    box(uid, x, y, w, h, paper);
    txt(
      value,
      x + .018,
      y + .015,
      w - .036,
      h - .025,
      size: size,
      color: color,
      font: 'NotoSans',
    );
    _photoTextIds.add(layers.last['id'] as String);
  }

  // Group portraits retain their full 3:2 composition in every album shape.
  Rect group(
    String file,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
  }) {
    final width = math.min(w, h * 1.5 / ratio),
        height = math.min(h, w * ratio / 1.5);
    final rect = Rect.fromLTWH(
      x + (w - width) / 2,
      y + (h - height) / 2,
      width,
      height,
    );
    pic(file, rect.left, rect.top, rect.width, rect.height, frame: frame);
    return rect;
  }

  Rect note(
    String material,
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .027,
  }) {
    final card = mat(material, x, y, w, h);
    paperText(card, value, .14, .28, .73, .55, size: size);
    return card;
  }

  void recipe(
    String ingredients,
    String instructions,
    double x,
    double y,
    double w,
    double h,
  ) {
    final card = mat('materialRecipeFoldout', x, y, w, h);
    paperText(card, ingredients, .09, .33, .23, .54, size: .023);
    paperText(card, instructions, .44, .33, .49, .54, size: .024);
  }
}
