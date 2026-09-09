part of 'authored_collections.dart';

const vowEditionChapters = [
  '준비한 마음',
  '약속을 적은 종이',
  '함께 앉은 자리',
  '입장을 기다리며',
  '마주 서서 건넨 말',
  '축하를 모아 두는 법',
  '꽃과 자리에 남은 흔적',
  '함께 나눈 저녁',
  '둘만 남은 시간',
  '오래 간직할 것',
];
const vowEditionInnerPageCount = 20;

/// The approved compositions remain intact; six new spreads precede the ending.
Map<String, dynamic> buildVowKeepsakeEdition(
  CollectionAspect aspect, {
  EditorialCopy? copy,
}) {
  final study = HeirloomStudy.wedding;
  final b = _HeirloomBook(
    study,
    aspect,
    copy ?? study.defaultCopy,
    chapterNames: vowEditionChapters,
  );
  b.cover();
  _heirloomWedding(b, beforeClosing: _vowEditionExpansion);
  return {
    ...b.document,
    'version': 2,
    'source': 'snapfit-authored-edition',
    'editionId': 'vow-keepsake-20',
    'publicationStatus': 'production-review',
    'approvalStatus': 'extension-awaiting-review',
    'approvalScope': 'approved-baseline-eight-pages-only',
    'studyScope': 'twenty-page-edition',
    'approvedBaselinePageMap': [0, 1, 2, 3, 4, 5, 6, 19, 20],
    'releaseGates': {
      'baselineDesign': 'approved',
      'extensionDesign': 'pending-review',
      'printProof': 'pending',
      'distributionRights': 'pending',
      'price': 'unset',
      'commerceIntegration': 'not-published',
    },
  };
}

void _vowEditionExpansion(_HeirloomBook b) {
  // 7-8: a fabric close-up faces a folded ceremony programme.
  var p = b.page('#E3E8E1');
  b.material(p, 'studioCottonRag', .035, .09, .87, .75, turn: -2);
  b.photo(
    p,
    'veil_drape',
    'petal_veil',
    .065,
    .07,
    .62,
    .78,
    frame: 'studioDeckle',
  );
  b.text(p, 'waiting_label', '입장 전', .735, .17, .20, .06, size: .032);
  p.box('margin_rule', .742, .29, .0015, .40, '#A7B6A8');
  b.text(
    p,
    'fabric_note',
    '베일을\n고쳐 매고\n손을 잡았다.',
    .77,
    .36,
    .17,
    .24,
    size: .025,
    leading: 1.7,
  );
  b.material(p, 'studioRoseSilk', .665, .705, .24, .19, turn: 8);
  b.text(p, 'waiting_caption', '함께 문을 열기 직전', .08, .875, .63, .05, size: .029);
  b.save(p, 'vow-veil-and-margin');

  p = b.page('#EEF0E8');
  p.box('programme_shadow', .10, .106, .78, .68, '#D0D9CE');
  p.box('programme_paper', .084, .09, .78, .68, '#FAF8F0');
  p.box('programme_fold', .345, .11, .0014, .63, '#DEE0D6');
  b.text(p, 'programme_title', '그날의 순서', .14, .15, .62, .085, size: .043);
  for (final row in [
    ('01', '서로를 향해 걷기', .31),
    ('02', '약속을 나누기', .43),
    ('03', '함께 인사하기', .55),
  ]) {
    b.text(
      p,
      'programme_index_${row.$1}',
      row.$1,
      .15,
      row.$3,
      .13,
      .061,
      size: .038,
      font: 'Cormorant Garamond',
    );
    b.text(
      p,
      'programme_line_${row.$1}',
      row.$2,
      .39,
      row.$3 + .013,
      .42,
      .059,
      size: .027,
    );
  }
  b.text(
    p,
    'programme_date',
    b.copy.period,
    .39,
    .692,
    .40,
    .04,
    size: .019,
    font: 'NotoSans',
  );
  b.material(p, 'heirloomVowEnvelope', .10, .79, .68, .12, turn: -3);
  b.material(p, 'heirloomVowSeal', .71, .768, .125, .125, turn: 7);
  b.save(p, 'vow-folded-programme');

  // 9-10: the complete ceremony photograph, then a keepsake still life.
  p = b.page('#D9E3DA');
  b.text(p, 'ceremony_title', '마주 서서 건넨 말', .07, .061, .85, .087, size: .044);
  final ceremony = b.groupPhoto(
    p,
    'ceremony',
    'lightbound_ceremony',
    const Rect.fromLTWH(.045, .219, .91, .57),
    mounted: true,
  );
  b.material(p, 'studioSageRibbon', .04, .73, .18, .15, turn: -7);
  b.text(
    p,
    'ceremony_note',
    '목소리가 조금 떨렸지만, 또렷하게 기억한다.',
    .20,
    math.max(.817, ceremony.bottom + .025),
    .72,
    .07,
    size: .024,
  );
  b.material(p, 'studioWashiSage', .35, .199, .27, .044, turn: 2);
  b.save(p, 'vow-ceremony-folio');

  p = b.page('#EEEAE4');
  b.material(p, 'heirloomVowEnvelope', .075, .085, .85, .70, turn: -4);
  b.photo(
    p,
    'ring_box',
    'petal_details',
    .16,
    .18,
    .62,
    .535,
    frame: 'studioOvalMat',
  );
  b.material(p, 'heirloomVowSeal', .73, .632, .145, .145);
  b.text(p, 'ring_line', '매일의 약속이 된 작은 반지', .12, .807, .79, .075, size: .034);
  b.material(p, 'studioRoseSilk', .06, .657, .22, .18, turn: -6);
  b.save(p, 'vow-ring-envelope');

  // 11-12: guests and two distinct note formats, not another photo collage.
  p = b.page('#E0E7E0');
  b.groupPhoto(
    p,
    'guest_faces',
    'lightbound_guests',
    const Rect.fromLTWH(.045, .08, .91, .51),
  );
  final first = b.material(
    p,
    'heirloomVowPlaceCard',
    .065,
    .652,
    .43,
    .19,
    turn: -2,
  );
  final second = b.material(
    p,
    'heirloomVowPlaceCard',
    .525,
    .715,
    .41,
    .17,
    turn: 2,
  );
  b.text(
    p,
    'guest_message_a',
    '와 주어서\n더 좋은 날',
    first.left + .045,
    first.top + .036,
    first.width - .09,
    first.height - .044,
    size: .025,
    leading: 1.35,
  );
  b.text(
    p,
    'guest_message_b',
    '함께 웃던\n순간을 오래',
    second.left + .04,
    second.top + .025,
    second.width - .08,
    second.height - .032,
    size: .023,
    leading: 1.3,
  );
  b.material(p, 'studioWashiSage', .15, .06, .28, .049, turn: -2);
  b.save(p, 'vow-guests-and-place-notes');

  p = b.page('#EEEDE6');
  b.text(
    p,
    'guestbook_heading',
    '축하를 모아 두는 법',
    .07,
    .055,
    .87,
    .085,
    size: .043,
  );
  p.box('wide_note_shadow', .112, .232, .78, .273, '#D8DED1');
  p.box('wide_note', .09, .213, .78, .273, '#FBF9F1');
  b.text(
    p,
    'guestbook_note_one',
    '서로의 편이 되어 주기를.\n지금처럼 자주 웃기를.',
    .15,
    .286,
    .66,
    .142,
    size: .031,
    leading: 1.65,
  );
  p.box('second_note', .29, .58, .60, .23, '#E0E7DD');
  b.text(
    p,
    'guestbook_note_two',
    '좋은 날도, 평범한 날도\n함께 만들어 가기를.',
    .35,
    .636,
    .48,
    .125,
    size: .028,
    leading: 1.65,
  );
  b.material(p, 'studioOlivePress', .04, .51, .25, .30, turn: -7);
  b.material(p, 'studioWashiRose', .53, .565, .25, .048, turn: 4);
  b.text(
    p,
    'guestbook_caption',
    '그날 건네받은 마음들을 한곳에',
    .13,
    .866,
    .76,
    .048,
    size: .024,
  );
  b.save(p, 'vow-two-guest-letters');

  // 13-14: a florist's specimen print and a catalogue of tangible details.
  p = b.page('#E3E7DA');
  b.photo(
    p,
    'florist_print',
    'petal_bouquet',
    .045,
    .07,
    .76,
    .76,
    frame: 'studioTorn',
  );
  final specimen = b.material(
    p,
    'heirloomVowPlaceCard',
    .45,
    .817,
    .48,
    .10,
    turn: -3,
  );
  b.text(
    p,
    'specimen_label',
    '꽃을\n기억하는 법',
    specimen.left + .018,
    specimen.top + .018,
    specimen.width - .036,
    specimen.height - .022,
    size: .019,
    leading: 1.35,
  );
  b.text(p, 'florist_heading', '꽃을 고르던 마음', .08, .872, .34, .048, size: .030);
  b.material(p, 'studioSageRibbon', .75, .155, .19, .42, turn: 3);
  b.save(p, 'vow-florist-specimen');

  p = b.page('#F0EFE6');
  b.text(p, 'details_title', '손길이 닿았던 것들', .07, .06, .85, .083, size: .044);
  b.photo(
    p,
    'detail_veil',
    'petal_veil',
    .10,
    .23,
    .30,
    .46,
    frame: 'studioGallery',
  );
  b.photo(
    p,
    'detail_ring',
    'petal_details',
    .49,
    .23,
    .40,
    .31,
    frame: 'studioDeckle',
  );
  final details = b.material(
    p,
    'heirloomVowPlaceCard',
    .48,
    .60,
    .41,
    .22,
    turn: 2,
  );
  b.text(
    p,
    'detail_label',
    '베일 · 반지 · 꽃\n하나씩 골랐던 이유',
    details.left + .04,
    details.top + .04,
    details.width - .08,
    details.height - .045,
    size: .023,
    leading: 1.5,
  );
  b.material(p, 'studioRoseSilk', .065, .699, .20, .15, turn: -6);
  b.text(
    p,
    'detail_footer',
    '작은 선택들이 모여 만든 하루',
    .32,
    .858,
    .59,
    .052,
    size: .025,
  );
  b.save(p, 'vow-details-cabinet');

  // 15-16: a round place setting faces a menu with a tipped-in cake photograph.
  p = b.page('#D7E0D7');
  b.text(p, 'supper_heading', '같은 테이블에서', .075, .052, .83, .068, size: .040);
  b.material(p, 'heirloomTableLinen', .035, .167, .88, .67, turn: -3);
  final plate = math.min(.63, .53 / p.ratio);
  b.photo(
    p,
    'supper_table',
    'petal_table',
    .075,
    .142,
    plate,
    plate * p.ratio,
    frame: 'studioOvalMat',
  );
  b.material(p, 'studioOlivePress', .72, .22, .20, .34, turn: 8);
  final supper = b.material(
    p,
    'heirloomVowPlaceCard',
    .39,
    .715,
    .53,
    .19,
    turn: -2,
  );
  b.text(
    p,
    'supper_note',
    '잔을 들고,\n함께 웃던 저녁',
    supper.left + .04,
    supper.top + .04,
    supper.width - .08,
    supper.height - .048,
    size: .026,
    leading: 1.45,
  );
  b.material(p, 'studioRoseSilk', .055, .733, .23, .17, turn: -5);
  b.save(p, 'vow-linen-place-setting');

  p = b.page('#ECEEE4');
  p.box('menu_stock', .09, .085, .73, .77, '#F8F6EC');
  p.box('menu_border', .125, .12, .0016, .70, '#A7B99E');
  b.text(p, 'menu_title', '오래 나누고 싶은 저녁', .18, .176, .60, .09, size: .037);
  for (final line in [
    ('처음의 한 접시', .332),
    ('함께 나눈 따뜻한 식사', .425),
    ('마지막에는 달콤한 것', .518),
  ]) {
    b.text(p, 'menu_${line.$2}', line.$1, .18, line.$2, .58, .065, size: .026);
  }
  b.groupPhoto(
    p,
    'cake',
    'lightbound_cake',
    const Rect.fromLTWH(.39, .64, .52, .23),
    mounted: true,
  );
  b.material(p, 'heirloomVowSeal', .13, .693, .135, .135, turn: -8);
  b.material(p, 'studioWashiSage', .53, .621, .25, .040);
  b.save(p, 'vow-supper-menu');

  // 17-18: intimate portrait and a quiet evening dispatch before the saved ending.
  p = b.page('#D8E1D8');
  final portraitWidth = math.min(.79, .55 * 1.5 / p.ratio);
  final portrait = Rect.fromLTWH(
    .5 - portraitWidth / 2,
    .16,
    portraitWidth,
    portraitWidth * p.ratio / 1.5,
  );
  p.box(
    'twilight_mount',
    portrait.left - .03,
    portrait.top - .035,
    portrait.width + .06,
    portrait.height + .16,
    '#F9F8F0',
  );
  b.photo(
    p,
    'twilight',
    'lightbound_twilight',
    portrait.left,
    portrait.top,
    portrait.width,
    portrait.height,
  );
  b.text(
    p,
    'twilight_note',
    '사람들이 돌아간 뒤',
    portrait.left + .015,
    portrait.bottom + .045,
    portrait.width - .12,
    .055,
    size: .031,
  );
  b.material(
    p,
    'studioRoseSilk',
    portrait.right - .085,
    portrait.bottom + .053,
    .20,
    .14,
    turn: 3,
  );
  b.save(p, 'vow-intimate-portrait');

  p = b.page('#DFE6DE');
  b.text(
    p,
    'evening_heading',
    '둘이서 한 번 더 인사했다',
    .07,
    .061,
    .86,
    .079,
    size: .039,
  );
  b.material(p, 'heirloomVowEnvelope', .10, .20, .84, .68, turn: -4);
  p.box('evening_letter', .16, .247, .64, .25, '#FAF8EF');
  b.text(
    p,
    'evening_lines',
    '긴 하루를 같이 보낸 사람에게\n가장 마지막으로 건넨 고마움.',
    .205,
    .31,
    .55,
    .154,
    size: .028,
    leading: 1.65,
  );
  b.groupPhoto(
    p,
    'quiet_evening',
    'petal_evening',
    const Rect.fromLTWH(.23, .52, .61, .31),
    mounted: true,
  );
  b.material(p, 'heirloomVowSeal', .115, .692, .14, .14, turn: -7);
  b.text(
    p,
    'evening_postmark',
    b.copy.period,
    .16,
    .873,
    .57,
    .043,
    size: .020,
    font: 'NotoSans',
  );
  b.save(p, 'vow-evening-dispatch');
}
