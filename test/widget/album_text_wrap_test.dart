import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/printing/album_print_exporter.dart';
import 'package:snap_fit/features/album/printing/print_album_document.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

const _prose =
    '작은 순간이 모여 한 권의 기억이 됩니다. 사진의 색과 글씨의 선명함을 '
    '확인하며 우리가 고른 문장이 페이지 안에서 자연스럽게 이어지는지 살펴봅니다. '
    '긴 한글 문장도 빠짐없이 읽히고 문단 사이의 여백이 편안하게 남아 있으면 좋겠습니다. '
    '줄바꿈과 받침이 또렷하게 보이는지 확인해주세요. 마지막 글자 끝';

class _EditorTextCanvas extends ConsumerWidget {
  const _EditorTextCanvas(this.layer, this.canvas);
  final LayerModel layer;
  final Size canvas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interaction = LayerInteractionManager(
      ref: ref,
      coverKey: GlobalKey(),
      setState: (_) {},
      getCoverSize: () => canvas,
      onEditText: (_) {},
    );
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [LayerBuilder(interaction, () => canvas).buildText(layer)],
    );
  }
}

Future<RenderParagraph> _paint(
  WidgetTester tester,
  LayerModel layer,
  Size canvas, {
  required bool print,
  ThemeData? theme,
  double textScale = 1,
}) async {
  final page = PrintAlbumPage(
    index: 1,
    isCover: false,
    canvasSize: canvas,
    layers: [layer],
    backgroundColor: Colors.white,
  );
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme ?? SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          bottomNavigationBar: const Text(
            '화면 안내 글',
            key: ValueKey('interface-copy'),
          ),
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: canvas,
              child: print
                  ? PrintAlbumPageCanvas(page: page)
                  : _EditorTextCanvas(layer, canvas),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  return tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.text(layer.text!),
      matching: find.byType(RichText),
    ),
  );
}

void main() {
  setUpAll(() async {
    for (final font in [
      ('NotoSans', 'NotoSansKR-Regular.ttf'),
      ('Eulyoo', 'Eulyoo1945-Regular.ttf'),
      ('FigmaHand', 'Hakgyoansim_GongryongalR.ttf'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}'))).load();
    }
  });

  for (final canvas in [
    const Size(500, 375),
    const Size(800, 600),
    const Size(800, 800),
  ]) {
    testWidgets(
      'Korean prose wraps inside saved editor and PDF frames $canvas',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scale = canvas.width / 500;
        final layer = LayerModel(
          id: 'paragraph-layer',
          type: LayerType.text,
          position: Offset(242 * scale, 45 * scale),
          width: 233 * scale,
          height: 271 * scale,
          text: _prose,
          textAlign: TextAlign.left,
          textStyle: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 10 * scale,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.5,
          ),
        );
        List<Rect>? editorBoxes;
        for (final print in [false, true]) {
          final paragraph = await _paint(tester, layer, canvas, print: print);
          final boxes = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: _prose.length),
              )
              .map((box) => box.toRect())
              .toList();
          expect(boxes.map((box) => box.top).toSet().length, greaterThan(3));
          expect(paragraph.size.width, closeTo(layer.width, .001));
          final ending = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: _prose.length - 8,
              extentOffset: _prose.length,
            ),
          );
          expect(ending, isNotEmpty);
          for (final box in ending) {
            expect(box.right, lessThanOrEqualTo(layer.width + .01));
            expect(box.bottom, lessThanOrEqualTo(layer.height + .01));
            final global = paragraph.localToGlobal(
              Offset(box.right, box.bottom),
            );
            expect(global.dx, lessThan(canvas.width));
            expect(global.dy, lessThan(canvas.height));
          }
          if (print) {
            expect(boxes, editorBoxes);
          } else {
            editorBoxes = boxes;
          }
        }
      },
    );
  }

  testWidgets(
    'natural-width single-line titles keep their font and alignment',
    (tester) async {
      const canvas = Size(500, 375);
      for (final family in ['NotoSans', 'Eulyoo', 'FigmaHand']) {
        final layer = const AlbumEditorService().createTextLayer(
          text: '우리의 여름 기록',
          style: TextStyle(
            fontFamily: family,
            fontSize: 24,
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
          ),
          mode: TextStyleType.none,
          canvasSize: canvas,
          textAlign: TextAlign.center,
        );
        List<Rect>? editorBoxes;
        for (final print in [false, true]) {
          final paragraph = await _paint(tester, layer, canvas, print: print);
          final boxes = paragraph
              .getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: layer.text!.length),
              )
              .map((box) => box.toRect())
              .toList();
          expect(boxes.map((box) => box.top).toSet(), hasLength(1));
          expect(paragraph.size.width, lessThanOrEqualTo(layer.width));
          final center = paragraph.localToGlobal(
            Offset(paragraph.size.width / 2, 0),
          );
          expect(center.dx, closeTo(layer.position.dx + layer.width / 2, .001));
          expect(paragraph.text.style!.fontSize, 24);
          expect(paragraph.text.style!.fontFamily, family);
          expect(paragraph.textAlign, TextAlign.center);
          if (print) {
            expect(boxes, editorBoxes);
          } else {
            editorBoxes = boxes;
          }
        }
      }
    },
  );

  testWidgets(
    'missing saved typography uses the same app baseline on all surfaces',
    (tester) async {
      final fallback = SnapFitTheme.light().textTheme.bodyMedium!;
      const canvas = Size(500, 375);
      final layer = LayerModel(
        id: 'legacy-paragraph',
        type: LayerType.text,
        position: const Offset(242, 45),
        width: 233,
        height: 271,
        text: _prose,
        textAlign: TextAlign.left,
        // The stored layer deliberately omits spacing, weight, height and color.
        textStyle: const TextStyle(
          inherit: false,
          fontFamily: 'NotoSans',
          fontSize: 12,
        ),
      );
      List<Rect>? reference;
      for (final theme in [SnapFitTheme.light(), SnapFitTheme.dark()]) {
        for (final print in [false, true]) {
          final paragraph = await _paint(
            tester,
            layer,
            canvas,
            print: print,
            theme: theme,
          );
          final style = paragraph.text.style!;
          expect(style.inherit, isFalse);
          expect(style.fontFamily, 'NotoSans');
          expect(style.fontSize, 12);
          expect(style.fontWeight, fallback.fontWeight);
          expect(style.letterSpacing, fallback.letterSpacing);
          expect(style.height, fallback.height);
          expect(style.leadingDistribution, fallback.leadingDistribution);
          expect(style.color, fallback.color);
          final boxes = paragraph
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: _prose.length),
              )
              .map((box) => box.toRect())
              .toList();
          expect(boxes.map((box) => box.top).toSet().length, greaterThan(3));
          if (reference == null) {
            reference = boxes;
          } else {
            expect(boxes, reference);
          }
        }
      }
    },
  );

  testWidgets(
    'saved typography overrides the common fallback without resizing',
    (tester) async {
      const canvas = Size(500, 375);
      const style = TextStyle(
        fontFamily: 'Eulyoo',
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.25,
        height: 1.8,
        color: Color(0xffba4262),
        fontStyle: FontStyle.italic,
        leadingDistribution: TextLeadingDistribution.proportional,
      );
      final layer = LayerModel(
        id: 'authored-title',
        type: LayerType.text,
        position: const Offset(20, 20),
        width: 440,
        height: 100,
        text: '우리가 간직할 문장',
        textStyle: style,
        textAlign: TextAlign.right,
      );
      for (final print in [false, true]) {
        final paragraph = await _paint(tester, layer, canvas, print: print);
        final rendered = paragraph.text.style!;
        expect(rendered.fontFamily, style.fontFamily);
        expect(rendered.fontSize, style.fontSize);
        expect(rendered.fontWeight, style.fontWeight);
        expect(rendered.letterSpacing, style.letterSpacing);
        expect(rendered.height, style.height);
        expect(rendered.color, style.color);
        expect(rendered.fontStyle, style.fontStyle);
        expect(rendered.leadingDistribution, style.leadingDistribution);
        expect(paragraph.textAlign, TextAlign.right);
        final boxes = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: layer.text!.length),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1));
      }
    },
  );

  for (final textScale in [1.5, 2.0]) {
    testWidgets(
      'artwork keeps print typography at $textScale while UI scales',
      (tester) async {
        const canvas = Size(500, 375);
        for (final background in [null, 'noteGrid']) {
          final layer = LayerModel(
            id: 'accessible-artwork',
            type: LayerType.text,
            position: const Offset(30, 45),
            width: 440,
            height: 220,
            text: _prose,
            textAlign: TextAlign.left,
            textBackground: background,
            textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 10),
          );
          final baseline = await _paint(tester, layer, canvas, print: true);
          final expectedBoxes = baseline
              .getBoxesForSelection(
                const TextSelection(baseOffset: 0, extentOffset: _prose.length),
              )
              .map((box) => box.toRect())
              .toList();
          for (final print in [false, true]) {
            final paragraph = await _paint(
              tester,
              layer,
              canvas,
              print: print,
              textScale: textScale,
            );
            expect(paragraph.textScaler.scale(10), 10);
            final boxes = paragraph
                .getBoxesForSelection(
                  const TextSelection(
                    baseOffset: 0,
                    extentOffset: _prose.length,
                  ),
                )
                .map((box) => box.toRect())
                .toList();
            expect(boxes, expectedBoxes);
            final uiParagraph = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byKey(const ValueKey('interface-copy')),
                matching: find.byType(RichText),
              ),
            );
            expect(uiParagraph.textScaler.scale(10), 10 * textScale);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );
  }
}
