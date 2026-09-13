part of 'authored_collections.dart';

void _volumeDaily(_VolumeAuthor b) {
  b.spread('아침에 꺼낸 그릇', 1, () {
    b.page('breakfast-print', '#DCE5E4');
    b.paper('studioBlueFibre', .04, .12, .89, .72, turn: -3);
    b.photo('small_days_breakfast', .10, .19, .79, .51, mounted: true, turn: 2);
    b.paper('studioWashiIndigo', .20, .16, .32, .052, turn: -3);
    b.caption('늘 쓰던 그릇에 아침을 담았다.');
    b.end();
    b.page('breakfast-receipt', '#F0F1E9');
    b.heading('오늘의 첫 끼');
    b.stock(.115, .22, .71, .56, '#FBFAF5');
    b.stock(.20, .25, .0015, .47, '#B5C5C2');
    b.text(
      '빵을 굽고\n차를 한 잔 따르고\n천천히 앉았다.',
      .27,
      .32,
      .47,
      .29,
      size: .031,
      leading: 1.8,
    );
    b.paper('travelCafeReceipt', .71, .64, .17, .25, turn: 6);
    b.paper('studioWashiSage', .18, .20, .30, .052);
    b.end();
  });
  b.spread('집을 나서기 전', 1, () {
    b.page('window-margin', '#CFDCDE');
    b.photo(
      'small_days_walk',
      .065,
      .075,
      .60,
      .79,
      natural: false,
      frame: 'studioDeckle',
    );
    b.stock(.735, .14, .006, .48, '#688789');
    b.text('꽃을\n한 다발\n안았다', .77, .20, .17, .36, size: .034, leading: 1.6);
    b.paper('studioArchiveTag', .71, .64, .17, .22, turn: 3);
    b.end();
    b.page('before-leaving-list', '#EAEFEA');
    b.heading('나가기 전에 적어 둔 것');
    b.paper('travelNotebook', .11, .21, .71, .68, turn: -2);
    b.stock(.19, .31, .58, .43, '#F5F5EB');
    b.text(
      '꽃에 물 주기\n빌린 책 돌려주기\n집에 올 때 과일 사기',
      .235,
      .365,
      .49,
      .29,
      size: .028,
      leading: 1.9,
    );
    b.paper('studioOlivePress', .72, .67, .16, .21, turn: 6);
    b.end();
  });
  b.spread('책상에 남은 흔적', 1, () {
    b.page('desk-cutout', '#C7D6D9');
    b.stock(.075, .075, .055, .68, '#466570');
    b.photo('daily_desk', .18, .11, .72, .49, frame: 'studioTorn');
    b.card(
      'heirloomVowPlaceCard',
      '하던 일을\n잠깐 멈춘 자리',
      .38,
      .67,
      .50,
      .21,
      size: .028,
      turn: -2,
    );
    b.paper('studioWashiIndigo', .67, .07, .22, .045, turn: 6);
    b.end();
    b.page('desk-inventory', '#ECF0ED');
    b.heading('책상 위 세 가지');
    b.paper('heirloomLibraryCard', .07, .21, .32, .63);
    b.stock(.10, .33, .245, .29, '#E5EBE8');
    b.text(
      '01\n02\n03',
      .145,
      .36,
      .15,
      .24,
      size: .038,
      font: 'Cormorant Garamond',
      leading: 1.65,
    );
    b.text(
      '다 읽지 못한 책\n짧아진 연필\n미지근한 차',
      .47,
      .34,
      .43,
      .30,
      size: .027,
      leading: 2.1,
    );
    b.caption('다시 돌아와 이어 갈 일들');
    b.end();
  });
  b.spread('읽다가 오래 머문 문장', 2, () {
    b.page('reading-open-margin', '#DFE6E2');
    b.heading('책장을 접어 두고');
    b.photo('daily_book', .06, .235, .85, .50, mounted: true);
    b.paper('studioWashiSage', .66, .204, .24, .057, turn: 7);
    b.card(
      'heirloomVowPlaceCard',
      '여기까지 읽었다.',
      .12,
      .768,
      .48,
      .13,
      size: .023,
    );
    b.end();
    b.page('copied-sentence', '#F1F2EC');
    final letter = b.paper('studioCottonRag', .08, .08, .83, .73, turn: 2);
    b.paperText(
      letter,
      '다 읽고 나서\n말해 주고 싶은 책',
      .14,
      .20,
      .72,
      .33,
      size: .044,
      leading: 1.4,
    );
    b.stock(
      letter.left + letter.width * .14,
      letter.top + letter.height * .59,
      letter.width * .70,
      .002,
      '#A3B3AC',
    );
    b.paperText(
      letter,
      '제목과 작가를 적어 두고,\n좋았던 문장을 한 줄 옮겼다.',
      .14,
      .67,
      .72,
      .21,
      size: .027,
    );
    b.paper('studioWashiIndigo', .58, .80, .29, .06, turn: -3);
    b.end();
  });
  b.reversedSpread('잠깐 쉬어 가는 시간', 2, () {
    b.page('tea-coaster', '#D8E3E1');
    b.paper('travelCafeCoaster', .09, .10, .74, .67, turn: -5);
    final d = math.min(.53, .46 / b.ratio);
    b.photo(
      'small_days_breakfast',
      .17,
      .20,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOval',
    );
    b.paper('travelCafeReceipt', .70, .50, .19, .34, turn: 6);
    b.caption('컵을 비우는 동안');
    b.end();
    b.page('tea-pause-note', '#EDF0E7');
    b.heading('서두르지 않은 오후');
    b.stock(.12, .26, .72, .36, '#FBFAF5', turn: -2);
    b.text('한 잔을 다 마실 때까지\n다음 일은 잠깐 미뤄 두었다.', .19, .35, .58, .18, size: .032);
    b.photo('daily_fruit', .47, .67, .39, .20, frame: 'studioDeckle');
    b.paper('studioWashiSage', .44, .645, .22, .045, turn: -5);
    b.end();
  });
  b.reversedSpread('집에 들인 작은 계절', 2, () {
    b.page('flower-specimen', '#D5E0D5');
    b.photo(
      'small_days_walk',
      .075,
      .09,
      .69,
      .75,
      natural: false,
      frame: 'studioTorn',
    );
    b.paper('studioPressedCosmos', .73, .32, .17, .31, turn: 6);
    b.caption('꽃 한 다발을 나누어 꽂았다.');
    b.end();
    b.page('fruit-market-slip', '#EBEEE4');
    b.heading('돌아오는 길에 고른 것');
    b.paper('studioCottonRag', .13, .205, .79, .55, turn: 3);
    b.photo('daily_fruit', .20, .27, .60, .43, mounted: true);
    b.paper('travelMarketReceipt', .04, .55, .20, .32, turn: -6);
    b.caption('저녁에 같이 먹을 만큼만', x: .33, w: .58);
    b.end();
  });
  b.spread('가까운 곳으로 소풍', 3, () {
    b.page('picnic-wrapped-print', '#DFE7DE');
    b.paper('heirloomTableLinen', .075, .10, .85, .72, turn: 3);
    b.photo('daily_picnic', .125, .17, .75, .50, frame: 'studioGallery');
    b.paper('studioSageRibbon', .07, .69, .18, .18);
    b.caption('멀리 가지 않아도 좋았다.', x: .30, w: .61);
    b.end();
    b.page('picnic-foldout', '#F0F2EB');
    b.heading('소풍 가방의 목록');
    b.stock(.11, .22, .78, .53, '#FAFAF5');
    b.stock(.47, .24, .002, .48, '#BECBC0');
    b.text('담아 간 것\n\n빵과 과일\n작은 돗자리\n읽던 책', .17, .29, .26, .38, size: .025);
    b.text('가져온 것\n\n남은 빵\n사진 몇 장\n다음 약속', .53, .29, .29, .38, size: .025);
    b.paper('studioWashiSage', .28, .78, .35, .055, turn: -3);
    b.end();
  });
  b.reversedSpread('약속이 있던 날', 3, () {
    b.page('friends-contact', '#D6E0E1');
    b.heading('오랜만에 마주 앉아');
    b.photo('family_friends', .055, .25, .89, .52, mounted: true);
    b.paper('studioWashiIndigo', .11, .21, .27, .05, turn: -4);
    b.caption('사진보다 오래 이어진 이야기');
    b.end();
    b.page('evening-file-pocket', '#EEF0E8');
    b.paper('travelPhotoSleeve', .13, .11, .73, .65, turn: -2);
    b.stock(.21, .19, .60, .40, '#FCFBF4');
    b.text('다음에도\n이 시간에 만나자.', .26, .27, .49, .23, size: .043);
    b.card(
      'heirloomVowPlaceCard',
      '함께한 이름을 적어 둔다.',
      .19,
      .72,
      .61,
      .17,
      size: .023,
    );
    b.end();
  });
}

void _volumePet(_VolumeAuthor b) {
  b.spread('산책 가방을 챙기며', 1, () {
    b.page('walking-bag-flatlay', '#DCE5CF');
    b.heading('문을 나서기 전에');
    b.paper('studioCottonRag', .08, .21, .83, .62, turn: -3);
    b.photo('pet_keepsakes', .13, .27, .73, .45, frame: 'studioGallery');
    b.paper('heirloomPetTag', .73, .64, .14, .22, turn: 7);
    b.caption('늘 같이 챙기는 것들');
    b.end();
    b.page('walk-checklist', '#F0F1E4');
    b.paper('travelNotebook', .13, .07, .70, .79);
    b.stock(.20, .25, .55, .45, '#F4F4E9');
    b.text('산책 준비', .24, .29, .45, .07, size: .037);
    b.text(
      '목줄을 확인하고\n물을 조금 담고\n간식은 작은 주머니에',
      .24,
      .42,
      .45,
      .25,
      size: .027,
      leading: 1.8,
    );
    b.paper('studioWashiSage', .29, .79, .32, .055, turn: -3);
    b.end();
  });
  b.reversedSpread('네가 먼저 고른 길', 1, () {
    b.page('park-trail-photo', '#CBDACD');
    b.photo(
      'pet_walk',
      .08,
      .07,
      .72,
      .76,
      natural: false,
      frame: 'studioDeckle',
    );
    b.stock(.86, .17, .006, .43, '#739279');
    b.caption('오늘은 네가 앞장섰다.');
    b.end();
    b.page('route-field-note', '#EDF0E6');
    b.heading('자주 멈추는 자리');
    b.paper('travelContourSlip', .12, .22, .76, .56, turn: -3);
    b.stock(.17, .31, .64, .34, '#F8F8ED');
    b.text(
      '큰 나무 아래\n골목 끝의 모퉁이\n집으로 돌아오는 계단',
      .23,
      .37,
      .52,
      .24,
      size: .029,
      leading: 1.8,
    );
    b.paper('studioOlivePress', .72, .69, .16, .20);
    b.end();
  });
  b.spread('한 번 더 돌아본 얼굴', 1, () {
    b.page('park-portrait-mat', '#DDE5D6');
    b.stock(.12, .10, .77, .70, '#FAFAF3');
    b.photo('pet_dog', .16, .15, .69, .55, frame: 'studioOvalMat');
    b.paper('studioWashiSage', .38, .08, .28, .047);
    b.caption('이름을 부르면 돌아보는 표정');
    b.end();
    b.page('name-collar-record', '#EEF0E1');
    b.paper('heirloomPetTag', .09, .18, .29, .54, turn: -3);
    b.text('너를 부르는\n여러 가지 이름', .46, .23, .43, .18, size: .038);
    b.stock(.47, .47, .36, .002, '#9AAF93');
    b.text('기분이 좋을 때도,\n잠이 쏟아질 때도\n알아듣는 그 이름.', .47, .54, .39, .23, size: .026);
    b.paper('studioWashiSage', .48, .83, .30, .05, turn: 4);
    b.end();
  });
  b.spread('조금씩 알아가는 취향', 2, () {
    b.page('favorite-object-shelf', '#D5E0CE');
    b.heading('제일 먼저 고르는 것');
    b.photo('pet_keepsakes', .075, .22, .80, .47, mounted: true, turn: -2);
    b.card(
      'heirloomVowPlaceCard',
      '낡아도 좋은\n너의 물건들',
      .39,
      .71,
      .48,
      .18,
      size: .024,
    );
    b.end();
    b.page('preferences-notebook', '#EDF0E7');
    b.stock(.10, .12, .79, .69, '#F8F8EF');
    b.heading('너의 취향 사전', x: .17, y: .19, w: .68, size: .038);
    for (final item in [('좋아하는 간식', .37), ('편하게 쉬는 곳', .50), ('신나는 놀이', .63)]) {
      b.text(item.$1, .18, item.$2, .53, .06, size: .028);
      b.stock(.18, item.$2 + .081, .58, .0015, '#B5C3AD');
    }
    b.paper('studioOlivePress', .75, .65, .14, .20);
    b.end();
  });
  b.reversedSpread('잠들기 직전의 얼굴', 2, () {
    b.page('sleep-blanket-print', '#DAE2DC');
    b.paper('studioBlueFibre', .045, .12, .88, .64, turn: 3);
    b.photo('pet_nap', .11, .20, .76, .50, mounted: true);
    b.caption('소리를 조금 낮추었다.');
    b.end();
    b.page('sleep-observation', '#F0F2E9');
    b.heading('어디서든 편안하기를');
    final letter = b.paper('studioCottonRag', .13, .24, .73, .48, turn: -2);
    b.paperText(
      letter,
      '몸을 동그랗게 말고\n익숙한 자리에서 잠이 들었다.\n오늘 산책은 즐거웠을까.',
      .14,
      .22,
      .72,
      .57,
      size: .029,
      leading: 1.8,
    );
    b.paper('studioSageRibbon', .64, .73, .22, .17);
    b.end();
  });
  b.spread('집에서 하는 작은 놀이', 2, () {
    b.page('home-play-roundel', '#CFDCC9');
    final d = math.min(.70, .62 / b.ratio);
    b.photo(
      'pet_cat',
      .12,
      .13,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOvalMat',
    );
    b.paper('heirloomPetTag', .72, .58, .16, .27, turn: 6);
    b.caption('네가 먼저 다가온 순간');
    b.end();
    b.page('play-story-cards', '#E9EEE3');
    b.heading('오늘의 작은 사건');
    b.stock(.10, .235, .73, .235, '#FAFAF4', turn: -2);
    b.text('한참을 바라보다\n장난감을 툭 건드렸다.', .17, .29, .56, .13, size: .029);
    b.stock(.27, .565, .63, .23, '#D5E0CD', turn: 2);
    b.text('아무 일도 아닌데\n자꾸 사진을 찍게 된다.', .34, .62, .48, .13, size: .026);
    b.paper('studioWashiSage', .43, .54, .30, .05);
    b.end();
  });
  b.reversedSpread('날씨가 바뀌어도 같이', 3, () {
    b.page('walk-weather-window', '#D1DFDD');
    b.stock(.08, .09, .06, .74, '#71988C');
    b.photo('pet_walk', .19, .15, .68, .47, mounted: true);
    b.card(
      'heirloomVowPlaceCard',
      '서두르지 않고\n같이 돌아왔다.',
      .39,
      .69,
      .47,
      .20,
      size: .026,
    );
    b.end();
    b.page('weather-log', '#EBF0E6');
    b.heading('날씨와 걸음');
    b.paper('travelNotebook', .11, .22, .76, .64, turn: -2);
    b.stock(.19, .29, .60, .40, '#F5F6EE');
    b.text(
      '나간 시간\n함께 걸은 길\n집에 와서 한 일',
      .235,
      .35,
      .50,
      .28,
      size: .029,
      leading: 2,
    );
    b.paper('studioWashiSage', .15, .77, .31, .054);
    b.end();
  });
  b.spread('함께 쉬는 주말', 3, () {
    b.page('weekend-wide-rest', '#DDE5D5');
    b.heading('오늘은 집에서 오래');
    b.photo('pet_rest', .065, .23, .87, .53, frame: 'studioDeckle');
    b.caption('같은 공간에 있는 것만으로');
    b.end();
    b.page('weekend-keeping-note', '#EFF0E4');
    b.paper('studioGlassineEnvelope', .09, .22, .81, .56, turn: 2);
    b.stock(.15, .15, .66, .39, '#FAFAF3');
    b.text('너의 평범한 하루를\n오래 기억하고 싶다.', .21, .24, .55, .20, size: .037);
    b.paper('heirloomPetTag', .15, .61, .17, .23, turn: -5);
    b.caption(b.copy.byline, x: .46, y: .79, w: .40);
    b.end();
  });
}
