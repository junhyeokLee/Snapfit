import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/material_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_application_preview.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/features/store/presentation/views/template_full_screen_view.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_pages.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../support/store_detail_loading.dart';
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import 'ai_album_start_step_test.dart' show loadCreationFonts;
import 'experience_detail_redesign_test.dart' show reviewApp;

PremiumTemplate _book() => PremiumTemplate(
  id: -40002,
  title: '보기 전환 검증',
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 100,
  userCount: 0,
  templateJson: jsonEncode({
    'designWidth': 500,
    'designHeight': 500,
    'pages': [
      for (var index = 0; index <= 100; index++)
        {
          'layers': [
            {
              'id': 'review-page-$index',
              'type': 'decoration',
              'x': .1,
              'y': .1,
              'width': .8,
              'height': .8,
              'decorationFillColor': '#E5F1EC',
            },
          ],
        },
    ],
  }),
);

class _LiveArtwork extends StatefulWidget {
  const _LiveArtwork({required this.onMount, required this.onDispose});
  final VoidCallback onMount, onDispose;

  @override
  State<_LiveArtwork> createState() => _LiveArtworkState();
}

class _LiveArtworkState extends State<_LiveArtwork> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF087E79));
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets(
    'a distant cover round trip does not build intermediate thumbnail artwork',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        reviewApp(TemplateDetailScreen(template: _book())),
      );
      await settleStoreDetail(tester);
      tester
          .widget<PageView>(find.byKey(const ValueKey('template-spread-pager')))
          .controller!
          .jumpToPage(40);
      await settleStoreDetail(tester);
      expect(find.text('79–80쪽'), findsOneWidget);

      final intermediateThumbnails = <int>{};
      final renderedPages = <String>{};
      final tabs = find.byKey(const ValueKey('template-gallery-mode'));
      for (final label in ['표지', '내지']) {
        await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
        await tester.pump();
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (final element in find.byType(TemplatePageRenderer).evaluate()) {
            renderedPages.addAll(
              (element.widget as TemplatePageRenderer).layers.map(
                (layer) => layer.id,
              ),
            );
          }
          for (final element in find.byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey<String> &&
                key.value.startsWith('template-spread-thumb-');
          }).evaluate()) {
            final key = element.widget.key! as ValueKey<String>;
            final index = int.parse(
              key.value.substring('template-spread-thumb-'.length),
            );
            if (index >= 8 && index <= 32) intermediateThumbnails.add(index);
          }
        }
      }
      expect(find.text('79–80쪽'), findsOneWidget);
      expect(
        intermediateThumbnails,
        isEmpty,
        reason:
            'The gallery prepared ${renderedPages.length} page IDs across a tab round trip; '
            'off-route thumbnail indices were $intermediateThumbnails',
      );
      expect(
        renderedPages.length,
        lessThanOrEqualTo(30),
        reason: 'Only the source and destination previews should be prepared',
      );
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'nearby cover and interior tabs move the vertical thumbnail strip immediately',
    (tester) async {
      tester.view.physicalSize = const Size(648, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        reviewApp(TemplateDetailScreen(template: _book())),
      );
      await settleStoreDetail(tester);
      final strip = tester
          .widget<ListView>(find.byKey(const ValueKey('template-spread-list')))
          .controller!;
      final tabs = find.byKey(const ValueKey('template-gallery-mode'));
      for (final label in ['내지', '표지']) {
        final before = strip.offset;
        await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
        await tester.pump(const Duration(milliseconds: 16));
        final firstFrame = strip.offset;
        await settleStoreDetail(tester);
        expect((strip.offset - before).abs(), greaterThan(1));
        expect(firstFrame, closeTo(strip.offset, .01));
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(648, 320)]) {
    storeDetailTestWidgets(
      'adjacent page controls retain smooth thumbnail movement $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          reviewApp(TemplateDetailScreen(template: _book())),
        );
        await settleStoreDetail(tester);
        final pager = tester
            .widget<PageView>(
              find.byKey(const ValueKey('template-spread-pager')),
            )
            .controller!;
        final strip = tester
            .widget<ListView>(
              find.byKey(const ValueKey('template-spread-list')),
            )
            .controller!;
        pager.jumpToPage(10);
        await settleStoreDetail(tester);
        final before = strip.offset;
        await tester.tap(find.byTooltip('다음 펼침면'));
        final offsets = <double>[];
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          offsets.add(strip.offset);
        }
        await settleStoreDetail(tester);
        final end = strip.offset;
        expect(end, greaterThan(before + 1));
        expect(
          offsets.any((value) => value > before + 1 && value < end - 1),
          isTrue,
          reason:
              'An adjacent selection should keep intermediate animation frames',
        );
        expect(find.text('21–22쪽'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'selecting a distant thumbnail immediately aligns both previews',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        reviewApp(TemplateDetailScreen(template: _book())),
      );
      await settleStoreDetail(tester);
      final pager = tester
          .widget<PageView>(find.byKey(const ValueKey('template-spread-pager')))
          .controller!;
      final strip = tester
          .widget<ListView>(find.byKey(const ValueKey('template-spread-list')))
          .controller!;
      strip.jumpTo(40 * 96);
      await settleStoreDetail(tester);
      final thumbnail = find.byKey(const ValueKey('template-spread-thumb-40'));
      expect(thumbnail.hitTestable(), findsOneWidget);
      expect(pager.page, closeTo(0, .01));
      await tester.tap(thumbnail);
      await tester.pump(const Duration(milliseconds: 16));
      final firstFrame = strip.offset;
      expect(pager.page, closeTo(40, .01));
      await settleStoreDetail(tester);
      expect(firstFrame, closeTo(strip.offset, .01));
      expect(find.text('79–80쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'an adjacent turn jumps a thumbnail strip that was manually scrolled far away',
    (tester) async {
      await tester.pumpWidget(
        reviewApp(TemplateDetailScreen(template: _book())),
      );
      await settleStoreDetail(tester);
      final pager = tester
          .widget<PageView>(find.byKey(const ValueKey('template-spread-pager')))
          .controller!;
      final strip = tester
          .widget<ListView>(find.byKey(const ValueKey('template-spread-list')))
          .controller!;
      pager.jumpToPage(10);
      await settleStoreDetail(tester);
      strip.jumpTo(strip.position.maxScrollExtent);
      await settleStoreDetail(tester);
      final before = strip.offset;
      await tester.tap(find.byTooltip('다음 펼침면'));
      final offsets = <double>[];
      for (var frame = 0; frame < 30; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        offsets.add(strip.offset);
      }
      await settleStoreDetail(tester);
      final end = strip.offset;
      expect(before - end, greaterThan(strip.position.viewportDimension));
      expect(
        offsets.every(
          (value) => (value - before).abs() < .01 || (value - end).abs() < .01,
        ),
        isTrue,
        reason: 'Catching up must not traverse intermediate thumbnails',
      );
      expect(find.text('21–22쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final accessibleNavigation in [false, true]) {
    storeDetailTestWidgets(
      'motion preferences keep page and thumbnail movement immediate: accessibility=$accessibleNavigation',
      (tester) async {
        await tester.pumpWidget(
          reviewApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: !accessibleNavigation,
                  accessibleNavigation: accessibleNavigation,
                ),
                child: TemplateDetailScreen(template: _book()),
              ),
            ),
          ),
        );
        await settleStoreDetail(tester);
        final pager = tester
            .widget<PageView>(
              find.byKey(const ValueKey('template-spread-pager')),
            )
            .controller!;
        final strip = tester
            .widget<ListView>(
              find.byKey(const ValueKey('template-spread-list')),
            )
            .controller!;
        pager.jumpToPage(10);
        await settleStoreDetail(tester);
        await tester.tap(find.byTooltip('다음 펼침면'));
        await tester.pump(const Duration(milliseconds: 16));
        final firstFrame = strip.offset;
        expect(pager.page, closeTo(11, .01));
        await settleStoreDetail(tester);
        expect(firstFrame, closeTo(strip.offset, .01));
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'edition changes keep the clamped interior selected and immediately visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final template = publishedCreationTemplates.firstWhere(
        (item) => item.id == -9501,
      );
      await tester.pumpWidget(
        reviewApp(
          ProviderScope(
            overrides: [
              albumCreationDraftStoreProvider.overrideWithValue(
                MemoryCreationDraftStore(),
              ),
            ],
            child: TemplateDetailScreen(template: template),
          ),
          // The native action correctly stays disabled for an unlisted paid
          // item. This gallery test needs a listed item to open the editions.
          catalog: () async => [
            PointShopProduct(
              productKey: pointShopTemplateKey(template),
              kind: 'template',
              assetId: 'vow-keepsake',
              title: template.title,
              pointPrice: 1800,
              isActive: true,
            ),
          ],
        ),
      );
      await settleStoreDetail(tester);
      final pager = tester
          .widget<PageView>(find.byKey(const ValueKey('template-spread-pager')))
          .controller!;
      final strip = tester
          .widget<ListView>(find.byKey(const ValueKey('template-spread-list')))
          .controller!;
      pager.jumpToPage(16);
      await settleStoreDetail(tester);
      strip.jumpTo(0);
      await settleStoreDetail(tester);
      for (final count in [24, 32]) {
        await tester.tap(find.byKey(const ValueKey('template-detail-use')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final option = find.byKey(ValueKey('template-edition-$count'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(
          find.byKey(const ValueKey('template-edition-continue')),
        );
        await settleStoreDetail(tester);
        expect(find.byType(TemplateDetailScreen), findsOneWidget);
        expect(pager.page, closeTo(12, .01));
        expect(find.text('23–24쪽'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('template-spread-thumb-12')).hitTestable(),
          findsOneWidget,
        );
      }
      final tabs = find.byKey(const ValueKey('template-gallery-mode'));
      for (final label in ['표지', '내지']) {
        await tester.tap(find.descendant(of: tabs, matching: find.text(label)));
        await settleStoreDetail(tester);
      }
      expect(pager.page, closeTo(12, .01));
      expect(find.text('23–24쪽'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    storeDetailTestWidgets(
      'material views and disclosure release artwork with large type and theme changes $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var live = 0;
        var previewBuilds = 0;
        var dark = false;
        late StateSetter update;
        final screen = MaterialDetailScreen(
          productKey: 'sticker:review',
          favoriteKey: 'review',
          title: '큰 글씨 소재 상세 검증',
          type: '스티커',
          preview: (_) {
            previewBuilds++;
            return _LiveArtwork(onMount: () => live++, onDispose: () => live--);
          },
        );
        await tester.pumpWidget(
          reviewApp(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Theme(
                  data: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: screen,
                  ),
                );
              },
            ),
          ),
        );
        await settleStoreDetail(tester);
        final initialBuilds = previewBuilds;
        for (var cycle = 0; cycle < 6; cycle++) {
          final heading = find.text('소재 이용 안내');
          await tester.ensureVisible(heading);
          await tester.tap(heading);
          await settleStoreDetail(tester);
          expect(find.text('여러 앨범에 계속 사용'), findsOneWidget);
          await tester.tap(heading);
          await settleStoreDetail(tester);
          expect(find.text('여러 앨범에 계속 사용'), findsNothing);
          for (final mode in [1, 0]) {
            final button = find.byKey(ValueKey('store-gallery-view-$mode'));
            await tester.ensureVisible(button);
            await tester.tap(button);
            await settleStoreDetail(tester);
            expect(
              find.byType(MaterialApplicationPreview),
              mode == 1 ? findsOneWidget : findsNothing,
            );
            expect(live, 1);
          }
          expect(tester.takeException(), isNull);
          expect(tester.binding.hasScheduledFrame, false);
        }
        expect(previewBuilds, initialBuilds);
        update(() => dark = true);
        await settleStoreDetail(tester);
        expect(live, 1);
        expect(previewBuilds, lessThanOrEqualTo(initialBuilds + 1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settleStoreDetail(tester);
        expect(live, 0);
        expect(tester.binding.hasScheduledFrame, false);
      },
    );
  }

  storeDetailTestWidgets(
    'large dark template disclosure preserves the interior and bounded page cache',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        reviewApp(
          Builder(
            builder: (context) => Theme(
              data: SnapFitTheme.dark(),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(2)),
                child: TemplateDetailScreen(template: _book()),
              ),
            ),
          ),
        ),
      );
      await settleStoreDetail(tester);
      tester
          .widget<PageView>(find.byKey(const ValueKey('template-spread-pager')))
          .controller!
          .jumpToPage(40);
      await settleStoreDetail(tester);
      await tester.tap(find.byTooltip('전체 미리보기'));
      await settleStoreDetail(tester);
      final source =
          tester
                  .widget<TemplateFullScreenView>(
                    find.byType(TemplateFullScreenView),
                  )
                  .parsedPages
              as TemplateDetailPages;
      await tester.tap(find.byTooltip('닫기'));
      await settleStoreDetail(tester);
      final recentPages = <String, Object>{
        for (final element in find.byType(TemplatePageRenderer).evaluate())
          for (final renderer in [element.widget as TemplatePageRenderer])
            if (renderer.layers.isNotEmpty)
              renderer.layers.first.id: renderer.layers,
      };
      expect(recentPages, isNotEmpty);
      for (var cycle = 0; cycle < 8; cycle++) {
        final heading = find.text('디자인 구성 · 사진과 글');
        await tester.ensureVisible(heading);
        await tester.tap(heading);
        await settleStoreDetail(tester);
        expect(
          find.byKey(const ValueKey('template-detail-profile')),
          findsOneWidget,
        );
        await tester.tap(heading);
        await settleStoreDetail(tester);
        expect(
          find.byKey(const ValueKey('template-detail-profile')),
          findsNothing,
        );
        expect(find.text('79–80쪽'), findsOneWidget);
        expect(source.cache.length, lessThanOrEqualTo(source.cache.limit));
        expect(tester.binding.hasScheduledFrame, false);
        expect(tester.takeException(), isNull);
      }
      for (final element in find.byType(TemplatePageRenderer).evaluate()) {
        final renderer = element.widget as TemplatePageRenderer;
        if (renderer.layers.isEmpty) continue;
        expect(renderer.layers, same(recentPages[renderer.layers.first.id]));
      }
      await tester.pumpWidget(const SizedBox());
      await settleStoreDetail(tester);
      expect(source.cache.length, 0);
      expect(tester.binding.hasScheduledFrame, false);
    },
  );
}
