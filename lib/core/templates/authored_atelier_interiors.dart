part of 'authored_collections.dart';

void _atelierInteriorSpread(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  switch (l.edition) {
    case AtelierEdition.nightVows:
      _gardenInteriors(l, r, s, n);
    case AtelierEdition.slowRail:
      _railInteriors(l, r, s, n);
    case AtelierEdition.greenHours:
      _greenInteriors(l, r, s, n);
    case AtelierEdition.firstOrbit:
      _orbitInteriors(l, r, s, n);
    case AtelierEdition.tableStories:
      _kitchenInteriors(l, r, s, n);
    case AtelierEdition.privateCinema:
      _cinemaInteriors(l, r, s, n);
    case AtelierEdition.walkMap:
      _walkInteriors(l, r, s, n);
  }
  if (s.layout == _AtelierLayout.ledger) _atelierRecord(r, s, n);
}

void _interiorBody(
  _AtelierPage p,
  _AtelierStory s,
  double x,
  double y,
  double w, {
  double h = .145,
  double size = .027,
  String? color,
}) => p.txt(
  s.note,
  x,
  y,
  w,
  h,
  size: size,
  font: 'NotoSans',
  leading: 1.5,
  color: color,
);

void _interiorWord(
  _AtelierPage p,
  _AtelierStory s,
  double x,
  double y,
  double w, {
  double h = .15,
  double size = .082,
  String? color,
}) {
  final font = switch (p.edition) {
    AtelierEdition.slowRail => 'Poppins',
    AtelierEdition.firstOrbit => 'Yeongwol',
    AtelierEdition.tableStories => 'NanumPen',
    AtelierEdition.privateCinema => 'Raleway',
    AtelierEdition.walkMap => 'Poppins',
    _ => 'Cormorant Garamond',
  };
  _fittedEditorialType(
    p,
    p.uid,
    s.word,
    Rect.fromLTWH(x, y, w, h),
    font: font,
    size: size,
    color: color ?? p.ink,
    weight: font == 'Poppins' || font == 'Raleway' ? 600 : 400,
    leading: 1.1,
  );
}

void _gardenInteriors(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.pic(s.a, .055, .06, .89, .74, frame: 'studioGallery');
      l.mat('materialVellumBand', .10, .755, .55, .065);
      l.label('THE AISLE / $n', .13, .775, .52);
      r.headline(s.title, .09, .12, .82, .18, size: .068);
      r.scene(s.b, .34, .35, .56, .35, frame: 'studioOvalMat', photoRatio: 1);
      r.rule(.10, .51, .17, color: e.accent);
      _interiorBody(r, s, .10, .76, .80);
    case _AtelierLayout.montage:
      l.mat('studioCottonRag', .06, .18, .86, .56, turn: -1);
      l.scene(s.a, .08, .09, .74, .47, frame: 'signatureVowPocket', turn: -1.2);
      l.scene(s.b, .45, .53, .46, .30, frame: 'studioInstant', turn: 1.6);
      l.mat('studioSageRibbon', .08, .65, .24, .17, turn: -5);
      l.label('OUR PEOPLE / $n', .08, .85, .68);
      _interiorWord(r, s, .09, .10, .82, size: .086);
      r.headline(s.title, .09, .30, .82, .13, size: .055);
      r.scene(s.a, .11, .48, .42, .28, frame: 'studioPostage');
      _interiorBody(r, s, .59, .49, .31, h: .29, size: .024);
      r.label(s.record, .09, .84, .82);
    case _AtelierLayout.ledger:
      l.stock('heirloomVowPlaceCard', .07, .09, .56, .18, turn: -1);
      l.headline(s.title, .12, .13, .46, .10, size: .041);
      l.scene(s.a, .08, .29, .84, .48, frame: 'editionCameo');
      l.mat('studioOlivePress', .70, .64, .20, .18, turn: 8);
      _interiorBody(l, s, .09, .79, .70, size: .024);
    case _AtelierLayout.cameo:
      l.mat('materialLace', .035, .09, .80, .69);
      l.pic(s.a, .16, .17, .68, .55, frame: 'studioOvalMat');
      l.hand(s.word, .10, .80, .80);
      r.label('THE BOUQUET STUDY / $n', .10, .07, .80);
      r.headline(s.title, .10, .18, .80, .15, size: .064);
      r.scene(s.b, .41, .39, .47, .37, frame: 'editionScallop', photoRatio: 1);
      _interiorBody(r, s, .10, .42, .28, h: .31, size: .026);
      r.rule(.10, .82, .78, color: e.accent);
    case _AtelierLayout.panorama:
      l.pic(s.a, .035, .07, .93, .68);
      r.pic(s.b, 0, .22, .94, .64);
      l.headline(s.title, .07, .80, .86, .09, size: .043);
      r.label('THE GARDEN AT BLUE HOUR / $n', .08, .065, .84);
      _interiorBody(r, s, .08, .115, .84, h: .09, size: .023);
    case _AtelierLayout.triptych:
      l.label('A TOAST / $n', .08, .055, .84);
      l.scene(s.a, .07, .17, .86, .42, frame: 'studioDoubleMat');
      l.scene(s.b, .56, .58, .35, .28, frame: 'editionCameo', photoRatio: 1);
      l.hand('잔을 들기 전, 눈인사', .08, .68, .42);
      r.stock('atelierWritingVow', .08, .08, .84, .78);
      r.headline(s.title, .14, .16, .72, .17, size: .061);
      _interiorWord(r, s, .14, .395, .72, size: .095);
      _interiorBody(r, s, .14, .64, .72);
      r.mat('heirloomVowSeal', .70, .75, .13, .13);
    case _AtelierLayout.darkroom:
      _interiorWord(l, s, .08, .065, .84, size: .091, color: e.accent);
      l.pic(s.a, .065, .30, .87, .50, frame: 'studioPhotoCorners');
      l.label(s.record, .08, .845, .84);
      r.scene(s.b, .09, .07, .82, .52, frame: 'studioOval', photoRatio: 1);
      r.headline(s.title, .10, .65, .80, .10, size: .047);
      _interiorBody(r, s, .10, .79, .65, size: .025);
      r.mat('studioRoseSilk', .76, .76, .16, .13);
    case _AtelierLayout.correspondence:
      l.stock('atelierWritingVow', .055, .07, .89, .80, turn: -.5);
      l.label('A PROMISE IN OUR WORDS / $n', .14, .15, .72);
      l.headline(s.title, .14, .29, .72, .17, size: .062);
      _interiorBody(l, s, .14, .54, .69, h: .19, size: .034);
      l.hand('서연과 지우', .48, .76, .35);
      r.scene(s.b, .12, .08, .76, .55, frame: 'signatureVowPocket');
      r.mat('heirloomVowEnvelope', .09, .59, .56, .24, turn: -2);
      r.mat('heirloomVowSeal', .45, .70, .12, .12);
      r.label(s.record, .12, .85, .76);
    case _AtelierLayout.calendar:
      l.scene(s.a, .07, .065, .86, .55, frame: 'signatureVowPocket');
      l.headline(s.title, .09, .67, .82, .11, size: .054);
      l.label(s.record, .09, .825, .82);
      r.txt(
        '18',
        .09,
        .08,
        .35,
        .29,
        size: .24,
        font: 'Cormorant Garamond',
        leading: 1,
      );
      r.label('OCTOBER / THE MORNING AFTER', .47, .20, .43);
      r.scene(s.b, .38, .37, .52, .31, frame: 'studioGallery');
      r.mat('materialVellumBand', .08, .58, .37, .06);
      _interiorBody(r, s, .09, .76, .82);
    case _AtelierLayout.fieldnotes:
      l.pic(s.a, .06, .065, .88, .57, frame: 'studyFloatMount');
      l.headline(s.title, .09, .70, .82, .13, size: .052);
      r.stock('materialBlindEmboss', .09, .11, .80, .72);
      r.label('OFF CAMERA / $n', .16, .20, .67);
      _interiorBody(r, s, .16, .35, .65, h: .25, size: .034);
      r.scene(s.b, .50, .63, .39, .22, frame: 'studioInstant', turn: 1.5);
      r.mat('studioOlivePress', .12, .65, .23, .16);
    case _AtelierLayout.directory:
      l.label('THE PEOPLE & PLACES / $n', .08, .065, .84);
      l.scene(s.a, .08, .19, .43, .31, frame: 'studioPostage');
      l.scene(s.b, .49, .42, .42, .32, frame: 'studioPhotoCorners', turn: 1);
      l.headline(s.title, .08, .63, .36, .19, size: .048);
      r.stock('heirloomVowPlaceCard', .08, .16, .81, .24);
      _interiorWord(r, s, .13, .22, .70, size: .064, h: .12);
      _interiorBody(r, s, .10, .50, .80, h: .19, size: .031);
      r.label(s.record, .10, .81, .80);
    case _AtelierLayout.closing:
      l.pic(s.a, .045, .06, .91, .70, frame: 'studioDoubleMat');
      l.hand(s.word, .08, .81, .84);
      r.headline(s.title, .12, .18, .76, .22, size: .069);
      r.rule(.12, .46, .23, color: e.accent);
      _interiorBody(r, s, .12, .54, .76, h: .20, size: .030);
      r.mat('heirloomVowEnvelope', .56, .76, .31, .12);
    default:
      throw StateError('Unexpected garden spread: ${s.layout}');
  }
}

void _railInteriors(_AtelierPage l, _AtelierPage r, _AtelierStory s, String n) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.receipt:
      l.scene(s.a, .06, .075, .88, .50, frame: 'signatureRailWallet');
      l.scene(s.b, .51, .57, .39, .28, frame: 'studioPostage', turn: 1);
      l.hand(s.word, .09, .73, .38);
      l.label('A LONG LUNCH / $n', .09, .855, .80);
      r.stock('atelierWritingReceipt', .15, .10, .70, .77);
      r.label('BETWEEN TWO TRAINS', .23, .19, .54);
      r.headline(s.title, .23, .32, .54, .15, size: .052);
      r.label('오늘의 메뉴 / 파스타와 커피', .23, .52, .54);
      _interiorBody(r, s, .23, .62, .54, h: .16, size: .027);
    case _AtelierLayout.portrait:
      l.mat('travelContourSlip', .05, .08, .74, .75, turn: -1.5);
      l.pic(s.a, .17, .12, .74, .61, frame: 'studioGallery');
      l.mat('travelLuggageLabel', .10, .70, .43, .09, turn: -2);
      l.label(s.record, .10, .84, .80);
      _interiorWord(r, s, .08, .10, .84, size: .091);
      r.scene(s.b, .08, .34, .62, .40, frame: 'studioPostcard', turn: -1);
      r.headline(s.title, .73, .37, .19, .34, size: .040);
      _interiorBody(r, s, .09, .80, .82, size: .023);
    case _AtelierLayout.montage:
      l.scene(s.a, .05, .075, .88, .43, frame: 'atelierCornerFold');
      l.mat('travelMarketReceipt', .08, .51, .22, .32, turn: -2);
      l.scene(s.b, .38, .54, .52, .30, frame: 'studioPostage', turn: 1.2);
      r.headline(s.title, .08, .10, .84, .16, size: .062);
      r.stock('travelNotebook', .09, .32, .79, .52);
      _interiorBody(r, s, .16, .42, .64, h: .20, size: .032);
      r.label(s.record, .16, .72, .64);
    case _AtelierLayout.ledger:
      l.label('BETWEEN STATIONS / $n', .08, .065, .84);
      l.pic(s.a, .06, .17, .88, .48, frame: 'studioTicket');
      l.stock('travelDocumentPocket', .075, .61, .66, .18, turn: -1);
      l.headline(s.title, .11, .675, .57, .10, size: .040);
      _interiorBody(l, s, .09, .81, .82, h: .08, size: .022);
    case _AtelierLayout.cameo:
      l.mat('travelPostcard', .07, .10, .85, .64, turn: -1.5);
      l.scene(s.a, .14, .18, .73, .48, frame: 'studioDoubleMat');
      l.mat('studioPostalMark', .67, .64, .23, .14, turn: 2);
      l.hand(s.word, .08, .81, .84);
      r.pic(s.b, .10, .065, .44, .49, frame: 'studioPostage');
      r.label('A SMALL DETOUR / $n', .59, .09, .32);
      r.headline(s.title, .59, .24, .32, .29, size: .051);
      _interiorBody(r, s, .10, .68, .80, h: .18, size: .030);
    case _AtelierLayout.panorama:
      l.pic(s.a, 0, .06, 1, .59);
      r.pic(s.b, 0, .06, 1, .59);
      l.mat('travelLuggageLabel', .07, .61, .42, .10);
      l.headline(s.title, .08, .76, .84, .11, size: .051);
      r.label('SEEN THROUGH THE WINDOW / $n', .08, .70, .84);
      _interiorBody(r, s, .08, .78, .84, h: .10, size: .025);
    case _AtelierLayout.triptych:
      l.mat('travelPhotoSleeve', .055, .08, .89, .60);
      l.scene(s.a, .09, .105, .43, .32, frame: 'studioPhotoCorners');
      l.scene(s.b, .49, .33, .42, .32, frame: 'studioDoubleMat', turn: 1.4);
      l.mat('travelStayTag', .10, .61, .14, .19, turn: -3);
      l.label('TWO STOPS / $n', .31, .78, .59);
      _interiorWord(r, s, .09, .09, .82, size: .082);
      r.headline(s.title, .09, .30, .82, .16, size: .058);
      r.scene(s.b, .36, .51, .53, .25, frame: 'studioPostcard');
      _interiorBody(r, s, .09, .79, .82, h: .10, size: .024);
    case _AtelierLayout.darkroom:
      l.pic(s.a, .065, .10, .87, .61, frame: 'studioPhotoCorners');
      l.headline(s.title, .09, .76, .82, .12, size: .049);
      r.stock('travelNotebook', .09, .10, .80, .73);
      r.label('AFTER THE LAST TRAIN / $n', .16, .19, .65, color: e.ink);
      _interiorWord(r, s, .16, .32, .65, size: .074, h: .18, color: e.ink);
      _interiorBody(r, s, .16, .56, .64, h: .19, size: .029, color: e.ink);
      r.mat('travelCafeReceipt', .66, .67, .17, .19, turn: 3);
    case _AtelierLayout.correspondence:
      l.scene(s.a, .08, .07, .84, .48, frame: 'signatureRailWallet');
      l.stock('travelPostcard', .10, .57, .78, .29, turn: 1);
      l.headline(s.title, .16, .63, .66, .09, size: .043);
      l.label(s.record, .16, .76, .66);
      r.stock('travelNotebook', .055, .07, .89, .79);
      _interiorWord(r, s, .14, .15, .70, size: .073, h: .18);
      _interiorBody(r, s, .14, .40, .68, h: .24, size: .035);
      r.mat('studioCoastStamp', .64, .68, .18, .17, turn: -4);
    case _AtelierLayout.calendar:
      l.label('ONE DAY, ONE TOWN / $n', .08, .06, .84);
      l.scene(s.a, .06, .17, .70, .43, frame: 'studioGallery');
      l.mat('travelCafeCoaster', .66, .52, .23, .20);
      l.headline(s.title, .09, .72, .82, .14, size: .054);
      r.txt('09:40', .09, .09, .82, .20, size: .13, font: 'Cormorant Garamond');
      r.rule(.09, .35, .82, color: e.accent);
      r.scene(s.b, .36, .43, .54, .31, frame: 'studioInstant', turn: -1);
      _interiorBody(r, s, .09, .45, .23, h: .30, size: .025);
      r.label(s.record, .09, .83, .82);
    case _AtelierLayout.fieldnotes:
      l.mat('materialContourMap', .045, .075, .91, .75);
      l.pic(s.a, .11, .15, .73, .53, frame: 'signatureRailWallet', turn: -1);
      l.mat('materialTransitPunch', .72, .62, .14, .20, turn: 4);
      l.hand(s.word, .10, .80, .60);
      r.label('OFF THE TIMETABLE / $n', .09, .08, .82);
      r.headline(s.title, .09, .21, .82, .17, size: .064);
      _interiorBody(r, s, .09, .44, .82, h: .18, size: .034);
      r.scene(s.b, .50, .68, .40, .18, frame: 'studioPostage');
      r.mat('studioPostalMark', .10, .72, .26, .12);
    case _AtelierLayout.directory:
      l.label('THE RETURN ROUTE / $n', .08, .065, .84);
      l.headline(s.title, .08, .19, .42, .22, size: .063);
      l.pic(s.a, .54, .16, .36, .48, frame: 'studioPhotoCorners');
      l.mat('studioTravelTicket', .08, .56, .48, .15, turn: -2);
      _interiorBody(l, s, .09, .77, .82, h: .12, size: .025);
      r.scene(s.b, .06, .07, .88, .56, frame: 'atelierCornerFold');
      r.mat('travelLuggageLabel', .10, .59, .43, .11, turn: 1);
      _interiorWord(r, s, .10, .76, .80, size: .061, h: .13);
    case _AtelierLayout.closing:
      l.pic(s.a, .045, .07, .91, .64, frame: 'studyFloatMount');
      l.mat('studioCoastStamp', .73, .65, .15, .17, turn: -2);
      l.label(s.record, .08, .84, .65);
      r.scene(s.b, .10, .09, .80, .43, frame: 'studioPhotoCorners');
      r.headline(s.title, .10, .58, .80, .14, size: .057);
      _interiorBody(r, s, .10, .77, .80, h: .13, size: .027);
    default:
      throw StateError('Unexpected rail spread: ${s.layout}');
  }
}

void _greenInteriors(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.pic(s.a, .06, .08, .88, .68, frame: 'studyArchWindow');
      l.mat('studioPressedCosmos', .70, .65, .18, .18);
      l.label('A PLACE FOR GREEN / $n', .09, .83, .78);
      r.headline(s.title, .09, .15, .82, .18, size: .065);
      r.scene(s.b, .10, .40, .60, .34, frame: 'studioDeckle');
      _interiorBody(r, s, .10, .79, .80, size: .025);
    case _AtelierLayout.montage:
      l.mat('materialSpecimenPocket', .045, .08, .88, .78, turn: -1);
      l.pic(
        s.a,
        .11,
        .13,
        .70,
        .50,
        frame: 'signatureHerbariumSleeve',
        turn: -1,
      );
      l.scene(s.b, .51, .56, .38, .25, frame: 'studioPostage', turn: 1.6);
      l.mat('materialIndexTabs', .12, .72, .29, .06);
      l.label(s.record, .10, .845, .78);
      r.headline(s.title, .09, .10, .82, .16, size: .065);
      r.scene(s.b, .12, .33, .52, .36, frame: 'studioDeckle');
      r.mat('studioOlivePress', .67, .41, .21, .22, turn: 4);
      _interiorBody(r, s, .09, .76, .82, size: .027);
    case _AtelierLayout.ledger:
      l.mat('atelierGridLeaf', .06, .11, .87, .67);
      l.pic(s.a, .105, .17, .76, .47, frame: 'studioDoubleMat');
      l.mat('studioWashiSage', .60, .125, .25, .055, turn: 2);
      l.headline(s.title, .10, .71, .80, .11, size: .049);
      l.label(s.record, .10, .85, .80);
    case _AtelierLayout.cameo:
      l.pic(s.a, .08, .09, .84, .70, frame: 'studioOvalMat');
      l.label('A NEW LEAF / $n', .10, .845, .80);
      r.stock('studioCotton', .055, .13, .88, .65, turn: -1);
      r.headline(s.title, .13, .23, .73, .16, size: .061);
      _interiorBody(r, s, .13, .46, .40, h: .26, size: .030);
      r.scene(s.b, .59, .44, .28, .27, frame: 'studioPostage', photoRatio: 1);
      r.mat('studioPressedCosmos', .61, .71, .18, .16);
    case _AtelierLayout.panorama:
      l.pic(s.a, .04, .08, .96, .72);
      r.pic(s.b, 0, .25, .92, .63);
      l.label('THE GARDEN BEYOND OUR WINDOW / $n', .08, .845, .84);
      r.headline(s.title, .08, .065, .84, .12, size: .048);
    case _AtelierLayout.triptych:
      l.headline(s.title, .08, .08, .84, .14, size: .058);
      l.scene(s.a, .09, .28, .48, .38, frame: 'studioDeckle', photoRatio: 1);
      l.scene(s.b, .56, .51, .34, .28, frame: 'studioScallop', photoRatio: 1);
      l.mat('studioWashiSage', .08, .74, .30, .065, turn: -2);
      r.mat('materialLinen', .06, .11, .88, .65);
      r.scene(s.b, .13, .18, .74, .47, frame: 'studioGallery');
      _interiorBody(r, s, .10, .77, .80, size: .027);
    case _AtelierLayout.darkroom:
      l.pic(s.a, .07, .08, .86, .64, frame: 'studioPhotoCorners');
      l.hand(s.word, .10, .79, .80);
      r.stock('atelierWritingRecord', .10, .12, .78, .71);
      r.label('BEFORE THE LIGHTS GO OUT / $n', .17, .23, .64, color: e.ink);
      r.headline(s.title, .17, .35, .64, .16, size: .056, color: e.ink);
      _interiorBody(r, s, .17, .57, .64, h: .19, size: .029, color: e.ink);
    case _AtelierLayout.correspondence:
      l.stock('studioCotton', .065, .16, .86, .63);
      _interiorWord(l, s, .13, .24, .73, size: .068, h: .16);
      _interiorBody(l, s, .13, .49, .71, h: .20, size: .034);
      l.mat('studioOlivePress', .65, .70, .22, .16);
      r.scene(s.b, .08, .08, .70, .61, frame: 'signatureHerbariumSleeve');
      r.mat('materialSpecimenPocket', .57, .58, .31, .24, turn: 2);
      r.headline(s.title, .10, .78, .77, .11, size: .046);
    case _AtelierLayout.calendar:
      l.scene(s.a, .07, .085, .86, .51, frame: 'signatureHerbariumSleeve');
      l.headline(s.title, .09, .67, .82, .13, size: .054);
      l.mat('materialIndexTabs', .54, .79, .30, .07);
      r.label('A MONTH OF WATCHING / $n', .09, .08, .82);
      r.txt(
        '30',
        .09,
        .20,
        .42,
        .26,
        size: .21,
        font: 'Cormorant Garamond',
        leading: 1,
      );
      r.scene(s.b, .55, .22, .34, .27, frame: 'studioOval', photoRatio: 1);
      r.label('DAYS / 하루씩 살펴본 기록', .10, .51, .80);
      _interiorBody(r, s, .10, .64, .80, h: .20, size: .031);
    case _AtelierLayout.fieldnotes:
      l.pic(s.a, .055, .06, .89, .73, frame: 'studyFloatMount');
      l.label(s.record, .09, .84, .82);
      r.headline(s.title, .08, .10, .84, .18, size: .066);
      r.scene(s.b, .11, .36, .46, .35, frame: 'studioPostage');
      r.mat('studioOlivePress', .61, .40, .23, .25, turn: 3);
      _interiorBody(r, s, .09, .76, .82, size: .027);
    case _AtelierLayout.directory:
      l.mat('materialSpecimenPocket', .05, .095, .62, .70);
      l.pic(s.a, .11, .17, .49, .47, frame: 'studioDeckle');
      l.pic(s.b, .58, .43, .32, .37, frame: 'studioOvalMat');
      l.label('NEXT SEASON / $n', .09, .84, .82);
      _interiorWord(r, s, .10, .11, .80, size: .094);
      r.headline(s.title, .10, .34, .80, .17, size: .060);
      r.rule(.10, .58, .26, color: e.accent);
      _interiorBody(r, s, .10, .68, .80, h: .20, size: .030);
    case _AtelierLayout.closing:
      l.label('THE GARDEN CONTINUES / $n', .10, .10, .80);
      l.headline(s.title, .10, .24, .80, .22, size: .068);
      _interiorBody(l, s, .10, .55, .76, h: .21, size: .032);
      l.mat('studioBotanicalStamp', .70, .76, .15, .12, turn: -4);
      r.pic(s.a, .08, .08, .84, .67, frame: 'studioPhotoCorners');
      r.hand(s.word, .10, .82, .80);
    default:
      throw StateError('Unexpected herbarium spread: ${s.layout}');
  }
}
