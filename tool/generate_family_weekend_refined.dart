import 'dart:convert';
import 'dart:io';

const _assetDir = 'assets/templates/family_weekend/images/sources';
const _handoffPath = 'assets/templates/family_weekend_handoff.json';
const _storePath = 'assets/templates/generated/family_weekend_store.json';

String _asset(String fileName) => 'asset:$_assetDir/$fileName';

Map<String, dynamic> _imageLayer({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  required String imageUrl,
  String frame = 'free',
  int zIndex = 10,
  double rotation = 0,
  double opacity = 1,
}) {
  return {
    'id': id,
    'type': 'IMAGE',
    'zIndex': zIndex,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scale': 1.0,
    'rotation': rotation,
    'opacity': opacity,
    'payload': {
      'imageBackground': frame,
      'imageTemplate': 'free',
      'imageUrl': imageUrl,
      'previewUrl': imageUrl,
      'originalUrl': imageUrl,
    },
  };
}

Map<String, dynamic> _textLayer({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  required String text,
  String align = 'left',
  String fontFamily = 'NotoSans',
  int fontWeight = 600,
  double fontSize = 18,
  String color = '#FF1F2937',
  double letterSpacing = 0,
  double lineHeight = 1.2,
  int zIndex = 30,
}) {
  return {
    'id': id,
    'type': 'TEXT',
    'zIndex': zIndex,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scale': 1.0,
    'rotation': 0.0,
    'opacity': 1.0,
    'payload': {
      'text': text,
      'textAlign': align,
      'textStyleType': 'none',
      'textBackground': null,
      'textStyle': {
        'fontSize': fontSize,
        'fontSizeRatio': fontSize / 1080,
        'fontFamily': fontFamily,
        'fontWeight': fontWeight,
        'color': color,
        'letterSpacing': letterSpacing,
        'lineHeight': lineHeight,
      },
    },
  };
}

Map<String, dynamic> _decoLayer({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  String? fill,
  String? border,
  double? radius,
  double? borderWidth,
  int zIndex = 5,
  double rotation = 0,
  double opacity = 1,
}) {
  return {
    'id': id,
    'type': 'DECORATION',
    'zIndex': zIndex,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'scale': 1.0,
    'rotation': rotation,
    'opacity': opacity,
    'payload': {
      'imageBackground': 'free',
      'imageTemplate': 'free',
      if (fill != null) 'fill': fill,
      if (border != null) 'border': border,
      if (radius != null) 'cornerRadius': radius,
      if (borderWidth != null) 'borderWidth': borderWidth,
    },
  };
}

Map<String, dynamic> _page({
  required int pageNumber,
  required String layoutId,
  required String role,
  required int recommendedPhotoCount,
  required List<Map<String, dynamic>> layers,
}) {
  return {
    'pageNumber': pageNumber,
    'layoutId': layoutId,
    'role': _normalizeRole(role),
    'recommendedPhotoCount': recommendedPhotoCount,
    'layers': layers,
  };
}

String _normalizeRole(String role) {
  switch (role) {
    case 'cover':
      return 'cover';
    case 'ending':
      return 'end';
    case 'text':
      return 'chapter';
    default:
      return 'inner';
  }
}

bool _isFullBleedImage(Map<String, dynamic> layer) {
  if (layer['type'] != 'IMAGE') return false;
  final x = (layer['x'] as num?)?.toDouble() ?? 0;
  final y = (layer['y'] as num?)?.toDouble() ?? 0;
  final width = (layer['width'] as num?)?.toDouble() ?? 0;
  final height = (layer['height'] as num?)?.toDouble() ?? 0;
  return x <= 0.02 && y <= 0.02 && width >= 0.98 && height >= 0.98;
}

void _applyGenericRatioAdaptation({
  required List<Map<String, dynamic>> layers,
  required String ratioType,
}) {
  final verticalScale = ratioType == 'landscape' ? 0.72 : 0.86;
  final topInset = ratioType == 'landscape' ? 0.06 : 0.04;

  for (final layer in layers) {
    if (_isFullBleedImage(layer)) {
      layer['x'] = 0.0;
      layer['y'] = 0.0;
      layer['width'] = 1.0;
      layer['height'] = 1.0;
      continue;
    }

    final y = (layer['y'] as num?)?.toDouble() ?? 0;
    final height = (layer['height'] as num?)?.toDouble() ?? 0;
    layer['y'] = topInset + (y * verticalScale);
    layer['height'] = (height * verticalScale).clamp(0.02, 1.0);

    if (layer['type'] == 'TEXT') {
      final payload = layer['payload'] as Map<String, dynamic>? ?? {};
      final style = payload['textStyle'] as Map<String, dynamic>? ?? {};
      final fontSize = (style['fontSize'] as num?)?.toDouble();
      if (fontSize != null && ratioType == 'landscape') {
        style['fontSize'] = (fontSize * 0.92).clamp(10.0, 72.0);
      }
    }
  }
}

List<Map<String, dynamic>> _portraitPages() {
  final hands = _asset('hands_bw.png');
  final ceremony = _asset('ceremony_moment.png');
  final flowers = _asset('flower_table.png');
  final beach = _asset('beach_glow.png');
  final sunset = _asset('sunset_pair.png');
  final city = _asset('city_weekend.png');

  return [
    _page(
      pageNumber: 1,
      layoutId: 'cover_full_bleed',
      role: 'cover',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'cover_photo',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          imageUrl: city,
          zIndex: 5,
        ),
        _decoLayer(
          id: 'cover_bottom_sheet',
          x: 0.0,
          y: 1040 / 1440,
          width: 1.0,
          height: 400 / 1440,
          fill: '#FFF8F2EA',
          zIndex: 8,
        ),
        _textLayer(
          id: 'title',
          x: 96 / 1080,
          y: 1128 / 1440,
          width: 620 / 1080,
          height: 75 / 1440,
          text: '가족의\n주말',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 34,
          color: '#FF29424F',
          lineHeight: 1.0,
        ),
        _textLayer(
          id: 'subtitle',
          x: 100 / 1080,
          y: 1224 / 1440,
          width: 520 / 1080,
          height: 29 / 1440,
          text: '함께 보낸 하루의 장면들',
          fontSize: 14,
          color: '#FF55656E',
        ),
        _textLayer(
          id: 'badge_text',
          x: 796 / 1080,
          y: 1172 / 1440,
          width: 136 / 1080,
          height: 58 / 1440,
          text: 'SUN\nTOGET\nHER',
          align: 'center',
          fontWeight: 800,
          fontSize: 16,
          color: '#FF6C5A43',
          lineHeight: 1.1,
        ),
      ],
    ),
    _page(
      pageNumber: 2,
      layoutId: 'family_grid',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _imageLayer(
          id: 'photo_a',
          x: 88 / 1080,
          y: 112 / 1440,
          width: 566 / 1080,
          height: 832 / 1440,
          imageUrl: hands,
          frame: 'free',
        ),
        _imageLayer(
          id: 'photo_c',
          x: 694 / 1080,
          y: 524 / 1440,
          width: 298 / 1080,
          height: 420 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 88 / 1080,
          y: 1016 / 1440,
          width: 430 / 1080,
          height: 96 / 1440,
          text: '함께여서\n가능한\n기억들',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 34,
          color: '#FF233845',
          lineHeight: 1.15,
        ),
        _textLayer(
          id: 'body',
          x: 88 / 1080,
          y: 1118 / 1440,
          width: 430 / 1080,
          height: 48 / 1440,
          text: '가까이 찍힌 장면과 조금 먼 풍경을 섞어서\n하루의 결을 더 풍부하게 남긴다.',
          fontSize: 15,
          color: '#FF53666E',
          lineHeight: 1.4,
        ),
        _textLayer(
          id: 'chip_best_moments_text',
          x: 102 / 1080,
          y: 1248 / 1440,
          width: 178 / 1080,
          height: 17 / 1440,
          text: 'BEST MOMENTS',
          fontSize: 10,
          fontWeight: 700,
          color: '#FF2B4451',
        ),
      ],
    ),
    _page(
      pageNumber: 3,
      layoutId: 'double_memory',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _imageLayer(
          id: 'photo_large',
          x: 88 / 1080,
          y: 96 / 1440,
          width: 904 / 1080,
          height: 760 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'photo_small',
          x: 544 / 1080,
          y: 920 / 1440,
          width: 448 / 1080,
          height: 338 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 128 / 1080,
          y: 934 / 1440,
          width: 290 / 1080,
          height: 39 / 1440,
          text: '두고두고 꺼내 볼',
          fontFamily: 'NotoSerifKR',
          fontWeight: 700,
          fontSize: 22,
          color: '#FF223845',
        ),
        _textLayer(
          id: 'body',
          x: 128 / 1080,
          y: 994 / 1440,
          width: 300 / 1080,
          height: 81 / 1440,
          text: '한 장의 메인 컷과 작은 보조 컷으로\n주말의 리듬을 가볍게 남긴다.',
          fontSize: 14,
          color: '#FF53666E',
          lineHeight: 1.45,
        ),
      ],
    ),
    _page(
      pageNumber: 4,
      layoutId: 'tape_collage',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'ticket_a',
          x: 88 / 1080,
          y: 118 / 1440,
          width: 302.2285 / 1080,
          height: 479.6950 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_b',
          x: 398 / 1080,
          y: 118 / 1440,
          width: 296.2058 / 1080,
          height: 477.2732 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_c',
          x: 706 / 1080,
          y: 118 / 1440,
          width: 298.2052 / 1080,
          height: 477.3256 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _textLayer(
          id: 'footer',
          x: 124 / 1080,
          y: 628 / 1440,
          width: 820 / 1080,
          height: 96 / 1440,
          text: '벽에 기대 놓은 작은 기록들',
          align: 'center',
          fontSize: 16,
          color: '#FF556872',
        ),
      ],
    ),
    _page(
      pageNumber: 5,
      layoutId: 'quote_break',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _imageLayer(
          id: 'photo_top_wide',
          x: 88 / 1080,
          y: 112 / 1440,
          width: 904 / 1080,
          height: 472 / 1440,
          imageUrl: sunset,
          frame: 'free',
        ),
        _imageLayer(
          id: 'photo_corner',
          x: 740 / 1080,
          y: 530 / 1440,
          width: 198.0055 / 1080,
          height: 162.7488 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _textLayer(
          id: 'quote',
          x: 164 / 1080,
          y: 748 / 1440,
          width: 752 / 1080,
          height: 123 / 1440,
          text: '오래 남는 건 특별한 날보다\n함께 웃은 표정과\n가만한 손의 온기였다.',
          align: 'center',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 32,
          color: '#FF3B3435',
          lineHeight: 1.3,
        ),
      ],
    ),
    _page(
      pageNumber: 6,
      layoutId: 'four_cut',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'cut_a',
          x: 88 / 1080,
          y: 120 / 1440,
          width: 432 / 1080,
          height: 324 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'cut_b',
          x: 560 / 1080,
          y: 120 / 1440,
          width: 432 / 1080,
          height: 324 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _imageLayer(
          id: 'cut_d',
          x: 560 / 1080,
          y: 484 / 1440,
          width: 432 / 1080,
          height: 324 / 1440,
          imageUrl: hands,
          frame: 'free',
        ),
        _textLayer(
          id: 'chip_text_FOUR_CUT',
          x: 104 / 1080,
          y: 938 / 1440,
          width: 150 / 1080,
          height: 18 / 1440,
          text: 'FOUR CUT',
          fontWeight: 800,
          fontSize: 9,
          color: '#FF2A4350',
        ),
        _textLayer(
          id: 'body',
          x: 88 / 1080,
          y: 980 / 1440,
          width: 430 / 1080,
          height: 27 / 1440,
          text: '한 장 한 장 넘길수록 선명해지는 하루의 표정',
          fontSize: 14,
          color: '#FF4B5D67',
        ),
      ],
    ),
    _page(
      pageNumber: 7,
      layoutId: 'wide_banner',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'wide_photo',
          x: 88 / 1080,
          y: 120 / 1440,
          width: 904 / 1080,
          height: 640 / 1440,
          imageUrl: sunset,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 124 / 1080,
          y: 838 / 1440,
          width: 360 / 1080,
          height: 36 / 1440,
          text: '먼 곳을 볼 때의',
          fontWeight: 800,
          fontSize: 18,
          color: '#FF3B3435',
        ),
        _textLayer(
          id: 'sub',
          x: 124 / 1080,
          y: 900 / 1440,
          width: 350 / 1080,
          height: 44 / 1440,
          text: '먼저 웃는 쪽을\n기억하고 싶다.',
          fontSize: 16,
          color: '#FF5C6E77',
        ),
      ],
    ),
    _page(
      pageNumber: 8,
      layoutId: 'detail_mix',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'photo_large',
          x: 88 / 1080,
          y: 112 / 1440,
          width: 520 / 1080,
          height: 820 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _imageLayer(
          id: 'detail_a',
          x: 648 / 1080,
          y: 112 / 1440,
          width: 344 / 1080,
          height: 258 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _imageLayer(
          id: 'detail_c',
          x: 648 / 1080,
          y: 410 / 1440,
          width: 344 / 1080,
          height: 258 / 1440,
          imageUrl: beach,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 88 / 1080,
          y: 976 / 1440,
          width: 420 / 1080,
          height: 36 / 1440,
          text: '하루를 채운 디테일',
          fontSize: 18,
          fontWeight: 700,
          color: '#FF4D6069',
        ),
      ],
    ),
    _page(
      pageNumber: 9,
      layoutId: 'memory_wall',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'side_band',
          x: 88 / 1080,
          y: 928 / 1440,
          width: 240 / 1080,
          height: 190 / 1440,
          fill: '#FF4B6777',
          zIndex: 8,
        ),
        _imageLayer(
          id: 'wall_b',
          x: 180 / 1080,
          y: 176 / 1440,
          width: 530 / 1080,
          height: 662 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 120 / 1080,
          y: 952 / 1440,
          width: 190 / 1080,
          height: 62 / 1440,
          text: '가족의 편지처럼',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 22,
          color: '#FFFFFFFF',
        ),
      ],
    ),
    _page(
      pageNumber: 10,
      layoutId: 'ending_note',
      role: 'ending',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'ending_photo',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          imageUrl: sunset,
          zIndex: 5,
        ),
        _textLayer(
          id: 'title',
          x: 124 / 1080,
          y: 1164 / 1440,
          width: 300 / 1080,
          height: 96 / 1440,
          text: '다음에도\n함께.',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 24,
          color: '#FFFFFFFF',
          lineHeight: 1.0,
          zIndex: 30,
        ),
      ],
    ),
    _page(
      pageNumber: 11,
      layoutId: 'big_memory',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'hero_photo',
          x: 88 / 1080,
          y: 114 / 1440,
          width: 592 / 1080,
          height: 884 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _imageLayer(
          id: 'side_top',
          x: 720 / 1080,
          y: 114 / 1440,
          width: 272 / 1080,
          height: 332 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _imageLayer(
          id: 'side_bottom',
          x: 720 / 1080,
          y: 492 / 1440,
          width: 272 / 1080,
          height: 332 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _textLayer(
          id: 'chip_text_FOUR_CUT',
          x: 104 / 1080,
          y: 1008 / 1440,
          width: 158 / 1080,
          height: 18 / 1440,
          text: 'DAY MEMORY',
          fontWeight: 800,
          fontSize: 9,
          color: '#FF2A4350',
        ),
        _textLayer(
          id: 'body',
          x: 88 / 1080,
          y: 1050 / 1440,
          width: 430 / 1080,
          height: 92 / 1440,
          text: '가장 크게 남기고 싶은 한 장과\n그 옆을 맴도는 작은 순간들.',
          fontSize: 16,
          color: '#FF53656D',
        ),
      ],
    ),
    _page(
      pageNumber: 12,
      layoutId: 'polaroid_line',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'ticket_a',
          x: 96 / 1080,
          y: 144 / 1440,
          width: 293.4160 / 1080,
          height: 353.9788 / 1440,
          imageUrl: hands,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_b',
          x: 404 / 1080,
          y: 136 / 1440,
          width: 284.8056 / 1080,
          height: 347.1083 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_c',
          x: 712 / 1080,
          y: 144 / 1440,
          width: 287.6977 / 1080,
          height: 349.4251 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
        _textLayer(
          id: 'footer',
          x: 126 / 1080,
          y: 566 / 1440,
          width: 400 / 1080,
          height: 44 / 1440,
          text: '줄에 걸어 둔 사진처럼\n가볍게 이어지는 순간들.',
          fontSize: 16,
          color: '#FF4C626E',
        ),
      ],
    ),
    _page(
      pageNumber: 13,
      layoutId: 'circle_and_note',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'circle_main_rectified',
          x: 90 / 1080,
          y: 120 / 1440,
          width: 560 / 1080,
          height: 840 / 1440,
          imageUrl: hands,
          frame: 'free',
        ),
        _imageLayer(
          id: 'circle_small_a_rectified',
          x: 690 / 1080,
          y: 120 / 1440,
          width: 300 / 1080,
          height: 390 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'circle_small_b_rectified',
          x: 690 / 1080,
          y: 570 / 1440,
          width: 300 / 1080,
          height: 390 / 1440,
          imageUrl: beach,
          frame: 'free',
        ),
        _textLayer(
          id: 'label_text',
          x: 124 / 1080,
          y: 958 / 1440,
          width: 320 / 1080,
          height: 58 / 1440,
          text: 'ROUND STORY',
          align: 'left',
          fontSize: 12,
          fontWeight: 700,
          color: '#FF2A4350',
          lineHeight: 1.1,
        ),
        _textLayer(
          id: 'title',
          x: 88 / 1080,
          y: 1132 / 1440,
          width: 330 / 1080,
          height: 112 / 1440,
          text: '둥글게\n모인 이야기',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 22,
          color: '#FF213744',
          lineHeight: 1.2,
        ),
        _textLayer(
          id: 'body',
          x: 88 / 1080,
          y: 1218 / 1440,
          width: 360 / 1080,
          height: 24 / 1440,
          text: '크게 웃던 순간을 모은 페이지',
          fontSize: 14,
          color: '#FF5A6B74',
        ),
      ],
    ),
    _page(
      pageNumber: 14,
      layoutId: 'banner_and_detail',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'wide_photo',
          x: 88 / 1080,
          y: 112 / 1440,
          width: 904 / 1080,
          height: 602 / 1440,
          imageUrl: city,
          frame: 'free',
        ),
        _textLayer(
          id: 'title',
          x: 124 / 1080,
          y: 814 / 1440,
          width: 420 / 1080,
          height: 39 / 1440,
          text: '길게 펼친 기억',
          fontSize: 18,
          fontWeight: 800,
          color: '#FF223845',
        ),
        _textLayer(
          id: 'body',
          x: 124 / 1080,
          y: 878 / 1440,
          width: 380 / 1080,
          height: 48 / 1440,
          text: '하루의 흐름을 한 장으로 묶는다.',
          fontSize: 13,
          color: '#FF5D7078',
        ),
      ],
    ),
    _page(
      pageNumber: 15,
      layoutId: 'ending_grid',
      role: 'ending',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'side_band',
          x: 88 / 1080,
          y: 772 / 1440,
          width: 260 / 1080,
          height: 176 / 1440,
          fill: '#FF4B6777',
        ),
        _textLayer(
          id: 'title',
          x: 124 / 1080,
          y: 804 / 1440,
          width: 140 / 1080,
          height: 144 / 1440,
          text: '한 번 더\n남겨 둘\n게',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 20,
          color: '#FFFFFFFF',
          lineHeight: 1.2,
        ),
        _imageLayer(
          id: 'wall_b',
          x: 548 / 1080,
          y: 132 / 1440,
          width: 444 / 1080,
          height: 240 / 1440,
          imageUrl: ceremony,
          frame: 'free',
        ),
        _imageLayer(
          id: 'wall_c',
          x: 548 / 1080,
          y: 412 / 1440,
          width: 444 / 1080,
          height: 240 / 1440,
          imageUrl: flowers,
          frame: 'free',
        ),
      ],
    ),
  ];
}

List<Map<String, dynamic>> _adaptPages({
  required List<Map<String, dynamic>> pages,
  required String ratioType,
}) {
  final cloned = jsonDecode(jsonEncode(pages)) as List<dynamic>;
  final next = cloned.cast<Map<String, dynamic>>();
  for (final page in next) {
    final role = page['role']?.toString() ?? '';
    final layers = (page['layers'] as List).cast<Map<String, dynamic>>();
    _applyGenericRatioAdaptation(layers: layers, ratioType: ratioType);
    if (ratioType == 'square' && role == 'cover') {
      for (final layer in layers) {
        if (_isFullBleedImage(layer)) {
          layer['x'] = 0.0;
          layer['y'] = 0.0;
          layer['width'] = 1.0;
          layer['height'] = 1.0;
          continue;
        }
        switch (layer['id']) {
          case 'cover_bottom_sheet':
            layer['y'] = 0.66;
            layer['height'] = 0.28;
            break;
          case 'sticker_a':
            layer['x'] = 0.10;
            layer['y'] = 0.69;
            break;
          case 'sticker_b':
            layer['x'] = 0.82;
            layer['y'] = 0.10;
            break;
          case 'chip_family':
            layer['x'] = 0.11;
            layer['y'] = 0.70;
            break;
          case 'chip_family_text':
            layer['x'] = 0.125;
            layer['y'] = 0.708;
            break;
          case 'title':
            layer['y'] = 0.73;
            break;
          case 'subtitle':
            layer['y'] = 0.84;
            break;
          case 'badge_card':
            layer['x'] = 0.70;
            layer['y'] = 0.74;
            break;
          case 'badge_text':
            layer['x'] = 0.74;
            layer['y'] = 0.77;
            break;
        }
      }
    }
    if (ratioType == 'landscape' && role == 'cover') {
      for (final layer in layers) {
        if (_isFullBleedImage(layer)) {
          layer['x'] = 0.0;
          layer['y'] = 0.0;
          layer['width'] = 1.0;
          layer['height'] = 1.0;
          continue;
        }
        switch (layer['id']) {
          case 'cover_bottom_sheet':
            layer['x'] = 0.0;
            layer['y'] = 0.62;
            layer['width'] = 1.0;
            layer['height'] = 0.38;
            break;
          case 'sticker_a':
            layer['x'] = 0.07;
            layer['y'] = 0.66;
            break;
          case 'sticker_b':
            layer['x'] = 0.86;
            layer['y'] = 0.12;
            break;
          case 'chip_family':
            layer['x'] = 0.08;
            layer['y'] = 0.68;
            break;
          case 'chip_family_text':
            layer['x'] = 0.096;
            layer['y'] = 0.689;
            break;
          case 'title':
            layer['x'] = 0.11;
            layer['y'] = 0.72;
            layer['payload']['textStyle']['fontSize'] = 38.0;
            break;
          case 'subtitle':
            layer['x'] = 0.11;
            layer['y'] = 0.86;
            layer['width'] = 0.30;
            break;
          case 'badge_card':
            layer['x'] = 0.73;
            layer['y'] = 0.70;
            break;
          case 'badge_text':
            layer['x'] = 0.77;
            layer['y'] = 0.75;
            break;
        }
      }
    }
  }
  return next;
}

Map<String, dynamic> _templateJson() {
  final portraitPages = _portraitPages();
  final squarePages = _adaptPages(pages: portraitPages, ratioType: 'square');
  final landscapePages = _adaptPages(
    pages: portraitPages,
    ratioType: 'landscape',
  );

  return {
    'schemaVersion': 1,
    'strictLayout': true,
    'autoFit': false,
    'autoFitPadding': 0.0,
    'aspect': 'portrait',
    'designWidth': 1080,
    'designHeight': 1440,
    'templateId': 'family_weekend_v1',
    'version': 2,
    'lifecycleStatus': 'published',
    'ratio': '9:16',
    'cover': {'pageNumber': 1, 'layers': portraitPages.first['layers']},
    'metadata': {
      'style': 'bright_family_scrapbook',
      'designWidth': 1080,
      'designHeight': 1440,
      'difficulty': 2,
      'recommendedPhotoCount': 6,
      'mood': 'warm_family_memory',
      'tags': ['가족', '주말', '포토북', '스크랩북'],
      'heroTextSafeArea': {'x': 0.10, 'y': 0.74, 'width': 0.80, 'height': 0.20},
      'sourceBottomSheetTemplateIds': ['family_weekend_v1'],
      'applyScope': 'cover_and_pages',
      'bottomSheetReferenceMode': 'style_and_tone_only',
      'templateType': 'family',
      'theme': 'weekend',
      'title': '가족의 주말',
      'category': 'family',
    },
    'pages': portraitPages,
    'variants': {
      'square': {
        'variantId': 'family_weekend_square',
        'aspect': 'square',
        'ratio': '1:1',
        'designWidth': 1440,
        'designHeight': 1440,
        'metadata': {'theme': 'weekend', 'templateType': 'family'},
        'pages': squarePages,
      },
      'landscape': {
        'variantId': 'family_weekend_landscape',
        'aspect': 'landscape',
        'ratio': '16:9',
        'designWidth': 1440,
        'designHeight': 1080,
        'metadata': {'theme': 'weekend', 'templateType': 'family'},
        'pages': landscapePages,
      },
    },
  };
}

Map<String, dynamic> _storeEntry() {
  final templateJson = _templateJson();
  final previews = <String>[
    _asset('city_weekend.png'),
    _asset('ceremony_moment.png'),
    _asset('hands_bw.png'),
    _asset('flower_table.png'),
    _asset('beach_glow.png'),
    _asset('sunset_pair.png'),
  ];

  return {
    'id': 48,
    'title': '가족의 주말',
    'subTitle': '가족 앨범 · bright scrapbook',
    'description': '함께 보낸 주말의 장면을 밝고 다정한 스크랩북 무드로 담아내는 가족 포토북 템플릿',
    'coverImageUrl': previews.first,
    'previewImages': previews,
    'pageCount': 15,
    'likeCount': 0,
    'userCount': 0,
    'category': '가족',
    'tags': ['가족', '주말', '포토북', '스크랩북'],
    'weeklyScore': 0,
    'isNew': true,
    'isBest': false,
    'isPremium': false,
    'isLiked': false,
    'templateId': 'family_weekend_v1',
    'version': 'v1',
    'lifecycleStatus': 'published',
    'templateJson': jsonEncode(templateJson),
  };
}

Future<void> main() async {
  final handoff = {
    'templateId': 'family_weekend_v1',
    'templateSlug': 'family_weekend',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'template': _storeEntry(),
  };
  final storeEntry = _storeEntry();

  await File(
    _handoffPath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(handoff));
  await File(
    _storePath,
  ).writeAsString(const JsonEncoder.withIndent('  ').convert([storeEntry]));

  stdout.writeln('Generated family_weekend template');
  stdout.writeln('handoff=$_handoffPath');
  stdout.writeln('store=$_storePath');
  stdout.writeln(
    'next=./scripts/template_asset_pipeline.sh --template-slug=family_weekend '
    '--template-store-json=$_storePath',
  );
}
