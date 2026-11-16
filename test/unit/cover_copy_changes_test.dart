import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/cover_copy_changes.dart';

LayerModel _text(String id, String value, {bool? sample = true}) => LayerModel(
  id: id,
  type: LayerType.text,
  position: const Offset(37, 211),
  text: value,
  isTemplateContent: sample,
  width: 280,
  height: 82,
  scale: 1.2,
  rotation: -.08,
  textStyle: const TextStyle(
    fontFamily: 'Pretendard',
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Colors.teal,
    letterSpacing: 1.3,
    height: 1.25,
    shadows: [
      Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 2)),
    ],
  ),
  textAlign: TextAlign.center,
  textBackground: 'tag',
  textFillMode: 'outline',
  opacity: .8,
  zIndex: 6,
);

void main() {
  test(
    'unchanged sample and unknown copy keep their exact content markers',
    () {
      final sample = _text('sample', '여행의 조각');
      final unknown = _text('legacy', '2026', sample: null);
      final layers = [sample, unknown];
      final edits = CoverCopyChanges.fromValues(layers, {
        'sample': '여행의 조각',
        'legacy': '2026',
      });
      expect(edits.isEmpty, isTrue);
      expect(edits.applyTo(layers), same(layers));
      expect(sample.isTemplateContent, isTrue);
      expect(unknown.isTemplateContent, isNull);
    },
  );

  test(
    'only changed text is personal while all artwork and typography survive',
    () {
      final title = _text('title', '여행의 조각');
      final date = _text('date', '2026');
      final photo = LayerModel(
        id: 'photo',
        type: LayerType.image,
        position: const Offset(21, 33),
        width: 400,
        height: 250,
        imageUrl: 'asset:assets/frame_preview/ocean_shore.jpg',
        imageOffset: const Offset(9, -11),
        imageZoom: 1.6,
        imageBackground: 'polaroid',
        isTemplateContent: false,
      );
      final sticker = LayerModel(
        id: 'sticker',
        type: LayerType.decoration,
        position: const Offset(15, 19),
        decorationFillColor: '#D8E8DC',
        width: 50,
        height: 70,
        isTemplateContent: true,
      );
      final original = [photo, title, date, sticker];
      final edited = CoverCopyChanges.fromValues(original, {
        'title': '우리의 제주',
        'date': '2026',
      }).applyTo(original);
      final result = edited[1];
      expect(title.text, '여행의 조각');
      expect(result.text, '우리의 제주');
      expect(result.isTemplateContent, isFalse);
      expect(result.id, title.id);
      expect(result.textStyle, same(title.textStyle));
      expect(result.position, title.position);
      expect(result.width, title.width);
      expect(result.height, title.height);
      expect(result.scale, title.scale);
      expect(result.rotation, title.rotation);
      expect(result.textAlign, title.textAlign);
      expect(result.textBackground, title.textBackground);
      expect(result.textFillMode, title.textFillMode);
      expect(result.opacity, title.opacity);
      expect(result.zIndex, title.zIndex);
      expect(edited[0], same(photo));
      expect(edited[2], same(date));
      expect(edited[3], same(sticker));
    },
  );

  test(
    'size variants match IDs or existing copy without borrowing geometry',
    () {
      final original = [_text('title', '여행의 조각'), _text('date', '2026')];
      final variantTitle = _text('wide-heading', '여행의 조각').copyWith(
        position: const Offset(180, 58),
        width: 310,
        textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 44),
      );
      final variantDate = _text('wide-date', '2026');
      final footer = _text('wide-footer', 'MEMORIES');
      final inner = [_text('inner', '내지의 글은 그대로')];
      final edits = CoverCopyChanges.fromValues(original, {'title': '우리의 제주'});
      final result = edits.applyToPages([
        [variantDate, variantTitle, footer],
        inner,
      ]);
      expect(result.first[1].text, '우리의 제주');
      expect(result.first[1].position, variantTitle.position);
      expect(result.first[1].width, variantTitle.width);
      expect(result.first[1].textStyle, same(variantTitle.textStyle));
      expect(result.first[0], same(variantDate));
      expect(result.first[2], same(footer));
      expect(result[1], same(inner));
    },
  );

  test(
    'legacy matching text roles retain words across different variant IDs',
    () {
      final original = [_text('title', '여행의 조각'), _text('date', '2026')];
      final edits = CoverCopyChanges.fromValues(original, {'title': '우리의 제주'});
      final result = edits.applyTo([
        _text('legacy-heading', 'TRAVEL'),
        _text('legacy-date', 'AUTUMN'),
      ]);
      expect(result.first.text, '우리의 제주');
      expect(result.last.text, 'AUTUMN');
      expect(result.last.isTemplateContent, isTrue);
    },
  );
}
