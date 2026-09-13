part of 'authored_collections.dart';

void _conceptReading(_ConceptBook b) {
  b.add('reading-opening-index', '#EDF0F3', (p) {
    p.label('A READING LIFE', .08, .06, .84);
    p.rule(.08, .135, .84);
    p.numeral('Contents', .08, .19, .84, .18, size: .123);
    p.txt('책상에 앉기 전', .08, .41, .85, .12, size: .065);
    p.mat('atelierGridLeaf', .08, .60, .51, .27);
    p.txt('책 한 권\n노트 한 권\n짧아진 연필', .135, .635, .42, .17, size: .029);
    p.mat('wavePencil', .65, .59, .27, .28);
  });
  b.add('desk-room-plate', '#D9E3EE', (p) {
    p.pic('daily_desk', .05, .065, .90, .72);
    p.label('창을 열고 책상을 조금 비웠다.', .08, .845, .8);
  });
  b.add('book-exlibris', '#F9F9F4', (p) {
    p.mat('atelierArchiveSeal', .12, .09, .74, .46);
    p.numeral('Ex Libris', .245, .225, .53, .13, size: .090);
    p.txt(b.copy.byline, .235, .385, .54, .085, size: .03);
    p.rule(.10, .64, .79);
    p.txt('오늘 펼친 책', .10, .72, .79, .12, size: .068);
  });
  b.add('open-book-frame', '#DCE5ED', (p) {
    p.pic('daily_book', .08, .10, .84, .62, frame: 'atelierFolio');
    p.mat('materialBookmark', .69, .61, .20, .25);
    p.label('READING NOTES / 02', .08, .83, .57);
  });
  b.add('underline-typographic', '#F6F7F3', (p) {
    p.label('IN THE MARGINS', .08, .07, .83);
    p.txt('밑줄 대신\n사진', .08, .21, .82, .27, size: .095);
    p.box('underline', .085, .485, .42, .012, '#356BB0');
    p.txt('좋아하는 구절 옆에\n그날의 풍경을 놓아 두었다.', .09, .63, .73, .16, size: .038);
    p.mat('wavePencil', .70, .76, .21, .12);
  });
  b.add('book-and-margin-note', '#E3EAF0', (p) {
    p.pic('daily_book', .08, .08, .64, .44, frame: 'materialNotebookMount');
    p.mat('atelierGridLeaf', .33, .52, .57, .33);
    p.txt('다 읽고 나서도\n접어 둔 페이지가\n자꾸 생각났다.', .40, .60, .45, .19, size: .030);
    p.mat('materialClip', .50, .485, .13, .08);
  });
  b.add('window-room-vertical', '#F9F9F4', (p) {
    p.pic('daily_desk', .045, .06, .66, .80);
    p.txt('창가의\n자리', .755, .20, .21, .23, size: .044);
    p.label('04 / HOME', .75, .79, .23);
  });
  b.add('window-time-study', '#244993', (p) {
    p.numeral('14:30', .09, .07, .79, .19, size: .18, color: '#EDF2F4');
    p.pic('daily_book', .10, .40, .63, .38, frame: 'studioPhotoCorners');
    p.txt('같은 자리에서\n한 장 더', .52, .27, .38, .12, size: .032, color: '#F1F5F5');
    p.label('오후에는 책장을 더 천천히 넘겼다.', .10, .845, .81, color: '#F1F5F5');
  }, dark: true);
  b.add('reading-outside', '#E4ECE4', (p) {
    p.numeral('Outside', .08, .06, .84, .16, size: .135);
    p.pic('daily_picnic', .06, .285, .88, .48, frame: 'atelierOxford');
    p.txt('밖에서 읽는 날', .09, .815, .81, .095, size: .044);
  });
  b.add('picnic-pocket-layout', '#F8F9F4', (p) {
    p.mat('materialSpecimenPocket', .08, .09, .69, .55);
    p.pic('daily_book', .17, .19, .51, .36, frame: 'studioInstant');
    p.mat('materialBookmark', .72, .25, .19, .32);
    p.txt('가방에 넣은 책 한 권', .10, .74, .79, .12, size: .049);
    p.label('가볍게 나갔다가 오래 앉아 있었다.', .10, .865, .82);
  });
  b.add('walk-tall-prints', '#DDE7EC', (p) {
    p.pic('small_days_walk', .06, .07, .41, .58, frame: 'studioPhotoCorners');
    p.pic('daily_fruit', .53, .29, .40, .41, frame: 'studioPhotoCorners');
    p.txt('돌아오는 길', .085, .80, .82, .10, size: .058);
  });
  b.add('walk-receipt-note', '#F7F8F4', (p) {
    p.numeral('06', .08, .08, .21, .2, color: '#A8BDD1', size: .16);
    p.pic('daily_fruit', .09, .34, .18, .22, frame: 'studioSticker');
    p.mat('atelierGridLeaf', .31, .145, .6, .39);
    p.txt('오늘 가져온 것', .38, .23, .46, .1, size: .038);
    p.txt('책갈피 한 장\n제철 과일 조금\n천천히 걷던 기분', .38, .34, .46, .17, size: .028);
    p.rule(.09, .655, .8);
    p.txt('책을 덮은 뒤의\n시간도 남긴다', .09, .72, .8, .17, size: .044);
  });
  b.add('breakfast-and-book', '#ECEEE7', (p) {
    p.label('BETWEEN BREAKFAST & A BOOK', .08, .06, .82);
    p.pic('small_days_breakfast', .045, .195, .91, .57);
    p.mat('materialClip', .80, .145, .12, .08);
    p.txt('책과 식탁 사이', .08, .83, .72, .09, size: .043);
  });
  b.add('daily-still-life-notes', '#F9FAF5', (p) {
    p.pic('daily_fruit', .11, .09, .54, .43, frame: 'atelierCornerFold');
    p.txt('읽다가,\n차를 끓이다가', .10, .62, .80, .19, size: .059);
    p.mat('wavePencil', .70, .28, .22, .27);
    p.label('평범해서 더 오래 남기고 싶은 장면.', .10, .85, .80);
  });
  b.add('reading-together-plate', '#D6E2E4', (p) {
    p.numeral('In company', .08, .06, .83, .17, size: .10);
    p.pic('daily_friends', .055, .28, .89, .50);
    p.txt('함께 읽은 시간', .09, .82, .8, .09, size: .044);
  });
  b.add('conversation-transcript', '#F7F8F2', (p) {
    p.label('A CONVERSATION / 08', .09, .065, .8);
    p.rule(.09, .15, .8);
    p.numeral('Q.', .09, .20, .17, .11, size: .08);
    p.txt('어떤 문장이 남았어?', .30, .235, .60, .10, size: .036);
    p.numeral('A.', .09, .39, .17, .11, size: .08);
    p.txt('다 읽고 나서\n처음으로 돌아가게 한 문장.', .30, .42, .60, .17, size: .029);
    p.pic('daily_book', .57, .67, .33, .22, frame: 'materialSlideMount');
    p.caption('같은 책, 다른 밑줄.', .10, .76, .41);
  });
  b.add('notebook-document', '#E7ECED', (p) {
    p.mat('atelierGridLeaf', .07, .08, .84, .55);
    p.label('NOTES / 09', .155, .15, .7);
    p.txt(b.copy.note, .16, .28, .66, .22, size: .032);
    p.mat('wavePencil', .59, .43, .30, .22);
    p.txt('노트에 남긴 것', .09, .77, .82, .12, size: .059);
  });
  b.add('notebook-desk-inset', '#FAFAF5', (p) {
    p.pic('daily_desk', .07, .075, .64, .50, frame: 'materialNotebookMount');
    p.pic('daily_book', .50, .61, .41, .27, frame: 'studioInstant');
    p.mat('materialClip', .24, .045, .15, .075);
    p.txt('사진 뒤에도\n한 줄을 적었다.', .09, .71, .34, .13, size: .032);
  });
  b.add('rereading-number', '#234A87', (p) {
    p.numeral('Again', .075, .065, .85, .23, size: .19, color: '#EDF4F4');
    p.txt('다시 찾은\n문장', .08, .34, .81, .26, size: .085, color: '#F3F5F3');
    p.mat('materialBookmark', .74, .62, .16, .26);
    p.txt(
      '같은 문장이\n다르게 읽히는 날.',
      .085,
      .735,
      .59,
      .14,
      size: .034,
      color: '#F3F5F3',
    );
  }, dark: true);
  b.add('reopened-book', '#E5EBEC', (p) {
    p.pic('daily_book', .09, .09, .82, .64, frame: 'studioDoubleMat');
    p.box('blue_marker', .09, .775, .08, .015, '#356BB0');
    p.caption('접어 둔 자리를 다시 펼쳤다.', .22, .80, .68);
  });
  b.add('month-contact-sheet', '#F8F9F4', (p) {
    p.txt('한 달의 책상', .085, .07, .82, .13, size: .063);
    p.pic('daily_desk', .085, .27, .53, .49, frame: 'atelierNegative');
    p.pic('daily_book', .655, .27, .26, .22, frame: 'materialSlideMount');
    p.pic('daily_fruit', .655, .54, .26, .22, frame: 'materialSlideMount');
    p.label(b.copy.period, .085, .84, .8);
  });
  b.add('month-index', '#DDE6EB', (p) {
    p.numeral('Index', .085, .055, .82, .20, size: .16);
    for (var i = 0; i < 4; i++) {
      final y = .34 + i * .13;
      p.rule(.09, y, .80, color: '#9AAFC0');
      p.label('0${i + 1}', .09, y + .027, .12);
      p.txt(
        ['창가에서 읽은 책', '가방에 넣어 간 책', '친구와 이야기한 책', '다시 펼친 책'][i],
        .27,
        y + .02,
        .62,
        .085,
        size: .032,
      );
    }
  });
  b.add('reading-colophon', '#FAFAF5', (p) {
    p.label('TO BE CONTINUED', .09, .075, .8);
    p.txt('다음 책을\n펼치며', .09, .20, .81, .25, size: .081);
    p.rule(.09, .535, .80);
    p.txt(b.copy.note, .10, .60, .78, .16, size: .03);
    p.mat('wavePencil', .67, .73, .22, .15);
    p.caption(b.copy.byline, .10, .82, .53);
  });
  b.add('reading-last-plate', '#DCE6E8', (p) {
    p.pic('daily_desk', .10, .09, .80, .64, frame: 'studioPhotoCorners');
    p.txt('아직 읽고 싶은 날이 많다', .085, .80, .83, .10, size: .035, align: 'center');
  });
}
