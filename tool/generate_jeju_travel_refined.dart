import 'dart:convert';
import 'dart:io';

const _assetDir = 'assets/templates/jeju_travel/images/sources';
const _handoffPath = 'assets/templates/jeju_travel_handoff.json';
const _storePath = 'assets/templates/generated/jeju_travel_store.json';

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
  final aerial = _asset('jeju_aerial.jpg');
  final ocean = _asset('jeju_ocean.jpg');
  final rocky = _asset('jeju_rocky_coast.jpg');
  final seongsan = _asset('jeju_seongsan.jpg');
  final sunset = _asset('jeju_sunset.jpg');

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
          imageUrl: aerial,
          zIndex: 5,
        ),
        _decoLayer(
          id: 'journal_card',
          x: 0.0685,
          y: 0.5861,
          width: 0.8630,
          height: 0.3167,
          fill: '#E0264552',
          radius: 0.032,
          zIndex: 20,
        ),
        _decoLayer(
          id: 'ticket_stub',
          x: 0.7444,
          y: 0.6347,
          width: 0.1521,
          height: 0.1623,
          fill: '#F7E5BC',
          radius: 0.02,
          rotation: -8,
          zIndex: 22,
        ),
        _textLayer(
          id: 'title',
          x: 0.0870,
          y: 0.6222,
          width: 0.5741,
          height: 0.1333,
          text: '제주의\n기록',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 58,
          color: '#FFFFFFFF',
          lineHeight: 1.0,
          zIndex: 30,
        ),
        _textLayer(
          id: 'subtitle',
          x: 0.0870,
          y: 0.8028,
          width: 0.6722,
          height: 0.0292,
          text: '바람, 바다, 풍경이 남긴 여행의 장면들',
          fontSize: 14,
          color: '#FFF8FAFC',
          zIndex: 30,
        ),
        _textLayer(
          id: 'meta',
          x: 0.0870,
          y: 0.8528,
          width: 0.3148,
          height: 0.0181,
          text: 'APRIL 2026',
          align: 'left',
          fontFamily: 'NotoSansKR',
          fontWeight: 800,
          fontSize: 10,
          color: '#FFF7EAD6',
          letterSpacing: 1.2,
          zIndex: 30,
        ),
        _textLayer(
          id: 'ticket_text',
          x: 0.7685,
          y: 0.6681,
          width: 0.0833,
          height: 0.0833,
          text: 'JE\nJU',
          align: 'center',
          fontFamily: 'NotoSansKR',
          fontWeight: 700,
          fontSize: 14,
          color: '#FF21404F',
          lineHeight: 1.15,
          zIndex: 30,
        ),
        _decoLayer(
          id: 'seal',
          x: 0.8241,
          y: 0.8250,
          width: 0.0685,
          height: 0.0514,
          fill: '#FFEC9B59',
          radius: 0.04,
          zIndex: 24,
        ),
      ],
    ),
    _page(
      pageNumber: 2,
      layoutId: 'opening_editorial',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _textLayer(
          id: 'kicker',
          x: 0.0963,
          y: 0.0681,
          width: 0.2037,
          height: 0.0139,
          text: 'NOTE',
          fontSize: 10,
          fontWeight: 700,
          letterSpacing: 1.2,
          color: '#FF203B47',
        ),
        _decoLayer(
          id: 'memo_card',
          x: 0.0815,
          y: 0.1181,
          width: 0.3981,
          height: 0.3611,
          fill: '#FF21404F',
          radius: 0.03,
        ),
        _textLayer(
          id: 'title',
          x: 0.1130,
          y: 0.1639,
          width: 0.3130,
          height: 0.1361,
          text: '남쪽의\n빛을 따라',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 34,
          color: '#FFFFFFFF',
          lineHeight: 1.2,
        ),
        _textLayer(
          id: 'body',
          x: 0.1130,
          y: 0.3458,
          width: 0.3037,
          height: 0.0861,
          text: '제주에 닿는 순간,\n가장 먼저 만나게 되는 빛과 공기의\n온도를 모았다.',
          fontSize: 13,
          color: '#FFE5EEF3',
          lineHeight: 1.35,
        ),
        _imageLayer(
          id: 'photo_portrait',
          x: 0.5315,
          y: 0.0833,
          width: 0.3741,
          height: 0.3889,
          imageUrl: seongsan,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_landscape',
          x: 0.5315,
          y: 0.5111,
          width: 0.3741,
          height: 0.2111,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _decoLayer(
          id: 'caption_strip',
          x: 0.0815,
          y: 0.5347,
          width: 0.3981,
          height: 0.1389,
          fill: '#FFF8F2E8',
          radius: 0.02,
        ),
        _textLayer(
          id: 'footer',
          x: 0.1130,
          y: 0.5722,
          width: 0.3130,
          height: 0.0750,
          text: '바람과 파도가 닿는 리듬을 천천히 읽어 내려간다.',
          fontSize: 13,
          color: '#FF3B5563',
          lineHeight: 1.35,
        ),
        _decoLayer(
          id: 'tape_top',
          x: 0.5778,
          y: 0.0708,
          width: 0.0797,
          height: 0.0222,
          fill: '#E7D6B7',
          radius: 0.01,
          rotation: -6,
          zIndex: 15,
        ),
      ],
    ),
    _page(
      pageNumber: 3,
      layoutId: 'map_and_title',
      role: 'photo',
      recommendedPhotoCount: 4,
      layers: [
        _imageLayer(
          id: 'photo_main',
          x: 0.0648,
          y: 0.0486,
          width: 0.6293,
          height: 0.6126,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_small_top',
          x: 0.7093,
          y: 0.0569,
          width: 0.2296,
          height: 0.1778,
          imageUrl: aerial,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_small_mid',
          x: 0.6833,
          y: 0.2597,
          width: 0.2703,
          height: 0.2264,
          imageUrl: rocky,
          frame: 'paperTapeCard',
          rotation: -2,
        ),
        _decoLayer(
          id: 'caption_card',
          x: 0.0852,
          y: 0.6750,
          width: 0.8296,
          height: 0.1653,
          fill: '#FFF7F2E9',
          radius: 0.03,
          zIndex: 20,
        ),
        _textLayer(
          id: 'title',
          x: 0.1148,
          y: 0.7069,
          width: 0.4167,
          height: 0.0514,
          text: '해안에서\n시작한 하루',
          fontFamily: 'NotoSerifKR',
          fontWeight: 800,
          fontSize: 24,
          color: '#FF223845',
          lineHeight: 1.15,
        ),
        _textLayer(
          id: 'body',
          x: 0.5241,
          y: 0.7153,
          width: 0.3333,
          height: 0.0778,
          text: '빛과 그림자가 바뀔 때마다,\n같은 풍경도 전혀 다른 장면으로 남는다.',
          fontSize: 13,
          color: '#FF4B5F6A',
          lineHeight: 1.35,
        ),
        _imageLayer(
          id: 'photo_small_bottom',
          x: 0.7241,
          y: 0.5000,
          width: 0.1985,
          height: 0.1355,
          imageUrl: seongsan,
          frame: 'rounded28',
        ),
      ],
    ),
    _page(
      pageNumber: 4,
      layoutId: 'coastal_frame',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _decoLayer(
          id: 'frame_outer',
          x: 0.0704,
          y: 0.0806,
          width: 0.8593,
          height: 0.8389,
          fill: '#FF274350',
          radius: 0.02,
        ),
        _imageLayer(
          id: 'frame_inner',
          x: 0.1074,
          y: 0.1083,
          width: 0.7852,
          height: 0.5694,
          imageUrl: rocky,
          frame: 'free',
          zIndex: 12,
        ),
        _decoLayer(
          id: 'caption_panel',
          x: 0.1074,
          y: 0.7083,
          width: 0.7852,
          height: 0.1833,
          fill: '#FFFFFFFF',
          radius: 0.015,
          zIndex: 20,
        ),
        _textLayer(
          id: 'title',
          x: 0.1352,
          y: 0.7347,
          width: 0.5185,
          height: 0.05,
          text: '해안 프레임',
          fontWeight: 800,
          fontSize: 18,
          color: '#FF213744',
        ),
        _textLayer(
          id: 'body',
          x: 0.1352,
          y: 0.8000,
          width: 0.6481,
          height: 0.0639,
          text: '물빛과 바위의 질감을 크게 담는다.',
          fontSize: 11,
          color: '#FF5A6B74',
        ),
        _textLayer(
          id: 'note',
          x: 0.1352,
          y: 0.8694,
          width: 0.2037,
          height: 0.0153,
          text: '제주 남쪽 해안',
          fontSize: 10,
          color: '#FF6E7F88',
        ),
      ],
    ),
    _page(
      pageNumber: 5,
      layoutId: 'day_plan_timeline',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'photo_top',
          x: 0.0833,
          y: 0.0625,
          width: 0.8333,
          height: 0.2986,
          imageUrl: aerial,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_left',
          x: 0.0833,
          y: 0.3972,
          width: 0.3981,
          height: 0.4236,
          imageUrl: seongsan,
          frame: 'paperTapeCard',
          rotation: -2,
        ),
        _imageLayer(
          id: 'photo_right',
          x: 0.5185,
          y: 0.3972,
          width: 0.3981,
          height: 0.4236,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _decoLayer(
          id: 'note_strip',
          x: 0.0833,
          y: 0.8458,
          width: 0.5556,
          height: 0.0639,
          fill: '#FFF8F2E8',
          radius: 0.02,
        ),
        _textLayer(
          id: 'title',
          x: 0.1167,
          y: 0.8653,
          width: 0.2222,
          height: 0.0194,
          text: '가장 좋았던 장면',
          fontSize: 13,
          fontWeight: 800,
          color: '#FF244050',
        ),
        _textLayer(
          id: 'meta',
          x: 0.1167,
          y: 0.8861,
          width: 0.4444,
          height: 0.0139,
          text: '하루의 리듬을 사진 세 장으로 남긴다',
          fontSize: 10,
          color: '#FF6A7B84',
        ),
      ],
    ),
    _page(
      pageNumber: 6,
      layoutId: 'postcard_grid',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _textLayer(
          id: 'title',
          x: 0.0833,
          y: 0.0597,
          width: 0.2778,
          height: 0.025,
          text: '포스트카드처럼',
          fontSize: 18,
          fontWeight: 800,
          color: '#FF1E3440',
        ),
        _imageLayer(
          id: 'photo_a',
          x: 0.0852,
          y: 0.1042,
          width: 0.4055,
          height: 0.3711,
          imageUrl: sunset,
          frame: 'polaroidClassic',
          rotation: -4,
        ),
        _imageLayer(
          id: 'photo_b',
          x: 0.5407,
          y: 0.1139,
          width: 0.2593,
          height: 0.1458,
          imageUrl: rocky,
          frame: 'polaroidClassic',
          rotation: 2,
        ),
        _imageLayer(
          id: 'photo_c',
          x: 0.6370,
          y: 0.2889,
          width: 0.2241,
          height: 0.2326,
          imageUrl: ocean,
          frame: 'polaroidClassic',
          rotation: 5,
        ),
        _decoLayer(
          id: 'caption_card',
          x: 0.0852,
          y: 0.5847,
          width: 0.8333,
          height: 0.2028,
          fill: '#FFF7F2E9',
          radius: 0.03,
          zIndex: 20,
        ),
        _textLayer(
          id: 'caption',
          x: 0.1185,
          y: 0.625,
          width: 0.4667,
          height: 0.0875,
          text: '바다, 돌담, 노을이 번갈아 지나간 하루',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 21,
          color: '#FF1E3440',
        ),
        _textLayer(
          id: 'meta',
          x: 0.1185,
          y: 0.7278,
          width: 0.1481,
          height: 0.0139,
          text: 'POSTCARD',
          fontSize: 10,
          fontWeight: 800,
          color: '#FF7A654E',
          letterSpacing: 1.0,
        ),
        _decoLayer(
          id: 'stamp',
          x: 0.8315,
          y: 0.0833,
          width: 0.0667,
          height: 0.05,
          fill: '#FFEC9B59',
          radius: 0.05,
          zIndex: 24,
        ),
      ],
    ),
    _page(
      pageNumber: 7,
      layoutId: 'quote_break',
      role: 'text',
      recommendedPhotoCount: 0,
      layers: [
        _decoLayer(
          id: 'p06_bg',
          x: 0.16,
          y: 0.12,
          width: 0.68,
          height: 0.70,
          fill: '#FFF8F3EA',
          radius: 0.50,
          zIndex: 5,
        ),
        _decoLayer(
          id: 'p06_line_top',
          x: 0.38,
          y: 0.12,
          width: 0.24,
          height: 0.008,
          fill: '#FF25404E',
          radius: 0.01,
          zIndex: 6,
        ),
        _decoLayer(
          id: 'p06_line_bottom',
          x: 0.38,
          y: 0.82,
          width: 0.24,
          height: 0.008,
          fill: '#FF25404E',
          radius: 0.01,
          zIndex: 6,
        ),
        _textLayer(
          id: 'p06_quote',
          x: 0.24,
          y: 0.34,
          width: 0.52,
          height: 0.18,
          text: '제주는\n천천히 움직일수록\n더 많이 보이는 곳이다.',
          align: 'center',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 28,
          color: '#FF233844',
          lineHeight: 1.35,
        ),
      ],
    ),
    _page(
      pageNumber: 8,
      layoutId: 'spotlight_place',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _imageLayer(
          id: 'photo_main',
          x: 0.0815,
          y: 0.0611,
          width: 0.8370,
          height: 0.5972,
          imageUrl: seongsan,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_small',
          x: 0.6444,
          y: 0.6903,
          width: 0.2222,
          height: 0.1458,
          imageUrl: aerial,
          frame: 'paperTapeCard',
          rotation: 4,
        ),
        _decoLayer(
          id: 'caption_card',
          x: 0.0815,
          y: 0.6944,
          width: 0.5185,
          height: 0.1694,
          fill: '#FFF7F2E9',
          radius: 0.03,
        ),
        _textLayer(
          id: 'title',
          x: 0.1130,
          y: 0.7236,
          width: 0.2778,
          height: 0.0347,
          text: '한 장 크게,\n오래 남길 풍경',
          fontSize: 18,
          fontWeight: 800,
          color: '#FF233844',
          lineHeight: 1.2,
        ),
        _textLayer(
          id: 'body',
          x: 0.1130,
          y: 0.7833,
          width: 0.3889,
          height: 0.0569,
          text: '멀리 보이는 수평선과 가까운 바람의 결을 한 장에 담는다.',
          fontSize: 12,
          color: '#FF5D7078',
          lineHeight: 1.35,
        ),
        _decoLayer(
          id: 'tape',
          x: 0.7463,
          y: 0.0750,
          width: 0.1093,
          height: 0.0264,
          fill: '#E7D6B7',
          radius: 0.01,
          rotation: -6,
          zIndex: 18,
        ),
      ],
    ),
    _page(
      pageNumber: 9,
      layoutId: 'photo_strip',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'canvas_panel',
          x: 0.0815,
          y: 0.1111,
          width: 0.8370,
          height: 0.7917,
          fill: '#FFF5EFE5',
          radius: 0.02,
        ),
        _textLayer(
          id: 'title',
          x: 0.0815,
          y: 0.0625,
          width: 0.2963,
          height: 0.0292,
          text: '장면의 띠',
          fontSize: 20,
          fontWeight: 800,
          color: '#FF223845',
        ),
        _imageLayer(
          id: 'strip_a',
          x: 0.1259,
          y: 0.1681,
          width: 0.7537,
          height: 0.1444,
          imageUrl: rocky,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'strip_b',
          x: 0.1259,
          y: 0.3361,
          width: 0.7537,
          height: 0.1444,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'strip_c',
          x: 0.1259,
          y: 0.5042,
          width: 0.7519,
          height: 0.1347,
          imageUrl: sunset,
          frame: 'rounded28',
        ),
        _decoLayer(
          id: 'marker_a',
          x: 0.0852,
          y: 0.2083,
          width: 0.0259,
          height: 0.0194,
          fill: '#FFEC9B59',
          radius: 0.5,
        ),
        _decoLayer(
          id: 'marker_b',
          x: 0.8889,
          y: 0.3792,
          width: 0.0259,
          height: 0.0194,
          fill: '#FFEC9B59',
          radius: 0.5,
        ),
        _decoLayer(
          id: 'marker_c',
          x: 0.0852,
          y: 0.5514,
          width: 0.0259,
          height: 0.0194,
          fill: '#FFEC9B59',
          radius: 0.5,
        ),
        _textLayer(
          id: 'footer',
          x: 0.1259,
          y: 0.7014,
          width: 0.6204,
          height: 0.0833,
          text: '서로 다른 길이의 사진을 이어 붙이면\n하루의 리듬이 드러난다.',
          fontSize: 12,
          color: '#FF465A64',
          lineHeight: 1.35,
        ),
      ],
    ),
    _page(
      pageNumber: 10,
      layoutId: 'food_and_cafe',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _imageLayer(
          id: 'photo_main',
          x: 0.0815,
          y: 0.0611,
          width: 0.5741,
          height: 0.5278,
          imageUrl: sunset,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_small_top',
          x: 0.6926,
          y: 0.0611,
          width: 0.2259,
          height: 0.1528,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_small_bottom',
          x: 0.6926,
          y: 0.2389,
          width: 0.2259,
          height: 0.1278,
          imageUrl: aerial,
          frame: 'paperTapeCard',
          rotation: -3,
        ),
        _decoLayer(
          id: 'caption_note',
          x: 0.0815,
          y: 0.6292,
          width: 0.5741,
          height: 0.1431,
          fill: '#FFF7F2E9',
          radius: 0.03,
        ),
        _textLayer(
          id: 'title',
          x: 0.1093,
          y: 0.6597,
          width: 0.2407,
          height: 0.0333,
          text: '음식과 카페의 장면',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 20,
          color: '#FF1F3440',
        ),
        _textLayer(
          id: 'body',
          x: 0.1093,
          y: 0.6986,
          width: 0.4907,
          height: 0.0542,
          text: '따뜻한 컵과 디저트, 잠시 쉬어 가는 테이블의 온도를 기록한다.',
          fontSize: 12,
          color: '#FF53666E',
          lineHeight: 1.35,
        ),
        _textLayer(
          id: 'tag',
          x: 0.1093,
          y: 0.7556,
          width: 0.1481,
          height: 0.0125,
          text: 'CAFE NOTE',
          fontSize: 10,
          fontWeight: 800,
          color: '#FF775F45',
          letterSpacing: 0.8,
        ),
      ],
    ),
    _page(
      pageNumber: 11,
      layoutId: 'detail_memory',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'photo_large',
          x: 0.0833,
          y: 0.0625,
          width: 0.8333,
          height: 0.3611,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _decoLayer(
          id: 'note_left',
          x: 0.0833,
          y: 0.4681,
          width: 0.2778,
          height: 0.25,
          fill: '#FFFFFFFF',
          radius: 0.02,
          rotation: -2,
          zIndex: 20,
        ),
        _textLayer(
          id: 'title',
          x: 0.1148,
          y: 0.5030,
          width: 0.1389,
          height: 0.0472,
          text: '기억\n메모',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 18,
          color: '#FF223845',
          lineHeight: 1.2,
          zIndex: 21,
        ),
        _decoLayer(
          id: 'note_right',
          x: 0.3981,
          y: 0.4681,
          width: 0.5185,
          height: 0.25,
          fill: '#FF244050',
          radius: 0.025,
          zIndex: 20,
        ),
        _textLayer(
          id: 'body_left',
          x: 0.1148,
          y: 0.5743,
          width: 0.1852,
          height: 0.0833,
          text: '천천히 걷고\n오래 바라본 장면',
          fontSize: 12,
          color: '#FF53666E',
          lineHeight: 1.35,
          zIndex: 21,
        ),
        _textLayer(
          id: 'body_right',
          x: 0.4333,
          y: 0.5181,
          width: 0.3889,
          height: 0.0917,
          text: '파도 소리가 크게 들리던 오후 5시,\n빛이 가장 부드럽게 눕던 순간을 적어 둔다.',
          fontSize: 11,
          color: '#FFFFFFFF',
          lineHeight: 1.3,
          zIndex: 21,
        ),
        _decoLayer(
          id: 'ticket_piece',
          x: 0.7278,
          y: 0.4347,
          width: 0.1280,
          height: 0.1267,
          fill: '#E7D6B7',
          radius: 0.02,
          rotation: -4,
          zIndex: 19,
        ),
      ],
    ),
    _page(
      pageNumber: 12,
      layoutId: 'sunset_poster',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'sunset_block',
          x: 0.0833,
          y: 0.0625,
          width: 0.8333,
          height: 0.8750,
          imageUrl: sunset,
          frame: 'kraftPaper',
        ),
        _textLayer(
          id: 'title',
          x: 0.1315,
          y: 0.1236,
          width: 0.5741,
          height: 0.1250,
          text: '노을의\n포스터',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 34,
          color: '#FFFFFFFF',
          lineHeight: 1.05,
          zIndex: 30,
        ),
        _textLayer(
          id: 'subtitle',
          x: 0.1315,
          y: 0.7361,
          width: 0.4815,
          height: 0.0764,
          text: '마지막 빛이 가장 오래 머무는 순간,\n제주의 하루를 포스터처럼 남긴다.',
          fontSize: 14,
          color: '#FFF7EEE0',
          lineHeight: 1.35,
          zIndex: 30,
        ),
      ],
    ),
    _page(
      pageNumber: 13,
      layoutId: 'memory_board',
      role: 'photo',
      recommendedPhotoCount: 6,
      layers: [
        _decoLayer(
          id: 'left_band',
          x: 0.0815,
          y: 0.0611,
          width: 0.2037,
          height: 0.8778,
          fill: '#FF244050',
          radius: 0.02,
        ),
        _textLayer(
          id: 'title',
          x: 0.1037,
          y: 0.0875,
          width: 0.1241,
          height: 0.0681,
          text: '기억의\n페이지',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 22,
          color: '#FFFFFFFF',
          lineHeight: 1.2,
        ),
        _textLayer(
          id: 'body',
          x: 0.1037,
          y: 0.1986,
          width: 0.1389,
          height: 0.1528,
          text: '짧은 문장과\n여섯 장의 사진으로\n여행의 감도를 모은다.',
          fontSize: 12,
          color: '#FFE5EEF3',
          lineHeight: 1.35,
        ),
        _imageLayer(
          id: 'photo_a',
          x: 0.3370,
          y: 0.0611,
          width: 0.2556,
          height: 0.1597,
          imageUrl: aerial,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_b',
          x: 0.6241,
          y: 0.0611,
          width: 0.2556,
          height: 0.1278,
          imageUrl: rocky,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_c',
          x: 0.3370,
          y: 0.2472,
          width: 0.2556,
          height: 0.1528,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_d',
          x: 0.6241,
          y: 0.2167,
          width: 0.2556,
          height: 0.1528,
          imageUrl: sunset,
          frame: 'paperTapeCard',
          rotation: 3,
        ),
        _imageLayer(
          id: 'photo_e',
          x: 0.3370,
          y: 0.4264,
          width: 0.2556,
          height: 0.1528,
          imageUrl: seongsan,
          frame: 'rounded28',
        ),
        _imageLayer(
          id: 'photo_f',
          x: 0.6241,
          y: 0.3958,
          width: 0.2556,
          height: 0.1833,
          imageUrl: ocean,
          frame: 'rounded28',
        ),
        _decoLayer(
          id: 'seal',
          x: 0.8204,
          y: 0.0708,
          width: 0.0556,
          height: 0.0417,
          fill: '#FFEC9B59',
          radius: 0.05,
          zIndex: 20,
        ),
        _textLayer(
          id: 'badge_text',
          x: 0.8343,
          y: 0.0854,
          width: 0.0278,
          height: 0.0125,
          text: 'JEJU',
          fontSize: 8,
          fontWeight: 800,
          color: '#FF26424F',
          zIndex: 21,
        ),
      ],
    ),
    _page(
      pageNumber: 14,
      layoutId: 'ending_full_bleed',
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
        _decoLayer(
          id: 'bottom_caption',
          x: 0.0667,
          y: 0.7569,
          width: 0.8667,
          height: 0.1736,
          fill: '#DD244050',
          radius: 0.03,
          zIndex: 20,
        ),
        _textLayer(
          id: 'title',
          x: 0.1093,
          y: 0.7944,
          width: 0.3056,
          height: 0.0639,
          text: '다시,\n제주로.',
          fontFamily: 'Eulyoo',
          fontWeight: 800,
          fontSize: 26,
          color: '#FFFFFFFF',
          lineHeight: 1.0,
          zIndex: 30,
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
        if (layer['id'] == 'cover_title_block') {
          layer['y'] = 0.68;
        } else if (layer['id'] == 'cover_title') {
          layer['y'] = 0.71;
        } else if (layer['id'] == 'cover_sub') {
          layer['y'] = 0.81;
        } else if (layer['id'] == 'cover_ticket') {
          layer['y'] = 0.70;
        } else if (layer['id'] == 'cover_tag') {
          layer['y'] = 0.725;
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
        if (layer['id'] == 'cover_title_block') {
          layer['x'] = 0.08;
          layer['y'] = 0.60;
          layer['width'] = 0.38;
          layer['height'] = 0.22;
        } else if (layer['id'] == 'cover_title') {
          layer['x'] = 0.11;
          layer['y'] = 0.64;
          layer['width'] = 0.30;
          layer['payload']['textStyle']['fontSize'] = 42.0;
        } else if (layer['id'] == 'cover_sub') {
          layer['x'] = 0.11;
          layer['y'] = 0.78;
          layer['width'] = 0.34;
        } else if (layer['id'] == 'cover_ticket') {
          layer['x'] = 0.52;
          layer['y'] = 0.63;
        } else if (layer['id'] == 'cover_tag') {
          layer['x'] = 0.55;
          layer['y'] = 0.655;
        }
      }
    }

    if (ratioType == 'landscape' && role == 'photo') {
      for (final layer in layers) {
        final id = (layer['id'] ?? '').toString();
        if (id.contains('caption') ||
            id.contains('title') ||
            id.contains('body')) {
          final y = (layer['y'] as num).toDouble();
          layer['y'] = y.clamp(0.08, 0.78);
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
    'templateId': 'jeju_travel_v1',
    'version': 2,
    'lifecycleStatus': 'published',
    'ratio': '9:16',
    'cover': {'pageNumber': 1, 'layers': portraitPages.first['layers']},
    'metadata': {
      'style': 'jeju_photo_journal',
      'designWidth': 1080,
      'designHeight': 1440,
      'difficulty': 2,
      'recommendedPhotoCount': 5,
      'mood': 'travel_editorial_warm',
      'tags': ['여행', '제주도', '포토북', '에디토리얼'],
      'heroTextSafeArea': {'x': 0.08, 'y': 0.60, 'width': 0.84, 'height': 0.26},
      'sourceBottomSheetTemplateIds': ['jeju_travel_v1'],
      'applyScope': 'cover_and_pages',
      'bottomSheetReferenceMode': 'style_and_tone_only',
      'templateType': 'travel',
      'theme': 'jeju',
      'title': '제주의 기록',
      'category': 'travel',
    },
    'pages': portraitPages,
    'variants': {
      'square': {
        'variantId': 'jeju_travel_square',
        'aspect': 'square',
        'ratio': '1:1',
        'designWidth': 1440,
        'designHeight': 1440,
        'metadata': {'theme': 'jeju', 'templateType': 'travel'},
        'pages': squarePages,
      },
      'landscape': {
        'variantId': 'jeju_travel_landscape',
        'aspect': 'landscape',
        'ratio': '16:9',
        'designWidth': 1440,
        'designHeight': 1080,
        'metadata': {'theme': 'jeju', 'templateType': 'travel'},
        'pages': landscapePages,
      },
    },
  };
}

Map<String, dynamic> _storeEntry() {
  final templateJson = _templateJson();
  final previews = <String>[
    _asset('jeju_aerial.jpg'),
    _asset('jeju_seongsan.jpg'),
    _asset('jeju_ocean.jpg'),
    _asset('jeju_rocky_coast.jpg'),
    _asset('jeju_sunset.jpg'),
    _asset('jeju_aerial.jpg'),
    _asset('jeju_ocean.jpg'),
    _asset('jeju_sunset.jpg'),
  ];

  return {
    'id': 46,
    'title': '제주의 기록',
    'subTitle': '제주 여행 앨범 · editorial',
    'description': '제주의 바다와 풍경을 사진 중심으로 담는 여행 앨범 템플릿',
    'coverImageUrl': previews.first,
    'previewImages': previews,
    'pageCount': 14,
    'likeCount': 0,
    'userCount': 0,
    'category': '여행',
    'tags': ['여행', '제주도', '포토북', '에디토리얼'],
    'weeklyScore': 0,
    'isNew': true,
    'isBest': false,
    'isPremium': false,
    'isLiked': false,
    'templateId': 'jeju_travel_v1',
    'version': 'v1',
    'lifecycleStatus': 'published',
    'templateJson': jsonEncode(templateJson),
  };
}

Future<void> main() async {
  final handoff = {
    'templateId': 'jeju_travel_v1',
    'templateSlug': 'jeju_travel',
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

  stdout.writeln('Generated jeju_travel template');
  stdout.writeln('handoff=$_handoffPath');
  stdout.writeln('store=$_storePath');
  stdout.writeln(
    'next=./scripts/template_asset_pipeline.sh --template-slug=jeju_travel '
    '--template-store-json=$_storePath',
  );
}
