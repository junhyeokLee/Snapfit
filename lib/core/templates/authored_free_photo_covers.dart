part of 'authored_collections.dart';

const _freePhotoCoverVolumes = {
  FreeCollectionVolume.vows,
  FreeCollectionVolume.cinema,
  FreeCollectionVolume.seaside,
  FreeCollectionVolume.city,
  FreeCollectionVolume.weekend,
  FreeCollectionVolume.firstYear,
  FreeCollectionVolume.familyOuting,
  FreeCollectionVolume.loveSeason,
  FreeCollectionVolume.petPortrait,
};

void _freePhotoCover(_FreeBook b) {
  final p = b.sheet();
  final file = _freeCoverPhotos[b.volume]!;
  // Cover photography fills the print ratio without a decorative frame. Keep
  // it in the usage ledger so the first spread does not repeat the cover.
  b._photoSpread = 0;
  b._spreadPhotos.add(file);
  b._photoUses[file] = 1;
  p.photo('full_photo_cover', _freePhotoPath(file), 0, 0, 1, 1);
  const white = '#FFFFFF';
  void shade({bool top = false, double strength = .64}) {
    // One editable gradient is shared by the preview, editor and export.
    p._add(
      'scrim_${top ? 'top' : 'bottom'}',
      'decoration',
      0,
      top ? 0 : .52,
      1,
      .48,
      {
        'style': top ? 'photoCoverShadeTop' : 'photoCoverShadeBottom',
        'opacity': strength,
      },
    );
  }

  void label(
    String id,
    String value,
    double x,
    double y,
    double w, {
    String color = white,
    String align = 'left',
  }) => p.text(
    id,
    value,
    x,
    y,
    w,
    .048,
    size: .022,
    color: color,
    align: align,
    lineHeight: 1.3,
  );
  void title(
    String value,
    double x,
    double y,
    double w,
    double h, {
    double size = .084,
    String color = white,
    String align = 'left',
  }) => p.title(
    value,
    x: x,
    y: y,
    w: w,
    h: h,
    size: size,
    color: color,
    align: align,
  );

  switch (b.volume) {
    case FreeCollectionVolume.vows:
      shade(strength: .66);
      label('date', b.copy.period, .08, .075, .84);
      title('우리의\n서약', .08, .65, .84, .24, size: .092);
      label('names', b.copy.byline, .08, .905, .84);
      p.box('vow_line', .08, .63, .13, .002, white);
    case FreeCollectionVolume.cinema:
      shade(top: true, strength: .26);
      if (b.aspect == CollectionAspect.landscape) {
        label('film_edition', 'OUR FIRST FILM', .065, .055, .30);
        title('영화 같던\n하루', .065, .125, .30, .255, size: .083);
      } else {
        label(
          'film_edition',
          'OUR FIRST FILM',
          .085,
          .03,
          .83,
          align: 'center',
        );
        title('영화 같던 하루', .085, .105, .83, .105, size: .083, align: 'center');
      }
      shade(strength: .52);
      label('film_names', b.copy.byline, .085, .857, .83, align: 'center');
      label('film_date', b.copy.period, .085, .917, .83, align: 'center');
    case FreeCollectionVolume.seaside:
      shade(top: true, strength: .52);
      title('바다를\n건너', .085, .085, .83, .26, size: .103);
      label('sea_date', b.copy.period, .085, .35, .83);
      shade(strength: .42);
      label('sea_names', b.copy.byline, .085, .906, .83);
    case FreeCollectionVolume.city:
      shade(strength: .78);
      label('city_date', b.copy.period, .075, .065, .85, color: '#243942');
      title('도시의\n수집가', .075, .671, .85, .226, size: .088);
      label('city_place', b.copy.place, .075, .912, .85);
      p.box('city_rule', .075, .64, .85, .0015, white);
    case FreeCollectionVolume.weekend:
      title('주말의\n온도', .08, .075, .84, .235, size: .09, color: b.palette.ink);
      label(
        'weekend_date',
        b.copy.period,
        .08,
        .325,
        .84,
        color: b.palette.ink,
      );
      shade(strength: .60);
      label('weekend_names', b.copy.byline, .08, .91, .84);
    case FreeCollectionVolume.firstYear:
      title(
        '너의 첫해',
        .08,
        .052,
        .84,
        .10,
        size: .069,
        color: b.palette.ink,
        align: 'center',
      );
      label(
        'first_year_date',
        b.copy.period,
        .08,
        .891,
        .84,
        color: b.palette.ink,
        align: 'center',
      );
      label(
        'first_year_names',
        b.copy.byline,
        .08,
        .944,
        .84,
        color: b.palette.ink,
        align: 'center',
      );
    case FreeCollectionVolume.familyOuting:
      shade(strength: .76);
      label('picnic_date', b.copy.period, .09, .075, .82);
      title('함께 떠난 소풍', .09, .777, .82, .105, size: .068);
      label('picnic_names', b.copy.byline, .09, .909, .82);
      p.box('picnic_rule', .09, .751, .10, .003, white);
    case FreeCollectionVolume.loveSeason:
      shade(strength: .68);
      title('사랑이 머문\n계절', .10, .685, .80, .205, size: .076);
      label('season_names', b.copy.byline, .10, .917, .80);
      label('season_date', b.copy.period, .10, .063, .80);
    case FreeCollectionVolume.petPortrait:
      shade(strength: .76);
      title('가장 다정한\n얼굴', .07, .681, .86, .209, size: .082);
      label('portrait_names', b.copy.byline, .07, .915, .86);
      label(
        'portrait_date',
        b.copy.period,
        .07,
        .067,
        .86,
        color: b.palette.ink,
      );
    default:
      throw StateError('Unknown photographic cover: ${b.volume.id}');
  }
  b.pages.add({
    ...p.json,
    'name': '사진으로 여는 표지',
    'role': '${b.volume.id}-photographic-cover',
    'spreadIndex': 0,
    'side': 'cover',
  });
}
