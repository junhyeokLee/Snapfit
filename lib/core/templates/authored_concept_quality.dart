part of 'authored_collections.dart';

const conceptQualityRevision = 'crafted-editorial-2026-10-07';

/// New artwork is composed independently; archived approved editions are not
/// overwritten, and saved customer albums continue to use their own layers.
Map<String, dynamic> _refineConceptQuality(
  ConceptVolume volume,
  CollectionAspect aspect,
  EditorialCopy copy,
  Map<String, dynamic> baseline,
) {
  final pages = [
    for (final original
        in (baseline['pages'] as List).cast<Map<String, dynamic>>())
      <String, dynamic>{
        ...original,
        'layers': [
          for (final layer
              in (original['layers'] as List).cast<Map<String, dynamic>>())
            if (layer['type'] == 'image' && layer['frame'] == 'studioOvalMat')
              {...layer, 'frame': 'studioOval'}
            else
              {...layer},
        ],
      },
  ];
  Map<String, dynamic> paint(
    int index,
    String stock,
    void Function(_ConceptPage p) draw, {
    bool dark = false,
  }) {
    final p = _ConceptPage(volume, aspect, index, stock);
    draw(p);
    if (index != 0) {
      p.folio(volume.title, color: dark ? '#F5F7F3' : volume.ink);
    }
    return {
      ...(index == 0
          ? baseline['cover'] as Map<String, dynamic>
          : pages[index - 1]),
      ...p.json,
      'photoOverlayTextIds': p._photoTextIds,
      'qualityRevision': conceptQualityRevision,
    };
  }

  void page(
    int index,
    String stock,
    void Function(_ConceptPage p) draw, {
    bool dark = false,
  }) => pages[index - 1] = paint(index, stock, draw, dark: dark);

  final cover = paint(0, '#FFFFFF', (p) => _paintConceptCover(p, copy));
  cover['coverRevision'] = catalogCoverRevision;

  switch (volume) {
    case ConceptVolume.silkVows:
      page(1, '#EDF0EB', (p) {
        p.label('서약의 결 / 예식을 앞둔 아침', .085, .065, .83);
        p.numeral('Vows', .075, .16, .84, .18, size: .16);
        p.txt('함께 시작하는\n오늘의 마음', .085, .36, .82, .22, size: .067);
        p.rule(.085, .625, .18);
        p.txt(
          '작은 준비부터 마지막 인사까지.\n두 사람의 하루를 차례로 담았다.',
          .085,
          .685,
          .60,
          .14,
          size: .027,
        );
        p.mat('waveSilkKnot', .70, .65, .22, .20);
      });
      page(2, '#DCE5DE', (p) {
        p.pic('petal_veil', .045, .045, .91, .84);
        p.mat('materialVellumBand', .065, .74, .67, .12);
        p.photoLabel(
          '천천히 준비하던 아침',
          .10,
          .78,
          .68,
          .085,
          paper: '#EEF2EB',
          size: .026,
        );
      });
      page(3, '#F5F6F1', (p) {
        p.label('01 / 손에 남은 작은 것들', .075, .065, .85);
        p.pic('petal_details', .07, .19, .60, .57, frame: 'atelierCrossRibbon');
        p.pic('petal_bouquet', .70, .26, .23, .29, frame: 'studioOval');
        p.mat('materialLace', .72, .59, .20, .14);
        p.txt('하나씩, 마음을 담아', .08, .813, .80, .085, size: .043);
      });
      page(4, '#DBE3DD', (p) {
        p.numeral('The details', .08, .075, .83, .145, size: .105);
        p.txt('나란히 놓아 둔\n우리의 약속', .09, .27, .81, .21, size: .066);
        p.rule(.09, .525, .81);
        p.pic(
          'petal_bouquet',
          .09,
          .585,
          .34,
          .265,
          frame: 'studioPhotoCorners',
        );
        p.txt('손에 쥔 부케\n서로 고른 반지\n접어 둔 손수건', .52, .615, .39, .205, size: .029);
      });
      page(5, '#FFFFFF', (p) {
        p.pic('petal_couple', .045, .045, .91, .79);
        p.label('나란히 선 두 사람', .08, .869, .83);
      });
      page(6, '#E7ECE6', (p) {
        p.label('TWO PEOPLE / ONE PROMISE', .09, .07, .82);
        p.txt('같은 곳을\n바라보는 사이', .09, .18, .82, .23, size: .076);
        p.rule(.09, .465, .18);
        p.pic(
          'lightbound_ceremony',
          .09,
          .545,
          .59,
          .285,
          frame: 'studioPhotoCorners',
        );
        p.mat('waveSilkKnot', .73, .62, .19, .18);
        p.label(copy.byline, .09, .864, .81);
      });
    case ConceptVolume.shoreDays:
      page(1, '#D8E7E5', (p) {
        p.label('해변에서 보낸 날 / 도착', .085, .065, .83);
        p.numeral('Coast', .075, .15, .84, .19, size: .17, color: '#24545D');
        p.mat('materialContourMap', .075, .40, .48, .415);
        p.txt('바다가 보이기\n시작했다', .625, .46, .30, .21, size: .041);
        p.mat('waveSeaGlass', .66, .725, .20, .15);
        p.label('FIELD NOTES / 01', .075, .857, .50);
      });
      page(2, '#296B74', (p) {
        p.pic('travel_coast', .045, .055, .91, .70, frame: 'atelierCoastline');
        p.txt(
          '짐을 내려놓고\n곧장 바다로',
          .085,
          .803,
          .67,
          .10,
          size: .032,
          color: '#F2F7F3',
        );
        p.label('01', .81, .821, .10, color: '#F2F7F3');
      }, dark: true);
      page(3, '#F4F6F0', (p) {
        p.label('02 / 해안선을 따라', .075, .065, .85);
        p.pic('travel_harbor', .07, .19, .62, .54, frame: 'studioDeckle');
        p.mat('materialTransitPunch', .74, .20, .18, .285);
        p.label('09:10', .76, .33, .14);
        p.txt('지도를 접고, 걷는 날', .075, .80, .84, .10, size: .051);
      });
      page(4, '#C2DCD8', (p) {
        p.numeral('On foot', .075, .065, .85, .18, size: .13);
        p.pic('travel_street', .08, .295, .49, .49, frame: 'studioPostcard');
        p.pic(
          'journey_market',
          .645,
          .49,
          .275,
          .245,
          frame: 'materialSlideMount',
        );
        p.txt('같은 길에서\n다른 풍경을 찾았다.', .645, .29, .275, .17, size: .029);
        p.label('바다 곁의 작은 마을', .08, .855, .84);
      });
      page(5, '#E8F0EA', (p) {
        p.pic('travel_harbor', .04, .045, .92, .72);
        p.txt('배가 돌아오는 시간', .08, .81, .83, .095, size: .049);
      });
      page(6, '#F5F7F1', (p) {
        p.label('FROM THE HARBOUR', .08, .065, .84);
        p.numeral('Collected', .075, .17, .85, .17, size: .117);
        p.mat('materialSpecimenPocket', .075, .405, .43, .365);
        p.mat('waveSeaGlass', .145, .485, .29, .205);
        p.txt('주머니에 담아 온\n작은 물빛', .575, .42, .345, .17, size: .043);
        p.pic('travel_coast', .62, .655, .27, .18, frame: 'studioPhotoCorners');
        p.mat('materialShell', .48, .785, .11, .075);
        p.label('돌아와서도 기억하고 싶은 것', .08, .858, .84);
      });
    case ConceptVolume.readingRoom:
      page(1, '#EDF1F3', (p) {
        p.label('문장을 모으는 생활 / 책상에 앉기 전', .08, .065, .84);
        p.numeral('In the margins', .075, .17, .85, .14, size: .103);
        p.txt('읽고, 적고,\n다시 펼치는 날들', .08, .355, .84, .23, size: .069);
        p.box(p.uid, .08, .623, .84, .006, '#244993');
        p.txt(
          '책 한 권과 노트 한 권.\n오늘 남겨 둘 문장을 고른다.',
          .08,
          .705,
          .63,
          .145,
          size: .029,
        );
        p.mat('wavePencil', .76, .70, .16, .18);
      });
      page(2, '#244993', (p) {
        p.pic('daily_desk', .055, .065, .89, .70);
        p.label('창을 열고 책상을 조금 비웠다.', .08, .837, .84, color: '#F2F6F4');
      }, dark: true);
      page(3, '#F4F6F1', (p) {
        p.label('02 / 오늘 펼친 책', .08, .065, .84);
        p.numeral('Ex Libris', .075, .15, .85, .15, size: .124);
        p.pic('daily_book', .08, .365, .55, .435, frame: 'atelierFolio');
        p.mat('materialBookmark', .74, .38, .15, .26);
        p.txt('좋아하는 구절\n옆에 날짜를', .69, .68, .23, .16, size: .027);
        p.label(copy.byline, .08, .865, .54);
      });
      page(4, '#DEE7ED', (p) {
        p.numeral('Reading notes', .075, .075, .85, .14, size: .101);
        p.mat('atelierGridLeaf', .075, .29, .84, .37);
        p.txt(
          '오늘의 책\n\n책을 펼친 자리\n\n오래 남은 문장',
          .14,
          .345,
          .67,
          .275,
          size: .027,
        );
        p.rule(.08, .72, .84);
        p.txt('다 읽은 뒤에도\n다시 돌아가고 싶은 페이지.', .08, .765, .84, .13, size: .032);
      });
      page(5, '#244993', (p) {
        p.label('UNDERLINES, WITHOUT A PEN', .08, .065, .84, color: '#EFF4F2');
        p.txt(
          '밑줄 대신\n그날의 풍경',
          .08,
          .21,
          .84,
          .275,
          size: .093,
          color: '#EFF4F2',
        );
        p.box(p.uid, .08, .545, .64, .010, '#BBD3E0');
        p.txt(
          '좋아하는 구절 옆에\n사진 한 장을 놓아 두었다.',
          .08,
          .68,
          .83,
          .16,
          size: .037,
          color: '#EFF4F2',
        );
      }, dark: true);
      page(6, '#F3F6F2', (p) {
        p.pic(
          'daily_book',
          .075,
          .08,
          .66,
          .45,
          frame: 'materialNotebookMount',
        );
        p.mat('materialClip', .76, .12, .12, .08);
        p.txt('접어 둔 페이지가\n자꾸 생각났다.', .10, .62, .80, .18, size: .057);
        p.label('사진 뒤에도 한 줄을 적었다.', .10, .855, .80);
      });
    case ConceptVolume.firstWardrobe:
      page(1, '#DCE7E8', (p) {
        p.label('너의 작은 옷장 / 첫 계절의 기록', .085, .065, .83);
        p.numeral(
          'Little things',
          .075,
          .16,
          .85,
          .15,
          size: .118,
          color: '#385873',
        );
        p.txt(
          '작은 옷을\n접어 두는 마음',
          .085,
          .34,
          .83,
          .225,
          size: .070,
          color: '#385873',
        );
        p.mat('lifeBonnet', .08, .61, .28, .21);
        p.rule(.435, .64, .45);
        p.txt(
          '너를 기다리며 골랐던 것들.\n함께 자란 마음도 남겨 둔다.',
          .435,
          .70,
          .45,
          .145,
          size: .025,
        );
      });
      page(2, '#385873', (p) {
        p.pic('growth_keepsakes', .05, .055, .90, .745);
        p.mat('materialCrossStitchBand', .63, .07, .27, .05);
        p.label('아직은 조금 큰 옷', .085, .85, .83, color: '#F4F7F2');
      }, dark: true);
    case ConceptVolume.sundayPicnic:
      page(1, '#E5EBDD', (p) {
        p.label('일요일의 피크닉 / 이번 주의 약속', .085, .065, .83);
        p.numeral(
          'Sunday!',
          .075,
          .15,
          .85,
          .185,
          size: .157,
          color: '#70443E',
        );
        p.txt(
          '돗자리를 펼치면\n우리의 자리가 된다',
          .085,
          .37,
          .83,
          .205,
          size: .060,
          color: '#70443E',
        );
        p.mat('materialCrossStitchBand', .08, .615, .30, .047);
        p.mat('lifeBasket', .105, .655, .27, .19);
        p.txt('도시락과 작은 약속,\n오래 웃을 시간까지.', .565, .69, .345, .14, size: .029);
      });
      page(2, '#596E4F', (p) {
        p.group(
          'family_picnic',
          .055,
          .09,
          .89,
          .62,
          frame: 'studioPhotoCorners',
        );
        p.txt(
          '같이 앉아서\n오래 웃은 날',
          .085,
          .755,
          .70,
          .13,
          size: .042,
          color: '#F5F7EE',
        );
      }, dark: true);
    case ConceptVolume.sharedSeasons:
      page(1, '#EAE6E8', (p) {
        p.label('같이 사는 계절 / 우리 집의 첫 장', .085, .065, .83);
        p.numeral('At home', .085, .135, .83, .105, size: .082);
        final width = math.min(.86, .58 * (1388 / 1133) / p.ratio);
        final paper = p.mat(
          'studioCottonRag',
          (1 - width) / 2,
          .28,
          width,
          .58,
        );
        p.paperText(paper, '같이 사는\n계절', .13, .18, .75, .43, size: .080);
        p.paperText(
          paper,
          copy.period,
          .13,
          .76,
          .74,
          .09,
          size: .020,
          font: 'NotoSans',
        );
        p.mat('studioOlivePress', .065, .665, .19, .17);
        p.label('함께 돌아올 곳이 있다는 것', .28, .866, .64);
      });
      page(2, '#5D525F', (p) {
        p.pic('couple_anniversary', .055, .065, .89, .70);
        p.label('같은 문을 열고 들어오는 사이', .085, .843, .83, color: '#F6F3F4');
      }, dark: true);
    case ConceptVolume.littleCompanion:
      page(1, '#DDE9E5', (p) {
        p.label('작은 동거인 / 우리 집의 새 식구', .085, .065, .83);
        p.numeral('Hello, friend.', .075, .15, .85, .155, size: .115);
        p.txt('말없이 곁을\n채워 주는 너', .085, .35, .83, .235, size: .076);
        p.rule(.085, .635, .17);
        p.txt('너의 작은 버릇과\n함께 보내는 평범한 하루.', .085, .70, .57, .15, size: .030);
        p.mat('lifeRopeBall', .74, .67, .16, .15);
      });
      page(2, '#31666A', (p) {
        p.pic('pet_cat', .045, .045, .91, .77);
        p.label('너의 이름을 부르면', .085, .85, .83, color: '#F4F7F1');
      }, dark: true);
  }
  return {
    ...baseline,
    'version': volume.contentRevision + 1,
    'qualityRevision': conceptQualityRevision,
    'qualityReview': 'pending-visual-approval',
    'coverRevision': catalogCoverRevision,
    'cover': cover,
    'pages': pages,
  };
}
