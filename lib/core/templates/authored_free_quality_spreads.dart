part of 'authored_collections.dart';

/// Editorial photo slots and copy remain separate, fully editable layers.
bool _freeQualitySpread(
  _FreeBook b,
  _FreeSpread story,
  _Sheet left,
  _Sheet right,
  String chapter,
) {
  void label(_Sheet p, String value, double x, double y, double w) => b.text(
    p,
    'quality_label_${p.layers.length}',
    value,
    x,
    y,
    w,
    .052,
    size: .021,
    color: b.palette.accent,
  );
  void caption(_Sheet p, double x, double y, double w, double h) =>
      b.text(p, 'quality_caption', story.caption, x, y, w, h, size: .027);
  void title(
    _Sheet p,
    double x,
    double y,
    double w,
    double h, {
    double size = .074,
  }) => b.title(p, story.line, x, y, w, h, size: size);
  void photo(
    _Sheet p,
    int source,
    double x,
    double y,
    double w,
    double h, {
    String frame = 'none',
  }) => b.photo(
    p,
    'quality_photo_${p.layers.length}',
    source,
    x,
    y,
    w,
    h,
    frame: frame,
  );
  switch (story.layout) {
    case _FreeLayout.opening:
      label(left, chapter, .085, .09, .83);
      title(left, .085, .24, .83, .245, size: .085);
      b.rule(left, .085, .53, .15);
      caption(left, .085, .605, .45, .17);
      photo(
        left,
        story.detail,
        .625,
        .60,
        .285,
        .23,
        frame: 'studioPhotoCorners',
      );
      photo(right, story.photo, .045, .06, .91, .77);
      label(right, '사진으로 남긴 첫 장면', .085, .863, .83);
    case _FreeLayout.gallery:
      label(left, chapter, .07, .085, .86);
      photo(left, story.photo, .07, .20, .86, .605);
      caption(left, .07, .855, .86, .055);
      photo(
        right,
        story.detail,
        .08,
        .10,
        .49,
        .37,
        frame: 'studioPhotoCorners',
      );
      label(right, '01 / 가까이 본 장면', .08, .497, .49);
      title(right, .64, .135, .28, .285, size: .041);
      b.rule(right, .08, .57, .84);
      photo(right, story.photo + 2, .31, .625, .61, .255);
      label(right, '02', .08, .65, .14);
    case _FreeLayout.paired:
      label(left, chapter, .08, .085, .84);
      photo(left, story.photo, .08, .205, .84, .485);
      title(left, .08, .755, .84, .15, size: .049);
      photo(
        right,
        story.detail,
        .13,
        .10,
        .74,
        .64,
        frame: b.palette.serif ? 'studioGallery' : 'studioPhotoCorners',
      );
      b.rule(right, .13, .792, .13);
      caption(right, .32, .789, .55, .115);
    case _FreeLayout.window:
      label(left, chapter, .09, .09, .82);
      photo(
        left,
        story.detail,
        .20,
        .225,
        .60,
        .405,
        frame: b.palette.frame == 'none' ? 'studioArch' : b.palette.frame,
      );
      title(left, .12, .725, .76, .18, size: .057);
      photo(right, story.photo, .055, .08, .89, .735);
      caption(right, .095, .851, .81, .055);
    case _FreeLayout.contact:
      label(left, chapter, .07, .09, .86);
      for (var i = 0; i < 4; i++) {
        photo(
          left,
          story.photo + i,
          .07 + (i % 2) * .445,
          .235 + (i ~/ 2) * .305,
          .405,
          .25,
          frame: b.volume == FreeCollectionVolume.cinema
              ? 'studioFilm'
              : 'studioPhotoCorners',
        );
      }
      caption(left, .07, .858, .86, .055);
      title(right, .10, .13, .80, .235, size: .079);
      b.rule(right, .10, .425, .16);
      photo(right, story.detail, .10, .515, .80, .33);
      label(right, '함께 모아 둔 장면들', .10, .868, .80);
    case _FreeLayout.letter:
      label(left, chapter, .10, .09, .80);
      title(left, .10, .205, .80, .22, size: .069);
      b.rule(left, .10, .468, .16);
      b.text(
        left,
        'quality_letter',
        b.copy.note,
        .10,
        .53,
        .80,
        .325,
        size: .026,
      );
      photo(
        right,
        story.photo,
        .10,
        .10,
        .80,
        .58,
        frame: 'studioPhotoCorners',
      );
      caption(right, .10, .735, .80, .105);
      label(right, b.copy.byline, .10, .865, .80);
    case _FreeLayout.panorama:
      label(left, chapter, .065, .09, .87);
      photo(left, story.photo, .045, .235, .91, .51);
      caption(left, .065, .825, .87, .085);
      title(right, .085, .12, .83, .265, size: .081);
      b.rule(right, .085, .446, .14);
      photo(right, story.detail, .085, .54, .48, .32, frame: 'studioGallery');
      photo(
        right,
        story.detail + 2,
        .64,
        .665,
        .275,
        .195,
        frame: 'studioPhotoCorners',
      );
    case _FreeLayout.closing:
      label(left, chapter, .10, .09, .80);
      title(left, .10, .245, .80, .24, size: .081);
      b.rule(left, .10, .55, .17);
      b.text(
        left,
        'quality_closing_letter',
        b.copy.note,
        .10,
        .615,
        .80,
        .26,
        size: .0225,
      );
      photo(right, story.photo, .10, .10, .80, .60);
      b.text(
        right,
        'quality_signature',
        b.copy.byline,
        .10,
        .77,
        .80,
        .065,
        size: .031,
        align: 'center',
      );
      b.text(
        right,
        'quality_date',
        b.copy.period,
        .10,
        .865,
        .80,
        .045,
        size: .021,
        align: 'center',
      );
    case _FreeLayout.ribbonPair:
      label(left, chapter, .09, .09, .82);
      photo(left, story.photo, .08, .225, .84, .455);
      title(left, .09, .755, .82, .15, size: .052);
      photo(right, story.detail, .15, .10, .70, .60, frame: 'studioGallery');
      right.material(
        'quality_ribbon',
        'studioSageRibbon',
        .72,
        .67,
        .14,
        h: .095,
      );
      caption(right, .15, .80, .70, .105);
    case _FreeLayout.portraitEssay:
      label(left, chapter, .09, .09, .82);
      photo(left, story.photo, .07, .21, .86, .57);
      caption(left, .09, .838, .82, .075);
      title(right, .11, .14, .78, .235, size: .079);
      b.rule(right, .11, .44, .16);
      b.text(
        right,
        'quality_essay',
        '다시 꺼내 보고 싶은\n오늘의 한 장.',
        .11,
        .555,
        .33,
        .185,
        size: .031,
      );
      photo(
        right,
        story.detail,
        .51,
        .535,
        .38,
        .32,
        frame: 'studioPhotoCorners',
      );
    default:
      return false;
  }
  return true;
}
