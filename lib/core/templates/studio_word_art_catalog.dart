import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/album/domain/entities/layer.dart';
import 'story_edition_catalog.dart';

part 'atelier_word_art_catalog.dart';
part 'story_edition_word_art_catalog.dart';
part 'story_edition_word_art_layers.dart';
part 'sensory_word_art_layers.dart';
part 'hobby_expansion_word_art_catalog.dart';
part 'hobby_expansion_word_art_layers.dart';
part 'milestone_expansion_word_art_catalog.dart';
part 'milestone_expansion_word_art_layers.dart';
part 'premium_quartet_word_art_catalog.g.dart';
part 'premium_quartet_word_art_layers.dart';

/// Text and stationery remain separate editable layers, not a flattened image.
class StudioWordArt {
  const StudioWordArt(
    this.id,
    this.label,
    this.text, {
    this.square = false,
    this.canvasSize,
  });

  final String id, label, text;
  final bool square;
  final Size? canvasSize;
  Size get sourceSize =>
      canvasSize ?? (square ? const Size(300, 300) : const Size(500, 192));
  String get insertionValue => 'wordart:$id';
  String get productKey => 'phrase:collage-$id';
  String get favoriteKey => 'textStyle:luminous-edition:$id';

  List<LayerModel> buildLayers(Size canvas) {
    final source = sourceSize;
    final scale = math.min(
      canvas.width * .72 / source.width,
      canvas.height * .52 / source.height,
    );
    final origin = Offset(
      (canvas.width - source.width * scale) / 2,
      (canvas.height - source.height * scale) / 2,
    );
    return _sourceLayers().map((layer) {
      var result = layer.copyWith(
        // Inserting a ready-made phrase is design selection, not authored text.
        isTemplateContent: true,
        position: origin + layer.position * scale,
        width: layer.width * scale,
        height: layer.height * scale,
        textStyle: layer.textStyle?.copyWith(
          fontSize: layer.textStyle!.fontSize! * scale,
        ),
      );
      if ((id.startsWith('atelier-') ||
              id.startsWith('story-') ||
              id.startsWith('sensory-')) &&
          layer.type == LayerType.text) {
        // Font hinting rounds line metrics at the inserted size, not the source size.
        final measure = TextPainter(
          text: TextSpan(text: result.text, style: result.textStyle),
          textDirection: TextDirection.ltr,
          textAlign: result.textAlign ?? TextAlign.center,
        )..layout(maxWidth: result.width);
        final height = measure.height + (id.startsWith('story-') ? 1 : 0);
        measure.dispose();
        result = result.copyWith(
          position: result.position + Offset(0, (result.height - height) / 2),
          height: height,
        );
      }
      return result;
    }).toList();
  }

  List<LayerModel> previewLayers() => _sourceLayers();

  List<LayerModel> _sourceLayers() {
    if (id.startsWith('story-premium-'))
      return _premiumQuartetWordArtLayers(this);
    if (id.startsWith('story-hobby-'))
      return _hobbyExpansionWordArtLayers(this);
    if (id.startsWith('story-milestone-'))
      return _milestoneExpansionWordArtLayers(this);
    if (const {
      'story-coffee-notebook',
      'story-night-city-archive',
      'sensory-coffee-note',
      'sensory-night-index',
    }.contains(id))
      return _sensoryWordArtLayers(this);
    if (id.startsWith('story-')) return _storyEditionWordArtLayers(this);
    if (id.startsWith('atelier-')) return _atelierWordArtLayers(this);
    LayerModel paper(String key, Rect rect) => LayerModel(
      id: '$id-paper',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      imageBackground: key,
      zIndex: 0,
    );
    LayerModel lettering(
      Rect rect,
      String font,
      double size,
      Color color, {
      String? fill,
      String? value,
      String key = 'text',
      FontWeight? weight,
      TextAlign align = TextAlign.center,
    }) {
      final copy = value ?? text;
      final style = TextStyle(
        fontFamily: font,
        fontSize: size,
        fontWeight: weight,
        height: 1.2,
        color: color,
        letterSpacing: 0,
      );
      final painter = TextPainter(
        text: TextSpan(text: copy, style: style),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout(maxWidth: rect.width);
      final height = painter.height;
      painter.dispose();
      // A tight text frame aligns the editor's top-aligned text with previews.
      return LayerModel(
        id: '$id-$key',
        type: LayerType.text,
        position: Offset(rect.left, rect.center.dy - height / 2),
        width: rect.width,
        height: height,
        text: copy,
        textStyle: style,
        textStyleType: TextStyleType.none,
        textFillMode: fill,
        textAlign: align,
        zIndex: 1,
      );
    }

    LayerModel mark(String key, Rect rect, Color color) => LayerModel(
      id: '$id-$key',
      type: LayerType.decoration,
      position: rect.topLeft,
      width: rect.width,
      height: rect.height,
      decorationFillColor:
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    );
    List<LayerModel> ordered(List<LayerModel> layers) => [
      for (var index = 0; index < layers.length; index++)
        layers[index].copyWith(zIndex: index),
    ];

    const ink = Color(0xFF202020);
    const blue = Color(0xFF2451E6);
    const rose = Color(0xFFA42E4A);
    return switch (id) {
      'bold-cut' => ordered([
        lettering(
          const Rect.fromLTWH(30, 8, 322, 24),
          'Poppins',
          10,
          const Color(0xFF3F5864),
          value: 'PHOTO CLUB / ONE MORE MOMENT',
          key: 'eyebrow',
          align: TextAlign.left,
        ),
        mark('viewfinder-top', const Rect.fromLTWH(422, 16, 47, 3), blue),
        mark('viewfinder-side', const Rect.fromLTWH(466, 16, 3, 25), blue),
        mark('baseline', const Rect.fromLTWH(31, 162, 72, 3), blue),
        lettering(
          const Rect.fromLTWH(122, 154, 347, 24),
          'Poppins',
          9,
          const Color(0xFF3F5864),
          value: 'GOOD DAYS, KEPT TOGETHER',
          key: 'caption',
          align: TextAlign.right,
        ),
        lettering(
          const Rect.fromLTWH(24, 50, 452, 94),
          'RiaSans',
          57,
          blue,
          fill: 'papercut',
        ),
      ]),
      'ticket-label' => ordered([
        paper('zineTicket', const Rect.fromLTWH(10, 12, 480, 168)),
        lettering(
          const Rect.fromLTWH(35, 27, 328, 23),
          'Poppins',
          10,
          const Color(0xFF3D6253),
          value: 'TODAY\'S SMALL TICKET',
          key: 'ticket-heading',
          align: TextAlign.left,
        ),
        lettering(
          // Keep the original ticket's perforation and barcode uncovered.
          const Rect.fromLTWH(398, 22, 64, 31),
          'Cormorant Garamond',
          22,
          const Color(0xFF3D6253),
          value: '01',
          key: 'ticket-number',
        ),
        lettering(
          const Rect.fromLTWH(35, 135, 328, 22),
          'Poppins',
          8.5,
          const Color(0xFF53655D),
          value: 'PHOTO JOURNAL / KEEP THIS DAY',
          key: 'ticket-caption',
          align: TextAlign.left,
        ),
        lettering(
          const Rect.fromLTWH(35, 62, 328, 58),
          'NotoSans',
          23,
          ink,
          weight: FontWeight.w500,
          align: TextAlign.left,
        ),
      ]),
      'hand-note' => ordered([
        paper('zineUnderline', const Rect.fromLTWH(45, 130, 410, 24)),
        lettering(
          const Rect.fromLTWH(34, 10, 334, 25),
          'Poppins',
          10,
          const Color(0xFF65716B),
          value: 'A NOTE FOR US',
          key: 'note-heading',
          align: TextAlign.left,
        ),
        mark(
          'note-tab',
          const Rect.fromLTWH(430, 14, 37, 12),
          const Color(0xFFD7A85A),
        ),
        lettering(
          const Rect.fromLTWH(30, 157, 440, 25),
          'NotoSans',
          10,
          const Color(0xFF65716B),
          value: '사진 사이에 남겨 둔 마음',
          key: 'note-caption',
          align: TextAlign.right,
        ),
        lettering(const Rect.fromLTWH(22, 43, 456, 93), 'Yeongwol', 57, ink),
      ]),
      'diecut' => ordered([
        lettering(
          const Rect.fromLTWH(48, 10, 404, 24),
          'Poppins',
          10,
          const Color(0xFF784757),
          value: 'GOOD LITTLE DAYS',
          key: 'diecut-heading',
        ),
        mark(
          'diecut-left-rule',
          const Rect.fromLTWH(52, 164, 64, 2),
          const Color(0xFFD7A85A),
        ),
        mark(
          'diecut-right-rule',
          const Rect.fromLTWH(384, 164, 64, 2),
          const Color(0xFFD7A85A),
        ),
        lettering(
          const Rect.fromLTWH(135, 153, 230, 25),
          'Poppins',
          8.5,
          const Color(0xFF784757),
          value: 'A MOMENT TO KEEP',
          key: 'diecut-caption',
        ),
        lettering(
          const Rect.fromLTWH(28, 47, 444, 99),
          'Samlip',
          49,
          rose,
          fill: 'sticker',
        ),
      ]),
      'ribbon' => [
        paper('luminousRibbon', const Rect.fromLTWH(10, 28, 480, 136)),
        lettering(
          const Rect.fromLTWH(64, 66, 372, 60),
          'BookMyungjo',
          40,
          Colors.white,
        ),
      ],
      'seal' => [
        paper('luminousRosette', const Rect.fromLTWH(8, 8, 284, 284)),
        lettering(
          const Rect.fromLTWH(70, 92, 160, 116),
          'BookMyungjo',
          34,
          rose,
        ),
      ],
      _ => [
        lettering(
          const Rect.fromLTWH(26, 50, 448, 92),
          'BookMyungjo',
          64,
          blue,
          fill: 'outline',
        ),
      ],
    };
  }
}

const studioWordArts = [
  ...premiumQuartetWordArts,
  ...hobbyExpansionWordArts,
  ...milestoneExpansionWordArts,
  StudioWordArt(
    'story-coffee-notebook',
    '오후 한 잔 타이틀',
    '커피가\n식기 전에',
    canvasSize: Size(500, 320),
  ),
  StudioWordArt(
    'story-night-city-archive',
    '도시 수집 타이틀',
    '밤의 도시\n수집',
    canvasSize: Size(500, 320),
  ),
  StudioWordArt(
    'sensory-coffee-note',
    '손으로 적는 카페 메모',
    '오늘의 한 잔',
    canvasSize: Size(500, 192),
  ),
  StudioWordArt(
    'sensory-night-index',
    '야간 노선 색인 문구',
    '오늘의 경로',
    canvasSize: Size(500, 192),
  ),
  ...storyEditionWordArts,
  StudioWordArt('bold-cut', '볼드 컷아웃', '같이 찍자!'),
  StudioWordArt('ticket-label', '티켓 라벨', '오늘의 기분 : 맑음'),
  StudioWordArt('hand-note', '손글씨 밑줄', '다음 장도 함께'),
  StudioWordArt('diecut', '겹인쇄 스티커', '반짝반짝'),
  StudioWordArt('ribbon', '리본 문구', '오늘도, 네 편!'),
  StudioWordArt('seal', '레이스 메달 문구', '소중한\n우리', square: true),
  StudioWordArt('outline', '아웃라인 명조', '우리의 순간'),
  ...atelierWordArts,
];

StudioWordArt? studioWordArtById(String id) =>
    studioWordArts.where((art) => art.id == id).firstOrNull;
