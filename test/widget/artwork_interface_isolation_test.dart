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
  for (final (style, text) in [..._stickers, ..._captions])
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
};

void main() {
  setUpAll(() async {
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });
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
          for (final (style, text) in [..._stickers, ..._captions]) {
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
      for (final (style, text) in [..._stickers, ..._captions]) {
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
