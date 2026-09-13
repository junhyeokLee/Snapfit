part of 'authored_collections.dart';

void _volumeTravel(_VolumeAuthor b) {
  b.spread('가방을 닫기 전에', 1, () {
    b.page('packing-tag-print', '#D5E2DE');
    b.paper('travelPhotoSleeve', .08, .12, .85, .67, turn: -3);
    b.photo('journey_train', .13, .19, .74, .49, mounted: true);
    b.paper('travelLuggageLabel', .70, .69, .17, .22, turn: 5);
    b.caption('가져갈 것과 두고 갈 것');
    b.end();
    b.page('packing-route-fold', '#EEF1E8');
    b.heading('출발 전에 적어 둔 목록');
    b.stock(.12, .23, .75, .55, '#FAFBF2');
    b.stock(.37, .25, .002, .49, '#B3C9C0');
    b.text('챙길 것\n남길 것\n기억할 것', .18, .34, .16, .32, size: .028, leading: 2);
    b.text(
      '가벼운 옷과 카메라\n빈 가방 한쪽\n돌아오는 기차 시간',
      .44,
      .34,
      .36,
      .32,
      size: .025,
      leading: 2,
    );
    b.paper('studioTravelTicket', .25, .79, .43, .12, turn: -3);
    b.end();
  });
  b.reversedSpread('창밖을 보며 가는 길', 1, () {
    b.page('train-window-frame', '#CBDCDE');
    b.stock(.06, .10, .045, .72, '#456D75');
    b.photo('journey_train', .16, .15, .76, .51, frame: 'studioGallery');
    b.paper('studioTravelTicket', .41, .70, .47, .15, turn: -3);
    b.caption('낯선 역 이름을 하나씩 지나쳤다.');
    b.end();
    b.page('train-ticket-journal', '#EDF1E9');
    b.paper('travelNotebook', .12, .10, .74, .75, turn: 2);
    b.stock(.20, .27, .59, .43, '#F6F7EF');
    b.text('차창 밖에 남은 장면', .24, .31, .49, .10, size: .035);
    b.text('바뀌는 풍경을 보다가\n도착할 곳을 다시 찾아봤다.', .24, .48, .49, .17, size: .027);
    b.paper('studioPostalMark', .69, .73, .16, .15);
    b.end();
  });
  b.spread('처음 마주한 항구', 1, () {
    b.page('harbor-vertical-print', '#D8E4DE');
    b.photo(
      'travel_harbor',
      .075,
      .095,
      .64,
      .76,
      natural: false,
      frame: 'studioDeckle',
    );
    b.paper('travelStayTag', .76, .20, .145, .32, turn: 3);
    b.caption('가장 먼저 카메라를 꺼낸 곳');
    b.end();
    b.page('harbor-map-label', '#EFF2E9');
    b.heading('여기서부터 걸어 보기로');
    b.paper('studioTravelMap', .08, .22, .84, .58, turn: -3);
    b.stock(.16, .28, .54, .29, '#F9FAF2');
    b.text('지도는 접어 두고\n물가 쪽으로 걸었다.', .22, .35, .42, .16, size: .030);
    b.paper('studioCoastStamp', .74, .59, .15, .22);
    b.end();
  });
  b.spread('시장 골목에서 산 것', 2, () {
    b.page('market-receipt-cutout', '#D9E2CD');
    b.photo(
      'journey_market',
      .07,
      .10,
      .64,
      .73,
      natural: false,
      frame: 'studioTorn',
    );
    b.paper('travelMarketReceipt', .73, .27, .18, .38, turn: 4);
    b.caption('한 번 맛보고 조금 더 샀다.');
    b.end();
    b.page('market-paper-inventory', '#EEF0E3');
    b.heading('봉투를 열어 보니');
    b.paper('studioCottonRag', .13, .22, .75, .57, turn: -2);
    b.photo('daily_fruit', .20, .28, .60, .39, frame: 'studioGallery');
    b.card(
      'heirloomVowPlaceCard',
      '그 동네에서\n골라 온 작은 것',
      .47,
      .73,
      .41,
      .17,
      size: .023,
    );
    b.end();
  });
  b.spread('카페에서 접은 지도', 2, () {
    b.page('cafe-map-print', '#D7E3DF');
    b.paper('travelContourSlip', .07, .13, .85, .66, turn: 3);
    b.photo('travel_cafe', .14, .22, .71, .46, mounted: true);
    b.paper('travelCafeReceipt', .75, .60, .15, .27, turn: -5);
    b.caption('걷던 길을 잠깐 멈췄다.');
    b.end();
    b.page('cafe-stamped-note', '#EFF2E9');
    b.heading('우연히 찾은 단골 자리');
    b.paper('travelCafeCoaster', .11, .24, .35, .34, turn: -3);
    b.stock(.45, .33, .43, .40, '#FBFCF4');
    b.text('다음에 오면\n또 이 자리에\n앉고 싶다.', .50, .40, .32, .25, size: .029);
    b.paper('studioPostalMark', .18, .72, .19, .16);
    b.end();
  });
  b.reversedSpread('이름을 모르는 골목', 2, () {
    b.page('street-blue-border', '#CEDDDC');
    b.stock(.075, .08, .052, .73, '#4E757B');
    b.photo('travel_street', .17, .15, .74, .49, mounted: true, turn: 2);
    b.caption('길을 잃어도 좋았던 동네');
    b.end();
    b.page('street-address-index', '#EFF1E8');
    b.heading('다시 찾아가고 싶은 곳');
    b.paper('travelNotebook', .10, .22, .76, .65);
    b.stock(.18, .29, .59, .40, '#F7F8F0');
    b.text(
      '골목 입구의 가게\n모퉁이를 돌면 나온 계단\n오래 머물렀던 벤치',
      .23,
      .35,
      .49,
      .27,
      size: .027,
      leading: 1.8,
    );
    b.paper('studioCoastStamp', .73, .71, .14, .17);
    b.end();
  });
  b.reversedSpread('바다를 곁에 두고', 3, () {
    b.page('coast-matted-roundel', '#CADDDC');
    b.paper('studioBlueFibre', .07, .12, .84, .68, turn: -3);
    final d = math.min(.64, .55 / b.ratio);
    b.photo(
      'travel_coast',
      .13,
      .19,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOvalMat',
    );
    b.paper('studioCoastStamp', .75, .64, .14, .21);
    b.caption('일정표에 없던 긴 산책');
    b.end();
    b.page('coast-bench-note', '#EFF1E9');
    b.heading('아무것도 하지 않은 시간');
    b.stock(.11, .25, .75, .39, '#FCFCF5');
    b.text(
      '사진을 몇 장 찍고\n카메라를 내려놓았다.\n한참 동안 바다만 봤다.',
      .19,
      .32,
      .59,
      .26,
      size: .030,
    );
    b.paper('travelContourSlip', .45, .70, .41, .17, turn: 3);
    b.end();
  });
  b.spread('돌아오는 가방 속에', 3, () {
    b.page('return-envelope-objects', '#D7E3DC');
    b.paper('travelDocumentPocket', .08, .24, .82, .51);
    b.photo('journey_train', .16, .13, .70, .46, mounted: true);
    b.paper('travelLuggageLabel', .12, .68, .16, .22, turn: -4);
    b.caption('처음보다 조금 무거워진 가방', x: .34, w: .56);
    b.end();
    b.page('return-address-letter', '#EEF1E8');
    b.paper('travelPostcard', .10, .18, .80, .58, turn: -2);
    b.stock(.16, .25, .67, .29, '#FAFBF1');
    b.text('다녀왔다는 말과 함께\n보내고 싶은 사진들.', .22, .32, .55, .17, size: .031);
    b.text(b.copy.period, .18, .67, .45, .07, size: .022, font: 'NotoSans');
    b.paper('studioPostalMark', .70, .71, .16, .14);
    b.end();
  });
  b.reversedSpread('잠시 머물 집의 열쇠', 1, () {
    b.page('stay-key-window', '#D5E2DD');
    b.photo(
      'travel_street',
      .07,
      .11,
      .63,
      .72,
      natural: false,
      frame: 'studioGallery',
    );
    b.paper('travelStayTag', .74, .28, .17, .36, turn: 5);
    b.caption('며칠 동안 우리의 주소');
    b.end();
    b.page('stay-desk-record', '#EFF2E9');
    b.heading('방에 들어와 처음 한 일');
    b.stock(.12, .25, .74, .47, '#FBFCF3');
    b.text(
      '가방을 내려놓고\n창을 열고\n내일 갈 곳을 함께 찾았다.',
      .20,
      .34,
      .57,
      .28,
      size: .030,
      leading: 1.8,
    );
    b.paper('travelStayTag', .69, .70, .15, .19);
    b.end();
  }, extra: true);
  b.spread('갈아타는 역에서', 1, () {
    b.page('transfer-ticket-strip', '#CFDDDF');
    b.heading('다음 출발까지');
    b.photo('journey_train', .06, .23, .86, .49, frame: 'studioDeckle');
    b.paper('studioTravelTicket', .40, .76, .46, .13, turn: -4);
    b.end();
    b.page('transfer-timetable', '#EFF1E9');
    b.stock(.11, .19, .76, .57, '#FAFBF3');
    b.text('들고 다닌 시간표', .19, .27, .59, .09, size: .039);
    b.text(
      '출발하는 곳\n내려야 할 역\n다시 만날 시간',
      .19,
      .43,
      .59,
      .27,
      size: .029,
      leading: 1.9,
    );
    b.paper('studioPostalMark', .70, .72, .16, .13);
    b.end();
  }, extra: true);
  b.spread('처음 먹어 본 한 접시', 2, () {
    b.page('food-counter-print', '#DDE3D2');
    b.paper('heirloomTableLinen', .08, .14, .84, .65, turn: 3);
    b.photo('journey_market', .13, .22, .73, .46, mounted: true);
    b.caption('이름을 물어보고 주문했다.');
    b.end();
    b.page('food-receipt-note', '#F0F2E7');
    b.paper('travelMarketReceipt', .09, .19, .23, .54, turn: -3);
    b.text('기억하고 싶은 맛', .42, .25, .47, .15, size: .038);
    b.text('같이 나누어 먹고\n다음 메뉴를 하나 더 골랐다.', .42, .47, .43, .23, size: .028);
    b.paper('studioWashiSage', .47, .79, .32, .05);
    b.end();
  }, extra: true);
  b.spread('사진 밖의 여행', 2, () {
    b.page('outtake-mounted-print', '#D2DFDD');
    b.photo('travel_cafe', .09, .13, .80, .54, mounted: true, turn: -3);
    b.paper('studioWashiSage', .58, .095, .29, .05);
    b.caption('잘 찍히지 않아도 기억나는 순간');
    b.end();
    b.page('outtake-caption-file', '#EDF1E8');
    b.heading('사진으로 남기지 못한 것');
    b.paper('travelPhotoSleeve', .13, .23, .73, .58, turn: 2);
    b.stock(.20, .31, .60, .34, '#FBFCF4');
    b.text(
      '길을 알려 준 사람의 친절,\n가게에서 들리던 음악,\n같이 웃던 목소리.',
      .25,
      .37,
      .49,
      .23,
      size: .026,
    );
    b.end();
  }, extra: true);
  b.reversedSpread('다른 시간에 다시 찾은 물가', 3, () {
    b.page('evening-harbor-print', '#CDDCDD');
    b.paper('studioBlueFibre', .07, .15, .85, .63, turn: -2);
    b.photo('travel_harbor', .14, .23, .73, .48, mounted: true);
    b.caption('같은 자리를 다른 시간에 다시');
    b.end();
    b.page('evening-route-postcard', '#EFF2EA');
    b.paper('travelPostcard', .10, .24, .81, .52, turn: -3);
    b.stock(.17, .17, .64, .34, '#FAFCF2');
    b.text('조금 더 머물다가\n숙소로 돌아가기로 했다.', .24, .25, .50, .19, size: .033);
    b.paper('studioCoastStamp', .73, .66, .14, .20);
    b.end();
  }, extra: true);
  b.spread('한 번 더 펴 보는 지도', 3, () {
    b.page('route-archive', '#D7E2DB');
    b.paper('studioTravelMap', .07, .10, .85, .72, turn: -2);
    b.photo('travel_coast', .34, .42, .51, .34, mounted: true);
    b.paper('travelLuggageLabel', .10, .54, .17, .29, turn: -3);
    b.caption('이번 여행의 끝에 표시한 곳');
    b.end();
    b.page('next-route-index', '#EDF1E7');
    b.heading('다음에 이어 걸을 길');
    b.stock(.12, .25, .74, .49, '#FAFBF2');
    b.text(
      '다시 가고 싶은 동네\n이번에 들르지 못한 곳\n다음에는 함께 가고 싶은 사람',
      .20,
      .34,
      .57,
      .28,
      size: .027,
      leading: 1.8,
    );
    b.paper('studioTravelTicket', .33, .78, .44, .13);
    b.end();
  }, extra: true);
}

void _volumeBaby(_VolumeAuthor b) {
  b.spread('집에 처음 온 날', 1, () {
    b.page('home-first-sleep', '#DEE5DA');
    b.paper('studioCottonRag', .07, .12, .86, .68, turn: -3);
    b.photo('growth_sleep', .13, .20, .74, .49, mounted: true);
    b.paper('studioSageRibbon', .69, .68, .21, .18);
    b.caption('작은 숨소리가 집에 가득했다.');
    b.end();
    b.page('arrival-record-card', '#F1F1E7');
    b.heading('너를 맞이한 우리의 집');
    b.stock(.12, .23, .74, .54, '#FCFBF4');
    b.text(
      '처음 눕힌 자리\n네 곁을 지킨 사람\n그날 잊지 못할 순간',
      .21,
      .34,
      .56,
      .29,
      size: .029,
      leading: 1.9,
    );
    b.paper('heirloomGrowthRuler', .15, .80, .68, .085);
    b.end();
  });
  b.reversedSpread('손바닥에 닿은 작은 손', 1, () {
    b.page('tiny-hand-mount', '#D6E0D4');
    b.photo('growth_hand', .09, .12, .77, .56, frame: 'studioOvalMat');
    b.paper('studioSageRibbon', .08, .69, .20, .19);
    b.caption('내 손가락을 꼭 잡았다.', x: .33, w: .56);
    b.end();
    b.page('hand-letter', '#EFF0E5');
    final letter = b.paper('studioCottonRag', .10, .13, .80, .68, turn: 3);
    b.paperText(letter, '놓치지 않고\n기억해 두고 싶은 크기', .14, .23, .72, .33, size: .039);
    b.stock(
      letter.left + letter.width * .14,
      letter.top + letter.height * .64,
      letter.width * .70,
      .0015,
      '#B4C4AF',
    );
    b.paperText(letter, '날짜와 그날의 너를 적어 둔다.', .14, .73, .72, .14, size: .026);
    b.paper('heirloomGrowthRuler', .20, .82, .62, .075);
    b.end();
  });
  b.spread('처음 눈을 맞추던 순간', 1, () {
    b.page('first-look-print', '#DFE6D8');
    b.heading('한참을 바라보았다');
    b.photo('growth_play', .08, .24, .82, .52, mounted: true);
    b.paper('studioWashiSage', .17, .205, .31, .05, turn: -4);
    b.caption('눈을 맞추고 이름을 불렀다.');
    b.end();
    b.page('first-look-date-note', '#F1F2E9');
    b.stock(.13, .19, .72, .59, '#FCFCF5');
    b.text('처음이라서\n더 오래 남은 날', .21, .28, .57, .21, size: .043);
    b.text('언제였는지, 누구와 있었는지,\n어떤 표정으로 바라봤는지.', .21, .58, .56, .15, size: .027);
    b.paper('studioSageRibbon', .68, .73, .19, .17);
    b.end();
  });
  b.spread('밖으로 나간 작은 여행', 2, () {
    b.page('first-walk-mat', '#D6E2D7');
    b.paper('studioCottonRag', .08, .13, .84, .67, turn: -2);
    b.photo('growth_walk', .13, .22, .74, .49, mounted: true);
    b.caption('멀지 않은 곳까지 천천히');
    b.end();
    b.page('first-walk-notebook', '#EEF1E5');
    b.heading('처음 같이 걸은 길');
    b.paper('travelNotebook', .12, .23, .74, .63);
    b.stock(.20, .30, .58, .39, '#F7F8EE');
    b.text(
      '출발한 시간\n잠깐 쉬었던 자리\n네가 오래 바라본 것',
      .25,
      .36,
      .48,
      .27,
      size: .028,
      leading: 1.9,
    );
    b.paper('studioOlivePress', .73, .69, .14, .18);
    b.end();
  });
  b.reversedSpread('스스로 해낸 작은 일', 2, () {
    b.page('milestone-playing', '#DCE4D6');
    b.photo('growth_play', .085, .14, .78, .53, frame: 'studioDeckle');
    b.card(
      'heirloomVowPlaceCard',
      '어제는 어려웠던 일이\n오늘은 조금 쉬워졌다.',
      .22,
      .72,
      .65,
      .18,
      size: .024,
    );
    b.end();
    b.page('milestone-date-file', '#F0F2E8');
    b.heading('처음 해낸 날의 기록');
    b.stock(.115, .24, .75, .52, '#FCFBF3');
    b.text('혼자 해낸 것', .20, .31, .59, .075, size: .034);
    b.stock(.20, .43, .57, .0015, '#B4C5AB');
    b.text('함께 기뻐한 사람\n그때의 너와 우리의 표정', .20, .50, .57, .19, size: .027);
    b.paper('heirloomGrowthRuler', .15, .80, .67, .085);
    b.end();
  });
  b.spread('좋아하는 놀이가 생겼어', 2, () {
    b.page('favorite-toys-insert', '#D5E0D1');
    b.paper('heirloomTableLinen', .07, .16, .86, .64, turn: 3);
    b.photo('growth_keepsakes', .14, .24, .72, .47, mounted: true);
    b.caption('가장 먼저 손이 가는 물건');
    b.end();
    b.page('play-preferences', '#F1F1E5');
    b.heading('너의 요즘 취향');
    b.stock(.12, .24, .73, .50, '#FAFAF2');
    b.text(
      '좋아하는 장난감\n웃음을 터뜨리는 놀이\n집중해서 바라보는 것',
      .21,
      .34,
      .55,
      .28,
      size: .027,
      leading: 1.9,
    );
    b.paper('studioSageRibbon', .70, .70, .18, .19);
    b.end();
  });
  b.reversedSpread('옷장에 남겨 둔 한 벌', 3, () {
    b.page('first-clothes-gallery', '#DEE5D8');
    b.photo(
      'growth_keepsakes',
      .07,
      .09,
      .61,
      .76,
      natural: false,
      frame: 'studioGallery',
    );
    b.paper('heirloomGrowthRuler', .73, .20, .16, .52, turn: 90);
    b.caption('작아져도 버리지 못한 옷');
    b.end();
    b.page('clothes-tag-letter', '#F0F2E8');
    final letter = b.paper('studioCottonRag', .10, .17, .80, .64, turn: -3);
    b.paperText(
      letter,
      '이렇게 작은 옷을\n입던 날이 있었지.',
      .14,
      .21,
      .72,
      .33,
      size: .040,
    );
    b.paperText(
      letter,
      '입었던 날과 함께한 장면을\n옷 곁에 적어 둔다.',
      .14,
      .64,
      .72,
      .24,
      size: .027,
    );
    b.paper('studioArchiveTag', .72, .71, .15, .17);
    b.end();
  });
  b.spread('생일을 준비하는 마음', 3, () {
    b.page('birthday-preparation', '#DDE4D4');
    b.heading('한 살을 앞두고');
    b.photo('growth_birthday', .08, .24, .83, .53, mounted: true);
    b.paper('studioWashiSage', .24, .205, .30, .05);
    b.caption('우리가 같이 지나온 첫해');
    b.end();
    b.page('birthday-invitation-note', '#F1F1E6');
    b.paper('heirloomVowEnvelope', .09, .27, .82, .54, turn: -3);
    b.stock(.17, .18, .64, .38, '#FCFBF3');
    b.text('너를 사랑하는 사람들과\n첫 생일을 함께 보내려 해.', .24, .28, .50, .21, size: .031);
    b.paper('studioSageRibbon', .69, .72, .20, .17);
    b.end();
  });
  b.spread('너를 기다리며 꺼낸 것', 1, () {
    b.page('waiting-keepsake-paper', '#E0E6D8');
    b.paper('studioCottonRag', .08, .12, .85, .66, turn: 3);
    b.photo('growth_keepsakes', .14, .20, .71, .47, frame: 'studioDeckle');
    b.caption('만나기 전에 준비해 두었던 것');
    b.end();
    b.page('waiting-letter', '#F1F2E8');
    b.heading('너를 기다리던 우리');
    b.stock(.12, .25, .74, .47, '#FCFCF4');
    b.text('작은 옷을 개어 놓고\n네 이름을 몇 번이나 불러 봤다.', .21, .35, .56, .22, size: .031);
    b.paper('heirloomGrowthRuler', .16, .80, .67, .085);
    b.end();
  }, extra: true);
  b.reversedSpread('잠든 너를 지켜보며', 1, () {
    b.page('sleep-circle-mount', '#D9E3D8');
    final d = math.min(.69, .59 / b.ratio);
    b.photo(
      'growth_sleep',
      .12,
      .16,
      d,
      d * b.ratio,
      natural: false,
      frame: 'studioOvalMat',
    );
    b.paper('studioSageRibbon', .71, .65, .19, .18);
    b.caption('작은 숨소리에 귀를 기울였다.');
    b.end();
    b.page('sleep-night-note', '#F0F2E8');
    final letter = b.paper('studioCottonRag', .10, .19, .81, .59, turn: -2);
    b.paperText(
      letter,
      '오늘도 잘 자라 줘서\n고마운 마음으로',
      .14,
      .22,
      .72,
      .32,
      size: .037,
    );
    b.paperText(
      letter,
      '잠든 시간과, 깨서 웃어 준 순간을\n짧게 남겨 둔다.',
      .14,
      .65,
      .72,
      .23,
      size: .025,
    );
    b.end();
  }, extra: true);
  b.spread('봄부터 여름까지', 2, () {
    b.page('spring-summer-walk', '#D2E0D4');
    b.photo('growth_walk', .085, .15, .80, .53, mounted: true);
    b.paper('studioOlivePress', .09, .70, .18, .19);
    b.caption('가벼워진 옷과 길어진 산책', x: .33, w: .56);
    b.end();
    b.page('spring-summer-record', '#EFF2E7');
    b.heading('계절이 바뀌는 동안');
    b.stock(.11, .23, .77, .53, '#FBFCF4');
    b.stock(.46, .25, .002, .47, '#B5C8AE');
    b.text('봄에 좋아한 것\n\n처음 만난 꽃\n가벼운 바람', .17, .32, .25, .34, size: .025);
    b.text('여름에 새로 한 것\n\n물장난\n그늘에서 쉬기', .53, .32, .28, .34, size: .025);
    b.end();
  }, extra: true);
  b.reversedSpread('가을에서 겨울로', 2, () {
    b.page('autumn-small-objects', '#E0E5D3');
    b.paper('studioCottonRag', .07, .12, .85, .69, turn: 2);
    b.photo('growth_keepsakes', .13, .21, .73, .48, mounted: true);
    b.caption('조금 더 두꺼워진 네 옷');
    b.end();
    b.page('autumn-winter-record', '#F0F1E5');
    b.heading('또 한 계절을 지나');
    b.paper('travelNotebook', .13, .23, .72, .64);
    b.stock(.21, .31, .56, .38, '#F8F8EE');
    b.text(
      '처음 만져 본 낙엽\n따뜻하게 입고 나간 날\n눈을 바라보던 표정',
      .255,
      .37,
      .47,
      .27,
      size: .026,
      leading: 1.9,
    );
    b.paper('studioSageRibbon', .70, .70, .18, .17);
    b.end();
  }, extra: true);
  b.spread('곁에서 함께 자란 사람들', 3, () {
    b.page('family-first-year', '#DAE4D5');
    b.heading('너를 안아 준 사람들');
    b.photo('family_picnic', .06, .25, .88, .53, mounted: true);
    b.paper('studioWashiSage', .19, .21, .30, .05);
    b.end();
    b.page('family-messages', '#F0F2E7');
    b.card(
      'heirloomVowPlaceCard',
      '처음 만났을 때\n건네 준 한마디',
      .10,
      .20,
      .70,
      .22,
      size: .029,
      turn: -2,
    );
    b.card(
      'heirloomVowPlaceCard',
      '네가 조금 더 크면\n꼭 전해 주고 싶은 말',
      .29,
      .59,
      .59,
      .23,
      size: .025,
      turn: 2,
    );
    b.paper('studioOlivePress', .09, .66, .15, .22);
    b.end();
  }, extra: true);
  b.spread('첫해의 기록 상자', 3, () {
    b.page('first-year-box', '#D9E3D5');
    b.paper('travelDocumentPocket', .08, .24, .83, .51);
    b.photo('growth_hand', .15, .14, .71, .47, mounted: true);
    b.paper('heirloomGrowthRuler', .16, .79, .66, .085);
    b.caption('사진 밖의 작은 것들도 함께');
    b.end();
    b.page('first-year-time-letter', '#F0F2E7');
    b.heading('나중의 너에게');
    b.stock(.12, .25, .75, .48, '#FCFBF4');
    b.text(
      '이 책을 같이 펼치는 날,\n얼마나 작았는지 이야기해 줄게.\n얼마나 많이 웃었는지도.',
      .21,
      .34,
      .57,
      .28,
      size: .028,
      leading: 1.8,
    );
    b.paper('studioSageRibbon', .70, .72, .18, .17);
    b.end();
  }, extra: true);
}
