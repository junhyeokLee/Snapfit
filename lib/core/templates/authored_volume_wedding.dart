part of 'authored_collections.dart';

void _volumeWedding(_VolumeAuthor b) {
  b.spread('청첩장을 건네던 날', 1, () {
    b.page('invitation-envelope-still', '#E0E7DA');
    b.paper('heirloomVowEnvelope', .09, .17, .82, .62, turn: -3);
    b.photo('petal_details', .16, .24, .69, .47, mounted: true);
    b.paper('heirloomVowSeal', .11, .70, .15, .15);
    b.caption('한 사람씩 떠올리며 준비했다.');
    b.end();
    b.page('invitation-handwritten-list', '#F0F1E7');
    b.heading('기쁜 소식을 전하며');
    b.stock(.12, .24, .73, .50, '#FBFAF2');
    b.text(
      '직접 만나 건넨 날,\n멀리서 축하를 보내 준 사람,\n함께 와 주겠다는 약속.',
      .21,
      .34,
      .56,
      .28,
      size: .029,
      leading: 1.8,
    );
    b.paper('studioRoseSilk', .68, .69, .21, .20);
    b.end();
  });
  b.reversedSpread('꽃과 리본을 골라', 2, () {
    b.page('ribbon-floral-specimen', '#DDE5D7');
    b.heading('같이 골랐던 작은 것들');
    b.photo(
      'petal_bouquet',
      .075,
      .24,
      .59,
      .61,
      natural: false,
      frame: 'studioDeckle',
    );
    b.paper('studioRoseSilk', .71, .28, .21, .27);
    b.paper('studioOlivePress', .73, .59, .15, .22);
    b.end();
    b.page('floral-preparation-note', '#F0EFE6');
    b.paper('heirloomVowPaper', .12, .11, .77, .76);
    b.stock(.20, .29, .60, .40, '#F4F3EA');
    b.text('하나씩 고르던 시간', .25, .33, .49, .09, size: .035);
    b.text('서로 좋아하는 색을 말하고,\n함께 어울리는 것을 찾았다.', .25, .51, .49, .15, size: .027);
    b.paper('heirloomVowSeal', .73, .75, .13, .13);
    b.end();
  });
  b.spread('입장 전 마지막 준비', 4, () {
    b.page('veil-ready-print', '#DDE5DC');
    b.paper('studioCottonRag', .08, .12, .84, .65, turn: 3);
    b.photo('petal_veil', .14, .20, .72, .49, frame: 'studioGallery');
    b.caption('매무새를 한 번 더 고쳐 주었다.');
    b.end();
    b.page('ready-message-slip', '#F1F0E7');
    b.heading('떨리는 마음을 나누며');
    b.stock(.12, .25, .74, .46, '#FCFBF3');
    b.text(
      '준비됐냐고 묻고,\n눈을 맞추고 웃었다.\n이제 같이 걸어가자.',
      .21,
      .34,
      .56,
      .27,
      size: .030,
      leading: 1.8,
    );
    b.paper('studioRoseSilk', .65, .68, .23, .21);
    b.end();
  }, extra: true);
  b.reversedSpread('축하를 건네 준 얼굴들', 6, () {
    b.page('celebration-group', '#D8E3D7');
    b.heading('다 같이 웃던 순간');
    b.photo('lightbound_guests', .055, .25, .89, .52, mounted: true);
    b.paper('studioWashiSage', .18, .21, .29, .05);
    b.caption('와 주어서 더 특별해진 날');
    b.end();
    b.page('guest-letter-stack', '#EEEFE6');
    b.stock(.10, .21, .70, .25, '#FCFAF3', turn: -2);
    b.text('오래 알고 지낸 사람들이\n우리의 시작을 함께 봐 주었다.', .17, .27, .56, .14, size: .028);
    b.stock(.29, .58, .60, .24, '#DFE7D9', turn: 2);
    b.text('한 사람씩 고마운 마음을\n적어 두고 싶다.', .35, .64, .47, .14, size: .026);
    b.paper('studioOlivePress', .07, .61, .18, .25);
    b.end();
  }, extra: true);
  b.reversedSpread('마지막 한 조각까지', 8, () {
    b.page('cake-mounted-record', '#E0E6D7');
    b.paper('heirloomTableLinen', .08, .14, .84, .66, turn: -3);
    b.photo('lightbound_cake', .14, .23, .72, .47, mounted: true);
    b.paper('studioRoseSilk', .70, .69, .18, .18);
    b.caption('달콤한 것까지 같이 나누었다.');
    b.end();
    b.page('dinner-thankyou-card', '#F0F1E7');
    b.heading('오래 앉아 있어 준 사람들에게');
    b.paper('heirloomVowEnvelope', .11, .28, .79, .52, turn: 3);
    b.stock(.18, .22, .64, .33, '#FCFBF2');
    b.text('끝까지 함께해 주어서\n더 오래 기억할 하루가 됐다.', .25, .30, .50, .19, size: .030);
    b.paper('heirloomVowSeal', .14, .69, .14, .14);
    b.end();
  }, extra: true);
  b.spread('우리의 첫 번째 내일', 9, () {
    b.page('morning-after-portrait', '#DAE4D8');
    b.photo('lightbound_twilight', .08, .15, .84, .55, mounted: true);
    b.paper('studioWashiSage', .59, .11, .29, .05, turn: -3);
    b.caption('평범한 하루를 같이 시작하는 일');
    b.end();
    b.page('marriage-tomorrow-note', '#EFF1E7');
    final letter = b.paper('studioCottonRag', .11, .16, .80, .62, turn: -2);
    b.paperText(letter, '오늘의 약속을\n내일의 습관으로', .14, .21, .72, .32, size: .041);
    b.paperText(
      letter,
      '작은 일도 나누고,\n잘 듣고, 자주 같이 웃기로.',
      .14,
      .62,
      .72,
      .24,
      size: .028,
    );
    b.paper('studioRoseSilk', .71, .71, .18, .18);
    b.end();
  }, extra: true);
}
