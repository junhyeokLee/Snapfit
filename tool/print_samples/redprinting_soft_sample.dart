import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/printing/print_vendor_spec.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

/// Operator-owned test artwork. No photographs, account data, or network inputs.
const sampleTestCardSource = 'memory:snapfit-generated-print-test-card';
const sampleCanvas = Size(500, 375);

PrintVendorSpec softSampleSpec() => PrintVendorSpec.fromJson({
  'id': 'REDP_200X150_SOFT',
  'specVersion': 'REDP_200X150_SOFT_REVIEW_V3_SAMPLE_20_7.22',
  'verified': false,
  'geometrySource':
      'PHBKMYB 200x150 softcover 20p guide; sample validation required',
  'pageCount': 20,
  'dpi': 300,
  'minimumPhotoPpi': 150,
  'colorSpace': 'sRGB',
  'interior': {'trimWidthMm': 200, 'trimHeightMm': 150, 'bleedMm': 5},
  'cover': {
    'bleedMm': 5,
    'widthMm': 417.22,
    'heightMm': 160,
    'back': {'xMm': 5, 'yMm': 5, 'widthMm': 200, 'heightMm': 150},
    'front': {'xMm': 212.22, 'yMm': 5, 'widthMm': 200, 'heightMm': 150},
  },
});

LayerModel _text(
  String id,
  String value,
  Rect bounds, {
  String family = 'NotoSans',
  double size = 12,
  Color color = const Color(0xff233c43),
  FontWeight weight = FontWeight.w400,
  TextAlign align = TextAlign.left,
}) => LayerModel(
  id: id,
  type: LayerType.text,
  position: bounds.topLeft,
  width: bounds.width,
  height: bounds.height,
  text: value,
  textAlign: align,
  textStyle: TextStyle(
    fontFamily: family,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: 1.5,
  ),
  zIndex: 100,
);

LayerModel _photo(
  String id,
  Rect bounds, {
  String frame = 'none',
  double zoom = 1,
  double rotation = 0,
  Offset offset = Offset.zero,
}) => LayerModel(
  id: id,
  type: LayerType.image,
  position: bounds.topLeft,
  width: bounds.width,
  height: bounds.height,
  originalUrl: sampleTestCardSource,
  previewUrl: sampleTestCardSource,
  imageBackground: frame,
  imageTemplate: 'free',
  imageZoom: zoom,
  imageOffset: offset,
  rotation: rotation,
);

Map<String, dynamic> _page(
  int index,
  String title,
  List<LayerModel> layers, {
  Color background = const Color(0xfffffbf5),
}) => {
  'index': index,
  'isCover': index == 0,
  'backgroundColor': background.toARGB32(),
  'layers':
      [
            if (index > 0)
              _text(
                'page-$index-heading',
                '${index.toString().padLeft(2, '0')}  $title',
                const Rect.fromLTWH(24, 10, 452, 31),
                size: 11,
                weight: FontWeight.w600,
                color: background.computeLuminance() < .2
                    ? Colors.white
                    : const Color(0xff233c43),
              ),
            ...layers,
            if (index > 0)
              _text(
                'page-$index-footer',
                '스냅핏 실물 검수 샘플 · 생성 테스트 카드 · $index / 20',
                const Rect.fromLTWH(24, 345, 452, 22),
                size: 7.5,
                color: background.computeLuminance() < .2
                    ? const Color(0xffcad9dc)
                    : const Color(0xff627477),
              ),
          ]
          .map(
            (layer) => LayerExportMapper.toJson(
              layer,
              canvasSize: sampleCanvas,
              isCover: index == 0,
            ),
          )
          .toList(),
};

/// Uses the editor's current template builder and persisted layer schema.
Map<String, dynamic> softSampleAlbumSnapshot() {
  final pages = <Map<String, dynamic>>[
    _page(0, '스냅핏 인쇄 검수', [
      _text(
        'cover-brand',
        '스냅핏',
        const Rect.fromLTWH(38, 21, 425, 36),
        family: 'Eulyoo',
        size: 24,
        weight: FontWeight.w600,
      ),
      _photo('cover-card', const Rect.fromLTWH(38, 75, 425, 221)),
      _text(
        'cover-label',
        '사진과 글이 책이 되는 순간',
        const Rect.fromLTWH(38, 309, 425, 24),
        size: 12,
      ),
      _text(
        'cover-spec',
        '인쇄 검수용 테스트 카드 · 200×150mm · 소프트커버 · 내지 20쪽',
        const Rect.fromLTWH(38, 337, 425, 18),
        size: 7,
        color: const Color(0xff627477),
      ),
    ]),
  ];
  for (final entry in pageTemplates.indexed) {
    final index = entry.$1 + 1;
    final template = entry.$2;
    final built = const AlbumEditorService().createPageFromTemplate(
      template: template,
      index: index,
      canvasSize: const Size(452, 292),
    );
    final layers = built.layers.indexed.map((entry) {
      final layer = entry.$2;
      return layer.copyWith(
        id: 'template-$index-${entry.$1}',
        position: layer.position + const Offset(24, 45),
        originalUrl: sampleTestCardSource,
        previewUrl: sampleTestCardSource,
        imageUrl: sampleTestCardSource,
      );
    }).toList();
    pages.add(
      _page(
        index,
        '앱 레이아웃 · ${template.name}',
        layers,
        background: template.backgroundColor,
      ),
    );
  }
  pages.addAll([
    _page(13, '프레임과 사진 확대 · 1배 / 4배', [
      _photo(
        'crop-1',
        const Rect.fromLTWH(30, 83, 194, 184),
        frame: 'studioInstant',
      ),
      _photo(
        'crop-4',
        const Rect.fromLTWH(276, 83, 194, 184),
        frame: 'studioInstant',
        zoom: 4,
        offset: const Offset(31, -25),
      ),
      _text(
        'crop-label-1',
        '원본 사진 · 확대 1배',
        const Rect.fromLTWH(30, 310, 194, 24),
        size: 9,
      ),
      _text(
        'crop-label-4',
        '사진만 4배 · 프레임 크기 유지',
        const Rect.fromLTWH(276, 310, 194, 24),
        size: 9,
      ),
    ]),
    _page(14, '서로 다른 프레임 · 회전과 이동', [
      _photo(
        'frame-oval',
        const Rect.fromLTWH(35, 58, 194, 230),
        frame: 'studioOvalMat',
        rotation: -3,
      ),
      _photo(
        'frame-film',
        const Rect.fromLTWH(274, 62, 190, 226),
        frame: 'studioFilm',
        rotation: 3,
        offset: const Offset(-40, 25),
      ),
      _text(
        'frame-label',
        '타원 매트 / 필름 · 사진 자르기와 테두리를 확인하세요.',
        const Rect.fromLTWH(35, 306, 430, 28),
        size: 9,
      ),
    ]),
    _page(15, '색상 · 그라데이션 · 가는 선', [
      _photo('color-card', const Rect.fromLTWH(24, 46, 452, 274)),
      _text(
        'color-note',
        '생성 카드입니다. 자연사진의 피부색·사진 질감은 별도 확인합니다.',
        const Rect.fromLTWH(24, 322, 452, 20),
        size: 8,
      ),
    ]),
    _page(16, '한글 본문 · 자동 줄바꿈', [
      _photo(
        'prose-card',
        const Rect.fromLTWH(25, 56, 194, 263),
        frame: 'studioRounded',
      ),
      _text(
        'prose-body',
        '작은 순간이 모여 한 권의 기억이 됩니다.\n\n'
            '사진의 색과 글씨의 선명함을 확인하며, 우리가 고른 문장이 페이지 안에서 '
            '자연스럽게 이어지는지 살펴봅니다.\n\n'
            '긴 한글 문장도 빠짐없이 읽히고, 문단 사이의 여백이 편안하게 남아 있으면 좋겠습니다. '
            '줄바꿈과 받침이 또렷하게 보이는지 확인해주세요.',
        const Rect.fromLTWH(242, 55, 233, 271),
        size: 10,
      ),
    ]),
    _page(17, '한글 글꼴 · 작은 글씨', [
      _text(
        'sans-small',
        'NotoSans 8pt 정도\n가나다라마바사 아자차카타파하 0123456789',
        const Rect.fromLTWH(26, 52, 449, 45),
        size: 7,
      ),
      _text(
        'sans-body',
        'NotoSans 본문\n오늘의 소중한 장면을 한 권에 담습니다.',
        const Rect.fromLTWH(26, 108, 449, 65),
        size: 12,
      ),
      _text(
        'serif-body',
        '을유 명조\n오래 간직하고 싶은 우리의 이야기',
        const Rect.fromLTWH(26, 184, 449, 65),
        size: 12,
        family: 'Eulyoo',
      ),
      _text(
        'hand-body',
        '손글씨\n사진처럼 선명하게, 기억처럼 따뜻하게.',
        const Rect.fromLTWH(26, 260, 449, 69),
        size: 13,
        family: 'FigmaHand',
      ),
    ]),
    _page(18, '검은 배경 · 밝은 글씨', [
      _photo('dark-card', const Rect.fromLTWH(24, 47, 280, 281)),
      _text(
        'dark-prose',
        '어두운 배경에서도\n또렷한 한글\n\n하얀 글씨의 가장자리와\n얇은 획을 확인하세요.',
        const Rect.fromLTWH(326, 92, 150, 226),
        size: 11,
        color: Colors.white,
      ),
    ], background: const Color(0xff182c34)),
    _page(19, '두께와 순서 · 펼친 책의 방향', [
      _photo(
        'binding-card',
        const Rect.fromLTWH(34, 54, 201, 263),
        frame: 'studioGallery',
      ),
      _text(
        'binding-note',
        '내지 19쪽\n\n'
            '표지는 별도 파일 1쪽입니다.\n'
            '내지는 한 파일 안에 1쪽부터 20쪽까지 개별 페이지로 저장했습니다.\n\n'
            '제본 방향, 장수, 펼침과 좌우 순서를 실물에서 확인합니다.',
        const Rect.fromLTWH(259, 61, 215, 260),
        size: 10,
      ),
    ]),
    _page(20, '실물 검수 · 마지막 페이지', [
      _text(
        'final-heading',
        '끝까지 잘 담겼나요?',
        const Rect.fromLTWH(28, 61, 445, 52),
        size: 23,
        family: 'Eulyoo',
      ),
      _text(
        'final-body',
        '표지의 책등과 재단 여백\n사진 확대 후 선명함과 프레임\n'
            '한글 줄바꿈과 작은 글씨\n내지 1-20쪽의 순서와 장수\n'
            '색상·검은 면·종이·제본·포장',
        const Rect.fromLTWH(28, 133, 445, 173),
        size: 13,
      ),
      _text(
        'final-note',
        '이 카드로 실제 자연사진의 인쇄 품질을 보증하지 않습니다.',
        const Rect.fromLTWH(28, 312, 445, 25),
        size: 8,
      ),
    ]),
  ]);
  return {
    'album': {
      'title': '스냅핏 실물 검수 샘플',
      'ratio': 4 / 3,
      'cover_layers_json': {
        'printProduct': PrintProduct.forId('REDP_200X150_SOFT')!.toJson(),
        'pages': pages,
      },
    },
    'pages': <Object>[],
  };
}

/// Rendered input to the photo pipeline, not a substitute PDF renderer.
Future<Uint8List> generatedSampleTestCard() async {
  const width = 4800, height = 3600;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final full = const Rect.fromLTWH(0, 0, 4800, 3600);
  canvas.drawRect(full, Paint()..color = const Color(0xfffbf6ed));
  final spectrum = const Rect.fromLTWH(220, 240, 4360, 1180);
  canvas.drawRect(
    spectrum,
    Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xff153f70),
          Color(0xff427c9e),
          Color(0xffa9ccb2),
          Color(0xffffdc99),
          Color(0xffdc6948),
          Color(0xff5a294c),
        ],
      ).createShader(spectrum),
  );
  for (var i = 0; i < 16; i++) {
    final shade = (255 * i / 15).round();
    canvas.drawRect(
      Rect.fromLTWH(220 + 272.5 * i, 1570, 272.5, 470),
      Paint()..color = Color.fromARGB(255, shade, shade, shade),
    );
  }
  for (var group = 0; group < 3; group++) {
    final pitch = [4, 8, 16][group];
    final area = Rect.fromLTWH(220 + group * 1470, 2230, 1300, 1020);
    canvas.drawRect(area, Paint()..color = Colors.white);
    for (double x = area.left; x < area.right; x += pitch) {
      canvas.drawRect(
        Rect.fromLTWH(x, area.top, pitch / 2, area.height),
        Paint()..color = const Color(0xff17282d),
      );
    }
  }
  final colors = [
    const Color(0xff094958),
    const Color(0xfff28f52),
    const Color(0xffbf4260),
    const Color(0xff366c3b),
  ];
  for (var i = 0; i < 4; i++) {
    final point = [
      const Offset(85, 85),
      const Offset(4715, 85),
      const Offset(85, 3515),
      const Offset(4715, 3515),
    ][i];
    canvas.drawCircle(point, 60, Paint()..color = colors[i]);
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    return (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
