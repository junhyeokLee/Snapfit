import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/published_premium_templates.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_edition_sheet.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Widget _app(
  Widget home, {
  bool dark = false,
  double textScale = 1,
  Set<String> owned = const {},
  PointShopAccessGate? gate,
  GlobalKey? captureKey,
}) => ProviderScope(
  overrides: [
    pointShopCatalogProvider.overrideWith(
      (ref) async => const [
        PointShopProduct(
          productKey: 'template:vow-keepsake',
          kind: 'template',
          assetId: 'vow-keepsake',
          title: '서약의 기록',
          pointPrice: 1200,
          isActive: true,
        ),
      ],
    ),
    ownedPointShopKeysProvider.overrideWith((ref) async => owned),
    pointShopAccessGateProvider.overrideWithValue(
      gate ??
          (context, ref, {required productKey, required title}) async => false,
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: RepaintBoundary(key: captureKey, child: child!),
      ),
      home: home,
    ),
  ),
);

Future<void> _paint(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('TEMPLATE_EDITION_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/store-selection-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Widget _openSheet({
  ValueChanged<int?>? onResult,
  String? variant,
  String? title,
  PremiumVolume volume = PremiumVolume.wedding,
}) => Scaffold(
  body: Builder(
    builder: (context) => Center(
      child: FilledButton(
        onPressed: () async {
          final selected = await showTemplateEditionSheet(
            context,
            volume: volume,
            title: title ?? volume.title,
            productKey: 'template:${volume.id}',
            initialCount: volume.extendedPages,
            previewVariant: variant,
          );
          onResult?.call(selected);
        },
        child: const Text('분량 보기'),
      ),
    ),
  ),
);

Future<void> _choose(WidgetTester tester, int count) async {
  final option = find.byKey(ValueKey('template-edition-$count'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await _paint(tester);
}

CreationDocumentPreview _preview(WidgetTester tester) =>
    tester.widget<CreationDocumentPreview>(
      find.descendant(
        of: find.byType(TemplateEditionSheet),
        matching: find.byType(CreationDocumentPreview),
      ),
    );

void main() {
  _PaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('edition preview and CTA respect system insets $suffix', (
        tester,
      ) async {
        _size(tester, size);
        final key = GlobalKey();
        int? selected;
        var checks = 0;
        await tester.pumpWidget(
          _app(
            _openSheet(onResult: (value) => selected = value),
            dark: dark,
            captureKey: key,
            gate: (context, ref, {required productKey, required title}) async {
              checks++;
              return true;
            },
          ),
        );
        await tester.tap(find.text('분량 보기'));
        await _paint(tester);
        expect(_preview(tester).pages, hasLength(33));
        final photos = _preview(tester).pages.fold<int>(
          0,
          (count, page) =>
              count + page.where((l) => l.type == LayerType.image).length,
        );
        expect(find.text('사진 자리 $photos개 · 분량별 템플릿 가격 동일'), findsOneWidget);
        final action = find.byKey(const ValueKey('template-edition-continue'));
        expect(action.hitTestable(), findsOneWidget);
        final rect = tester.getRect(action);
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        expect(
          rect.left,
          greaterThanOrEqualTo(size.width > size.height ? 44 : 0),
        );
        expect(
          rect.right,
          lessThanOrEqualTo(size.width - (size.width > size.height ? 24 : 0)),
        );
        expect(checks, 0);
        await _capture(tester, key, 'edition-$suffix');
        await tester.tap(find.byTooltip('다음 페이지'));
        await _paint(tester);
        expect(find.text('1 / 32쪽'), findsOneWidget);
        await _capture(tester, key, 'edition-pages-$suffix');
        await tester.tap(find.byTooltip('이전 페이지'));
        await _paint(tester);
        await _choose(tester, 24);
        expect(_preview(tester).pages, hasLength(25));
        expect(find.text('표지 + 내지 24쪽'), findsOneWidget);
        expect(selected, isNull);
        expect(checks, 0);
        await _capture(tester, key, 'edition-basic-$suffix');
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(selected, 24);
        expect(checks, 0);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'large text keeps edition selection and close reachable $suffix',
        (tester) async {
          _size(tester, size);
          await tester.pumpWidget(
            _app(
              _openSheet(title: '서약을 담아 오래도록 간직하는 우리의 아주 긴 결혼 기록 템플릿'),
              dark: dark,
              textScale: 1.6,
            ),
          );
          await tester.tap(find.text('분량 보기'));
          await _paint(tester);
          await _choose(tester, 24);
          expect(find.text('표지 + 내지 24쪽'), findsOneWidget);
          expect(
            find
                .byKey(const ValueKey('template-edition-continue'))
                .hitTestable(),
            findsOneWidget,
          );
          expect(find.byTooltip('분량 선택 닫기').hitTestable(), findsOneWidget);
          await tester.tap(find.byTooltip('분량 선택 닫기'));
          await tester.pumpAndSettle();
          expect(find.byType(TemplateEditionSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final aspect in [null, 'square', 'landscape', 'portrait']) {
    testWidgets('edition preview uses authored $aspect layers and canvas', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(_openSheet(variant: aspect)));
      await tester.tap(find.text('분량 보기'));
      await _paint(tester);
      for (final count in [32, 24]) {
        await _choose(tester, count);
        final document = premiumCatalogDocument(
          PremiumVolume.wedding,
          innerPages: count,
        );
        final shown = aspect == null
            ? document
            : Map<String, dynamic>.from((document['variants'] as Map)[aspect]);
        final canvas = Size(
          (shown['designWidth'] as num).toDouble(),
          (shown['designHeight'] as num).toDouble(),
        );
        final preview = _preview(tester);
        expect(preview.canvas, canvas);
        expect(preview.preserveTypography, isTrue);
        expect(preview.pages, hasLength(count + 1));
        final documentPages = templateDocumentPages(shown);
        for (final index in [0, 1, count]) {
          final authored = DataTemplateEngine.buildLayersFromJson({
            'strictLayout': true,
            'designWidth': canvas.width,
            'designHeight': canvas.height,
            'layers': documentPages[index]['layers'],
          }, canvas);
          expect(
            preview.pages[index]
                .map(
                  (layer) => LayerExportMapper.toJson(
                    layer,
                    canvasSize: canvas,
                    isCover: index == 0,
                  ),
                )
                .toList(),
            authored
                .map(
                  (layer) => LayerExportMapper.toJson(
                    layer,
                    canvasSize: canvas,
                    isCover: index == 0,
                  ),
                )
                .toList(),
          );
          expect(
            preview.pages[index]
                .where((l) => l.type == LayerType.image)
                .every((l) => l.imageUrl != null),
            isTrue,
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'edition switch caches artwork and clamps the inspected last page',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(_app(_openSheet()));
      await tester.tap(find.text('분량 보기'));
      await _paint(tester);
      final extended = _preview(tester).pages;
      for (var index = 0; index < 32; index++) {
        await tester.tap(find.byTooltip('다음 페이지'));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.text('32 / 32쪽'), findsOneWidget);
      await _choose(tester, 24);
      expect(find.text('24 / 24쪽'), findsOneWidget);
      final basic = _preview(tester).pages;
      await _choose(tester, 32);
      expect(_preview(tester).pages, same(extended));
      expect(find.text('24 / 32쪽'), findsOneWidget);
      await _choose(tester, 24);
      expect(_preview(tester).pages, same(basic));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelled edition preserves detail and never checks purchase', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    var checks = 0;
    await tester.pumpWidget(
      _app(
        TemplateDetailScreen(
          template: publishedPremiumTemplates.first,
          selectForCreation: true,
        ),
        gate: (context, ref, {required productKey, required title}) async {
          checks++;
          return false;
        },
      ),
    );
    await _paint(tester);
    final pages = tester
        .widget<CreationTemplatePreview>(find.byType(CreationTemplatePreview))
        .pages;
    await tester.tap(find.text('이 디자인 선택'));
    await _paint(tester);
    await _choose(tester, 24);
    await tester.tap(find.byTooltip('분량 선택 닫기'));
    await tester.pumpAndSettle();
    final detail = tester.widget<CreationTemplatePreview>(
      find.byType(CreationTemplatePreview),
    );
    expect(detail.pages, same(pages));
    expect(detail.isUsing, false);
    expect(checks, 0);
    await tester.tap(find.text('이 디자인 선택'));
    await _paint(tester);
    expect(find.text('표지 + 내지 32쪽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'gate failure unlocks retry; paid and owned selections use the same confirmed edition',
    (tester) async {
      _size(tester, const Size(390, 844));
      AlbumCreationTemplate? selected;
      var checks = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('템플릿 보기'),
                onPressed: () async {
                  selected = await Navigator.push<AlbumCreationTemplate>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TemplateDetailScreen(
                        template: publishedPremiumTemplates.first,
                        selectForCreation: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          owned: {'template:vow-keepsake'},
          gate: (context, ref, {required productKey, required title}) async {
            expect(productKey, 'template:vow-keepsake');
            checks++;
            if (checks == 1) throw StateError('private purchase failure');
            return true;
          },
        ),
      );
      await tester.tap(find.text('템플릿 보기'));
      await _paint(tester);
      await tester.tap(find.text('이 디자인 선택'));
      await _paint(tester);
      await _choose(tester, 24);
      await tester.tap(find.byKey(const ValueKey('template-edition-continue')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(checks, 1);
      expect(find.textContaining('private purchase failure'), findsNothing);
      expect(find.text('디자인 적용을 준비하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.widgetWithText(FilledButton, '이 디자인 선택')).top,
        ),
      );
      await tester.tap(find.text('이 디자인 선택'));
      await _paint(tester);
      expect(find.text('구매 완료'), findsWidgets);
      expect(find.text('표지 + 내지 24쪽'), findsOneWidget);
      final confirmed = _preview(tester);
      await tester.tap(find.byKey(const ValueKey('template-edition-continue')));
      await tester.pumpAndSettle();
      expect(selected!.pages, hasLength(25));
      final prepared = AlbumCreationTemplate.preparePages(
        confirmed.pages,
        sourceCanvas: confirmed.canvas,
        cover: selected!.cover,
      );
      for (var index = 0; index < prepared.length; index++) {
        expect(
          selected!.pages[index]
              .map(
                (layer) => LayerExportMapper.toJson(
                  layer,
                  canvasSize: selected!.pagesCanvasSize!,
                  isCover: index == 0,
                ),
              )
              .toList(),
          prepared[index]
              .map(
                (layer) => LayerExportMapper.toJson(
                  layer,
                  canvasSize: selected!.pagesCanvasSize!,
                  isCover: index == 0,
                ),
              )
              .toList(),
        );
      }
      expect(
        selected!.variants.values.every((pages) => pages.length == 25),
        isTrue,
      );
      expect(
        selected!.pages
            .expand((p) => p)
            .where((l) => l.type == LayerType.image)
            .every((l) => l.imageUrl == null),
        isTrue,
      );
      expect(checks, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final volume in PremiumVolume.values.where(
    (v) => v.pageCounts.length > 1,
  )) {
    testWidgets(
      '${volume.id} exposes only authored 24-${volume.extendedPages} page editions',
      (tester) async {
        _size(tester, const Size(390, 844));
        await tester.pumpWidget(_app(_openSheet(volume: volume)));
        await tester.tap(find.text('분량 보기'));
        await _paint(tester);
        for (final count in volume.pageCounts) {
          await _choose(tester, count);
          expect(_preview(tester).pages, hasLength(count + 1));
          expect(find.text('표지 + 내지 $count쪽'), findsOneWidget);
          expect(
            _preview(
              tester,
            ).pages.expand((p) => p).where((l) => l.type == LayerType.image),
            isNotEmpty,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rotating the edition sheet preserves count and inspected page', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(_app(_openSheet()));
    await tester.tap(find.text('분량 보기'));
    await _paint(tester);
    await tester.tap(find.byTooltip('다음 페이지'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('다음 페이지'));
    await _paint(tester);
    final pages = _preview(tester).pages;
    _size(tester, const Size(844, 390));
    await _paint(tester);
    expect(find.text('2 / 32쪽'), findsOneWidget);
    expect(_preview(tester).pages, same(pages));
    await _choose(tester, 24);
    _size(tester, const Size(390, 844));
    await _paint(tester);
    expect(find.text('2 / 24쪽'), findsOneWidget);
    expect(find.text('표지 + 내지 24쪽'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'shorter confirmed edition clamps detail spread after cancelled purchase',
    (tester) async {
      _size(tester, const Size(390, 844));
      var checks = 0;
      await tester.pumpWidget(
        _app(
          TemplateDetailScreen(template: publishedPremiumTemplates.first),
          gate: (context, ref, {required productKey, required title}) async {
            checks++;
            return false;
          },
        ),
      );
      await _paint(tester);
      final last = find.byKey(const ValueKey('template-spread-thumb-16'));
      await tester.scrollUntilVisible(
        last,
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('template-spread-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.text('31–32쪽'), findsOneWidget);
      await tester.tap(find.text('이 디자인으로 시작'));
      await _paint(tester);
      await _choose(tester, 24);
      await tester.tap(find.byKey(const ValueKey('template-edition-continue')));
      await tester.pumpAndSettle();
      expect(checks, 1);
      expect(find.byType(TemplateEditionSheet), findsNothing);
      expect(find.text('23–24쪽'), findsOneWidget);
      final pager = tester.widget<PageView>(
        find.byKey(const ValueKey('template-spread-pager')),
      );
      expect(pager.controller!.page, 12);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending access is single flight and may finish after closing detail',
    (tester) async {
      _size(tester, const Size(390, 844));
      final access = Completer<bool>();
      var checks = 0;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TemplateDetailScreen(
                      template: publishedPremiumTemplates.first,
                      selectForCreation: true,
                    ),
                  ),
                ),
                child: const Text('템플릿 보기'),
              ),
            ),
          ),
          gate: (context, ref, {required productKey, required title}) {
            checks++;
            return access.future;
          },
        ),
      );
      await tester.tap(find.text('템플릿 보기'));
      await _paint(tester);
      await tester.tap(find.text('이 디자인 선택'));
      await _paint(tester);
      await tester.tap(find.byKey(const ValueKey('template-edition-continue')));
      await _paint(tester);
      final detail = tester.widget<CreationTemplatePreview>(
        find.byType(CreationTemplatePreview),
      );
      detail.onUse();
      await tester.pump();
      expect(checks, 1);
      Navigator.of(tester.element(find.byType(TemplateDetailScreen))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      access.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
