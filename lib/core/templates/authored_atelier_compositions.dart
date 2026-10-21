part of 'authored_collections.dart';

// Four authored spread roles per topic; not a recoloured common collage.
void _atelierConceptSpread(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String number,
) {
  switch (l.edition) {
    case AtelierEdition.nightVows:
      _gardenComposition(l, r, s, number);
    case AtelierEdition.slowRail:
      _railComposition(l, r, s, number);
    case AtelierEdition.greenHours:
      _herbariumComposition(l, r, s, number);
    case AtelierEdition.firstOrbit:
      _orbitComposition(l, r, s, number);
    case AtelierEdition.tableStories:
      _kitchenComposition(l, r, s, number);
    case AtelierEdition.privateCinema:
      _cinemaComposition(l, r, s, number);
    case AtelierEdition.walkMap:
      _walkComposition(l, r, s, number);
  }
}

void _atelierCaption(
  _AtelierPage p,
  _AtelierStory s,
  double x,
  double y,
  double w, {
  double size = .029,
}) {
  p.txt(s.note, x, y, w, .145, size: size, font: 'NotoSans', leading: 1.5);
}

void _gardenComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.invitation) {
    l.box(l.uid, .035, .035, .93, .865, e.ink);
    l.mount(s.a, .105, .075, .79, .72);
    l.binding('서연 · 지우 / 17 OCT', .17, .74, .66, .10);
    l.label('THE GARDEN CEREMONY / $n', .11, .855, .78, color: e.paper);
    r.mat(e.paperMaterial, .08, .065, .84, .78);
    r.label('서연과 지우의 결혼식', .15, .13, .70);
    r.txt(s.word, .15, .22, .70, .15, size: .10, font: 'Cormorant Garamond');
    r.rule(.15, .40, .15, color: e.accent);
    r.txt(s.title, .15, .445, .70, .13, size: .054);
    _atelierCaption(r, s, .15, .595, .68, size: .026);
    r.mat(e.signatureMaterial, .60, .72, .29, .18, turn: -5);
    r.label(s.record, .15, .795, .45);
  } else if (s.layout == _AtelierLayout.prologue) {
    l.mat(e.paperMaterial, .09, .08, .78, .73, turn: -1.3);
    l.label('THE FIRST LOOK / $n', .14, .145, .72);
    l.txt(s.word, .14, .245, .72, .18, size: .094, font: 'Cormorant Garamond');
    l.txt(s.title, .14, .465, .70, .15, size: .062);
    _atelierCaption(l, s, .14, .67, .70);
    l.binding('THE FIRST LOOK', .10, .795, .65, .085);
    r.pic(s.a, .075, .045, .85, .68, frame: 'materialLaceMount');
    r.pic(s.b, .55, .61, .36, .26, frame: 'studioInstant', turn: 2);
    r.hand('눈을 마주친 순간', .10, .77, .42);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mat(e.paperMaterial, .06, .08, .82, .77, turn: -2);
    l.pic(s.a, .11, .12, .70, .58, frame: 'studioDoubleMat');
    l.pic(s.b, .56, .57, .35, .29, frame: 'studioOvalMat');
    l.binding('BEFORE / 17 OCT', .08, .685, .43, .075);
    l.hand('마지막 매듭까지', .09, .805, .46);
    r.label('THE DETAILS / $n', .09, .07, .82);
    r.txt(s.word, .09, .17, .82, .14, size: .095, font: 'Cormorant Garamond');
    r.txt(s.title, .09, .345, .82, .13, size: .064);
    r.rule(.09, .515, .82, color: e.accent);
    r.label('01  베일을 고쳐 주던 손', .09, .55, .82);
    r.label('02  서로에게 건넨 반지', .09, .615, .82);
    _atelierCaption(r, s, .09, .72, .82);
  } else {
    l.label('KEEPSAKE CABINET / $n', .08, .055, .84);
    l.mount(s.a, .08, .14, .62, .60);
    l.mat(e.signatureMaterial, .59, .60, .32, .23, turn: 5);
    l.hand('작은 것들이 남았다', .10, .79, .62);
    r.mat(e.paperMaterial, .08, .06, .83, .80);
    r.txt(s.title, .14, .14, .71, .15, size: .061);
    r.pic(s.b, .15, .35, .39, .33, frame: 'studioPostage');
    r.txt(
      'INVITATION\nBOUQUET\nRIBBON',
      .60,
      .41,
      .25,
      .18,
      size: .017,
      font: 'NotoSans',
      leading: 1.6,
    );
    _atelierCaption(r, s, .14, .73, .72, size: .026);
  }
}

void _railComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.prologue) {
    l.mat(e.paperMaterial, .035, .09, .92, .72, turn: -1);
    l.tag('RAIL JOURNAL / $n', .08, .10, .42);
    l.txt(s.title, .09, .215, .82, .18, size: .071);
    l.mount(s.a, .08, .445, .84, .37);
    l.label(s.record, .09, .84, .80);
    r.pic(s.b, .07, .055, .86, .65, frame: 'studioDoubleMat');
    r.mat(e.bandMaterial, .06, .65, .56, .10, turn: -2);
    r.mat(e.signatureMaterial, .57, .67, .34, .23, turn: 4);
    _atelierCaption(r, s, .08, .77, .47, size: .025);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.mount(s.a, .055, .08, .89, .47);
    l.txt(s.word, .08, .57, .84, .13, size: .087, font: 'Cormorant Garamond');
    l.txt(s.title, .08, .725, .84, .12, size: .048);
    r.mat(e.paperMaterial, .055, .09, .89, .73);
    r.label('NEXT DEPARTURE / $n', .10, .13, .80);
    r.pic(s.b, .11, .26, .59, .39, frame: 'studioPostage', turn: -1);
    r.mat(e.bandMaterial, .35, .60, .54, .10, turn: 2);
    _atelierCaption(r, s, .10, .75, .80);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mat(e.paperMaterial, .04, .07, .91, .76);
    l.pic(s.a, .09, .12, .72, .51, frame: 'studioDoubleMat', turn: -1);
    l.mat(e.bandMaterial, .42, .57, .48, .10, turn: 3);
    l.mat(e.signatureMaterial, .08, .67, .34, .22);
    l.label(s.record, .47, .76, .42);
    r.txt(s.word, .08, .065, .84, .16, size: .090, font: 'Cormorant Garamond');
    r.pic(s.b, .34, .28, .56, .38, frame: 'studioTicket');
    r.txt(s.title, .08, .43, .24, .25, size: .050);
    _atelierCaption(r, s, .08, .75, .84);
  } else {
    l.label('POCKET INVENTORY / $n', .08, .06, .84);
    l.mount(s.a, .06, .18, .86, .45);
    l.mat(e.signatureMaterial, .10, .61, .42, .24, turn: -3);
    l.hand('꺼내 보면 떠오르는 역', .50, .75, .41);
    r.mat(e.paperMaterial, .055, .055, .89, .80);
    r.txt(s.title, .11, .14, .77, .15, size: .060);
    r.pic(s.b, .12, .36, .72, .32, frame: 'studioDoubleMat');
    r.binding('RAIL / KEEPSAKES', .53, .66, .35, .075);
    _atelierCaption(r, s, .11, .765, .77, size: .025);
  }
}

void _herbariumComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.prologue) {
    l.mount(s.a, .055, .06, .80, .78);
    l.mat(e.bandMaterial, .36, .76, .54, .09, turn: -2);
    r.label('THE LIVING HERBARIUM / $n', .08, .07, .84);
    r.txt(s.word, .08, .155, .84, .16, size: .090, font: 'Cormorant Garamond');
    r.txt(s.title, .08, .35, .84, .15, size: .061);
    r.mat(e.paperMaterial, .07, .55, .46, .34, turn: -3);
    r.pic(s.b, .48, .53, .41, .32, frame: 'studioDeckle', turn: 2);
    r.txt(
      s.note,
      .11,
      .605,
      .34,
      .21,
      size: .025,
      leading: 1.5,
      font: 'NotoSans',
    );
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mat(e.paperMaterial, .055, .07, .87, .80);
    l.pic(s.a, .12, .125, .63, .58, frame: 'studioDeckle', turn: -1);
    l.mat(e.signatureMaterial, .56, .63, .34, .25, turn: 3);
    l.label('SPECIMEN / $n', .12, .81, .40);
    r.txt(s.title, .08, .10, .84, .17, size: .065);
    r.pic(s.b, .12, .33, .42, .40, frame: 'studioOvalMat');
    r.txt(
      'LEAF\nSTEM\nTEXTURE',
      .62,
      .40,
      .29,
      .18,
      size: .017,
      font: 'NotoSans',
      leading: 1.6,
    );
    r.binding('BOTANICAL STUDY', .48, .66, .42, .085);
    _atelierCaption(r, s, .08, .78, .84, size: .026);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.label('A SMALL GARDEN / $n', .08, .06, .84);
    l.txt(s.word, .08, .15, .84, .14, size: .087, font: 'Cormorant Garamond');
    l.mount(s.a, .19, .32, .62, .53);
    r.mat(e.paperMaterial, .07, .07, .85, .79);
    r.txt(s.title, .14, .16, .72, .18, size: .063);
    r.pic(s.b, .15, .40, .44, .30, frame: 'studioPostage', turn: -2);
    r.mat(e.signatureMaterial, .60, .45, .27, .24, turn: 4);
    _atelierCaption(r, s, .14, .75, .72, size: .025);
  } else {
    l.mat(e.paperMaterial, .05, .07, .89, .79);
    l.label('THE GARDEN DRAWER / $n', .12, .13, .74);
    l.pic(s.a, .11, .24, .48, .37, frame: 'studioDeckle', turn: -2);
    l.mat(e.signatureMaterial, .49, .52, .39, .30, turn: 3);
    l.label('씨앗 / 도구 / 마른 잎', .12, .79, .74);
    r.mount(s.b, .14, .08, .70, .58);
    r.txt(s.title, .09, .68, .82, .11, size: .047);
    r.txt(s.note, .09, .81, .82, .075, size: .024, font: 'NotoSans');
  }
}

void _orbitComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.prologue) {
    l.mat(e.paperMaterial, .055, .08, .89, .79);
    l.label('OUR LITTLE UNIVERSE / $n', .13, .14, .74);
    l.txt(s.title, .13, .25, .74, .20, size: .073);
    _atelierCaption(l, s, .13, .52, .61);
    l.mat(e.signatureMaterial, .51, .66, .37, .22, turn: -3);
    l.binding('FIRST YEAR', .11, .77, .37, .075);
    r.mount(s.a, .07, .09, .86, .67);
    r.hand('너의 작은 손을 기억해', .12, .78, .76);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mount(s.a, .06, .065, .82, .65);
    l.mat(e.paperMaterial, .48, .57, .43, .28, turn: 2);
    l.pic(s.b, .53, .60, .32, .22, frame: 'studioOval');
    l.label('LITTLE DETAILS / $n', .08, .80, .40);
    r.txt(s.word, .08, .08, .84, .16, size: .096, font: 'Cormorant Garamond');
    r.txt(s.title, .08, .30, .84, .17, size: .066);
    r.rule(.08, .52, .24, color: e.accent);
    _atelierCaption(r, s, .08, .585, .84);
    r.binding('작은 순간을 한 달씩', .08, .78, .80, .09);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.mat(e.paperMaterial, .06, .07, .87, .80);
    l.label('A NEW CHAPTER / $n', .13, .14, .74);
    l.txt(s.title, .13, .26, .74, .18, size: .066);
    l.pic(s.a, .16, .49, .49, .30, frame: 'studioOvalMat');
    l.mat(e.signatureMaterial, .63, .56, .24, .26);
    r.mount(s.b, .12, .12, .76, .60);
    _atelierCaption(r, s, .12, .76, .76);
  } else {
    l.mat(e.paperMaterial, .06, .08, .87, .79);
    l.mount(s.a, .12, .16, .68, .53);
    l.mat(e.bandMaterial, .24, .665, .65, .09, turn: 1);
    l.label('THE FIRST YEAR BOX / $n', .12, .82, .76);
    r.txt(s.title, .09, .10, .82, .18, size: .063);
    r.pic(s.b, .10, .37, .42, .36, frame: 'editionScallop', turn: -1);
    r.mat(e.signatureMaterial, .57, .42, .32, .24);
    _atelierCaption(r, s, .09, .79, .82, size: .025);
  }
}

void _kitchenComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.prologue) {
    l.mat(e.paperMaterial, .045, .065, .91, .77);
    l.txt(s.title, .10, .12, .80, .18, size: .072);
    l.mount(s.a, .10, .36, .80, .40);
    l.label('FROM OUR FAMILY KITCHEN / $n', .10, .81, .80);
    r.pic(s.b, .07, .06, .86, .59, frame: 'studioDoubleMat');
    r.mat(e.bandMaterial, .06, .61, .61, .09, turn: -2);
    r.mat(e.signatureMaterial, .58, .66, .34, .21, turn: 3);
    _atelierCaption(r, s, .08, .75, .45, size: .026);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mat(e.paperMaterial, .05, .07, .90, .79, turn: -1);
    l.pic(s.a, .10, .13, .70, .53, frame: 'studioInstant', turn: -2);
    l.pic(s.b, .52, .57, .37, .27, frame: 'studioScallop', turn: 2);
    l.binding('THE KITCHEN', .10, .66, .36, .07);
    l.hand('손에 익은 도구들', .10, .79, .43);
    r.label('KITCHEN STILL LIFE / $n', .08, .07, .84);
    r.txt(s.word, .08, .17, .84, .16, size: .083, font: 'Cormorant Garamond');
    r.txt(s.title, .08, .37, .84, .16, size: .062);
    _atelierCaption(r, s, .08, .59, .84);
    r.mat(e.signatureMaterial, .50, .73, .39, .15);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.mount(s.a, .06, .10, .88, .51);
    l.hand(s.word, .09, .67, .82);
    l.txt(s.title, .09, .79, .82, .10, size: .047);
    r.mat(e.paperMaterial, .055, .08, .89, .77);
    r.label('PULL UP A CHAIR / $n', .12, .14, .76);
    r.pic(
      s.b,
      .12,
      r.wide ? .25 : .29,
      r.wide ? .55 : .67,
      r.wide ? .55 * r.ratio / 1.5 : .37,
      frame: r.wide ? 'studioDoubleMat' : 'studioInstant',
      turn: -1,
    );
    r.mat(e.bandMaterial, .42, .63, .46, .085);
    _atelierCaption(r, s, .12, .76, .76, size: .026);
  } else {
    l.mat(e.paperMaterial, .045, .065, .91, .78);
    l.label('THE RECIPE BOX / $n', .11, .13, .78);
    l.pic(s.a, .10, .24, .49, .39, frame: 'studioScallop', turn: -2);
    l.mat(e.signatureMaterial, .43, .56, .46, .25, turn: 3);
    l.hand('다음에도 이 맛으로', .11, .79, .63);
    r.txt(s.title, .08, .10, .84, .17, size: .060);
    r.mount(s.b, .08, .34, .84, .40);
    _atelierCaption(r, s, .08, .79, .84, size: .025);
  }
}

void _cinemaComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.darkroom) {
    l.label('OPENING SCENE / $n', .08, .055, .84);
    l.mount(s.a, .035, .13, .93, .51);
    l.txt(
      s.word,
      .08,
      .68,
      .84,
      .12,
      size: .081,
      font: 'Cormorant Garamond',
      color: e.accent,
    );
    l.hand(s.title, .08, .82, .84);
    r.mat(e.paperMaterial, .055, .055, .89, .81);
    r.txt('둘만의 상영 기록', .12, .125, .76, .10, size: .049, color: e.ink);
    r.label(s.record, .12, .24, .76, color: e.ink);
    r.pic(s.b, .12, .34, .66, .35, frame: 'materialSlideMount', turn: -1);
    r.mat(e.signatureMaterial, .52, .62, .37, .22, turn: 3);
    r.txt(
      s.note,
      .12,
      .75,
      .40,
      .12,
      size: .025,
      font: 'NotoSans',
      color: e.ink,
      leading: 1.5,
    );
  } else if (s.layout == _AtelierLayout.prologue) {
    l.box(l.uid, .035, .045, .93, .85, e.ink);
    l.label('A FILM BY THE TWO OF US / $n', .09, .10, .82, color: e.paper);
    l.txt(
      s.word,
      .09,
      .21,
      .82,
      .16,
      size: .094,
      font: 'Cormorant Garamond',
      color: e.paper,
    );
    l.txt(s.title, .09, .43, .82, .16, size: .067, color: e.paper);
    l.txt(
      s.note,
      .09,
      .66,
      .73,
      .15,
      size: .027,
      font: 'NotoSans',
      color: e.paper,
      leading: 1.5,
    );
    l.binding('STARRING THE TWO OF US', .09, .80, .67, .08);
    r.mount(s.a, .045, .09, .91, .45);
    r.pic(s.b, .10, .55, .49, .28, frame: 'materialSlideMount', turn: -2);
    r.mat(e.signatureMaterial, .57, .61, .35, .23, turn: 4);
    r.label(s.record, .10, .855, .80);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mat(e.paperMaterial, .055, .07, .89, .79);
    l.mount(s.a, .08, .13, .84, .41);
    l.pic(s.b, .45, .54, .44, .31, frame: 'materialSlideMount', turn: 2);
    l.binding('SCENE STUDY', .10, .57, .32, .075);
    l.label('SCENE STUDY / $n', .10, .81, .32);
    r.label('THE CLOSE-UP', .08, .08, .84);
    r.txt(s.word, .08, .17, .84, .16, size: .091, font: 'Cormorant Garamond');
    r.txt(s.title, .08, .39, .84, .16, size: .064);
    r.rule(.08, .61, .84, color: e.accent);
    _atelierCaption(r, s, .08, .70, .84);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.mat(e.paperMaterial, .06, .06, .87, .80);
    l.label('TONIGHT, JUST US / $n', .12, .13, .76);
    l.txt(s.title, .12, .25, .76, .17, size: .067);
    l.mount(s.a, .11, .47, .78, .35);
    r.mount(s.b, .055, .10, .89, .43);
    r.mat(e.signatureMaterial, .54, .55, .36, .23, turn: 4);
    _atelierCaption(r, s, .08, .60, .43, size: .025);
    r.binding('ADMIT TWO', .08, .80, .78, .075);
  } else {
    l.box(l.uid, .035, .05, .93, .84, e.ink);
    l.label('THE TICKET DRAWER / $n', .09, .105, .82, color: e.paper);
    l.mount(s.a, .07, .23, .86, .40);
    l.mat(e.signatureMaterial, .10, .63, .37, .23, turn: -2);
    l.hand('같이 본 날을 모아서', .50, .74, .41, color: e.paper);
    r.mat(e.paperMaterial, .06, .06, .87, .80);
    r.txt(s.title, .12, .14, .76, .17, size: .061);
    r.pic(s.b, .14, .36, .70, .32, frame: 'studioFilm');
    r.mat(e.bandMaterial, .39, .65, .49, .085, turn: 1);
    _atelierCaption(r, s, .12, .77, .76, size: .025);
  }
}

void _walkComposition(
  _AtelierPage l,
  _AtelierPage r,
  _AtelierStory s,
  String n,
) {
  final e = l.edition;
  if (s.layout == _AtelierLayout.prologue) {
    l.mat(e.paperMaterial, .045, .065, .91, .78);
    l.label('WALK CLUB / $n', .11, .13, .78);
    l.txt(s.title, .11, .25, .78, .18, size: .074);
    _atelierCaption(l, s, .11, .49, .78);
    l.mat(e.signatureMaterial, .53, .65, .35, .23, turn: 3);
    l.binding('WALK CLUB', .10, .74, .37, .08);
    r.mount(s.a, .07, .075, .85, .70);
    r.hand('오늘도 네 걸음에 맞춰', .11, .79, .78);
  } else if (s.layout == _AtelierLayout.specimen) {
    l.mount(s.a, .07, .07, .78, .65);
    l.mat(e.paperMaterial, .51, .58, .40, .27, turn: 3);
    l.pic(s.b, .55, .61, .31, .21, frame: 'studioRounded');
    l.binding('TRAIL NOTES', .08, .70, .39, .08);
    l.label('TRAIL DETAILS / $n', .08, .83, .40);
    r.txt(s.word, .08, .08, .84, .16, size: .093, font: 'Cormorant Garamond');
    r.txt(s.title, .08, .31, .84, .17, size: .064);
    r.rule(.08, .53, .26, color: e.accent);
    _atelierCaption(r, s, .08, .61, .84);
    r.mat(e.signatureMaterial, .55, .74, .34, .15);
  } else if (s.layout == _AtelierLayout.invitation) {
    l.mat(e.paperMaterial, .06, .06, .87, .80);
    l.label('THE NEXT WALK / $n', .12, .13, .76);
    l.txt(s.title, .12, .25, .76, .18, size: .065);
    l.pic(s.a, .13, .48, .54, .32, frame: 'studioCapsule');
    l.mat(e.signatureMaterial, .64, .60, .24, .22);
    r.mount(s.b, .12, .11, .76, .62);
    r.mat(e.bandMaterial, .12, .705, .66, .085);
    r.txt(s.note, .12, .82, .76, .07, size: .023, font: 'NotoSans');
  } else {
    l.mat(e.paperMaterial, .05, .06, .90, .81);
    l.label('THE WALKING KIT / $n', .11, .13, .78);
    l.pic(s.a, .10, .25, .52, .39, frame: 'studioInstant', turn: -2);
    l.mat(e.signatureMaterial, .48, .57, .41, .25, turn: 3);
    l.hand('현관 옆에 모아 둔 것', .11, .795, .66);
    r.txt(s.title, .08, .10, .84, .18, size: .063);
    r.mount(s.b, .14, .34, .72, .40);
    _atelierCaption(r, s, .08, .79, .84, size: .025);
  }
}
