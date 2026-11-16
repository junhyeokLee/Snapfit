import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';

const _stickers = [
  ('stickerHeartRed', '❤'),
  ('stickerLeafGreen', '❧'),
  ('stickerSparkleBlue', '✶'),
  ('stickerSparkleGold', '✶'),
  ('stickerBowPink', '🎀'),
  ('stickerHeartPink', '❤'),
  ('stickerCherryBlossom', '🌸'),
  ('stickerCloudSoft', '☁'),
  ('stickerCloverGreen', '☘'),
];
const _captions = [
  ('win95', 'image.exe'),
  ('vhs', 'PLAY'),
  ('vhs', 'SP 00:12:44'),
  ('postalStamp', '1924'),
];
const _vectorStickerColors = {
  'stickerHeartRed': Color(0xFFD74A4A),
  'stickerLeafGreen': Color(0xFF6FA05A),
  'stickerCloverGreen': Color(0xFF4C8F4E),
};
Iterable<(String, String)> get _textStickers =>
    _stickers.where((entry) => !_vectorStickerColors.containsKey(entry.$1));

class _Artwork extends ConsumerWidget {
  const _Artwork({this.print = false, this.staticStickers = false});
  final bool print, staticStickers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const canvas = Size(660, 560);
    final interaction = print
        ? LayerInteractionManager.printPreview(() => canvas)
        : LayerInteractionManager.preview(ref, () => canvas);
    final builder = LayerBuilder(interaction, () => canvas);
    return SizedBox.fromSize(
      size: canvas,
      child: Wrap(
        children: [
          for (final (style, _) in _stickers)
            SizedBox(
              key: ValueKey('artwork-$style'),
              width: 220,
              height: 140,
              child: Center(
                child: SizedBox(
                  width: 90,
                  height: 100,
                  child: staticStickers
                      ? LayerBuilder.buildStickerDecoration(
                          style: style,
                          width: 90,
                          height: 100,
                        )
                      : Stack(
                          children: [
                            builder.buildImage(
                              LayerModel(
                                id: style,
                                type: LayerType.decoration,
                                width: 90,
                                height: 100,
                                position: Offset.zero,
                                imageBackground: style,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          for (final style in ['win95', 'vhs', 'postalStamp'])
            SizedBox(
              key: ValueKey('artwork-$style'),
              width: 220,
              height: 140,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: builder.buildPhotoFrame(
                  LayerModel(
                    id: style,
                    type: LayerType.image,
                    width: 204,
                    height: 124,
                    position: Offset.zero,
                    imageBackground: style,
                  ),
                  const ColoredBox(color: Color(0xFF6F98A3)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> _mount(
  WidgetTester tester,
  ThemeData theme, {
  double scale = 1,
  bool print = false,
  bool staticStickers = false,
}) async {
  Widget artwork = _Artwork(print: print, staticStickers: staticStickers);
  if (print) {
    artwork = MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 14,
          color: Colors.black,
        ),
        child: artwork,
      ),
    );
  }
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(alignment: Alignment.topLeft, child: artwork),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

RenderParagraph _paragraph(WidgetTester tester, String style, String text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.descendant(
          of: find.byKey(ValueKey('artwork-$style')),
          matching: find.text(text),
        ),
        matching: find.byType(RichText),
      ),
    );

Map<String, Object?> _geometry(WidgetTester tester) => {
  for (final (style, text) in [..._textStickers, ..._captions])
    '$style:$text': () {
      final paragraph = _paragraph(tester, style, text);
      final resolved = paragraph.text.style!;
      return {
        'size': paragraph.size,
        'paint': MatrixUtils.transformRect(
          paragraph.getTransformTo(null),
          paragraph.paintBounds,
        ),
        'glyphs': paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: text.length),
            )
            .map((box) => box.toRect())
            .toList(),
        'height': resolved.height,
        'spacing': resolved.letterSpacing,
        'font': resolved.fontFamily,
        'sizeInDocument': resolved.fontSize,
        'weight': resolved.fontWeight,
      };
    }(),
  for (final style in _vectorStickerColors.keys)
    '$style:vector': () {
      final paint = find.descendant(
        of: find.byKey(ValueKey('artwork-$style')),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter != null,
        ),
      );
      final render = tester.renderObject<RenderCustomPaint>(paint);
      return {
        'size': render.size,
        'paint': MatrixUtils.transformRect(
          render.getTransformTo(null),
          render.paintBounds,
        ),
        'painter': tester.widget<CustomPaint>(paint).painter.runtimeType,
      };
    }(),
};

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });
  testWidgets(
    'basic heart leaf and clover paint solid vector shapes without glyph fonts',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final reference = <String, List<int>>{};
      for (final (print, staticStickers) in [
        (false, false),
        (false, true),
        (true, false),
      ]) {
        await _mount(
          tester,
          SnapFitTheme.dark(),
          scale: 1.8,
          print: print,
          staticStickers: staticStickers,
        );
        for (final entry in _vectorStickerColors.entries) {
          final artwork = find.byKey(ValueKey('artwork-${entry.key}'));
          expect(
            find.descendant(of: artwork, matching: find.byType(Text)),
            findsNothing,
          );
          final vector = find.descendant(
            of: artwork,
            matching: find.byWidgetPredicate(
              (widget) => widget is CustomPaint && widget.painter != null,
            ),
          );
          expect(vector, findsOneWidget);
          final painter = tester.widget<CustomPaint>(vector).painter!;
          await tester.runAsync(() async {
            final recorder = ui.PictureRecorder();
            painter.paint(Canvas(recorder), const Size(90, 100));
            final picture = recorder.endRecording();
            try {
              final image = await picture.toImage(90, 100);
              try {
                final data = (await image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                ))!;
                final pixels = data.buffer
                    .asUint8List(data.offsetInBytes, data.lengthInBytes)
                    .toList();
                final argb = entry.value.toARGB32();
                var solid = 0;
                var minX = 90, minY = 100, maxX = 0, maxY = 0;
                for (var y = 0; y < 100; y++) {
                  for (var x = 0; x < 90; x++) {
                    final offset = (y * 90 + x) * 4;
                    if (pixels[offset + 3] == 0) continue;
                    minX = x < minX ? x : minX;
                    minY = y < minY ? y : minY;
                    maxX = x > maxX ? x : maxX;
                    maxY = y > maxY ? y : maxY;
                    if (pixels[offset] == (argb >> 16 & 255) &&
                        pixels[offset + 1] == (argb >> 8 & 255) &&
                        pixels[offset + 2] == (argb & 255) &&
                        pixels[offset + 3] == 255)
                      solid++;
                  }
                }
                expect(solid, greaterThan(500), reason: entry.key);
                expect(maxX - minX, greaterThan(40), reason: entry.key);
                expect(maxY - minY, greaterThan(50), reason: entry.key);
                expect(pixels[3], 0, reason: 'The shape leaves corner space.');
                reference.putIfAbsent(entry.key, () => pixels);
                expect(pixels, reference[entry.key], reason: entry.key);
              } finally {
                image.dispose();
              }
            } finally {
              picture.dispose();
            }
          });
        }
      }
    },
  );
  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets(
        'saved emoji and frame glyphs retain legacy geometry ${dark ? 'dark' : 'light'} $scale',
        (tester) async {
          tester.view.physicalSize = const Size(900, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final current = dark ? SnapFitTheme.dark() : SnapFitTheme.light();
          final legacyBody =
              (dark
                      ? ThemeData.dark(useMaterial3: true)
                      : ThemeData.light(useMaterial3: true))
                  .textTheme
                  .apply(fontFamily: 'NotoSans')
                  .bodyMedium!;
          final legacy = current.copyWith(
            textTheme: current.textTheme.copyWith(bodyMedium: legacyBody),
          );
          await _mount(tester, legacy, scale: scale);
          final reference = _geometry(tester);
          await _mount(tester, current, scale: scale);
          expect(_geometry(tester), reference);
          final changed = current.copyWith(
            textTheme: current.textTheme.copyWith(
              bodyMedium: current.textTheme.bodyMedium!.copyWith(
                fontFamily: 'FigmaHand',
                fontWeight: FontWeight.w800,
                height: 2.2,
                letterSpacing: 4,
              ),
            ),
          );
          await _mount(tester, changed, scale: scale);
          expect(_geometry(tester), reference);
          for (final (style, text) in [..._textStickers, ..._captions]) {
            final resolved = _paragraph(tester, style, text).text.style!;
            expect(resolved.height, 1.43);
            expect(resolved.letterSpacing, .25);
          }
        },
      );
    }
  }

  testWidgets('static sticker previews use the same saved glyph geometry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, SnapFitTheme.light());
    final reference = _geometry(tester);
    await _mount(tester, SnapFitTheme.light(), staticStickers: true);
    expect(_geometry(tester), reference);
  });

  testWidgets(
    'print preserves its independent unscaled frame and emoji baseline',
    (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _mount(tester, SnapFitTheme.light(), print: true);
      final reference = _geometry(tester);
      await _mount(tester, SnapFitTheme.dark(), scale: 1.8, print: true);
      expect(_geometry(tester), reference);
      for (final (style, text) in [..._textStickers, ..._captions]) {
        final paragraph = _paragraph(tester, style, text);
        expect(paragraph.text.style!.height, isNull);
        expect(paragraph.text.style!.letterSpacing, isNull);
        expect(paragraph.textScaler.scale(14), 14);
      }
    },
  );

  testWidgets(
    'authored typography inside a photo frame retains its own values',
    (tester) async {
      const textStyle = TextStyle(
        fontFamily: 'NotoSans',
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: Color(0xFFBA4262),
        height: 1.9,
        letterSpacing: 1.25,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: SnapFitTheme.dark(),
          home: Scaffold(
            body: ProviderScope(
              child: Consumer(
                builder: (context, ref, _) {
                  final builder = LayerBuilder(
                    LayerInteractionManager.preview(
                      ref,
                      () => const Size(300, 200),
                    ),
                    () => const Size(300, 200),
                  );
                  return SizedBox(
                    width: 300,
                    height: 200,
                    child: builder.buildPhotoFrame(
                      LayerModel(
                        id: 'authored-photo',
                        type: LayerType.image,
                        position: Offset.zero,
                        width: 300,
                        height: 200,
                        imageBackground: 'vhs',
                      ),
                      const Text('사진 원본', style: textStyle),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('사진 원본'),
          matching: find.byType(RichText),
        ),
      );
      final rendered = paragraph.text.style!;
      expect(rendered.height, textStyle.height);
      expect(rendered.letterSpacing, textStyle.letterSpacing);
      expect(rendered.fontFamily, textStyle.fontFamily);
      expect(rendered.fontSize, textStyle.fontSize);
      expect(rendered.fontWeight, textStyle.fontWeight);
      expect(rendered.color, textStyle.color);
      expect(tester.takeException(), isNull);
    },
  );
}
