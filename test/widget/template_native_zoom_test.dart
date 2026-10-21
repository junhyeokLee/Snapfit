import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

const _emit = bool.fromEnvironment('SELECTION_MEMORY_IMAGES');

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

List<List<LayerModel>> _pages() => [
  for (var index = 0; index < 4; index++)
    [
      LayerModel(
        id: 'paper-$index',
        type: LayerType.decoration,
        position: Offset.zero,
        width: 500,
        height: 500,
        decorationFillColor: '#F8F5EE',
      ),
      LayerModel(
        id: 'title-$index',
        type: LayerType.text,
        position: const Offset(48, 72),
        width: 404,
        height: 100,
        text: index == 0 ? '우리의 여행' : '여행의 기록 $index',
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 40,
          color: Color(0xFF17332F),
          height: 1.3,
        ),
      ),
      LayerModel(
        id: 'body-$index',
        type: LayerType.text,
        position: const Offset(48, 220),
        width: 404,
        height: 180,
        text: '천천히 걸으며 만난 장면들을 기억합니다.\n사진과 함께 그날의 이야기를 남겨요.',
        textStyle: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 18,
          height: 1.5,
          color: Color(0xFF17332F),
        ),
      ),
    ],
];

Widget _app(Widget child, {double textScale = 1, GlobalKey? boundary}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      builder: (context, child) => RepaintBoundary(
        key: boundary,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: child!,
        ),
      ),
      home: child,
    );

void _viewport(WidgetTester tester, Size size, {bool inset = false}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (inset) {
    tester.view.padding = size.width > size.height
        ? const FakeViewPadding(left: 32, right: 24, bottom: 24)
        : const FakeViewPadding(top: 24, bottom: 24);
  }
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Matrix4 _transform(WidgetTester tester, int page) => tester
    .widget<Transform>(
      find.byKey(ValueKey('template-native-page-transform-$page')),
    )
    .transform
    .clone();

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 70));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

void _expectArtworkBounds(WidgetTester tester, Rect fittedPage, Rect viewport) {
  final transform = _transform(tester, 0);
  final page = MatrixUtils.transformRect(
    transform,
    fittedPage.shift(-viewport.topLeft),
  ).shift(viewport.topLeft);
  void expectAxis(double start, double end, double leading, double trailing) {
    if (end - start <= trailing - leading + .01) {
      expect((start + end) / 2, closeTo((leading + trailing) / 2, .01));
    } else {
      expect(start, lessThanOrEqualTo(leading + .01));
      expect(end, greaterThanOrEqualTo(trailing - .01));
    }
  }

  expectAxis(page.left, page.right, viewport.left, viewport.right);
  expectAxis(page.top, page.bottom, viewport.top, viewport.bottom);
}

Future<void> _memoryImage(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String id,
) async {
  if (!_emit) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final rendered = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
      // RAM protocol only: do not create preview or image files.
      // ignore: avoid_print
      print(
        'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': rendered.width, 'height': rendered.height, 'base64': base64Encode(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
      );
    } finally {
      rendered.dispose();
    }
  });
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final raw in manifest.whereType<Map>()) {
      final loader = FontLoader(raw['family'] as String);
      for (final font in (raw['fonts'] as List).whereType<Map>()) {
        loader.addFont(rootBundle.load(font['asset'] as String));
      }
      await loader.load();
    }
  });

  testWidgets(
    'native 1x swipe still changes pages and reports the viewed page',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final viewed = <int>[];
      await tester.pumpWidget(
        _app(
          TemplateFullScreenView(
            parsedPages: _pages(),
            previewImages: const [],
            designCanvasSize: const Size(500, 500),
            preserveTypography: true,
            onPageChanged: viewed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('template-native-page-view')),
        const Offset(-270, 0),
      );
      await tester.pumpAndSettle();
      expect(viewed, [1]);
      expect(find.text('2 / 4'), findsOneWidget);
      expect(_transform(tester, 1).getMaxScaleOnAxis(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'double tap anchors at the tap and zoomed drag pans the same page',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final viewed = <int>[];
      final pages = _pages();
      await tester.pumpWidget(
        _app(
          TemplateFullScreenView(
            parsedPages: pages,
            previewImages: const [],
            designCanvasSize: const Size(500, 500),
            preserveTypography: true,
            onPageChanged: viewed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // At 2x this square page remains shorter than the viewport, so its
      // vertical center stays fixed while the horizontal tap stays anchored.
      const focal = Offset(125, 422);
      await _doubleTapAt(tester, focal);
      final beforePan = _transform(tester, 0);
      expect(beforePan.getMaxScaleOnAxis(), 2);
      expect(
        (MatrixUtils.transformPoint(beforePan, focal) - focal).distance,
        lessThan(.01),
      );
      expect(
        tester
            .widget<PageView>(
              find.byKey(const ValueKey('template-native-page-view')),
            )
            .physics,
        isA<NeverScrollableScrollPhysics>(),
      );
      await tester.dragFrom(const Offset(195, 450), const Offset(90, 45));
      await tester.pumpAndSettle();
      expect(viewed, isEmpty);
      expect(
        _transform(tester, 0).getTranslation().x,
        greaterThan(beforePan.getTranslation().x),
      );
      expect(pages[0][2].text, contains('그날의 이야기를 남겨요.'));
      await tester.tap(find.byTooltip('화면에 맞추기'));
      await tester.pumpAndSettle();
      expect(_transform(tester, 0).getMaxScaleOnAxis(), 1);
      await tester.drag(
        find.byKey(const ValueKey('template-native-page-view')),
        const Offset(-270, 0),
      );
      await tester.pumpAndSettle();
      expect(viewed, [1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('two finger pinch magnifies without turning the page', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final viewed = <int>[];
    await tester.pumpWidget(
      _app(
        TemplateFullScreenView(
          parsedPages: _pages(),
          previewImages: const [],
          designCanvasSize: const Size(500, 500),
          preserveTypography: true,
          onPageChanged: viewed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    const center = Offset(195, 420);
    final left = await tester.startGesture(
      center - const Offset(40, 0),
      pointer: 11,
    );
    final right = await tester.startGesture(
      center + const Offset(40, 0),
      pointer: 12,
    );
    for (var step = 1; step <= 5; step++) {
      await left.moveTo(center - Offset(40 + 15.0 * step, 0));
      await right.moveTo(center + Offset(40 + 15.0 * step, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(_transform(tester, 0).getMaxScaleOnAxis(), greaterThan(1.3));
    expect(viewed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('horizontal pinch claims both pointers before page drag slop', (
    tester,
  ) async {
    _viewport(tester, const Size(844, 390));
    final viewed = <int>[];
    await tester.pumpWidget(
      _app(
        TemplateFullScreenView(
          parsedPages: _pages(),
          previewImages: const [],
          initialIndex: 1,
          designCanvasSize: const Size(500, 500),
          onPageChanged: viewed.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    const center = Offset(422, 195);
    final left = await tester.startGesture(
      center - const Offset(250, 0),
      pointer: 21,
    );
    final right = await tester.startGesture(
      center + const Offset(250, 0),
      pointer: 22,
    );
    // One finger now exceeds horizontal drag slop while scale/focal change
    // is still below ScaleGestureRecognizer's ordinary acceptance limits.
    await left.moveTo(center - const Offset(270, 0));
    await tester.pump(const Duration(milliseconds: 20));
    for (var step = 1; step <= 5; step++) {
      await right.moveTo(center + Offset(250 + 20.0 * step, 0));
      if (step > 1) {
        await left.moveTo(center - Offset(250 + 20.0 * step, 0));
      }
      await tester.pump(const Duration(milliseconds: 20));
    }
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
    expect(_transform(tester, 1).getMaxScaleOnAxis(), greaterThan(1.3));
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('template-native-page-view')),
    );
    expect(pageView.controller!.page, closeTo(1, .001));
    expect(viewed, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final viewport in [const Size(390, 844), const Size(844, 390)]) {
    for (final canvas in [const Size(800, 600), const Size(600, 800)]) {
      testWidgets(
        'native pan bounds follow the fitted page $canvas in $viewport',
        (tester) async {
          _viewport(tester, viewport);
          final viewed = <int>[];
          await tester.pumpWidget(
            _app(
              TemplateFullScreenView(
                parsedPages: _pages(),
                previewImages: const [],
                designCanvasSize: canvas,
                onPageChanged: viewed.add,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final stage = find.byKey(
            const ValueKey('template-native-zoom-stage-0'),
          );
          final stageRect = tester.getRect(stage);
          final fittedPage = tester.getRect(
            find.descendant(
              of: stage,
              matching: find.byType(TemplatePageRenderer),
            ),
          );
          // At 1.5x one axis is still letterboxed. At 4x both axes exceed
          // the viewport. Every corner pan must keep the actual page in view.
          for (final target in [1.5, 4.0]) {
            while (_transform(tester, 0).getMaxScaleOnAxis() < target) {
              await tester.tap(find.byTooltip('확대'));
              await tester.pumpAndSettle();
            }
            _expectArtworkBounds(tester, fittedPage, stageRect);
            for (final pan in [
              const Offset(2000, 2000),
              const Offset(-4000, -4000),
              const Offset(4000, -4000),
              const Offset(-4000, 4000),
            ]) {
              await tester.dragFrom(stageRect.center, pan);
              await tester.pumpAndSettle();
              _expectArtworkBounds(tester, fittedPage, stageRect);
            }
          }
          expect(viewed, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'explicit page movement resets zoom and retains callback indices',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final viewed = <int>[];
      await tester.pumpWidget(
        _app(
          TemplateFullScreenView(
            parsedPages: _pages(),
            previewImages: const [],
            initialIndex: 1,
            designCanvasSize: const Size(500, 500),
            onPageChanged: viewed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
      expect(_transform(tester, 1).getMaxScaleOnAxis(), 1.5);
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      expect(viewed, [2]);
      expect(find.text('3 / 4'), findsOneWidget);
      expect(_transform(tester, 2).getMaxScaleOnAxis(), 1);
      await _doubleTapAt(tester, const Offset(150, 450));
      expect(_transform(tester, 2).getMaxScaleOnAxis(), 2);
      await _doubleTapAt(tester, const Offset(150, 450));
      expect(_transform(tester, 2).getMaxScaleOnAxis(), 1);
      expect(viewed, [2]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closing and reopening keeps the last viewed page with fresh zoom',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      var lastViewed = 1;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => TemplateFullScreenView(
                      parsedPages: _pages(),
                      previewImages: const [],
                      initialIndex: lastViewed,
                      designCanvasSize: const Size(500, 500),
                      onPageChanged: (index) => lastViewed = index,
                    ),
                  ),
                ),
                child: const Text('내지 살펴보기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('내지 살펴보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(lastViewed, 2);
      await tester.tap(find.text('내지 살펴보기'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4'), findsOneWidget);
      expect(_transform(tester, 2).getMaxScaleOnAxis(), 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 320),
    const Size(320, 568),
    const Size(844, 320),
  ]) {
    testWidgets('native zoom controls remain reachable at 200% text $size', (
      tester,
    ) async {
      _viewport(tester, size, inset: true);
      await tester.pumpWidget(
        _app(
          TemplateFullScreenView(
            parsedPages: _pages(),
            previewImages: const [],
            initialIndex: 1,
            designCanvasSize: const Size(500, 500),
          ),
          textScale: 2,
        ),
      );
      await tester.pumpAndSettle();
      for (final tooltip in ['확대', '화면에 맞추기', '닫기', '다음 페이지']) {
        final control = find.byTooltip(tooltip);
        final rect = tester.getRect(control);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(size.width));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
      }
      await tester.tap(find.byTooltip('확대'));
      await tester.pumpAndSettle();
      expect(_transform(tester, 1).getMaxScaleOnAxis(), 1.5);
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      expect(find.text('3 / 4'), findsOneWidget);
      expect(_transform(tester, 2).getMaxScaleOnAxis(), 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rotation resets the view transform and preserves the page', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    await tester.pumpWidget(
      _app(
        TemplateFullScreenView(
          parsedPages: _pages(),
          previewImages: const [],
          initialIndex: 2,
          designCanvasSize: const Size(500, 500),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('확대'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(find.text('3 / 4'), findsOneWidget);
    expect(_transform(tester, 2).getMaxScaleOnAxis(), 1);
    expect(tester.takeException(), isNull);
  });

  if (_emit)
    testWidgets('native text inspection emits two RAM frames without files', (
      tester,
    ) async {
      _viewport(tester, const Size(390, 844));
      final design = publishedPremiumTemplates.firstWhere(
        (template) => template.category == '여행',
      );
      final source = jsonDecode(design.templateJson!) as Map<String, dynamic>;
      final canvas = Size(
        (source['designWidth'] as num).toDouble(),
        (source['designHeight'] as num).toDouble(),
      );
      final pages = templateDocumentPages(source)
          .take(3)
          .map(
            (page) => DataTemplateEngine.buildLayersFromJson({
              'strictLayout': true,
              'designWidth': canvas.width,
              'designHeight': canvas.height,
              'layers': page['layers'],
            }, canvas),
          )
          .toList(growable: false);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        _app(
          TemplateFullScreenView(
            parsedPages: pages,
            previewImages: const [],
            initialIndex: 1,
            designCanvasSize: canvas,
            preserveTypography: true,
          ),
          boundary: boundary,
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await tester.pumpAndSettle();
      await _memoryImage(tester, boundary, 'native-text-inspection-fit');
      final texts =
          pages[1].where((layer) => layer.type == LayerType.text).toList()
            ..sort(
              (a, b) => (b.text?.length ?? 0).compareTo(a.text?.length ?? 0),
            );
      final body = texts.first;
      final scale = 390 / canvas.width;
      final pageTop = (844 - canvas.height * scale) / 2;
      final focal = Offset(
        ((body.position.dx + body.width * .5) * scale).clamp(60.0, 330.0),
        (pageTop + (body.position.dy + body.height * .5) * scale).clamp(
          120.0,
          700.0,
        ),
      );
      await _doubleTapAt(tester, focal);
      expect(_transform(tester, 1).getMaxScaleOnAxis(), 2);
      await _memoryImage(tester, boundary, 'native-text-inspection-magnified');
      expect(tester.takeException(), isNull);
    });
}
