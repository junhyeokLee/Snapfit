part of 'authored_collections.dart';

void _orbitInteriors(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.mat('studioBlueFibre', .035, .13, .93, .63, turn: -1);
      l.scene(s.a, .11, .09, .77, .66, frame: 'signatureOrbitQuilt');
      l.mat('lifeWardrobeLabel', .14, .72, .36, .10);
      l.label('A PORTRAIT OF YOU / $n', .13, .85, .75);
      r.headline(s.title, .10, .13, .80, .19, size: .067);
      r.scene(s.b, .41, .38, .47, .36, frame: 'studioOvalMat', photoRatio: 1);
      _interiorBody(r, s, .10, .77, .80, h: .12, size: .026);
    case _AtelierLayout.montage:
      l.mat('materialScallopNote', .045, .13, .86, .68, turn: -1);
      l.scene(s.a, .09, .09, .72, .46, frame: 'studioInstant', turn: -1);
      l.scene(s.b, .49, .53, .42, .28, frame: 'studioPhotoCorners', turn: 1.5);
      l.mat('lifeRattle', .07, .63, .21, .19, turn: -4);
      l.label('THE LITTLE THINGS / $n', .10, .855, .80);
      r.headline(s.title, .09, .08, .82, .17, size: .063);
      r.scene(s.b, .16, .33, .68, .36, frame: 'studioOval', photoRatio: 1.3);
      _interiorBody(r, s, .10, .76, .80, size: .027);
    case _AtelierLayout.ledger:
      l.label('FIRST TIMES / $n', .10, .07, .80);
      l.pic(s.a, .09, .19, .82, .48, frame: 'studioRounded');
      l.mat('heirloomGrowthRuler', .08, .635, .80, .10, turn: -.5);
      l.headline(s.title, .10, .77, .80, .12, size: .047);
    case _AtelierLayout.cameo:
      l.scene(
        s.a,
        .08,
        .10,
        .84,
        .65,
        frame: 'materialLinenOval',
        photoRatio: 1,
      );
      l.mat('materialBooties', .67, .65, .21, .18, turn: 3);
      l.label('SMALL ENOUGH TO HOLD / $n', .10, .845, .78);
      r.headline(s.title, .11, .15, .78, .18, size: .064);
      r.stock('materialScallopNote', .09, .41, .44, .39);
      _interiorBody(r, s, .15, .49, .31, h: .26, size: .027);
      r.scene(s.b, .58, .46, .30, .30, frame: 'studioOval', photoRatio: 1);
    case _AtelierLayout.panorama:
      l.pic(s.a, .035, .14, .965, .66);
      r.pic(s.b, 0, .065, .93, .62);
      l.label('THE WORLD AT YOUR HEIGHT / $n', .09, .065, .82);
      r.headline(s.title, .09, .735, .82, .14, size: .051);
    case _AtelierLayout.triptych:
      l.txt(
        '12',
        .09,
        .07,
        .44,
        .31,
        size: .24,
        font: 'Cormorant Garamond',
        leading: 1,
      );
      l.label('MONTHS OF DISCOVERY / $n', .49, .19, .40);
      l.scene(s.a, .10, .43, .57, .38, frame: 'studioScallop', photoRatio: 1);
      l.mat('lifeBib', .69, .57, .18, .20, turn: 3);
      r.scene(s.b, .08, .08, .84, .52, frame: 'studioGallery');
      r.headline(s.title, .10, .665, .80, .11, size: .050);
      _interiorBody(r, s, .10, .80, .80, h: .09, size: .023);
    case _AtelierLayout.darkroom:
      l.label('WHILE YOU WERE SLEEPING / $n', .08, .065, .84);
      l.pic(s.a, .08, .18, .84, .58, frame: 'studioPhotoCorners');
      l.hand(s.word, .10, .82, .80);
      r.stock('studioCotton', .08, .13, .83, .63);
      r.headline(s.title, .15, .23, .69, .17, size: .059, color: e.ink);
      _interiorBody(r, s, .15, .48, .67, h: .21, size: .031, color: e.ink);
      r.mat('lifeBonnet', .66, .70, .19, .17, turn: 2);
    case _AtelierLayout.correspondence:
      l.stock('atelierWritingVow', .10, .09, .79, .77);
      l.label('A LETTER TO YOU / $n', .17, .18, .65);
      l.headline(s.title, .17, .30, .64, .16, size: .058);
      _interiorBody(l, s, .17, .52, .63, h: .23, size: .032);
      r.scene(s.b, .12, .10, .76, .57, frame: 'signatureOrbitQuilt');
      r.mat('studioGlassineEnvelope', .10, .62, .31, .23, turn: -2);
      r.hand('나중에 같이 읽어 보자', .44, .78, .44);
    case _AtelierLayout.calendar:
      l.mat('materialMonthDial', .08, .14, .69, .62);
      l.scene(s.a, .27, .34, .62, .44, frame: 'studioOvalMat', photoRatio: 1);
      l.label(s.record, .09, .84, .82);
      r.label('THIS MONTH WITH YOU / $n', .10, .07, .80);
      r.headline(s.title, .10, .20, .80, .17, size: .061);
      r.scene(s.b, .10, .44, .41, .33, frame: 'studioInstant', turn: -1);
      _interiorBody(r, s, .57, .47, .32, h: .30, size: .026);
    case _AtelierLayout.fieldnotes:
      l.scene(s.a, .06, .08, .88, .59, frame: 'signatureOrbitQuilt');
      l.headline(s.title, .09, .73, .82, .13, size: .052);
      r.stock('lifeWardrobeLabel', .08, .13, .81, .29);
      _interiorWord(r, s, .15, .20, .66, h: .13, size: .067);
      _interiorBody(r, s, .10, .51, .79, h: .22, size: .034);
      r.mat('lifeRattle', .68, .75, .18, .13, turn: -3);
    case _AtelierLayout.directory:
      l.label('THE NEXT LITTLE FIRST / $n', .10, .07, .80);
      l.scene(s.a, .08, .21, .50, .39, frame: 'studioOval', photoRatio: 1);
      l.scene(s.b, .53, .48, .36, .28, frame: 'studioScallop', photoRatio: 1);
      l.mat('materialIndexTabs', .11, .70, .27, .065);
      l.hand('다음의 처음도 함께', .10, .83, .80);
      r.headline(s.title, .12, .19, .76, .22, size: .066);
      r.rule(.12, .48, .27, color: e.accent);
      _interiorBody(r, s, .12, .59, .76, h: .24, size: .033);
    case _AtelierLayout.closing:
      l.scene(s.a, .08, .09, .67, .55, frame: 'studioOvalMat', photoRatio: 1);
      l.scene(s.b, .54, .54, .36, .29, frame: 'studioScallop', photoRatio: 1);
      l.hand(s.word, .10, .81, .80);
      r.headline(s.title, .12, .17, .76, .22, size: .068);
      _interiorBody(r, s, .12, .49, .76, h: .21, size: .032);
      r.mat('heirloomGrowthRuler', .12, .79, .72, .065);
    default:
      throw StateError('Unexpected orbit spread: ${s.layout}');
  }
}

void _kitchenInteriors(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.scene(s.a, .055, .07, .89, .63, frame: 'signatureKitchenFold');
      l.mat('materialCrossStitchBand', .10, .67, .56, .075);
      l.label('AROUND OUR TABLE / $n', .11, .81, .78);
      r.headline(s.title, .10, .11, .80, .17, size: .065);
      r.scene(s.b, .12, .38, .76, .35, frame: 'studioPhotoCorners');
      _interiorBody(r, s, .10, .78, .80, size: .026);
    case _AtelierLayout.montage:
      l.mat('materialLinen', .035, .09, .91, .70, turn: -1);
      l.scene(s.a, .09, .11, .74, .48, frame: 'studioInstant', turn: -1.4);
      l.scene(s.b, .51, .56, .38, .27, frame: 'studioScallop', turn: 1.4);
      l.mat('lifeBasket', .10, .65, .22, .18);
      _interiorWord(r, s, .09, .09, .82, size: .086);
      r.headline(s.title, .09, .29, .82, .15, size: .058);
      r.scene(s.a, .11, .51, .40, .29, frame: 'studioPostage');
      _interiorBody(r, s, .58, .52, .31, h: .30, size: .025);
    case _AtelierLayout.ledger:
      l.mat('materialRecipeFoldout', .045, .08, .91, .64, turn: -1);
      l.scene(s.a, .09, .13, .74, .43, frame: 'studioPhotoCorners');
      l.stock('atelierWritingReceipt', .38, .56, .51, .17, turn: 1.5);
      l.headline(s.title, .43, .60, .41, .10, size: .037);
      _interiorBody(l, s, .09, .79, .82, h: .10, size: .025);
    case _AtelierLayout.cameo:
      l.mat('heirloomTableLinen', .04, .15, .92, .61);
      l.scene(s.a, .13, .16, .73, .57, frame: 'studioOvalMat', photoRatio: 1);
      l.label('KITCHEN DETAILS / $n', .10, .83, .80);
      r.headline(s.title, .09, .12, .82, .17, size: .064);
      r.scene(s.b, .09, .39, .45, .34, frame: 'studioPostcard');
      r.mat('lifeMug', .62, .45, .22, .22);
      _interiorBody(r, s, .10, .78, .80, size: .026);
    case _AtelierLayout.panorama:
      l.pic(s.a, .045, .08, .955, .65);
      r.pic(s.b, 0, .18, .92, .70);
      l.headline(s.title, .09, .785, .82, .10, size: .048);
      r.label('A LONG LUNCH / $n', .09, .065, .82);
    case _AtelierLayout.triptych:
      l.label('FROM THE SAME AFTERNOON / $n', .09, .065, .82);
      l.scene(s.a, .07, .19, .53, .40, frame: 'studioPostcard', turn: -1.1);
      l.scene(s.b, .51, .49, .39, .29, frame: 'studioPhotoCorners', turn: 1.2);
      l.mat('materialCrossStitchBand', .10, .72, .31, .065);
      l.hand(s.word, .10, .83, .79);
      r.scene(s.b, .08, .09, .84, .51, frame: 'studioDoubleMat');
      r.headline(s.title, .10, .665, .80, .11, size: .052);
      _interiorBody(r, s, .10, .80, .80, h: .09, size: .024);
    case _AtelierLayout.darkroom:
      l.pic(s.a, .07, .08, .86, .60, frame: 'studioPhotoCorners');
      l.headline(s.title, .10, .75, .80, .13, size: .053);
      r.stock('atelierWritingReceipt', .08, .16, .83, .56);
      _interiorWord(r, s, .16, .25, .67, size: .070, color: e.ink);
      _interiorBody(r, s, .16, .47, .66, h: .18, size: .030, color: e.ink);
      r.mat('lifeMug', .70, .71, .16, .15, turn: 2);
    case _AtelierLayout.correspondence:
      l.stock('atelierWritingLetter', .055, .10, .89, .72);
      l.label('FROM ONE KITCHEN TO ANOTHER / $n', .13, .19, .73);
      l.headline(s.title, .13, .32, .72, .18, size: .059);
      _interiorBody(l, s, .13, .57, .70, h: .20, size: .032);
      r.scene(s.b, .07, .09, .86, .50, frame: 'signatureKitchenFold');
      r.mat('heirloomTableLinen', .10, .59, .43, .20, turn: -1);
      r.scene(s.a, .48, .58, .41, .27, frame: 'studioInstant', turn: 1.5);
      r.label(s.record, .10, .86, .78);
    case _AtelierLayout.calendar:
      l.scene(s.a, .06, .08, .88, .54, frame: 'signatureKitchenFold');
      l.stock('atelierWritingVow', .12, .57, .51, .18, turn: -1);
      l.headline(s.title, .16, .62, .43, .10, size: .038);
      l.label(s.record, .10, .83, .80);
      r.txt(
        'SUNDAY',
        .09,
        .12,
        .82,
        .15,
        size: .088,
        font: 'Cormorant Garamond',
      );
      r.scene(s.b, .45, .35, .45, .34, frame: 'studioScallop', photoRatio: 1);
      r.mat('lifeBasket', .11, .40, .22, .20);
      _interiorBody(r, s, .10, .76, .80, h: .14, size: .028);
    case _AtelierLayout.fieldnotes:
      l.scene(s.a, .07, .085, .86, .56, frame: 'studioDoubleMat');
      l.headline(s.title, .10, .71, .80, .14, size: .055);
      r.mat('materialLinen', .06, .14, .87, .62);
      r.stock('atelierWritingLetter', .12, .20, .75, .56, turn: 1);
      _interiorWord(r, s, .19, .28, .61, size: .061, h: .16);
      _interiorBody(r, s, .19, .51, .59, h: .20, size: .028);
      r.label(s.record, .10, .845, .80);
    case _AtelierLayout.directory:
      l.headline(s.title, .09, .09, .82, .18, size: .065);
      l.scene(s.a, .08, .34, .47, .37, frame: 'studioOval', photoRatio: 1);
      l.scene(s.b, .56, .57, .34, .25, frame: 'studioPostcard', turn: 1);
      l.hand('다음에도 같이 먹자', .09, .84, .80);
      r.stock('atelierWritingRecord', .055, .18, .89, .60);
      _interiorWord(r, s, .13, .27, .74, size: .065, h: .18);
      _interiorBody(r, s, .13, .54, .72, h: .19, size: .031);
    case _AtelierLayout.closing:
      l.headline(s.title, .10, .11, .80, .19, size: .065);
      _interiorBody(l, s, .10, .36, .80, h: .17, size: .030);
      l.scene(s.a, .07, .58, .86, .29, frame: 'studioPostcard');
      r.scene(s.b, .08, .08, .84, .64, frame: 'studioGallery');
      r.hand(s.word, .12, .77, .76);
      r.label(s.record, .12, .83, .76);
    default:
      throw StateError('Unexpected kitchen spread: ${s.layout}');
  }
}

void _cinemaInteriors(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.scene(s.a, .055, .07, .89, .64, frame: 'studioGallery');
      l.mat('heirloomCinemaStub', .10, .66, .50, .12, turn: -1);
      l.label(s.record, .10, .84, .80);
      r.label('THE LEADING ROLES / $n', .10, .08, .80);
      r.headline(s.title, .10, .23, .80, .18, size: .068);
      r.scene(s.b, .37, .45, .52, .30, frame: 'materialSlideMount');
      _interiorBody(r, s, .10, .80, .80, h: .09, size: .024);
    case _AtelierLayout.montage:
      l.scene(s.a, .055, .08, .89, .43, frame: 'signatureCinemaGate');
      l.scene(s.b, .42, .53, .48, .30, frame: 'studioPhotoCorners', turn: 1.4);
      l.mat('materialTicketDuo', .08, .66, .30, .13, turn: -2);
      l.label('CUTS WE KEPT / $n', .10, .855, .80);
      _interiorWord(r, s, .09, .09, .82, size: .090);
      r.headline(s.title, .09, .32, .82, .16, size: .061);
      r.stock('atelierWritingLetter', .09, .55, .78, .30);
      _interiorBody(r, s, .16, .61, .65, h: .18, size: .026);
    case _AtelierLayout.ledger:
      l.label('THE SCREENING DIARY / $n', .09, .07, .82);
      l.scene(s.a, .07, .20, .86, .48, frame: 'studioFilm');
      l.headline(s.title, .10, .73, .80, .13, size: .050);
    case _AtelierLayout.cameo:
      l.scene(s.a, .07, .10, .86, .58, frame: 'materialSlideMount');
      l.mat('materialTicketDuo', .13, .64, .54, .16, turn: -1);
      l.label(s.record, .10, .845, .80);
      r.headline(s.title, .10, .11, .80, .18, size: .065);
      r.pic(s.b, .58, .37, .31, .41, frame: 'studioPhotoCorners');
      _interiorBody(r, s, .10, .42, .40, h: .30, size: .032);
    case _AtelierLayout.panorama:
      l.box(l.uid, 0, .17, 1, .61, e.ink);
      r.box(r.uid, 0, .17, 1, .61, e.ink);
      l.pic(s.a, .025, .22, .975, .50);
      r.pic(s.b, 0, .22, .975, .50);
      l.label('WIDESCREEN / $n', .08, .08, .84);
      r.headline(s.title, .08, .82, .84, .09, size: .043);
    case _AtelierLayout.triptych:
      l.txt(
        'TAKE $n',
        .08,
        .08,
        .84,
        .16,
        size: .095,
        font: 'Cormorant Garamond',
      );
      l.mat('studioVellum', .045, .30, .60, .47, turn: -1);
      l.scene(s.a, .07, .33, .49, .35, frame: 'studioPhotoCorners');
      l.scene(s.b, .54, .53, .36, .26, frame: 'studioGallery');
      l.rule(.09, .84, .81, color: e.accent);
      r.stock('studioCotton', .065, .10, .87, .64);
      r.scene(s.b, .12, .14, .75, .45, frame: 'studioInstant', turn: -1);
      r.headline(s.title, .12, .64, .74, .13, size: .050);
      _interiorBody(r, s, .10, .80, .80, h: .09, size: .023);
    case _AtelierLayout.correspondence:
      l.stock('atelierWritingLetter', .075, .10, .84, .76, turn: -.6);
      l.label('A LETTER AFTER THE CREDITS / $n', .15, .19, .70);
      l.headline(s.title, .15, .32, .69, .17, size: .058);
      _interiorBody(l, s, .15, .56, .68, h: .20, size: .032);
      r.scene(s.b, .08, .09, .84, .54, frame: 'signatureCinemaGate');
      r.mat('studioGlassineEnvelope', .10, .60, .31, .23, turn: -2);
      r.mat('heirloomCinemaStub', .47, .62, .42, .14, turn: 1);
      r.hand(s.word, .10, .81, .80);
    case _AtelierLayout.calendar:
      l.scene(s.a, .07, .09, .86, .56, frame: 'signatureCinemaGate');
      l.headline(s.title, .10, .72, .80, .13, size: .054);
      r.label('OUR ANNIVERSARY SCREENING / $n', .10, .07, .80);
      r.txt(
        '02',
        .10,
        .17,
        .42,
        .29,
        size: .23,
        font: 'Cormorant Garamond',
        leading: 1,
      );
      r.label('SEATS / TWO OF US', .52, .29, .37);
      r.scene(s.b, .36, .47, .53, .27, frame: 'zineContact');
      _interiorBody(r, s, .10, .79, .80, h: .10, size: .025);
    case _AtelierLayout.fieldnotes:
      l.pic(s.a, .06, .085, .88, .65, frame: 'studioPhotoCorners');
      l.label(s.record, .10, .83, .80);
      r.stock('atelierWritingRecord', .09, .13, .79, .66);
      r.label('DIRECTOR’S NOTES / $n', .16, .22, .65);
      r.headline(s.title, .16, .35, .64, .16, size: .055);
      _interiorBody(r, s, .16, .57, .63, h: .18, size: .028);
      r.mat('studioKeepsakeTicket', .58, .77, .28, .10, turn: -1);
    case _AtelierLayout.directory:
      l.label('THE REPLAY LIST / $n', .10, .07, .80);
      l.headline(s.title, .10, .21, .80, .18, size: .066);
      l.scene(s.a, .10, .48, .47, .32, frame: 'studioPostage');
      l.scene(s.b, .60, .62, .29, .21, frame: 'studioPhotoCorners', turn: 1.5);
      _interiorWord(r, s, .10, .15, .80, size: .080, h: .19);
      r.rule(.10, .43, .80, color: e.accent);
      _interiorBody(r, s, .10, .55, .80, h: .24, size: .035);
    case _AtelierLayout.closing:
      l.scene(s.a, .06, .12, .88, .56, frame: 'atelierNegative');
      l.label('THE END IS ANOTHER BEGINNING', .10, .79, .80);
      r.label('END CREDITS / $n', .12, .10, .76);
      r.headline(s.title, .12, .25, .76, .22, size: .066, align: 'center');
      r.txt(
        s.note,
        .12,
        .57,
        .76,
        .19,
        size: .031,
        font: 'NotoSans',
        leading: 1.5,
        align: 'center',
      );
      r.label(s.record, .12, .84, .76);
    default:
      throw StateError('Unexpected cinema spread: ${s.layout}');
  }
}

void _walkInteriors(_AtelierPage l, _AtelierPage r, _AtelierStory s, String n) {
  final e = l.edition;
  switch (s.layout) {
    case _AtelierLayout.portrait:
      l.pic(s.a, .085, .07, .83, .69, frame: 'studioCapsule');
      l.mat('materialNamePatch', .14, .72, .41, .10);
      l.label('THE WALKING COMPANION / $n', .10, .85, .80);
      r.headline(s.title, .10, .14, .80, .18, size: .066);
      r.scene(s.b, .40, .40, .48, .34, frame: 'studioPhotoCorners');
      _interiorBody(r, s, .10, .79, .80, h: .10, size: .025);
    case _AtelierLayout.montage:
      l.mat('atelierGridLeaf', .05, .11, .88, .65, turn: -1);
      l.scene(
        s.a,
        .09,
        .08,
        .73,
        .45,
        frame: 'signatureTrailPocket',
        turn: -1.3,
      );
      l.scene(s.b, .48, .53, .42, .29, frame: 'studioPhotoCorners', turn: 1.6);
      l.mat('materialLeash', .08, .64, .23, .19);
      _interiorWord(r, s, .10, .10, .80, size: .085);
      r.headline(s.title, .10, .31, .80, .16, size: .059);
      r.scene(s.b, .41, .55, .48, .28, frame: 'studioGallery');
      _interiorBody(r, s, .10, .56, .26, h: .29, size: .025);
    case _AtelierLayout.ledger:
      l.label('THE WALK / $n', .10, .065, .80);
      l.pic(s.a, .09, .18, .82, .50, frame: 'studioRounded');
      l.mat('materialNamePatch', .12, .64, .45, .11);
      l.headline(s.title, .10, .78, .80, .12, size: .048);
    case _AtelierLayout.cameo:
      l.scene(s.a, .07, .09, .86, .61, frame: 'studioOvalMat', photoRatio: 1);
      l.mat('lifeFeltMouse', .70, .65, .17, .17, turn: -3);
      l.label('A CLOSER LOOK / $n', .10, .84, .80);
      r.stock('atelierWritingVow', .09, .17, .79, .24);
      r.headline(s.title, .15, .22, .66, .13, size: .049);
      r.scene(s.b, .52, .46, .37, .30, frame: 'studioPostage', photoRatio: 1);
      _interiorBody(r, s, .10, .48, .34, h: .28, size: .029);
    case _AtelierLayout.panorama:
      l.pic(s.a, .04, .10, .96, .68);
      r.pic(s.b, 0, .10, .96, .68);
      l.headline(s.title, .09, .83, .82, .08, size: .043);
      r.label(s.record, .08, .83, .84);
    case _AtelierLayout.triptych:
      l.label('NO TWO WALKS ALIKE / $n', .09, .07, .82);
      l.scene(s.a, .08, .22, .48, .38, frame: 'studioPostcard', turn: -1);
      l.scene(s.b, .52, .50, .37, .29, frame: 'studioScallop', photoRatio: 1);
      l.mat('heirloomPetTag', .10, .66, .12, .16, turn: 3);
      l.hand(s.word, .25, .80, .63);
      r.headline(s.title, .10, .12, .80, .17, size: .062);
      r.scene(s.b, .13, .37, .74, .37, frame: 'studioDoubleMat');
      _interiorBody(r, s, .10, .80, .80, h: .09, size: .024);
    case _AtelierLayout.darkroom:
      l.scene(s.a, .06, .12, .88, .57, frame: 'studioGallery');
      l.headline(s.title, .10, .755, .80, .13, size: .053);
      r.stock('atelierWritingRecord', .10, .12, .78, .71);
      r.label('HOME AFTER THE WALK / $n', .17, .23, .64, color: e.ink);
      _interiorBody(r, s, .17, .40, .63, h: .25, size: .034, color: e.ink);
      r.mat('lifeBowl', .68, .69, .17, .16);
    case _AtelierLayout.correspondence:
      l.stock('studioCotton', .08, .16, .83, .62, turn: -.5);
      l.headline(s.title, .15, .26, .70, .17, size: .059);
      _interiorBody(l, s, .15, .51, .68, h: .21, size: .033);
      l.mat('studioWashiSage', .13, .73, .34, .065, turn: -2);
      r.scene(s.b, .10, .09, .68, .60, frame: 'signatureTrailPocket');
      r.scene(s.a, .57, .60, .32, .24, frame: 'studioInstant', turn: 1.5);
      r.hand(s.word, .10, .80, .45);
    case _AtelierLayout.calendar:
      l.stock('atelierWritingRecord', .055, .10, .82, .73);
      l.scene(s.a, .12, .18, .66, .45, frame: 'signatureTrailPocket');
      l.mat('heirloomPetTag', .73, .62, .12, .17, turn: 3);
      l.label(s.record, .13, .76, .63);
      r.txt('07:30', .10, .13, .80, .18, size: .13, font: 'Cormorant Garamond');
      r.headline(s.title, .10, .38, .80, .16, size: .060);
      _interiorBody(r, s, .10, .62, .80, h: .21, size: .031);
    case _AtelierLayout.fieldnotes:
      l.pic(s.a, .06, .07, .88, .68, frame: 'studioPhotoCorners');
      l.headline(s.title, .10, .81, .80, .09, size: .046);
      r.label('FIELD OBSERVATIONS / $n', .10, .08, .80);
      r.stock('atelierGridLeaf', .08, .24, .83, .55);
      _interiorWord(r, s, .15, .31, .69, size: .064, h: .17);
      _interiorBody(r, s, .15, .54, .67, h: .19, size: .028);
      r.mat('lifeRopeBall', .71, .74, .16, .13, turn: 2);
    case _AtelierLayout.directory:
      l.headline(s.title, .10, .10, .80, .19, size: .065);
      l.scene(s.a, .09, .36, .48, .35, frame: 'studioPostage');
      l.scene(s.b, .53, .58, .36, .27, frame: 'studioPhotoCorners', turn: 1.2);
      l.label('THE NEXT ROUTE / $n', .10, .82, .38);
      r.stock('materialContourMap', .055, .15, .89, .61);
      _interiorWord(r, s, .13, .24, .74, size: .065, h: .17);
      _interiorBody(r, s, .13, .49, .71, h: .22, size: .032);
    case _AtelierLayout.closing:
      l.pic(s.a, .075, .07, .85, .68, frame: 'studyFloatMount');
      l.hand(s.word, .10, .81, .80);
      r.headline(s.title, .12, .12, .76, .20, size: .064);
      r.scene(s.b, .15, .39, .54, .32, frame: 'studioPostage');
      _interiorBody(r, s, .12, .77, .76, h: .12, size: .027);
      r.label(s.record, .12, .845, .76);
    default:
      throw StateError('Unexpected walk spread: ${s.layout}');
  }
}
