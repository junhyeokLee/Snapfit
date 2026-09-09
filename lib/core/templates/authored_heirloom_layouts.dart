part of 'authored_collections.dart';

void _heirloomWedding(
  _HeirloomBook b, {
  void Function(_HeirloomBook)? beforeClosing,
}) {
  var p = b.page('#E8EEE7');
  b.material(p, 'studioCottonRag', .07, .08, .83, .74, turn: -2);
  b.photo(p, 'walking', 'petal_couple', .09, .095, .69, .755);
  b.material(p, 'studioRoseSilk', .76, .18, .18, .49, turn: 5);
  b.text(p, 'heading', '같은 방향으로 걷던 날', .10, .865, .81, .055, size: .032);
  b.save(p, 'wedding-ribbon-bound-portrait');

  p = b.page('#EEEAE4');
  b.material(p, 'studioVellum', .05, .12, .78, .76, turn: -3);
  b.material(p, 'heirloomVowPaper', .14, .065, .75, .81);
  b.text(p, 'invitation', '서로의 곁에 서기로', .23, .21, .58, .10, size: .037);
  b.text(p, 'names', b.copy.byline, .24, .355, .56, .06, size: .028);
  b.text(p, 'date', b.copy.period, .24, .439, .56, .043, size: .020);
  b.material(p, 'studioOlivePress', .62, .575, .28, .28, turn: -8);
  b.print(
    p,
    'invitation_detail',
    'petal_details',
    .125,
    .622,
    .40,
    .242,
    turn: -4,
  );
  b.material(p, 'studioWashiSage', .22, .604, .24, .042);
  b.save(p, 'wedding-invitation-insert');

  p = b.page('#E4E9E1');
  b.text(p, 'florist', '그날 골랐던 꽃', .07, .06, .82, .09, size: .048);
  b.material(p, 'studioCottonRag', .10, .19, .84, .68, turn: 3);
  b.photo(
    p,
    'bouquet',
    'petal_bouquet',
    .20,
    .22,
    .60,
    .57,
    frame: 'studioOvalMat',
  );
  b.material(p, 'studioRoseSilk', .045, .635, .29, .25, turn: -4);
  b.text(
    p,
    'floral_note',
    '드레스 옆에 두었던 작은 꽃다발',
    .31,
    .839,
    .60,
    .047,
    size: .022,
  );
  b.save(p, 'wedding-botanical-oval');

  p = b.page('#F0F0E8');
  b.material(p, 'heirloomVowPaper', .09, .07, .85, .81);
  b.text(p, 'vow_heading', '오늘의 약속', .20, .215, .63, .09, size: .047);
  b.text(
    p,
    'vow_body',
    '서로의 말을 끝까지 듣기.\n작은 일도 함께 기뻐하기.\n돌아올 자리를 늘 비워 두기.',
    .20,
    .365,
    .62,
    .23,
    size: .028,
    leading: 1.8,
  );
  b.text(p, 'vow_sign', b.copy.byline, .20, .690, .57, .075, size: .031);
  b.material(p, 'studioOlivePress', .74, .655, .16, .21, turn: 8);
  b.save(p, 'wedding-stitched-vows');

  p = b.page('#DDE5DD');
  b.text(p, 'reception', '함께 앉은 자리', .07, .075, .85, .09, size: .047);
  b.photo(p, 'long_table', 'petal_table', 0, .237, 1, .46);
  b.material(p, 'studioCottonRag', .045, .664, .49, .219, turn: -3);
  b.material(p, 'studioOlivePress', .70, .666, .21, .22, turn: 9);
  b.text(p, 'toast', '우리의 시작을 축하해 준 사람들', .12, .804, .59, .065, size: .025);
  b.save(p, 'wedding-reception-panorama');

  p = b.page('#EAE6E2');
  b.material(p, 'studioVellum', .10, .095, .80, .75, turn: -2);
  final guests = b.groupPhoto(
    p,
    'guests',
    'lightbound_guests',
    const Rect.fromLTWH(.09, .12, .82, .55),
    mounted: true,
  );
  b.material(p, 'studioWashiRose', .31, .095, .33, .046, turn: 2);
  final lower = guests.bottom + .06;
  b.text(p, 'guest_heading', '와 주어서 고마워요', .14, lower, .74, .068, size: .034);
  b.text(
    p,
    'guest_note',
    '사진 밖의 웃음까지 오래 기억할게요.',
    .14,
    lower + .094,
    .74,
    .065,
    size: .023,
  );
  b.material(p, 'studioRoseSilk', .66, .76, .24, .13, turn: -7);
  b.save(p, 'wedding-guestbook-photo');

  beforeClosing?.call(b);

  p = b.page('#F0EFE7');
  b.text(p, 'small_objects', '작은 것까지 간직하기', .07, .058, .86, .079, size: .04);
  b.material(p, 'studioCottonRag', .055, .23, .81, .63, turn: 3);
  b.photo(
    p,
    'ring_detail',
    'petal_details',
    .09,
    .23,
    .43,
    .50,
    frame: 'studioGallery',
  );
  b.photo(
    p,
    'veil_detail',
    'petal_veil',
    .59,
    .23,
    .29,
    .50,
    frame: 'studioDeckle',
  );
  b.material(p, 'studioWashiSage', .21, .206, .24, .043, turn: -3);
  b.text(
    p,
    'details_caption',
    '반지와 베일, 그날의 손길',
    .12,
    .805,
    .71,
    .06,
    size: .027,
  );
  b.save(p, 'wedding-keepsake-diptych');

  p = b.page('#DFE7DF');
  b.photo(
    p,
    'closing_garden',
    'petal_evening',
    .07,
    .075,
    .86,
    .43,
    frame: 'studioDeckle',
  );
  b.material(p, 'studioCottonRag', .08, .50, .84, .39);
  p.box('letter_stock', .11, .56, .77, .28, '#F6F5ED');
  b.text(
    p,
    'closing_letter',
    b.copy.note,
    .15,
    .62,
    .70,
    .19,
    size: .025,
    leading: 1.6,
  );
  b.material(p, 'studioOlivePress', .80, .793, .12, .10, turn: -10);
  b.save(p, 'wedding-garden-letter');
}

void _heirloomDaily(_HeirloomBook b) {
  var p = b.page('#E1E8EA');
  p.box('blue_edge', .055, .075, .04, .71, '#5B7780');
  b.photo(p, 'desk_scene', 'daily_desk', .105, .075, .825, .65);
  b.material(p, 'studioWashiIndigo', .61, .704, .29, .06, turn: -4);
  b.text(p, 'morning', '아침에 열어 둔 창', .10, .794, .81, .087, size: .047);
  b.save(p, 'daily-window-and-caption');

  p = b.page('#EEF0E8');
  b.material(p, 'heirloomLibraryCard', .065, .09, .39, .72, turn: -3);
  p.box('card_note', .12, .19, .29, .255, '#E5EBE8');
  b.text(p, 'record_label', '오늘의 목록', .14, .22, .26, .072, size: .030);
  b.text(
    p,
    'record_items',
    '읽을 책\n테이블 위의 꽃\n집에 오는 길',
    .14,
    .328,
    .26,
    .13,
    size: .022,
    leading: 1.55,
  );
  b.print(p, 'book_insert', 'daily_book', .49, .16, .42, .42, turn: 3);
  b.material(p, 'studioWashiSage', .57, .135, .25, .045, turn: -4);
  b.material(p, 'travelDocumentPocket', .065, .62, .85, .29);
  b.text(
    p,
    'collection_heading',
    '하루에서 고른 것들',
    .12,
    .794,
    .74,
    .06,
    size: .030,
  );
  b.save(p, 'daily-library-pocket');

  p = b.page('#D9E3E5');
  b.material(p, 'studioCottonRag', .04, .08, .86, .78);
  b.photo(
    p,
    'book_page',
    'daily_book',
    .12,
    .12,
    .62,
    .71,
    frame: 'studioGallery',
  );
  p.box('bookmark', .75, .065, .093, .49, '#84989B');
  b.text(
    p,
    'bookmark_type',
    '책\n갈\n피',
    .774,
    .14,
    .050,
    .29,
    size: .031,
    color: '#FFFFFF',
    leading: 1.8,
  );
  b.text(p, 'reading_note', '다 읽지 않아도 좋은 시간', .12, .865, .73, .045, size: .025);
  b.save(p, 'daily-bookmark-portrait');

  p = b.page('#F0EFE8');
  b.material(p, 'heirloomLibraryCard', .15, .09, .73, .77, turn: 2);
  p.box('reading_stock', .19, .22, .55, .39, '#E5EBE8');
  b.text(p, 'reading_title', '읽다가 적어 둔 말', .23, .27, .50, .075, size: .034);
  b.text(
    p,
    'reading_lines',
    '한 문장을 읽고\n잠깐 창밖을 봤다.\n책갈피를 끼우고 차를 따랐다.',
    .23,
    .391,
    .50,
    .19,
    size: .024,
    leading: 1.6,
  );
  b.print(
    p,
    'reading_table',
    'small_days_breakfast',
    .41,
    .64,
    .48,
    .25,
    turn: -4,
  );
  b.material(p, 'studioWashiIndigo', .13, .133, .29, .049, turn: -8);
  b.save(p, 'daily-reading-card');

  p = b.page('#E8ECDD');
  b.text(p, 'market_heading', '장바구니를 펼치면', .07, .06, .86, .08, size: .046);
  b.photo(
    p,
    'market_fruit',
    'daily_fruit',
    .065,
    .215,
    .56,
    .60,
    frame: 'studioTorn',
  );
  b.photo(p, 'market_flowers', 'small_days_walk', .68, .215, .245, .35);
  b.material(p, 'travelMarketReceipt', .685, .565, .22, .315, turn: 3);
  b.material(p, 'studioWashiSage', .22, .184, .26, .058);
  b.text(
    p,
    'market_caption',
    '계절의 과일과 꽃 한 다발',
    .07,
    .854,
    .57,
    .052,
    size: .025,
  );
  b.save(p, 'daily-shopping-column');

  p = b.page('#DDE7E6');
  b.material(p, 'heirloomTableLinen', .06, .12, .85, .72, turn: -2);
  final circle = math.min(.67, .58 / p.ratio);
  b.photo(
    p,
    'picnic_plate',
    'daily_picnic',
    .46 - circle / 2,
    .18,
    circle,
    circle * p.ratio,
    frame: 'studioOval',
  );
  b.material(p, 'heirloomLibraryCard', .66, .59, .25, .27, turn: 4);
  b.text(p, 'picnic_caption', '밖에서 먹는 점심', .08, .813, .57, .068, size: .037);
  b.save(p, 'daily-picnic-roundel');

  p = b.page('#EBEEE9');
  b.text(p, 'company_title', '함께 보내면 더 좋은 날', .07, .065, .86, .084, size: .040);
  final friends = b.groupPhoto(
    p,
    'friends',
    'daily_friends',
    const Rect.fromLTWH(.06, .22, .88, .53),
  );
  b.material(
    p,
    'studioCottonRag',
    friends.left + .025,
    friends.bottom + .01,
    .61,
    .16,
    turn: -3,
  );
  b.text(
    p,
    'company_note',
    '오래 앉아서 이야기를 나눴다.',
    .12,
    friends.bottom + .05,
    .75,
    .07,
    size: .026,
  );
  b.material(p, 'studioWashiIndigo', .70, .20, .22, .05, turn: 5);
  b.save(p, 'daily-company-panorama');

  p = b.page('#DEE6E8');
  p.box('file_tab', .08, .125, .28, .061, '#AEBFC2');
  p.box('file_stock', .075, .18, .85, .68, '#F3F3EB');
  b.text(p, 'file_title', '오늘을 넣어 둔다', .14, .255, .70, .095, size: .042);
  b.text(
    p,
    'file_letter',
    b.copy.note,
    .14,
    .403,
    .72,
    .20,
    size: .027,
    leading: 1.6,
  );
  b.material(p, 'heirloomLibraryCard', .61, .64, .23, .19, turn: 5);
  b.material(p, 'studioWashiIndigo', .12, .775, .35, .07, turn: -3);
  b.save(p, 'daily-closing-file');
}

void _heirloomBaby(_HeirloomBook b) {
  var p = b.page('#E9EBE8');
  b.material(p, 'studioCottonRag', .055, .08, .89, .74, turn: -2);
  b.photo(
    p,
    'little_hand',
    'growth_hand',
    .09,
    .14,
    .82,
    .51,
    frame: 'studioDeckle',
  );
  b.material(p, 'heirloomGrowthRuler', .17, .646, .66, .15, turn: 2);
  b.text(p, 'hand_title', '손가락 하나를 꼭 쥐던 날', .11, .822, .80, .06, size: .034);
  b.save(p, 'baby-first-hand-print');

  p = b.page('#E2E9E7');
  p.box('birth_card_shadow', .10, .13, .79, .72, '#C6D2CC');
  p.box('birth_card', .08, .115, .79, .72, '#F5F5ED');
  b.text(p, 'birth_title', '처음 마주한 너', .15, .205, .64, .083, size: .044);
  b.text(p, 'birth_name', b.copy.byline, .15, .331, .62, .056, size: .027);
  b.text(p, 'birth_date', b.copy.period, .15, .420, .57, .042, size: .020);
  p.box('birth_rule', .15, .495, .62, .0015, '#BBC8BD');
  b.groupPhoto(
    p,
    'birth_sleep',
    'growth_sleep',
    const Rect.fromLTWH(.41, .559, .47, .255),
    mounted: true,
  );
  b.material(p, 'studioWashiIndigo', .11, .098, .29, .052, turn: -5);
  b.material(p, 'heirloomGrowthRuler', .13, .735, .23, .09);
  b.save(p, 'baby-birth-record');

  p = b.page('#DFE8E7');
  b.text(p, 'growing_title', '조금씩 자라는 중', .07, .055, .86, .087, size: .043);
  final wideTimeline = b.aspect == CollectionAspect.landscape;
  if (wideTimeline) {
    p.box('timeline', .11, .66, .77, .003, '#98B1A4');
  } else {
    p.box('timeline', .12, .23, .003, .61, '#98B1A4');
  }
  for (final item in [
    ('01', 'growth_sleep', '잠든 얼굴', .20),
    ('02', 'growth_play', '혼자 앉던 날', .435),
    ('03', 'growth_walk', '손잡고 걷기', .67),
  ]) {
    final x = .095 + (int.parse(item.$1) - 1) * .29;
    b.text(
      p,
      'month_${item.$1}',
      item.$1,
      wideTimeline ? x : .15,
      wideTimeline ? .235 : item.$4 + .02,
      .10,
      .055,
      size: .03,
    );
    b.groupPhoto(
      p,
      'stage_${item.$1}',
      item.$2,
      wideTimeline
          ? Rect.fromLTWH(x, .33, .25, .26)
          : Rect.fromLTWH(.29, item.$4, .40, .185),
    );
    b.text(
      p,
      'stage_note_${item.$1}',
      item.$3,
      wideTimeline ? x : .735,
      wideTimeline ? .70 : item.$4 + .06,
      .20,
      .10,
      size: .022,
    );
  }
  if (wideTimeline) {
    b.material(p, 'heirloomGrowthRuler', .10, .81, .71, .065);
  }
  b.save(p, 'baby-development-timeline');

  p = b.page('#EDEBE1');
  b.material(p, 'studioBlueFibre', .065, .17, .84, .67, turn: 3);
  b.photo(
    p,
    'first_play',
    'growth_play',
    .12,
    .215,
    .73,
    .58,
    frame: 'studioOvalMat',
  );
  b.material(p, 'heirloomGrowthRuler', .17, .106, .68, .14);
  b.text(p, 'play_title', '스스로 해낸 작은 일', .13, .836, .74, .056, size: .034);
  b.save(p, 'baby-play-oval');

  p = b.page('#DEE8E8');
  b.photo(p, 'keepsakes', 'growth_keepsakes', .04, .055, .92, .725);
  b.material(p, 'studioWashiIndigo', .11, .035, .29, .053, turn: -3);
  b.text(p, 'keepsake_title', '어느새 작아진 물건들', .09, .833, .82, .075, size: .039);
  b.save(p, 'baby-object-still-life');

  p = b.page('#E8EDE6');
  b.material(p, 'studioCottonRag', .07, .085, .83, .77, turn: -2);
  p.box('inventory', .13, .17, .72, .62, '#F6F5ED');
  b.text(p, 'inventory_title', '작은 보관함', .20, .255, .61, .084, size: .045);
  for (final item in [('첫 양말', .405), ('좋아하던 장난감', .514), ('자주 덮던 담요', .623)]) {
    b.text(
      p,
      'object_${item.$2}',
      item.$1,
      .20,
      item.$2,
      .57,
      .045,
      size: .026,
    );
    p.box('rule_${item.$2}', .20, item.$2 + .068, .55, .0015, '#C2CEC1');
  }
  b.material(p, 'travelDocumentPocket', .11, .714, .79, .16);
  b.material(p, 'heirloomGrowthRuler', .20, .10, .60, .07);
  b.save(p, 'baby-keepsake-inventory');

  p = b.page('#E9E6E8');
  b.text(p, 'birthday_title', '함께 맞은 첫 생일', .07, .06, .86, .086, size: .044);
  b.photo(
    p,
    'birthday',
    'growth_birthday',
    .055,
    .21,
    .89,
    .50,
    frame: 'studioGallery',
  );
  b.material(p, 'heirloomGrowthRuler', .10, .706, .65, .14, turn: -2);
  b.material(p, 'studioGouacheCake', .77, .726, .13, .15, turn: 4);
  b.save(p, 'baby-birthday-landscape');

  p = b.page('#DFE7E5');
  b.material(p, 'studioCottonRag', .07, .06, .84, .83);
  b.text(p, 'letter_title', '다음의 처음도 함께', .16, .15, .72, .085, size: .040);
  b.text(
    p,
    'letter',
    b.copy.note,
    .16,
    .296,
    .70,
    .225,
    size: .026,
    leading: 1.7,
  );
  b.print(p, 'letter_hand', 'growth_hand', .28, .602, .56, .266, turn: 2);
  b.material(p, 'studioWashiSage', .45, .584, .25, .047);
  b.save(p, 'baby-letter-and-hand');
}

void _heirloomFamily(_HeirloomBook b) {
  var p = b.page('#E4E9DF');
  b.material(p, 'heirloomTableLinen', .03, .095, .94, .75, turn: 2);
  b.photo(
    p,
    'table',
    'family_table',
    .105,
    .16,
    .79,
    .58,
    frame: 'studioGallery',
  );
  b.text(p, 'table_title', '조금 더 넓게 편 식탁', .11, .809, .80, .073, size: .039);
  b.save(p, 'family-linen-table');

  p = b.page('#EEEFE6');
  b.text(p, 'menu_title', '오늘 함께 먹은 것', .085, .07, .83, .092, size: .046);
  p.box('menu_rule', .085, .205, .82, .003, '#75917B');
  b.text(
    p,
    'menu',
    '따뜻한 국 한 그릇\n계절 채소와 작은 반찬\n마지막에는 과일을 나눠 먹기',
    .12,
    .274,
    .74,
    .22,
    size: .029,
    leading: 1.75,
  );
  b.material(p, 'heirloomTableLinen', .54, .552, .37, .327, turn: -4);
  b.print(p, 'menu_detail', 'daily_fruit', .09, .593, .39, .245, turn: 3);
  b.material(p, 'studioWashiSage', .17, .57, .24, .049);
  b.save(p, 'family-handwritten-menu');

  p = b.page('#DCE7DD');
  b.text(p, 'kitchen_title', '같이 만들면 더 맛있다', .07, .067, .85, .086, size: .041);
  final cooking = b.groupPhoto(
    p,
    'cooking',
    'family_kitchen',
    const Rect.fromLTWH(.06, .235, .88, .51),
  );
  b.material(
    p,
    'heirloomTableLinen',
    cooking.left + .06,
    cooking.bottom - .005,
    .44,
    .14,
    turn: -4,
  );
  b.text(
    p,
    'cooking_note',
    '손이 조금 더 가도 괜찮은 날',
    .14,
    cooking.bottom + .06,
    .75,
    .05,
    size: .024,
  );
  b.save(p, 'family-cooking-panorama');

  p = b.page('#EBEEE5');
  b.material(p, 'heirloomTableLinen', .06, .08, .85, .78, turn: -3);
  p.box('recipe', .13, .11, .74, .75, '#F8F6EB');
  b.text(p, 'recipe_title', '우리 집 주먹밥', .20, .19, .60, .09, size: .044);
  b.text(
    p,
    'ingredients',
    '밥 · 잘게 썬 채소 · 참기름 · 김',
    .20,
    .316,
    .60,
    .075,
    size: .023,
  );
  p.box('recipe_line', .20, .406, .59, .0015, '#B6C7B7');
  b.text(
    p,
    'recipe_steps',
    '01   재료를 작은 크기로 썬다.\n02   밥과 함께 골고루 섞는다.\n03   먹기 좋은 크기로 꼭 쥔다.',
    .20,
    .453,
    .61,
    .22,
    size: .024,
    leading: 1.8,
  );
  b.text(
    p,
    'recipe_note',
    '같이 만들고, 같이 나누어 먹기.',
    .20,
    .728,
    .60,
    .075,
    size: .024,
  );
  b.save(p, 'family-recipe-card');

  p = b.page('#E3E9E2');
  b.groupPhoto(
    p,
    'friends_table',
    'family_friends',
    const Rect.fromLTWH(.055, .10, .89, .61),
  );
  b.material(p, 'studioWashiSage', .14, .072, .32, .059, turn: -3);
  b.text(
    p,
    'friends_heading',
    '사진에 다 담기지 않은 웃음',
    .10,
    .772,
    .81,
    .091,
    size: .038,
  );
  b.save(p, 'family-long-company-print');

  p = b.page('#EAECDD');
  b.material(p, 'heirloomTableLinen', .07, .12, .86, .67, turn: 3);
  final w = math.min(.70, .60 / p.ratio);
  b.photo(
    p,
    'picnic_circle',
    'family_picnic',
    .48 - w / 2,
    .20,
    w,
    w * p.ratio,
    frame: 'studioOvalMat',
  );
  b.text(p, 'picnic_title', '식탁을 들고 바깥으로', .11, .84, .80, .069, size: .037);
  b.save(p, 'family-picnic-tableau');

  p = b.page('#E0E8E0');
  b.text(p, 'small_menu', '남겨 둔 식탁의 장면', .07, .065, .86, .085, size: .041);
  b.photo(
    p,
    'table_end',
    'family_table',
    .07,
    .23,
    .52,
    .56,
    frame: 'studioDeckle',
  );
  b.photo(p, 'flowers_end', 'daily_desk', .65, .23, .28, .34);
  b.material(p, 'heirloomTableLinen', .64, .587, .285, .23, turn: -4);
  b.text(
    p,
    'table_note',
    '반찬을 나누고, 다음 날짜를 정했다.',
    .09,
    .85,
    .82,
    .047,
    size: .025,
  );
  b.save(p, 'family-table-and-detail');

  p = b.page('#F0F0E7');
  b.material(p, 'heirloomTableLinen', .10, .10, .80, .77, turn: -2);
  p.box('family_letter', .17, .22, .66, .59, '#F7F6EC');
  b.text(p, 'letter_title', '다음에도 이 자리에', .23, .307, .56, .080, size: .038);
  b.text(
    p,
    'letter_text',
    b.copy.note,
    .23,
    .457,
    .56,
    .24,
    size: .025,
    leading: 1.7,
  );
  b.material(p, 'studioWashiSage', .29, .199, .38, .058, turn: 3);
  b.save(p, 'family-folded-table-letter');
}

void _heirloomCouple(_HeirloomBook b) {
  var p = b.page('#E9E0E2');
  b.text(
    p,
    'tickets_heading',
    '나란히 앉을 두 자리',
    .075,
    .067,
    .85,
    .086,
    size: .043,
  );
  b.material(p, 'studioVellum', .085, .21, .83, .63, turn: 3);
  b.material(p, 'heirloomCinemaStub', .095, .245, .80, .255, turn: -4);
  b.material(p, 'heirloomCinemaStub', .18, .51, .69, .23, turn: 4);
  b.text(
    p,
    'ticket_note',
    '영화가 끝나도 이야기는 계속됐다.',
    .13,
    .825,
    .78,
    .06,
    size: .026,
  );
  b.save(p, 'couple-ticket-pair');

  p = b.page('#DBDEE0');
  p.box('cinema_rail', .06, .09, .88, .665, '#3D3C3E');
  if (b.aspect == CollectionAspect.landscape) {
    b.groupPhoto(
      p,
      'walking_frame',
      'couple_walk',
      const Rect.fromLTWH(.095, .245, .39, .40),
    );
    b.groupPhoto(
      p,
      'cafe_frame',
      'couple_cafe',
      const Rect.fromLTWH(.515, .245, .39, .40),
    );
  } else {
    b.photo(p, 'walking_frame', 'couple_walk', .095, .128, .81, .265);
    b.photo(p, 'cafe_frame', 'couple_cafe', .095, .432, .81, .282);
  }
  for (var i = 0; i < 9; i++) {
    p.box('film_hole_$i', .069, .135 + i * .065, .012, .020, '#CBD3D3');
  }
  b.text(p, 'film_heading', '둘이 모은 장면', .095, .822, .81, .078, size: .042);
  b.save(p, 'couple-double-cinema-frame');

  p = b.page('#EEE8E6');
  b.material(p, 'studioCottonRag', .05, .09, .87, .75, turn: -3);
  b.groupPhoto(
    p,
    'cafe_people',
    'couple_cafe',
    const Rect.fromLTWH(.075, .185, .85, .55),
  );
  b.material(p, 'heirloomCinemaStub', .49, .733, .41, .14, turn: 3);
  b.text(p, 'cafe_title', '마주 앉아 오래 이야기한 날', .09, .079, .82, .067, size: .035);
  b.save(p, 'couple-cafe-full-print');

  p = b.page('#E7DDE0');
  b.material(p, 'studioCottonRag', .09, .065, .84, .80, turn: 2);
  p.box('letter_stock', .15, .15, .70, .66, '#F6F4ED');
  b.text(p, 'note_heading', '잊지 않으려고 적는다', .22, .265, .57, .085, size: .036);
  b.text(
    p,
    'note_body',
    '먼저 도착해 창가 자리를 골랐다.\n너는 늘 마시던 커피를 주문했다.\n별것 아닌 이야기를 오래 했다.',
    .22,
    .423,
    .56,
    .22,
    size: .025,
    leading: 1.7,
  );
  b.material(p, 'studioWashiRose', .24, .123, .41, .054, turn: -4);
  b.material(p, 'heirloomCinemaStub', .10, .772, .40, .115, turn: 4);
  b.save(p, 'couple-cafe-note');

  p = b.page('#DFDCDD');
  b.text(
    p,
    'anniversary_title',
    '오늘은 조금 특별하게',
    .08,
    .06,
    .84,
    .091,
    size: .041,
  );
  b.groupPhoto(
    p,
    'anniversary',
    'couple_anniversary',
    const Rect.fromLTWH(.055, .22, .89, .53),
  );
  b.material(p, 'studioRoseSilk', .74, .72, .17, .17, turn: -4);
  b.material(p, 'heirloomCinemaStub', .105, .758, .44, .125, turn: 2);
  b.save(p, 'couple-anniversary-panorama');

  p = b.page('#EFE9E7');
  b.photo(
    p,
    'keepsake_ribbon',
    'couple_keepsakes',
    .08,
    .115,
    .59,
    .69,
    frame: 'studioDeckle',
  );
  b.material(p, 'heirloomCinemaStub', .695, .15, .22, .115, turn: 4);
  b.text(p, 'date', b.copy.period, .71, .365, .20, .10, size: .023);
  b.text(
    p,
    'kept',
    '접어 둔\n티켓과\n짧은 편지',
    .71,
    .52,
    .19,
    .23,
    size: .027,
    leading: 1.8,
  );
  b.material(p, 'studioWashiRose', .25, .096, .28, .058);
  b.save(p, 'couple-keepsake-and-margin');

  p = b.page('#E1E4E0');
  b.material(p, 'studioVellum', .06, .105, .87, .77, turn: -3);
  b.photo(
    p,
    'together_portrait',
    'couple_walk',
    .235,
    .085,
    .55,
    .735,
    frame: 'studioGallery',
  );
  b.material(p, 'heirloomCinemaStub', .075, .735, .33, .105, turn: -5);
  b.text(p, 'walking_title', '한 정거장을 더 걸었다', .105, .865, .79, .05, size: .031);
  b.save(p, 'couple-last-walking-print');

  p = b.page('#EDE5E5');
  b.material(p, 'studioCottonRag', .06, .06, .87, .82);
  b.text(p, 'ending_title', '다음 장면도 함께', .15, .155, .71, .097, size: .046);
  b.text(
    p,
    'ending_letter',
    b.copy.note,
    .15,
    .30,
    .72,
    .23,
    size: .026,
    leading: 1.7,
  );
  b.material(p, 'heirloomCinemaStub', .20, .675, .64, .19, turn: -3);
  b.material(p, 'studioWashiRose', .61, .653, .24, .048, turn: 4);
  b.save(p, 'couple-next-ticket-letter');
}

void _heirloomPet(_HeirloomBook b) {
  var p = b.page('#DEE7DA');
  b.photo(p, 'park_walk', 'pet_walk', .045, .075, .91, .70);
  b.material(p, 'heirloomPetTag', .78, .633, .14, .235, turn: 5);
  b.text(p, 'walk_heading', '오늘도 같이 걷자', .09, .823, .66, .087, size: .043);
  b.save(p, 'pet-park-opening');

  p = b.page('#EEF0DF');
  p.box('passport', .085, .12, .82, .725, '#F8F7EB');
  b.text(p, 'profile_heading', '너를 알아가는 기록', .15, .21, .70, .077, size: .037);
  b.photo(p, 'profile', 'pet_dog', .15, .36, .34, .35, frame: 'studioOvalMat');
  b.text(p, 'profile_name', '보리', .56, .388, .26, .07, size: .040);
  b.text(
    p,
    'profile_details',
    '좋아하는 것\n천천히 걷기\n창가에서 낮잠',
    .56,
    .505,
    .29,
    .18,
    size: .025,
    leading: 1.6,
  );
  b.material(p, 'heirloomPetTag', .71, .748, .11, .14, turn: -8);
  b.material(p, 'studioWashiSage', .17, .10, .32, .056, turn: -4);
  b.save(p, 'pet-field-passport');

  p = b.page('#DDE5DC');
  b.text(p, 'walk_index', '산책 수첩', .075, .065, .83, .092, size: .048);
  p.box('route_rule', .135, .25, .004, .50, '#879D79');
  for (final row in [
    ('01', '늘 멈추는 나무', .25),
    ('02', '마시던 물 한 모금', .41),
    ('03', '집으로 가는 모퉁이', .57),
  ]) {
    b.text(p, 'route_${row.$1}', row.$1, .18, row.$3, .10, .058, size: .028);
    b.text(
      p,
      'walk_note_${row.$1}',
      row.$2,
      .31,
      row.$3,
      .49,
      .061,
      size: .026,
    );
  }
  b.material(p, 'heirloomPetTag', .76, .734, .12, .16, turn: 7);
  b.text(p, 'walk_record', '서두르지 않고 한 바퀴', .19, .798, .56, .059, size: .028);
  b.save(p, 'pet-walk-route-log');

  p = b.page('#E8EBDD');
  b.material(p, 'studioCottonRag', .07, .07, .86, .75, turn: -3);
  b.photo(
    p,
    'park_portrait',
    'pet_dog',
    .14,
    .13,
    .69,
    .675,
    frame: 'studioGallery',
  );
  b.material(p, 'heirloomPetTag', .07, .616, .145, .26, turn: -8);
  b.text(p, 'portrait_caption', '이 표정이 좋아서', .26, .857, .63, .054, size: .034);
  b.save(p, 'pet-name-tag-portrait');

  p = b.page('#E2E9E7');
  b.text(p, 'nap_title', '집에서는 이런 얼굴', .08, .067, .84, .091, size: .043);
  b.photo(p, 'resting', 'pet_rest', 0, .244, 1, .464);
  b.material(p, 'studioBlueFibre', .11, .681, .55, .15, turn: -3);
  b.text(p, 'nap_note', '산책을 마치고 창가에 누웠다.', .16, .802, .74, .061, size: .026);
  b.save(p, 'pet-window-nap-panorama');

  p = b.page('#EBEEE1');
  b.photo(
    p,
    'walking_things',
    'pet_keepsakes',
    .11,
    .105,
    .77,
    .58,
    frame: 'studioDeckle',
  );
  b.material(p, 'heirloomPetTag', .12, .645, .145, .23, turn: 3);
  b.text(p, 'things_title', '나가기 전에 챙기는 것', .32, .744, .58, .064, size: .029);
  b.text(
    p,
    'things_list',
    '하네스 · 물그릇 · 작은 수건',
    .32,
    .832,
    .58,
    .050,
    size: .022,
  );
  b.save(p, 'pet-walking-kit');

  p = b.page('#DBE5D8');
  b.material(p, 'studioCottonRag', .06, .10, .85, .73, turn: 3);
  final circle = math.min(.68, .59 / p.ratio);
  b.photo(
    p,
    'sleep_circle',
    'pet_rest',
    .46 - circle / 2,
    .17,
    circle,
    circle * p.ratio,
    frame: 'studioOval',
  );
  b.material(p, 'heirloomPetTag', .75, .653, .14, .23, turn: -4);
  b.text(p, 'sleep_title', '깨우지 않고 남긴 사진', .10, .825, .64, .068, size: .033);
  b.save(p, 'pet-curled-sleep-roundel');

  p = b.page('#EEF0E7');
  p.box('notebook_stock', .095, .115, .81, .725, '#F8F7ED');
  for (var i = 0; i < 7; i++) {
    p.box('binding_$i', .077, .18 + i * .084, .039, .004, '#91A58A');
  }
  b.text(p, 'tomorrow', '내일도 같은 시간에', .17, .242, .66, .087, size: .042);
  b.text(
    p,
    'last_note',
    b.copy.note,
    .17,
    .405,
    .66,
    .24,
    size: .026,
    leading: 1.7,
  );
  b.material(p, 'heirloomPetTag', .65, .709, .12, .163, turn: 5);
  b.save(p, 'pet-tomorrow-notebook');
}
