import '../support/store_detail_loading.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_pages.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_original_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;

PremiumTemplate _template(String Function() builder) => PremiumTemplate(
  id: -40001,
  title: '상세 성능 검증용 디자인',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 100,
  userCount: 0,
  isPremium: true,
  documentBuilder: builder,
);

PremiumTemplate _workerTemplate(SendPort events, String source) {
  final uiIsolate = Isolate.current.hashCode;
  return _template(() {
    if (Isolate.current.hashCode == uiIsolate)
      throw StateError('UI document generation');
    events.send('built');
    return source;
  });
}

String _document() {
  Map<String, dynamic> edition(int width, {int height = 500}) => {
    'designWidth': width,
    'designHeight': height,
    'pages': [
      for (var i = 0; i < 101; i++)
        {
          'layers': [
            {
              'id': 'page-$i',
              'type': 'decoration',
              'x': .1,
              'y': .1,
              'width': .8,
              'height': .8,
              'decorationFillColor': '#F0E9D4',
            },
          ],
        },
    ],
  };
  return jsonEncode({
    ...edition(500),
    'variants': {
      'square': edition(500),
      'landscape4x3': edition(800, height: 600),
    },
  });
}

typedef _MaterialReview = ({ThemeData theme, MaterialDetailScreen detail});

Widget _materialCacheApp(ValueNotifier<_MaterialReview> configuration) =>
    ProviderScope(
      overrides: [
        pointShopCatalogProvider.overrideWith((ref) async => []),
        ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
      ],
      child: ValueListenableBuilder<_MaterialReview>(
        valueListenable: configuration,
        builder: (_, value, __) => MaterialApp(
          theme: value.theme,
          themeAnimationDuration: Duration.zero,
          home: value.detail,
        ),
      ),
    );

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets('material zoom round trips reuse one source widget', (
    tester,
  ) async {
    var builds = 0;
    await tester.pumpWidget(
      reviewApp(
        MaterialDetailScreen(
          productKey: 'sticker:review',
          favoriteKey: 'review',
          title: '소재 원본 재사용',
          type: '스티커',
          preview: (_) {
            builds++;
            return ColoredBox(color: Colors.teal, child: Text('원본 $builds'));
          },
        ),
      ),
    );
    await settleStoreDetail(tester);
    expect(builds, 1);
    final source = tester
        .widget<MaterialOriginalPreview>(find.byType(MaterialOriginalPreview))
        .child;
    for (var visit = 0; visit < 3; visit++) {
      await tester.tap(find.byTooltip('소재 크게 보기'));
      await settleStoreDetail(tester);
      expect(builds, 1);
      final zoomSource = tester
          .widget<MaterialOriginalPreview>(
            find.descendant(
              of: find.byType(InteractiveViewer),
              matching: find.byType(MaterialOriginalPreview),
            ),
          )
          .child;
      expect(identical(zoomSource, source), isTrue);
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(builds, 1);
    }
    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  storeDetailTestWidgets(
    'theme changes refresh cached material including an open zoom',
    (tester) async {
      var builds = 0;
      final detail = MaterialDetailScreen(
        productKey: 'sticker:review',
        favoriteKey: 'review',
        title: '소재 테마 갱신',
        type: '스티커',
        preview: (context) {
          builds++;
          return ColoredBox(
            key: const ValueKey('theme-aware-material-source'),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.orange
                : Colors.teal,
          );
        },
      );
      final configuration = ValueNotifier<_MaterialReview>((
        theme: SnapFitTheme.light(),
        detail: detail,
      ));
      addTearDown(configuration.dispose);
      await tester.pumpWidget(_materialCacheApp(configuration));
      await settleStoreDetail(tester);
      expect(builds, 1);
      await tester.tap(find.byTooltip('소재 크게 보기'));
      await settleStoreDetail(tester);
      expect(builds, 1);
      configuration.value = (theme: SnapFitTheme.dark(), detail: detail);
      await settleStoreDetail(tester);
      expect(builds, 2);
      final zoomSource = find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byKey(const ValueKey('theme-aware-material-source')),
      );
      expect(tester.widget<ColoredBox>(zoomSource).color, Colors.orange);
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(builds, 2);
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('theme-aware-material-source')),
            )
            .color,
        Colors.orange,
      );
      configuration.value = (theme: SnapFitTheme.light(), detail: detail);
      await settleStoreDetail(tester);
      expect(builds, 3);
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('theme-aware-material-source')),
            )
            .color,
        Colors.teal,
      );
      await tester.tap(find.byTooltip('소재 크게 보기'));
      await settleStoreDetail(tester);
      expect(builds, 3);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'material identity and preview builder changes refresh the source',
    (tester) async {
      var firstBuilds = 0;
      var replacementBuilds = 0;
      Widget first(BuildContext context) {
        firstBuilds++;
        return ColoredBox(color: Colors.teal);
      }

      Widget replacement(BuildContext context) {
        replacementBuilds++;
        return ColoredBox(color: Colors.orange);
      }

      MaterialDetailScreen detail(
        String id,
        WidgetBuilder preview, {
        String title = '소재 갱신',
      }) => MaterialDetailScreen(
        productKey: 'sticker:$id',
        favoriteKey: id,
        title: title,
        type: '스티커',
        preview: preview,
      );
      final theme = SnapFitTheme.light();
      final configuration = ValueNotifier<_MaterialReview>((
        theme: theme,
        detail: detail('review', first),
      ));
      addTearDown(configuration.dispose);
      await tester.pumpWidget(_materialCacheApp(configuration));
      await settleStoreDetail(tester);
      final state = tester.state(find.byType(MaterialDetailScreen));
      expect(firstBuilds, 1);
      configuration.value = (
        theme: theme,
        detail: detail('review', first, title: '제목만 변경'),
      );
      await settleStoreDetail(tester);
      expect(firstBuilds, 1);
      configuration.value = (theme: theme, detail: detail('another', first));
      await settleStoreDetail(tester);
      expect(
        identical(tester.state(find.byType(MaterialDetailScreen)), state),
        isTrue,
      );
      expect(firstBuilds, 2);
      configuration.value = (
        theme: theme,
        detail: detail('another', replacement),
      );
      await settleStoreDetail(tester);
      expect(replacementBuilds, 1);
      final source = tester
          .widget<MaterialOriginalPreview>(find.byType(MaterialOriginalPreview))
          .child;
      expect((source as ColoredBox).color, Colors.orange);
      await tester.tap(find.byTooltip('소재 크게 보기'));
      await settleStoreDetail(tester);
      expect(replacementBuilds, 1);
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(replacementBuilds, 1);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets('material pinch reuses the painted source artwork', (
    tester,
  ) async {
    await tester.pumpWidget(
      reviewApp(
        MaterialDetailScreen(
          productKey: 'sticker:review',
          favoriteKey: 'review',
          title: '소재 확대 성능 검증',
          type: '스티커',
          preview: (_) => const Center(child: Text('도안의 선과 글')),
        ),
      ),
    );
    await settleStoreDetail(tester);
    await tester.tap(find.byTooltip('소재 크게 보기'));
    await settleStoreDetail(tester);
    final viewer = find.byType(InteractiveViewer);
    expect(viewer, findsOneWidget);
    final lettering = {
      for (final element
          in find
              .descendant(of: viewer, matching: find.byType(RichText))
              .evaluate())
        element.renderObject,
    };
    expect(lettering, isNotEmpty);
    var paints = 0;
    final previous = debugOnProfilePaint;
    debugOnProfilePaint = (object) {
      previous?.call(object);
      if (lettering.contains(object)) paints++;
    };
    try {
      final center = tester.getCenter(viewer);
      final left = await tester.startGesture(
        center - const Offset(35, 0),
        pointer: 7,
      );
      final right = await tester.startGesture(
        center + const Offset(35, 0),
        pointer: 8,
      );
      for (var frame = 1; frame <= 8; frame++) {
        await left.moveTo(center - Offset(35 + frame * 6, 0));
        await right.moveTo(center + Offset(35 + frame * 6, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await left.up();
      await right.up();
      await settleStoreDetail(tester);
      final transform = tester.widget<Transform>(
        find.descendant(of: viewer, matching: find.byType(Transform)).first,
      );
      expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1));
      expect(paints, 0, reason: 'Pinching must reuse the material artwork');
      expect(tester.takeException(), isNull);
    } finally {
      debugOnProfilePaint = previous;
    }
    await tester.tap(find.byTooltip('닫기'));
    await settleStoreDetail(tester);
    expect(viewer, findsNothing);
    expect(tester.binding.hasScheduledFrame, false);
  });

  storeDetailTestWidgets(
    'repeated material zoom and pan release dialog painting layers',
    (tester) async {
      await tester.pumpWidget(
        reviewApp(
          MaterialDetailScreen(
            productKey: 'sticker:review',
            favoriteKey: 'review',
            title: '소재 반복 확대 검증',
            type: '스티커',
            preview: (_) => const Center(child: Text('소재의 글과 장식')),
          ),
        ),
      );
      await settleStoreDetail(tester);
      for (var visit = 0; visit < 6; visit++) {
        await tester.tap(find.byTooltip('소재 크게 보기'));
        await settleStoreDetail(tester);
        final viewer = find.byType(InteractiveViewer);
        final transformFinder = find
            .descendant(of: viewer, matching: find.byType(Transform))
            .first;
        expect(
          tester
              .widget<Transform>(transformFinder)
              .transform
              .getMaxScaleOnAxis(),
          1,
        );
        final center = tester.getCenter(viewer);
        final left = await tester.startGesture(center - const Offset(40, 0));
        final right = await tester.startGesture(center + const Offset(40, 0));
        for (var frame = 1; frame <= 5; frame++) {
          await left.moveTo(center - Offset(40 + frame * 10, 0));
          await right.moveTo(center + Offset(40 + frame * 10, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await left.up();
        await right.up();
        await settleStoreDetail(tester);
        final before = Matrix4.copy(
          tester.widget<Transform>(transformFinder).transform,
        );
        expect(before.getMaxScaleOnAxis(), greaterThan(1));
        await tester.drag(viewer, const Offset(60, 20));
        await tester.pump();
        expect(
          tester.widget<Transform>(transformFinder).transform.getTranslation(),
          isNot(before.getTranslation()),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find
              .descendant(of: viewer, matching: find.byType(RepaintBoundary))
              .first,
        );
        final layer = boundary.debugLayer!;
        // Close while panning may still have a deceleration animation.
        await tester.tap(find.byTooltip('닫기'));
        await settleStoreDetail(tester);
        expect(boundary.debugDisposed, isTrue);
        expect(layer.debugDisposed, isTrue);
        expect(viewer, findsNothing);
        expect(
          find.byKey(const ValueKey('material-detail-stage')),
          findsOneWidget,
        );
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      }
    },
  );

  storeDetailTestWidgets(
    'entry paints first; switches and zoom reuse one prepared document',
    (tester) async {
      var builds = 0;
      final source = _document();
      final events = ReceivePort();
      events.listen((_) => builds++);
      addTearDown(events.close);
      final template = _workerTemplate(events.sendPort, source);
      await tester.pumpWidget(
        reviewApp(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => TemplateDetailScreen(template: template),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        find.byType(CatalogCoverSkeleton, skipOffstage: false),
        findsOneWidget,
      );
      expect(builds, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(builds, 0);
      await settleStoreDetail(tester);
      expect(builds, 1);

      final selector = find.byKey(const ValueKey('template-size-selector'));
      final sizes = tester.widget<DropdownButtonFormField<String>>(selector);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: selector,
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(
        dropdown.items!.map((item) => item.value),
        contains('REDP_200X150_SOFT'),
      );
      sizes.onChanged!('REDP_200X150_SOFT');
      await settleStoreDetail(tester);
      await tester.tap(find.text('내지'));
      await settleStoreDetail(tester);
      await tester.tap(find.byTooltip('전체 미리보기'));
      await settleStoreDetail(tester);
      final viewer = tester.widget<TemplateFullScreenView>(
        find.byType(TemplateFullScreenView),
      );
      final pages = viewer.parsedPages as TemplateDetailPages;
      expect(viewer.designCanvasSize, const Size(800, 600));
      expect(pages.length, 101);
      expect(pages.cache.length, lessThan(101));
      tester.binding.handleMemoryPressure();
      expect(pages.cache.length, 0);
      final pager = find.descendant(
        of: find.byType(TemplateFullScreenView),
        matching: find.byType(PageView),
      );
      tester.widget<PageView>(pager).controller!.jumpToPage(99);
      await settleStoreDetail(tester);
      expect(pages.cache.length, lessThanOrEqualTo(pages.cache.limit));
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(find.text('99–100쪽'), findsOneWidget);
      expect(builds, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(pages.cache.length, 0);
    },
  );

  storeDetailTestWidgets(
    'leaving during entry does not prepare an invisible book',
    (tester) async {
      var builds = 0;
      final events = ReceivePort();
      events.listen((_) => builds++);
      addTearDown(events.close);
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        reviewApp(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('목록')),
            ),
          ),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => TemplateDetailScreen(
              template: _workerTemplate(events.sendPort, _document()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      navigator.currentState!.pop();
      await settleStoreDetail(tester);
      expect(builds, 0);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'price responses reuse material art and rapid zoom opens one viewer',
    (tester) async {
      var previews = 0;
      final price = Completer<List<PointShopProduct>>();
      await tester.pumpWidget(
        reviewApp(
          MaterialDetailScreen(
            productKey: 'sticker:review',
            favoriteKey: 'review',
            title: '검증 소재',
            type: '스티커',
            preview: (_) {
              previews++;
              return const ColoredBox(color: Colors.teal);
            },
          ),
          catalog: () => price.future,
        ),
      );
      await tester.pump();
      final initialPreviews = previews;
      price.complete(const [
        PointShopProduct(
          productKey: 'sticker:review',
          kind: 'sticker',
          assetId: 'review',
          title: '검증 소재',
          pointPrice: 300,
          isActive: true,
        ),
      ]);
      await settleStoreDetail(tester);
      expect(previews, initialPreviews);
      expect(find.text('300P로 구매'), findsOneWidget);
      await tester.tap(find.text('앨범 적용 예시'));
      await settleStoreDetail(tester);
      await tester.tap(find.byKey(const ValueKey('material-example-next')));
      await settleStoreDetail(tester);
      final example = tester.widget<MaterialApplicationPreview>(
        find.byType(MaterialApplicationPreview),
      );
      expect(example.photoIndex, 1);
      final expand = tester.widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('소재 크게 보기'),
          matching: find.byType(IconButton),
        ),
      );
      expand.onPressed!();
      expand.onPressed!();
      await settleStoreDetail(tester);
      expect(find.byType(Dialog), findsOneWidget);
      final zoomExample = tester.widget<MaterialApplicationPreview>(
        find.byType(MaterialApplicationPreview).hitTestable(),
      );
      expect(zoomExample.photoIndex, example.photoIndex);
      await tester.tap(find.byTooltip('닫기'));
      // The underlying route is current before the old dialog finishes removal.
      expand.onPressed!();
      await settleStoreDetail(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(
        tester
            .widget<MaterialApplicationPreview>(
              find.byType(MaterialApplicationPreview),
            )
            .photoIndex,
        1,
      );
      expand.onPressed!();
      await settleStoreDetail(tester);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'preview restores after another route covers its dismissal',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final template = _template(_document);
      await tester.pumpWidget(
        reviewApp(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => TemplateDetailScreen(template: template),
            ),
          ),
        ),
      );
      await settleStoreDetail(tester);
      await tester.tap(find.byTooltip('전체 미리보기'));
      await settleStoreDetail(tester);
      final pager = find.descendant(
        of: find.byType(TemplateFullScreenView),
        matching: find.byType(PageView),
      );
      tester.widget<PageView>(pager).controller!.jumpToPage(17);
      await settleStoreDetail(tester);
      navigator.currentState!.pop();
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('다른 화면')),
          ),
        ),
      );
      await settleStoreDetail(tester);
      expect(find.text('다른 화면'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      navigator.currentState!.pop();
      await settleStoreDetail(tester);
      expect(find.text('17–18쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final material in [false, true]) {
    storeDetailTestWidgets(
      'access is single flight and cannot navigate after leaving (material=$material)',
      (tester) async {
        final template = _template(_document);
        final productKey = material
            ? 'sticker:review'
            : pointShopTemplateKey(template);
        final decision = Completer<bool>();
        var calls = 0;
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          reviewApp(
            ProviderScope(
              overrides: [
                albumCreationDraftStoreProvider.overrideWithValue(
                  MemoryCreationDraftStore(),
                ),
              ],
              child: Navigator(
                key: navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('상세 열기'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => material
                              ? MaterialDetailScreen(
                                  productKey: productKey,
                                  favoriteKey: 'review',
                                  title: '검증 소재',
                                  type: '스티커',
                                  preview: (_) => const SizedBox(),
                                )
                              : TemplateDetailScreen(template: template),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            catalog: () async => [
              PointShopProduct(
                productKey: productKey,
                kind: material ? 'sticker' : 'template',
                assetId: 'review',
                title: '검증 상품',
                pointPrice: 300,
                isActive: true,
              ),
            ],
            gate: (context, ref, {required productKey, required title}) {
              calls++;
              return decision.future;
            },
          ),
        );
        await tester.tap(find.text('상세 열기'));
        await settleStoreDetail(tester);
        final key = ValueKey(
          material ? 'material-access' : 'template-detail-use',
        );
        final action = tester.widget<FilledButton>(find.byKey(key));
        action.onPressed!();
        action.onPressed!();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(calls, 1);
        expect(tester.widget<FilledButton>(find.byKey(key)).onPressed, isNull);
        navigator.currentState!.pop();
        await settleStoreDetail(tester);
        decision.complete(true);
        await settleStoreDetail(tester);
        expect(find.text('상세 열기'), findsOneWidget);
        expect(find.byType(AlbumCreateFlowScreen), findsNothing);
        expect(find.text('사용할 앨범'), findsNothing);
        expect(calls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'full-screen fallback caps both decoded dimensions and preserves aspect',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        reviewApp(
          const TemplateFullScreenView(
            parsedPages: [],
            previewImages: [
              'asset:assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
            ],
          ),
        ),
      );
      await settleStoreDetail(tester);
      final provider =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      expect(provider.width, lessThanOrEqualTo(2048));
      expect(provider.height, lessThanOrEqualTo(2048));
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'image-only detail keeps its authored canvas when opening zoom',
    (tester) async {
      await tester.pumpWidget(
        reviewApp(
          const TemplateDetailScreen(
            guestPreview: true,
            template: PremiumTemplate(
              id: -40002,
              title: '이미지 미리보기',
              coverImageUrl: '',
              pageCount: 1,
              userCount: 0,
              templateJson: '{"designWidth":600,"designHeight":450,"pages":[]}',
              previewImages: [
                'asset:assets/templates/jeju_travel/images/sources/jeju_ocean.jpg',
              ],
            ),
          ),
        ),
      );
      await settleStoreDetail(tester);
      await tester.tap(find.byTooltip('전체 미리보기'));
      await settleStoreDetail(tester);
      final viewer = tester.widget<TemplateFullScreenView>(
        find.byType(TemplateFullScreenView),
      );
      expect(viewer.parsedPages, isEmpty);
      expect(viewer.designCanvasSize, const Size(600, 450));
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'material refresh keeps its paid price and retries a failed update',
    (tester) async {
      final refresh = Completer<List<PointShopProduct>>();
      var reads = 0;
      var accessCalls = 0;
      PointShopProduct product(int price) => PointShopProduct(
        productKey: 'sticker:review',
        kind: 'sticker',
        assetId: 'review',
        title: '검증 소재',
        pointPrice: price,
        isActive: true,
      );
      await tester.pumpWidget(
        reviewApp(
          MaterialDetailScreen(
            productKey: 'sticker:review',
            favoriteKey: 'review',
            title: '검증 소재',
            type: '스티커',
            preview: (_) => const SizedBox(),
          ),
          catalog: () {
            reads++;
            return reads == 1
                ? Future.value([product(300)])
                : reads == 2
                ? refresh.future
                : Future.value([product(550)]);
          },
          gate: (context, ref, {required productKey, required title}) async {
            accessCalls++;
            return false;
          },
        ),
      );
      await settleStoreDetail(tester);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(MaterialDetailScreen)),
      );
      scope.invalidate(pointShopCatalogProvider);
      final update = scope
          .read(pointShopCatalogProvider.future)
          .then<void>((_) {}, onError: (Object error, StackTrace stack) {});
      await tester.pump();
      expect(find.text('300P로 구매'), findsOneWidget);
      expect(find.text('무료로 이용하기'), findsNothing);
      expect(find.text('판매 준비 중'), findsNothing);
      refresh.completeError(StateError('fixture refresh failed'));
      await update;
      await settleStoreDetail(tester);
      expect(find.text('가격 다시 확인'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('material-access')));
      await settleStoreDetail(tester);
      expect(find.text('550P로 구매'), findsOneWidget);
      expect(accessCalls, 0);
      expect(reads, 3);
    },
  );

  for (final material in [false, true]) {
    storeDetailTestWidgets(
      'owned action stays usable while ownership refreshes (material=$material)',
      (tester) async {
        final template = _template(_document);
        final productKey = material
            ? 'sticker:review'
            : pointShopTemplateKey(template);
        final refresh = Completer<Set<String>>();
        var reads = 0;
        await tester.pumpWidget(
          reviewApp(
            ProviderScope(
              overrides: [
                ownedPointShopKeysProvider.overrideWith(
                  (ref) => ++reads == 1
                      ? Future.value({productKey})
                      : refresh.future,
                ),
              ],
              child: material
                  ? MaterialDetailScreen(
                      productKey: productKey,
                      favoriteKey: 'review',
                      title: '검증 소재',
                      type: '스티커',
                      preview: (_) => const SizedBox(),
                    )
                  : TemplateDetailScreen(template: template),
            ),
            catalog: () async => [
              PointShopProduct(
                productKey: productKey,
                kind: material ? 'sticker' : 'template',
                assetId: 'review',
                title: '검증 상품',
                pointPrice: 300,
                isActive: false,
              ),
            ],
          ),
        );
        await settleStoreDetail(tester);
        final type = material ? MaterialDetailScreen : TemplateDetailScreen;
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(type)),
        );
        scope.invalidate(ownedPointShopKeysProvider);
        await tester.pump();
        final action = find.byKey(
          ValueKey(material ? 'material-access' : 'template-detail-use'),
        );
        expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
        expect(
          find.descendant(
            of: action,
            matching: find.text(material ? '사용할 앨범 선택' : '이 디자인으로 시작'),
          ),
          findsOneWidget,
        );
        refresh.complete({productKey});
        await settleStoreDetail(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'repeated detail and zoom visits release controllers and page caches',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var documentReads = 0;
      final source = _document();
      final events = ReceivePort();
      events.listen((_) => documentReads++);
      addTearDown(events.close);
      final template = _workerTemplate(events.sendPort, source);
      await tester.pumpWidget(
        reviewApp(
          Navigator(
            key: navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('앨범 스토어')),
            ),
          ),
        ),
      );
      await settleStoreDetail(tester);
      for (var visit = 0; visit < 6; visit++) {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => TemplateDetailScreen(template: template),
            ),
          ),
        );
        await settleStoreDetail(tester);
        final detailController = tester
            .widget<PageView>(
              find.byKey(const ValueKey('template-spread-pager')),
            )
            .controller!;
        detailController.jumpToPage(visit + 2);
        await settleStoreDetail(tester);
        await tester.tap(find.byTooltip('전체 미리보기'));
        await settleStoreDetail(tester);
        final viewer = tester.widget<TemplateFullScreenView>(
          find.byType(TemplateFullScreenView),
        );
        final pages = viewer.parsedPages as TemplateDetailPages;
        final zoomController = tester
            .widget<PageView>(
              find.descendant(
                of: find.byType(TemplateFullScreenView),
                matching: find.byType(PageView),
              ),
            )
            .controller!;
        zoomController.jumpToPage(visit * 10 + 7);
        await settleStoreDetail(tester);
        expect(pages.cache.length, lessThanOrEqualTo(pages.cache.limit));
        if (visit.isEven) {
          tester.binding.handleMemoryPressure();
          expect(pages.cache.length, 0);
        }
        navigator.currentState!.pop();
        await settleStoreDetail(tester);
        expect(zoomController.hasClients, isFalse);
        expect(detailController.hasClients, isTrue);
        navigator.currentState!.pop();
        await settleStoreDetail(tester);
        expect(detailController.hasClients, isFalse);
        expect(pages.cache.length, 0);
        expect(find.byType(TemplateDetailScreen), findsNothing);
        expect(find.byType(TemplateFullScreenView), findsNothing);
        expect(tester.binding.hasScheduledFrame, isFalse);
        expect(tester.takeException(), isNull);
      }
      expect(documentReads, 6);
    },
  );

  storeDetailTestWidgets(
    'cover round trip preserves a distant interior at 16ms frame cadence',
    (tester) async {
      await tester.pumpWidget(
        reviewApp(TemplateDetailScreen(template: _template(_document))),
      );
      await settleStoreDetail(tester);
      final pager = find.byKey(const ValueKey('template-spread-pager'));
      tester.widget<PageView>(pager).controller!.jumpToPage(40);
      await settleStoreDetail(tester);
      expect(find.text('79–80쪽'), findsOneWidget);
      final tabs = find.byKey(const ValueKey('template-gallery-mode'));
      await tester.tap(find.descendant(of: tabs, matching: find.text('표지')));
      final visited = <String>{};
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final element
            in find
                .descendant(
                  of: pager,
                  matching: find.byType(TemplatePageRenderer),
                )
                .evaluate()) {
          visited.addAll(
            (element.widget as TemplatePageRenderer).layers.map(
              (layer) => layer.id,
            ),
          );
        }
      }
      expect(
        visited.length,
        lessThanOrEqualTo(5),
        reason: 'A tab switch must not prepare intermediate pages',
      );
      await tester.tap(find.descendant(of: tabs, matching: find.text('내지')));
      await tester.pump();
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('79–80쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final material in [false, true]) {
    storeDetailTestWidgets(
      'account reload discards old ownership for access buttons (material=$material)',
      (tester) async {
        final template = _template(_document);
        final productKey = material
            ? 'sticker:review'
            : pointShopTemplateKey(template);
        var account = 0;
        var accessCalls = 0;
        final accountProvider = Provider<int>((ref) => account);
        final pending = Completer<Set<String>>();
        await tester.pumpWidget(
          reviewApp(
            ProviderScope(
              overrides: [
                ownedPointShopKeysProvider.overrideWith((ref) {
                  final current = ref.watch(accountProvider);
                  return current == 0
                      ? Future.value({productKey})
                      : pending.future;
                }),
              ],
              child: material
                  ? MaterialDetailScreen(
                      productKey: productKey,
                      favoriteKey: 'review',
                      title: '검증 소재',
                      type: '스티커',
                      preview: (_) => const SizedBox(),
                    )
                  : TemplateDetailScreen(template: template),
            ),
            catalog: () async => [
              PointShopProduct(
                productKey: productKey,
                kind: material ? 'sticker' : 'template',
                assetId: 'review',
                title: '검증',
                pointPrice: 300,
                isActive: false,
              ),
            ],
            gate: (context, ref, {required productKey, required title}) async {
              accessCalls++;
              return false;
            },
          ),
        );
        await settleStoreDetail(tester);
        final action = find.byKey(
          ValueKey(material ? 'material-access' : 'template-detail-use'),
        );
        expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
        final type = material ? MaterialDetailScreen : TemplateDetailScreen;
        final scope = ProviderScope.containerOf(
          tester.element(find.byType(type)),
        );
        account = 1;
        scope.invalidate(accountProvider);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump();
        expect(scope.read(ownedPointShopKeysProvider).isReloading, isTrue);
        expect(
          scope.read(ownedPointShopKeysProvider).value,
          contains(productKey),
        );
        expect(tester.widget<FilledButton>(action).onPressed, isNull);
        expect(find.text('구매 완료'), findsNothing);
        expect(accessCalls, 0);
        pending.complete({});
        await settleStoreDetail(tester);
        expect(tester.widget<FilledButton>(action).onPressed, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
