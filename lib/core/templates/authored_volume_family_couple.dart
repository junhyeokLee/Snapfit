part of 'authored_collections.dart';

void _volumeFamily(_VolumeAuthor b) {
  b.spread('장을 보러 가는 아침', 1, () {
    b.page('market-cloth-print', '#DBE4D4');
    b.paper('heirloomTableLinen', .045, .14, .89, .68, turn: -3);
    b.photo('daily_fruit', .12, .20, .74, .47, mounted: true);
    b.paper('travelMarketReceipt', .73, .61, .16, .24, turn: 5);
    b.caption('모일 사람들을 생각하며 골랐다.');
    b.end();
    b.page('shopping-fold-list', '#EEF0E3');
    b.heading('오늘 장바구니');
    b.stock(.12, .23, .73, .56, '#F9FAF1', turn: -2);
    b.stock(.30, .25, .002, .49, '#C0CBAE');
    b.text('채소\n과일\n빵', .17, .33, .12, .30, size: .030, leading: 2.2);
    b.text(
      '함께 나눌 만큼\n식사 뒤에 꺼낼 것\n남으면 싸 줄 것',
      .37,
      .33,
      .40,
      .30,
      size: .027,
      leading: 2.2,
    );
    b.paper('studioOlivePress', .71, .71, .15, .17);
    b.end();
  });
  b.spread('식탁보를 펴고', 1, () {
    b.page('table-setting-oval', '#CFDDCD');
    b.heading('자리를 하나씩 놓았다');
    b.paper('heirloomTableLinen', .07, .21, .82, .64, turn: 3);
    final d = math.min(.58, .48 / b.ratio);
    b.photo(
      'family_table',
      .12,
      .26,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOvalMat',
    );
    b.paper('studioOlivePress', .73, .37, .17, .29, turn: 5);
    b.end();
    b.page('seating-placecards', '#F0F1E7');
    b.heading('오늘 함께 앉은 이름');
    b.card(
      'heirloomVowPlaceCard',
      '오랜만에\n같이 앉은 자리',
      .10,
      .24,
      .69,
      .22,
      size: .030,
      turn: -2,
    );
    b.card(
      'heirloomVowPlaceCard',
      '누가 어디에 앉았는지\n그것까지 기억하고 싶다.',
      .29,
      .59,
      .60,
      .22,
      size: .023,
      turn: 3,
    );
    b.paper('studioSageRibbon', .08, .65, .18, .19);
    b.end();
  });
  b.reversedSpread('함께 손을 보태던 시간', 1, () {
    b.page('kitchen-shared-work', '#DDE5D7');
    b.photo('family_kitchen', .08, .11, .84, .55, mounted: true);
    b.paper('studioWashiSage', .59, .075, .30, .051, turn: -3);
    b.text('한 사람은 씻고\n한 사람은 썰고', .13, .74, .73, .14, size: .034);
    b.end();
    b.page('kitchen-memo-fold', '#EDF0E4');
    final letter = b.paper('studioCottonRag', .11, .10, .79, .76, turn: -2);
    b.paperText(letter, '이 집의 준비 순서', .13, .22, .74, .16, size: .039);
    b.paperText(
      letter,
      '제일 오래 걸리는 것부터.\n간은 한 번 더 같이 보고,\n맛있는 건 먼저 한 입씩.',
      .13,
      .48,
      .74,
      .39,
      size: .029,
      leading: 1.8,
    );
    b.paper('studioWashiSage', .36, .79, .31, .052, turn: 5);
    b.end();
  });
  b.spread('손에 익은 조리 도구', 2, () {
    b.page('kitchen-tools-margin', '#D6E1D0');
    b.photo(
      'family_kitchen',
      .065,
      .09,
      .56,
      .73,
      natural: false,
      frame: 'studioTorn',
    );
    b.stock(.71, .15, .006, .43, '#799775');
    b.text('매번\n꺼내 쓰는\n물건들', .77, .20, .17, .30, size: .032);
    b.caption('손때가 묻어서 더 익숙한 것');
    b.end();
    b.page('recipe-handed-note', '#F0F1E8');
    b.stock(.12, .18, .73, .60, '#FCFBF2');
    b.text('계량하지 않아도\n기억하는 맛', .20, .26, .59, .19, size: .045);
    b.stock(.20, .53, .57, .002, '#BBC8B3');
    b.text(
      '조금씩 넣고, 한 번 맛보고.\n다음에도 만들 수 있게 적어 둔다.',
      .20,
      .59,
      .59,
      .14,
      size: .026,
    );
    b.paper('studioOlivePress', .73, .70, .15, .17);
    b.end();
  });
  b.reversedSpread('식탁 위의 한 접시', 2, () {
    b.page('meal-mounted-card', '#DEE6D6');
    b.paper('heirloomTableLinen', .08, .17, .84, .61, turn: -3);
    b.photo('family_table', .14, .25, .70, .46, frame: 'studioGallery');
    b.caption('한 접시를 가운데 놓고 나누었다.');
    b.end();
    b.page('recipe-ingredients', '#EDF0E7');
    b.heading('다음에 또 만들 음식');
    b.stock(.09, .235, .78, .54, '#F9FAF2');
    b.text('재료', .16, .29, .20, .065, size: .034);
    b.text('넣었던 것과 양을 적고', .16, .40, .62, .075, size: .027);
    b.stock(.16, .52, .61, .0015, '#AABD9F');
    b.text('기억할 점', .16, .575, .52, .065, size: .034);
    b.text('맛을 바꾼 작은 차이까지', .16, .685, .62, .065, size: .025);
    b.end();
  });
  b.spread('후식이 나오기까지', 2, () {
    b.page('dessert-fruit-roundel', '#D3DFCC');
    final d = math.min(.70, .61 / b.ratio);
    b.photo(
      'daily_fruit',
      .12,
      .13,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOvalMat',
    );
    b.paper('studioOlivePress', .76, .57, .14, .22);
    b.caption('후식 앞에서는 조금 더 오래');
    b.end();
    b.page('dessert-conversation', '#EEF1E5');
    b.heading('식사 뒤에 이어진 말');
    final letter = b.paper('studioCottonRag', .10, .22, .79, .48, turn: 3);
    b.paperText(
      letter,
      '차를 한 번 더 따르고\n그동안의 이야기를 나눴다.',
      .14,
      .26,
      .72,
      .43,
      size: .033,
    );
    b.photo('small_days_breakfast', .43, .67, .44, .21, mounted: true);
    b.paper('studioWashiSage', .41, .641, .29, .05, turn: -4);
    b.end();
  });
  b.reversedSpread('집 밖에 차린 식탁', 3, () {
    b.page('family-picnic-print', '#D3DFD2');
    b.heading('밖에서 먹는 점심');
    b.photo('family_picnic', .07, .24, .86, .52, mounted: true);
    b.paper('studioWashiSage', .16, .207, .27, .05, turn: 3);
    b.caption('자리가 달라도 익숙한 사람들');
    b.end();
    b.page('picnic-packing-note', '#EDF0E6');
    b.paper('heirloomTableLinen', .08, .14, .85, .67, turn: -3);
    b.stock(.18, .24, .62, .44, '#FBFAF3');
    b.text(
      '가져가길 잘한 것\n\n도시락과 돗자리,\n같이 앉아 있을 시간.',
      .25,
      .30,
      .49,
      .31,
      size: .029,
    );
    b.paper('studioSageRibbon', .65, .69, .19, .17);
    b.end();
  });
  b.spread('남은 음식을 나누며', 3, () {
    b.page('leftovers-receipt', '#DCE5D8');
    b.photo('family_kitchen', .07, .15, .75, .48, frame: 'studioDeckle');
    b.card(
      'heirloomVowPlaceCard',
      '조금씩 싸 주고\n조금씩 받아 왔다.',
      .38,
      .70,
      .49,
      .19,
      size: .024,
    );
    b.paper('studioOlivePress', .08, .67, .21, .23);
    b.end();
    b.page('after-gathering-letter', '#EEF1E7');
    b.heading('집에 돌아가서도');
    b.paper('heirloomVowEnvelope', .10, .26, .79, .57, turn: -3);
    b.stock(.17, .21, .65, .37, '#FCFBF4');
    b.text('나눠 담은 음식 덕분에\n다음 날까지 모임이 이어졌다.', .23, .30, .54, .21, size: .032);
    b.caption('빈 통을 돌려줄 다음 약속');
    b.end();
  });
  b.reversedSpread('주말의 느린 아침', 1, () {
    b.page('weekend-breakfast', '#D8E2D5');
    b.photo(
      'small_days_breakfast',
      .10,
      .09,
      .77,
      .53,
      mounted: true,
      turn: -2,
    );
    b.text('늦게 일어나\n같이 먹은 첫 끼', .15, .72, .72, .16, size: .035);
    b.end();
    b.page('weekend-table-note', '#F0F2E8');
    b.heading('약속 없는 아침');
    b.stock(.13, .24, .71, .48, '#FCFCF4');
    b.text(
      '각자 하고 싶은 일을 말하고\n오전은 조금 느리게 보내기로 했다.',
      .20,
      .34,
      .57,
      .22,
      size: .029,
    );
    b.paper('studioSageRibbon', .64, .68, .19, .18);
    b.end();
  }, extra: true);
  b.spread('오래된 조리법을 꺼내', 2, () {
    b.page('recipe-archive-portrait', '#D8E1CE');
    b.paper('heirloomLibraryCard', .07, .11, .35, .72, turn: -3);
    b.photo(
      'family_kitchen',
      .43,
      .23,
      .49,
      .46,
      natural: false,
      frame: 'studioGallery',
    );
    b.caption('알려 준 사람의 목소리까지');
    b.end();
    b.page('recipe-letter-steps', '#EEF0E5');
    b.heading('다음 사람에게 전할 말');
    b.stock(.11, .24, .74, .53, '#FAFAF1');
    b.text(
      '불은 너무 세지 않게.\n중간에 한 번 뒤집고,\n마지막에는 같이 맛보기.',
      .19,
      .35,
      .58,
      .29,
      size: .030,
      leading: 1.9,
    );
    b.paper('studioWashiSage', .59, .75, .28, .05);
    b.end();
  }, extra: true);
  b.spread('친구들이 모이는 날', 3, () {
    b.page('friends-extra-wide', '#D3E0D5');
    b.photo('family_friends', .04, .13, .92, .56, mounted: true);
    b.heading('자리를 더 붙이고', x: .12, y: .76, w: .77, size: .034);
    b.end();
    b.page('friends-message-slips', '#EEF1E8');
    b.heading('식탁에서 나온 약속들');
    b.card(
      'heirloomVowPlaceCard',
      '다음에는\n우리 집에서',
      .10,
      .26,
      .67,
      .23,
      size: .031,
      turn: -2,
    );
    b.card(
      'heirloomVowPlaceCard',
      '그때도 오늘처럼\n오래 앉아 있자.',
      .34,
      .64,
      .54,
      .20,
      size: .025,
      turn: 3,
    );
    b.end();
  }, extra: true);
  b.spread('치우고 난 뒤의 자리', 3, () {
    b.page('table-afterglow', '#DCE4D7');
    b.paper('studioCottonRag', .075, .10, .86, .68, turn: 3);
    b.photo('family_table', .13, .17, .73, .49, mounted: true);
    b.caption('모두 돌아간 뒤 사진을 다시 봤다.');
    b.end();
    b.page('next-meeting-pocket', '#EFF1E7');
    b.paper('travelDocumentPocket', .09, .24, .82, .49);
    b.stock(.16, .15, .67, .41, '#FBFCF4');
    b.text(
      '이번에 못 온 사람에게\n사진을 보내고,\n다음 날짜를 물었다.',
      .23,
      .24,
      .53,
      .28,
      size: .029,
    );
    b.paper('studioOlivePress', .73, .67, .16, .20);
    b.end();
  }, extra: true);
}

void _volumeCouple(_VolumeAuthor b) {
  b.spread('만나러 가는 길', 1, () {
    b.page('meeting-street-print', '#E6DADE');
    b.paper('studioCottonRag', .06, .15, .86, .65, turn: -3);
    b.photo('couple_walk', .115, .20, .77, .51, mounted: true);
    b.paper('heirloomCinemaStub', .36, .745, .46, .14, turn: 3);
    b.caption('조금 먼저 도착해서 기다렸다.', y: .87);
    b.end();
    b.page('meeting-time-note', '#F0EBE8');
    b.heading('약속한 시간과 장소');
    b.stock(.13, .23, .73, .52, '#FCF9F4');
    b.stock(.39, .25, .0015, .46, '#CDBABE');
    b.text('시간\n장소\n날씨', .18, .32, .17, .30, size: .029, leading: 2.1);
    b.text(
      '조금 이른 오후\n늘 만나던 입구\n걷기 좋은 날',
      .45,
      .32,
      .32,
      .30,
      size: .026,
      leading: 2.1,
    );
    b.paper('studioWashiRose', .26, .78, .32, .05, turn: -3);
    b.end();
  });
  b.reversedSpread('영화가 시작되기 전', 1, () {
    b.page('tickets-photo-sleeve', '#DECFD7');
    b.paper('travelPhotoSleeve', .08, .12, .84, .65, turn: 3);
    b.photo('couple_keepsakes', .13, .19, .73, .49, frame: 'studioGallery');
    b.paper('heirloomCinemaStub', .11, .75, .40, .13, turn: -3);
    b.caption('두 자리를 나란히 골랐다.', x: .53, y: .79, w: .39);
    b.end();
    b.page('film-review-fold', '#EFE9E8');
    b.heading('끝나고 나눈 감상');
    b.stock(.10, .24, .79, .51, '#FBF7F0');
    b.stock(.47, .26, .002, .45, '#DAC8CB');
    b.text('내가 기억한 장면', .16, .31, .26, .13, size: .028);
    b.text('네가 좋아한 장면', .54, .31, .27, .13, size: .028);
    b.text('같은 영화를 보고도\n다른 이야기가 남았다.', .17, .60, .63, .12, size: .025);
    b.paper('studioWashiRose', .31, .79, .34, .05);
    b.end();
  });
  b.spread('한 정거장 더 걸어서', 1, () {
    b.page('walking-side-margin', '#D9DADF');
    b.photo('couple_walk', .09, .12, .79, .53, mounted: true);
    b.stock(.09, .70, .005, .17, '#977984');
    b.text('돌아가는 길을\n조금 길게 잡았다.', .16, .72, .70, .15, size: .035);
    b.end();
    b.page('walk-keepsake-note', '#EFECE8');
    b.paper('studioGlassineEnvelope', .12, .24, .77, .48, turn: -3);
    b.stock(.18, .15, .62, .37, '#FBF9F3');
    b.text('무슨 이야기를 했는지\n잊기 전에 적어 둔다.', .24, .25, .50, .17, size: .033);
    b.paper('heirloomCinemaStub', .30, .73, .49, .15, turn: 3);
    b.end();
  });
  b.spread('서로 골라 준 메뉴', 2, () {
    b.page('cafe-coaster-insert', '#E4D9D8');
    b.heading('네가 고른 것, 내가 고른 것');
    b.paper('travelCafeCoaster', .09, .22, .65, .55, turn: 4);
    final d = math.min(.48, .42 / b.ratio);
    b.photo(
      'couple_cafe',
      .17,
      .275,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOval',
    );
    b.paper('travelCafeReceipt', .75, .43, .15, .34, turn: -4);
    b.end();
    b.page('cafe-order-note', '#F0ECE5');
    b.stock(.13, .16, .71, .60, '#FBF8F1');
    b.heading('다음에도 주문할 것', x: .20, y: .24, w: .58, size: .039);
    b.text('한 입씩 바꿔 먹고\n좋아하는 맛을 하나 더 알았다.', .20, .43, .57, .20, size: .030);
    b.paper('studioWashiRose', .16, .13, .30, .05, turn: -3);
    b.paper('studioRoseSilk', .64, .71, .21, .18);
    b.end();
  });
  b.reversedSpread('둘이 보낸 평범한 날', 2, () {
    b.page('ordinary-breakfast', '#E5DEDA');
    b.paper('studioCottonRag', .075, .13, .84, .68, turn: 3);
    b.photo('small_days_breakfast', .13, .20, .73, .49, frame: 'studioDeckle');
    b.caption('특별한 일정이 없어도');
    b.end();
    b.page('ordinary-note-pair', '#F0EBE8');
    b.heading('같이 해서 좋았던 일');
    b.stock(.10, .25, .70, .22, '#FCF8F2', turn: -2);
    b.text('장을 보고 돌아와\n늦은 점심을 먹었다.', .17, .30, .54, .13, size: .029);
    b.stock(.28, .59, .61, .24, '#E4D5DA', turn: 2);
    b.text('별일 없던 날도\n함께라서 남겨 둔다.', .35, .65, .46, .13, size: .026);
    b.paper('studioWashiRose', .43, .57, .28, .05);
    b.end();
  });
  b.spread('편지 봉투를 열고', 2, () {
    b.page('letter-artifact', '#DDD3D6');
    b.paper('heirloomVowEnvelope', .08, .19, .83, .61, turn: -4);
    b.photo('couple_keepsakes', .15, .28, .69, .46, mounted: true);
    b.paper('studioRoseSilk', .08, .70, .23, .19);
    b.caption('몇 번이나 다시 읽은 문장');
    b.end();
    b.page('letter-response', '#F0EAE6');
    final letter = b.paper('studioCottonRag', .12, .12, .77, .70, turn: 2);
    b.paperText(
      letter,
      '그때는 짧게 말했지만\n고마운 마음은 오래 남았다.',
      .14,
      .23,
      .72,
      .33,
      size: .036,
    );
    b.stock(
      letter.left + letter.width * .14,
      letter.top + letter.height * .65,
      letter.width * .70,
      .0015,
      '#C8B4B9',
    );
    b.paperText(letter, b.copy.byline, .14, .73, .72, .14, size: .027);
    b.paper('heirloomVowSeal', .73, .74, .12, .13);
    b.end();
  });
  b.spread('작은 기념일의 선물', 3, () {
    b.page('gift-torn-print', '#E1D7D9');
    b.heading('크지 않아도 오래 남는 것');
    b.photo('couple_keepsakes', .10, .25, .73, .48, frame: 'studioTorn');
    b.paper('studioRoseSilk', .72, .69, .18, .18);
    b.caption('고르던 마음까지 같이 간직하기');
    b.end();
    b.page('anniversary-gift-card', '#EFEAE4');
    b.stock(.12, .19, .73, .56, '#FCF8F0');
    b.text('선물에 담긴 이야기', .20, .27, .57, .11, size: .040);
    b.text('왜 이걸 골랐는지,\n받았을 때 어떤 표정이었는지.', .20, .46, .57, .19, size: .029);
    b.paper('heirloomCinemaStub', .24, .78, .49, .13, turn: -3);
    b.end();
  });
  b.spread('저녁을 오래 먹던 날', 3, () {
    b.page('anniversary-evening', '#DBD4D7');
    b.paper('studioVellum', .07, .10, .85, .70, turn: 3);
    b.photo('couple_anniversary', .12, .21, .76, .50, mounted: true);
    b.paper('studioWashiRose', .57, .185, .29, .05);
    b.caption('예약한 시간보다 오래 앉아 있었다.');
    b.end();
    b.page('evening-toast-note', '#F1EDE6');
    b.heading('그날 나눈 한마디');
    b.paper('heirloomVowEnvelope', .10, .27, .81, .51, turn: -3);
    b.stock(.17, .20, .65, .34, '#FCF9F0');
    b.text('오늘처럼\n앞으로도 같이 웃자.', .25, .28, .49, .21, size: .037);
    b.paper('heirloomVowSeal', .14, .68, .14, .14);
    b.end();
  });
  b.spread('처음 같이 간 곳', 1, () {
    b.page('first-outing-route', '#DCE0DF');
    b.paper('travelContourSlip', .10, .13, .78, .69, turn: -2);
    b.photo('couple_walk', .18, .21, .66, .44, mounted: true);
    b.caption('둘의 단골이 되기 전');
    b.end();
    b.page('first-outing-memory', '#F0EBE8');
    b.heading('처음이라 기억나는 것');
    b.stock(.12, .24, .74, .48, '#FCF8F2');
    b.text(
      '길을 한 번 잘못 들고\n우연히 좋은 자리를 찾았다.\n다음에도 오자고 했다.',
      .20,
      .33,
      .57,
      .29,
      size: .029,
    );
    b.paper('heirloomCinemaStub', .49, .74, .39, .13, turn: 4);
    b.end();
  }, extra: true);
  b.spread('취향이 겹치는 순간', 2, () {
    b.page('shared-book-photo', '#E1DBD8');
    b.photo(
      'daily_book',
      .065,
      .13,
      .57,
      .69,
      natural: false,
      frame: 'studioGallery',
    );
    b.text('같은\n장면에서\n웃었다.', .72, .27, .20, .28, size: .032);
    b.paper('studioWashiRose', .19, .095, .31, .05, turn: -4);
    b.end();
    b.page('shared-playlist', '#F0ECE6');
    b.heading('서로에게 건넨 추천');
    b.stock(.12, .24, .74, .50, '#FCF9F2');
    b.text(
      '다음에 읽을 책\n함께 듣고 싶은 노래\n다시 보고 싶은 영화',
      .21,
      .34,
      .56,
      .30,
      size: .030,
      leading: 1.8,
    );
    b.paper('heirloomCinemaStub', .32, .77, .41, .13, turn: -3);
    b.end();
  }, extra: true);
  b.reversedSpread('잠깐 떠난 주말', 3, () {
    b.page('weekend-coast-tickets', '#D7DEDE');
    b.heading('가까운 곳으로 둘이');
    b.photo('travel_coast', .055, .25, .89, .50, mounted: true);
    b.paper('studioTravelTicket', .13, .75, .44, .14, turn: -3);
    b.end();
    b.page('weekend-dispatch', '#EFECE6');
    b.paper('travelPostcard', .08, .19, .83, .60, turn: 3);
    b.stock(.13, .25, .72, .33, '#F9F8F0');
    b.text('멀리 가지는 않았지만\n하루가 조금 길어진 기분이었다.', .20, .32, .57, .18, size: .029);
    b.paper('studioCoastStamp', .73, .65, .13, .18);
    b.end();
  }, extra: true);
  b.spread('다음 계절의 약속', 3, () {
    b.page('future-walking-print', '#DCE1DA');
    b.paper('studioCottonRag', .08, .12, .83, .69, turn: -3);
    b.photo('couple_walk', .14, .19, .72, .48, frame: 'studioDeckle');
    b.caption('이 길을 다음 계절에도');
    b.end();
    b.page('future-ticket-note', '#F0EAE8');
    b.heading('아직 남겨 둔 두 자리');
    b.card(
      'heirloomVowPlaceCard',
      '같이 가 보고 싶은 곳',
      .12,
      .25,
      .74,
      .21,
      size: .030,
    );
    b.paper('heirloomCinemaStub', .19, .59, .62, .18, turn: -3);
    b.text('다음 장면도 함께 모아 두자.', .16, .81, .71, .065, size: .029);
    b.end();
  }, extra: true);
}
