import 'dart:convert';
import 'dart:io';

const _assetDir = 'assets/templates/anniversary_days/images/sources';
const _handoffPath = 'assets/templates/anniversary_days_handoff.json';
const _storePath = 'assets/templates/generated/anniversary_days_store.json';
const _creamBg = '#FFFAF4EE';
const _paperBg = '#FFFFFDF8';
const _lavender = '#FFC7BFEF';
const _roseBrown = '#FF7A4E56';
const _bodyBrown = '#FF8B7278';

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
}) => {
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

Map<String, dynamic> _textLayer({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  required String text,
  String align = 'left',
  String fontFamily = 'NotoSans',
  int fontWeight = 500,
  double fontSize = 18,
  String color = '#FF1F2937',
  double letterSpacing = 0,
  double lineHeight = 1.28,
  int zIndex = 30,
  double rotation = 0,
}) => {
  'id': id,
  'type': 'TEXT',
  'zIndex': zIndex,
  'x': x,
  'y': y,
  'width': width,
  'height': height,
  'scale': 1.0,
  'rotation': rotation,
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
      'height': lineHeight,
      'lineHeight': lineHeight,
    },
  },
};

Map<String, dynamic> _serifTitle({
  required String id,
  required double x,
  required double y,
  required double width,
  required double height,
  required String text,
  String align = 'left',
  double fontSize = 24,
  int fontWeight = 700,
  String color = _lavender,
  double lineHeight = 1.1,
  double letterSpacing = -0.2,
  int zIndex = 30,
}) => _textLayer(
  id: id,
  x: x,
  y: y,
  width: width,
  height: height,
  text: text,
  align: align,
  fontFamily: 'Cormorant',
  fontWeight: fontWeight,
  fontSize: fontSize,
  color: color,
  lineHeight: lineHeight,
  letterSpacing: letterSpacing,
  zIndex: zIndex,
);

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
}) => {
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

Map<String, dynamic> _page({
  required int pageNumber,
  required String layoutId,
  required String role,
  required int recommendedPhotoCount,
  required List<Map<String, dynamic>> layers,
}) => {
  'pageNumber': pageNumber,
  'layoutId': layoutId,
  'role': _normalizeRole(role),
  'recommendedPhotoCount': recommendedPhotoCount,
  'layers': layers,
};

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
  final sample = _asset('anniversary_sample.png');
  final pages = [
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
          imageUrl: sample,
          zIndex: 5,
        ),
        _serifTitle(
          id: 'title',
          x: 0.1889,
          y: 0.3292,
          width: 0.6222,
          height: 0.1069,
          text: 'We are Getting\nMarried',
          align: 'center',
          fontSize: 88,
          fontWeight: 800,
          color: '#FFF3EFFD',
          lineHeight: 0.86,
          letterSpacing: -0.88,
        ),
        _textLayer(
          id: 'subtitle',
          x: 0.2778,
          y: 0.4514,
          width: 0.4444,
          height: 0.0240,
          text: 'OUR SPECIAL DAY TO REMEMBER',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 16,
          color: '#FFFFFDF8',
          letterSpacing: 1.28,
          lineHeight: 1.25,
        ),
      ],
    ),
    _page(
      pageNumber: 2,
      layoutId: 'memory_collage',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: _paperBg,
          zIndex: 1,
        ),
        _decoLayer(
          id: 'photo_a_backer_soft',
          x: 0.0926,
          y: 0.1736,
          width: 0.3833,
          height: 0.3889,
          fill: '#FFFFFFFF',
          border: '#FFEEE8F1',
          borderWidth: 0.00185,
          zIndex: 6,
        ),
        _imageLayer(
          id: 'photo_a',
          x: 0.0556,
          y: 0.3403,
          width: 0.5463,
          height: 0.5431,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'photo_b',
          x: 0.6111,
          y: 0.0847,
          width: 0.3333,
          height: 0.3569,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'photo_c',
          x: 0.6111,
          y: 0.4632,
          width: 0.3333,
          height: 0.2722,
          imageUrl: sample,
          frame: 'free',
        ),
        _serifTitle(
          id: 'title',
          x: 0.0556,
          y: 0.0000,
          width: 0.5463,
          height: 0.3403,
          text: 'Our\nAnniversary\nDay',
          fontSize: 118,
          fontWeight: 400,
          color: _lavender,
          lineHeight: 0.46,
        ),
        _textLayer(
          id: 'caption',
          x: 0.6111,
          y: 0.7590,
          width: 0.3333,
          height: 0.2410,
          text: 'Our\n\nAnniversary\n\nDay',
          fontFamily: 'Cormorant',
          fontWeight: 400,
          fontSize: 58,
          color: _lavender,
          lineHeight: 0.72,
        ),
      ],
    ),
    _page(
      pageNumber: 3,
      layoutId: 'note_and_photo',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: _creamBg,
          zIndex: 1,
        ),
        _imageLayer(
          id: 'photo_main',
          x: 0.0556,
          y: 0.0417,
          width: 0.4444,
          height: 0.4583,
          imageUrl: sample,
          frame: 'free',
        ),
        _serifTitle(
          id: 'title',
          x: 0.1222,
          y: 0.0722,
          width: 0.1519,
          height: 0.0292,
          text: 'Mijin',
          fontSize: 34,
          fontWeight: 400,
          color: '#FFFFFFFF',
        ),
        _textLayer(
          id: 'body',
          x: 0.5278,
          y: 0.0417,
          width: 0.4166,
          height: 0.4361,
          text: 'brick light\nquiet smile',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 20,
          color: _lavender,
          lineHeight: 0.9,
          align: 'center',
        ),
        _textLayer(
          id: 'note_text',
          x: 0.0556,
          y: 0.7681,
          width: 0.4166,
          height: 0.1528,
          text: '오늘의 온도와 네 표정을\n한 장의 기록으로 남겨 둘게.',
          fontFamily: 'BookMyungjo',
          fontWeight: 400,
          fontSize: 20,
          color: _lavender,
          lineHeight: 1.1,
          align: 'center',
        ),
        _imageLayer(
          id: 'photo_small',
          x: 0.5000,
          y: 0.4951,
          width: 0.4444,
          height: 0.4785,
          imageUrl: sample,
          frame: 'free',
        ),
      ],
    ),
    _page(
      pageNumber: 4,
      layoutId: 'circle_story',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: _paperBg,
          zIndex: 1,
        ),
        _imageLayer(
          id: 'heart_story_main_photo',
          x: 0.1639,
          y: 0.2472,
          width: 0.6741,
          height: 0.5059,
          imageUrl: sample,
          frame: 'heartFrame',
        ),
      ],
    ),
    _page(
      pageNumber: 5,
      layoutId: 'ticket_board',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFFBF8F1',
          zIndex: 1,
        ),
        _serifTitle(
          id: 'title',
          x: 0.2963,
          y: 0.1118,
          width: 0.4074,
          height: 0.0403,
          text: 'Moments of\nLove',
          align: 'center',
          fontSize: 28,
          fontWeight: 500,
          color: _lavender,
          lineHeight: 1.0,
        ),
        _imageLayer(
          id: 'ticket_a',
          x: 0.0556,
          y: 0.3194,
          width: 0.2778,
          height: 0.3958,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_b',
          x: 0.3611,
          y: 0.3194,
          width: 0.2778,
          height: 0.3958,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_c',
          x: 0.6667,
          y: 0.3194,
          width: 0.2778,
          height: 0.3958,
          imageUrl: sample,
          frame: 'free',
        ),
        _textLayer(
          id: 'footer',
          x: 0.2481,
          y: 0.8215,
          width: 0.5037,
          height: 0.0375,
          text: 'D-day',
          align: 'center',
          fontFamily: 'Cormorant',
          fontWeight: 500,
          fontSize: 20,
          color: _lavender,
          lineHeight: 1.2,
        ),
      ],
    ),
    _page(
      pageNumber: 6,
      layoutId: 'quote_break',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'ending_photo',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          imageUrl: sample,
          zIndex: 5,
        ),
      ],
    ),
    _page(
      pageNumber: 7,
      layoutId: 'four_cut',
      role: 'inner',
      recommendedPhotoCount: 4,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _imageLayer(
          id: 'ticket_tl',
          x: 0.0556,
          y: 0.0188,
          width: 0.4352,
          height: 0.4722,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_tr',
          x: 0.5092,
          y: 0.0188,
          width: 0.4352,
          height: 0.4722,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_bl',
          x: 0.0556,
          y: 0.5021,
          width: 0.4352,
          height: 0.4722,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'ticket_br',
          x: 0.5092,
          y: 0.5021,
          width: 0.4352,
          height: 0.4722,
          imageUrl: sample,
          frame: 'free',
        ),
      ],
    ),
    _page(
      pageNumber: 8,
      layoutId: 'spotlight_frame',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _imageLayer(
          id: 'left_column',
          x: 0.0556,
          y: 0.0278,
          width: 0.4352,
          height: 0.9458,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'right_column',
          x: 0.5092,
          y: 0.0271,
          width: 0.4352,
          height: 0.9458,
          imageUrl: sample,
          frame: 'free',
        ),
      ],
    ),
    _page(
      pageNumber: 9,
      layoutId: 'detail_mix',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFFBF8F1',
          zIndex: 1,
        ),
        _decoLayer(
          id: 'stack_back_border',
          x: 0.0556,
          y: 0.0368,
          width: 0.6481,
          height: 0.4132,
          fill: '#00FFFFFF',
          border: '#FFEEE8F1',
          borderWidth: 0.00185,
          zIndex: 7,
        ),
        _imageLayer(
          id: 'stack_back',
          x: 0.0556,
          y: 0.0368,
          width: 0.6481,
          height: 0.4132,
          imageUrl: sample,
          frame: 'free',
          zIndex: 8,
        ),
        _imageLayer(
          id: 'stack_front',
          x: 0.5278,
          y: 0.4236,
          width: 0.4166,
          height: 0.5278,
          imageUrl: sample,
          frame: 'archOval',
          zIndex: 10,
        ),
        _textLayer(
          id: 'body_small',
          x: 0.6685,
          y: 0.1903,
          width: 0.2963,
          height: 0.0569,
          text: '현지의 공기와\n빛을 기억해',
          fontFamily: 'BookMyungjo',
          fontWeight: 600,
          fontSize: 34,
          color: _lavender,
          lineHeight: 1.0,
        ),
        _serifTitle(
          id: 'body_large',
          x: 0.0556,
          y: 0.6875,
          width: 0.5000,
          height: 0.3403,
          text: 'Our\nAnniversary\nDay',
          fontSize: 118,
          fontWeight: 400,
          color: _lavender,
          lineHeight: 0.46,
        ),
      ],
    ),
    _page(
      pageNumber: 10,
      layoutId: 'memory_wall',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _imageLayer(
          id: 'memory_left',
          x: 0.0556,
          y: 0.0278,
          width: 0.4815,
          height: 0.6931,
          imageUrl: sample,
          frame: 'free',
          zIndex: 8,
        ),
        _imageLayer(
          id: 'memory_right',
          x: 0.3333,
          y: 0.3132,
          width: 0.6111,
          height: 0.6590,
          imageUrl: sample,
          frame: 'free',
          zIndex: 10,
        ),
        _textLayer(
          id: 'memory_body',
          x: 0.1093,
          y: 0.7861,
          width: 0.4185,
          height: 0.0972,
          text: '한 장의 사진보다 오래 남는 건\n그날 네가 건넨 다정한 표정이었다.',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 20,
          color: '#FF8D7E78',
          lineHeight: 1.45,
        ),
      ],
    ),
    _page(
      pageNumber: 11,
      layoutId: 'ending_note',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _imageLayer(
          id: 'ending_photo',
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          imageUrl: sample,
          zIndex: 5,
        ),
      ],
    ),
    _page(
      pageNumber: 12,
      layoutId: 'big_memory',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _textLayer(
          id: 'side_phrase_band',
          x: 0.0,
          y: 0.1097,
          width: 1.0,
          height: 0.0743,
          text: 'Every little thing with you became worth keeping.',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 500,
          fontSize: 18,
          color: '#FFBEAEBE',
          lineHeight: 1.2,
          zIndex: 8,
        ),
        _serifTitle(
          id: 'title',
          x: 0.0,
          y: 0.2007,
          width: 1.0,
          height: 0.0354,
          text: 'big memory',
          align: 'center',
          fontSize: 34,
          fontWeight: 500,
          color: '#FFBFAFD2',
        ),
        _imageLayer(
          id: 'hero_memory',
          x: 0.0556,
          y: 0.2778,
          width: 0.5926,
          height: 0.4444,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'side_top',
          x: 0.6667,
          y: 0.2778,
          width: 0.2778,
          height: 0.2153,
          imageUrl: sample,
          frame: 'free',
        ),
        _imageLayer(
          id: 'side_bottom',
          x: 0.6667,
          y: 0.5069,
          width: 0.2778,
          height: 0.2153,
          imageUrl: sample,
          frame: 'free',
        ),
        _textLayer(
          id: 'memory_tag_text',
          x: 0.1741,
          y: 0.6417,
          width: 0.1259,
          height: 0.0160,
          text: 'memory tag',
          fontFamily: 'NotoSans',
          fontWeight: 500,
          fontSize: 14,
          color: '#FFAD97AA',
          zIndex: 20,
        ),
      ],
    ),
    _page(
      pageNumber: 13,
      layoutId: 'polaroid_line',
      role: 'photo',
      recommendedPhotoCount: 2,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _decoLayer(
          id: 'ribbon_stage',
          x: 0.0556,
          y: 0.1167,
          width: 0.8888,
          height: 0.6694,
          fill: '#FFF2E7DD',
          radius: 0.03,
          zIndex: 4,
        ),
        _imageLayer(
          id: 'postcard_left',
          x: 0.1111,
          y: 0.1611,
          width: 0.3333,
          height: 0.3179,
          imageUrl: sample,
          frame: 'free',
          rotation: -2,
        ),
        _imageLayer(
          id: 'postcard_right',
          x: 0.5556,
          y: 0.1431,
          width: 0.3333,
          height: 0.3179,
          imageUrl: sample,
          frame: 'free',
          rotation: 2,
        ),
        _decoLayer(
          id: 'receipt_slip',
          x: 0.1574,
          y: 0.5625,
          width: 0.6185,
          height: 0.0875,
          fill: '#FFFFFCF8',
          border: '#FFE7D8C8',
          borderWidth: 0.002,
          radius: 0.02,
          zIndex: 8,
        ),
        _textLayer(
          id: 'receipt_text',
          x: 0.2037,
          y: 0.5889,
          width: 0.5333,
          height: 0.0354,
          text: 'The day was simple, and that is why it stayed beautiful.',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 15,
          color: '#FF8D7E78',
          zIndex: 20,
        ),
        _textLayer(
          id: 'footer',
          x: 0.1907,
          y: 0.6708,
          width: 0.4185,
          height: 0.0333,
          text: '붙잡아 두고 싶은 오후의 장면들',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 500,
          fontSize: 16,
          color: '#FFBEAEBE',
          zIndex: 20,
        ),
      ],
    ),
    _page(
      pageNumber: 14,
      layoutId: 'circle_and_note',
      role: 'photo',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _imageLayer(
          id: 'heart_story_main_photo',
          x: 0.1370,
          y: 0.0889,
          width: 0.5204,
          height: 0.3625,
          imageUrl: sample,
          frame: 'heartFrame',
          zIndex: 10,
        ),
        _imageLayer(
          id: 'heart_story_small_a',
          x: 0.6648,
          y: 0.1069,
          width: 0.1810,
          height: 0.1267,
          imageUrl: sample,
          frame: 'heartFrame',
          zIndex: 10,
        ),
        _imageLayer(
          id: 'heart_story_small_b',
          x: 0.6981,
          y: 0.2736,
          width: 0.1477,
          height: 0.1044,
          imageUrl: sample,
          frame: 'heartFrame',
          zIndex: 10,
        ),
        _serifTitle(
          id: 'title',
          x: 0.1426,
          y: 0.5278,
          width: 0.3519,
          height: 0.0375,
          text: 'Love Notes',
          fontSize: 36,
          fontWeight: 500,
          color: '#FFC7C0E8',
        ),
        _textLayer(
          id: 'body',
          x: 0.1444,
          y: 0.5819,
          width: 0.3630,
          height: 0.0514,
          text: '서로를 바라보는 방식도 결국 우리의 기념일이 된다.',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 16,
          color: '#FF8D7E78',
          lineHeight: 1.45,
        ),
        _decoLayer(
          id: 'label_card',
          x: 0.6037,
          y: 0.5278,
          width: 0.2296,
          height: 0.0917,
          fill: '#FFFFFCF7',
          border: '#FFE7D8C8',
          borderWidth: 0.002,
          radius: 0.03,
          zIndex: 8,
        ),
        _textLayer(
          id: 'label_text',
          x: 0.6426,
          y: 0.5500,
          width: 0.1556,
          height: 0.0375,
          text: 'D+100',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 600,
          fontSize: 22,
          color: '#FFAD97AA',
          zIndex: 20,
        ),
        _decoLayer(
          id: 'mini_tag',
          x: 0.1426,
          y: 0.6458,
          width: 0.2037,
          height: 0.0389,
          fill: '#FFF2E7DD',
          radius: 0.02,
          zIndex: 8,
        ),
        _textLayer(
          id: 'mini_tag_text',
          x: 0.1630,
          y: 0.6576,
          width: 0.1667,
          height: 0.0167,
          text: 'with all my heart',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 500,
          fontSize: 13,
          color: '#FF8A6B72',
          zIndex: 20,
        ),
      ],
    ),
    _page(
      pageNumber: 15,
      layoutId: 'banner_and_detail',
      role: 'photo',
      recommendedPhotoCount: 1,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: '#FFF9F5EF',
          zIndex: 1,
        ),
        _imageLayer(
          id: 'banner',
          x: 0.0556,
          y: 0.1250,
          width: 0.8888,
          height: 0.3042,
          imageUrl: sample,
          frame: 'free',
        ),
        _decoLayer(
          id: 'panel',
          x: 0.1074,
          y: 0.5278,
          width: 0.3889,
          height: 0.1319,
          fill: '#FFFFFCF7',
          border: '#FFE7D8C8',
          borderWidth: 0.002,
          radius: 0.03,
          zIndex: 8,
        ),
        _serifTitle(
          id: 'title',
          x: 0.1333,
          y: 0.5583,
          width: 0.2407,
          height: 0.0236,
          text: 'For Our Day',
          fontSize: 28,
          fontWeight: 500,
          color: '#FFC7C0E8',
        ),
        _textLayer(
          id: 'body',
          x: 0.1352,
          y: 0.5931,
          width: 0.2093,
          height: 0.0292,
          text: '처음보다 더 깊어진 마음으로\n오늘을 오래 남긴다.',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 15,
          color: '#FF8A6B72',
          lineHeight: 1.4,
        ),
        _decoLayer(
          id: 'bottom_oval_tag',
          x: 0.5963,
          y: 0.5486,
          width: 0.2333,
          height: 0.1153,
          fill: '#FFF4EAE2',
          radius: 0.20,
          zIndex: 8,
        ),
        _textLayer(
          id: 'bottom_oval_tag_text',
          x: 0.6426,
          y: 0.5820,
          width: 0.1407,
          height: 0.0208,
          text: 'Our Day',
          align: 'center',
          fontFamily: 'NotoSans',
          fontWeight: 600,
          fontSize: 20,
          color: '#FFAD97AA',
          zIndex: 20,
        ),
      ],
    ),
    _page(
      pageNumber: 16,
      layoutId: 'ending_grid',
      role: 'ending',
      recommendedPhotoCount: 3,
      layers: [
        _decoLayer(
          id: 'paper_bg',
          x: 0,
          y: 0,
          width: 1,
          height: 1,
          fill: _paperBg,
          zIndex: 1,
        ),
        _decoLayer(
          id: 'ending_board',
          x: 0.1074,
          y: 0.1139,
          width: 0.7852,
          height: 0.6403,
          fill: '#FFFFF9F4',
          radius: 0.03,
          zIndex: 4,
        ),
        _decoLayer(
          id: 'ending_a_backer',
          x: 0.1630,
          y: 0.1542,
          width: 0.2774,
          height: 0.2434,
          fill: '#FFFFFBFB',
          border: '#FFF0D1DA',
          borderWidth: 0.00185,
          radius: 0.03,
          zIndex: 5,
        ),
        _imageLayer(
          id: 'ending_a',
          x: 0.1389,
          y: 0.1444,
          width: 0.2851,
          height: 0.2576,
          imageUrl: sample,
          frame: 'rounded28',
          rotation: 4,
          zIndex: 10,
        ),
        _decoLayer(
          id: 'ending_b_backer',
          x: 0.4222,
          y: 0.1403,
          width: 0.3425,
          height: 0.2890,
          fill: '#FFFFFBF8',
          border: '#FFF0D3DB',
          borderWidth: 0.00185,
          radius: 0.03,
          zIndex: 5,
        ),
        _imageLayer(
          id: 'ending_b',
          x: 0.4315,
          y: 0.1375,
          width: 0.3514,
          height: 0.3043,
          imageUrl: sample,
          frame: 'rounded28',
          rotation: -3,
          zIndex: 10,
        ),
        _imageLayer(
          id: 'ending_c',
          x: 0.1537,
          y: 0.4194,
          width: 0.2111,
          height: 0.1250,
          imageUrl: sample,
          frame: 'free',
          zIndex: 10,
        ),
        _serifTitle(
          id: 'title',
          x: 0.4481,
          y: 0.4722,
          width: 0.3630,
          height: 0.0333,
          text: '그리고 다음 기념일',
          fontSize: 42,
          fontWeight: 600,
          color: _roseBrown,
        ),
        _textLayer(
          id: 'body',
          x: 0.4481,
          y: 0.5250,
          width: 0.3074,
          height: 0.0800,
          text: '우리가 만든 계절을\n계속 쌓아 가기로 했다.\n다음 기념일의 우리도 기대하면서.',
          fontFamily: 'NotoSans',
          fontWeight: 400,
          fontSize: 16,
          color: _bodyBrown,
          lineHeight: 1.5,
        ),
      ],
    ),
  ];
  return pages;
}

List<Map<String, dynamic>> _canonicalizeAnniversaryPages(
  List<Map<String, dynamic>> pages,
) {
  const order = [
    'cover_full_bleed',
    'memory_collage',
    'note_and_photo',
    'circle_story',
    'ticket_board',
    'quote_break',
    'four_cut',
    'spotlight_frame',
    'detail_mix',
    'memory_wall',
    'ending_note',
    'big_memory',
    'polaroid_line',
    'circle_and_note',
    'banner_and_detail',
    'ending_grid',
  ];

  final byLayout = <String, Map<String, dynamic>>{};
  for (final page in pages) {
    final key = page['layoutId']?.toString();
    if (key == null || byLayout.containsKey(key)) continue;
    byLayout[key] = page;
  }

  final canonical = <Map<String, dynamic>>[];
  for (var i = 0; i < order.length; i++) {
    final page = byLayout[order[i]];
    if (page == null) continue;
    final clone = jsonDecode(jsonEncode(page)) as Map<String, dynamic>;
    clone['pageNumber'] = i + 1;
    canonical.add(clone);
  }
  return canonical;
}

List<Map<String, dynamic>> _adaptPages({
  required List<Map<String, dynamic>> pages,
  required String ratioType,
}) {
  final cloned = jsonDecode(jsonEncode(pages)) as List<dynamic>;
  final next = cloned.cast<Map<String, dynamic>>();
  for (final page in next) {
    final layers = (page['layers'] as List).cast<Map<String, dynamic>>();
    _applyGenericRatioAdaptation(layers: layers, ratioType: ratioType);
  }
  return next;
}

Map<String, dynamic> _templateJson() {
  final portraitPages = _canonicalizeAnniversaryPages(_portraitPages());
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
    'templateId': 'anniversary_days_v1',
    'version': 2,
    'lifecycleStatus': 'published',
    'ratio': '9:16',
    'cover': {'pageNumber': 1, 'layers': portraitPages.first['layers']},
    'metadata': {
      'style': 'romantic_anniversary_editorial',
      'designWidth': 1080,
      'designHeight': 1440,
      'difficulty': 2,
      'recommendedPhotoCount': 6,
      'mood': 'soft_cream_editorial',
      'tags': ['기념일', '커플', '100일', '1주년', '포토북'],
      'heroTextSafeArea': {'x': 0.16, 'y': 0.70, 'width': 0.68, 'height': 0.18},
      'sourceBottomSheetTemplateIds': ['anniversary_days_v1'],
      'applyScope': 'cover_and_pages',
      'bottomSheetReferenceMode': 'style_and_tone_only',
      'templateType': 'anniversary',
      'theme': 'days',
      'title': '우리의 기념일',
      'category': '기념일',
    },
    'pages': portraitPages,
    'variants': {
      'square': {
        'variantId': 'anniversary_days_square',
        'aspect': 'square',
        'ratio': '1:1',
        'designWidth': 1440,
        'designHeight': 1440,
        'metadata': {'theme': 'days', 'templateType': 'anniversary'},
        'pages': squarePages,
      },
      'landscape': {
        'variantId': 'anniversary_days_landscape',
        'aspect': 'landscape',
        'ratio': '16:9',
        'designWidth': 1440,
        'designHeight': 1080,
        'metadata': {'theme': 'days', 'templateType': 'anniversary'},
        'pages': landscapePages,
      },
    },
  };
}

Map<String, dynamic> _storeEntry() {
  final preview = _asset('anniversary_sample.png');
  return {
    'id': 49,
    'title': '우리의 기념일',
    'subTitle': '커플 기념일 앨범 · clean romantic',
    'description': '100일, 1주년 같은 기념일을 크림 배경의 정돈된 에디토리얼 포토북으로 담는 템플릿',
    'coverImageUrl': preview,
    'previewImages': List<String>.filled(16, preview),
    'pageCount': 16,
    'likeCount': 0,
    'userCount': 0,
    'category': '기념일',
    'tags': ['기념일', '커플', '100일', '1주년', '포토북'],
    'weeklyScore': 0,
    'isNew': true,
    'isBest': false,
    'isPremium': false,
    'isLiked': false,
    'templateId': 'anniversary_days_v1',
    'version': 'v1',
    'lifecycleStatus': 'published',
    'templateJson': jsonEncode(_templateJson()),
  };
}

void main() {
  final entry = _storeEntry();
  File(_handoffPath)
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert([entry]));
  File(_storePath)
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert([entry]));

  stdout.writeln('Generated anniversary_days template');
  stdout.writeln('handoff=$_handoffPath');
  stdout.writeln('store=$_storePath');
  stdout.writeln(
    'next=./scripts/template_asset_pipeline.sh --template-slug=anniversary_days '
    '--template-store-json=$_storePath',
  );
}
