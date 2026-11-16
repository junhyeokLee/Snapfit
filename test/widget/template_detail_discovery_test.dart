import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/store_template_discovery.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_material_gallery.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_related_section.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import '../support/store_detail_loading.dart';

const _document = '''{"designWidth":500,"designHeight":500,"pages":[
{"layers":[{"id":"cover-title","type":"TEXT","x":0.1,"y":0.1,"width":0.6,"height":0.2,"payload":{"text":"우리의 여행"}}]},
{"layers":[{"id":"inside-title","type":"TEXT","x":0.1,"y":0.1,"width":0.6,"height":0.2,"payload":{"text":"여행 기록"}}]}]}''';

PremiumTemplate _template(
  int id, {
  String? title,
  String Function()? builder,
}) => PremiumTemplate(
  id: id,
  title: title ?? '여백이 있는 여행 $id',
  category: '여행',
  tags: const ['미니멀'],
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 24,
  userCount: 0,
  isPremium: true,
  templateJson: builder == null ? _document : null,
  documentBuilder: builder,
);

PointShopProduct _product(int id, {bool active = true}) => PointShopProduct(
  productKey: 'template:server-$id',
  kind: 'template',
  assetId: 'server-$id',
  title: '디자인 $id',
  pointPrice: 1800,
  isActive: active,
);

Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    pointShopCatalogProvider.overrideWith(
      (_) async => [_product(2201), _product(2202)],
    ),
    ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ),
);

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'all materials are inline without expansion at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final keys = [for (var n = 0; n < 11; n++) 'sticker:material-$n'];
        String? opened;
        await tester.pumpWidget(
          _wrap(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TemplateMaterialGallery(
                  materialKeys: keys,
                  name: (key) => '여행의 기억을 모으는 긴 이름의 소재 $key',
                  kind: (_) => '종이 소재',
                  artwork: (_) => const ColoredBox(color: Color(0xFFDFE9E5)),
                  usage: (_) => const Text('재사용 가능 · 무료'),
                  onOpen: (key) => opened = key,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ExpansionTile), findsNothing);
        expect(find.text('함께 사용한 꾸밈 소재 11종'), findsOneWidget);
        for (final key in keys) {
          expect(
            find.byKey(ValueKey('template-material-preview-$key')),
            findsOneWidget,
          );
        }
        final last = find.byKey(
          ValueKey('template-material-preview-${keys.last}'),
        );
        await tester.ensureVisible(last);
        await tester.pumpAndSettle();
        await tester.tap(last);
        expect(opened, keys.last);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'related cards explain the match and navigate without authoring books',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var documentReads = 0;
      final template = _template(
        2201,
        builder: () {
          documentReads++;
          throw StateError('A related card must not read a full document');
        },
      );
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.all(16),
              child: TemplateRelatedSection(
                recommendations: [
                  RelatedStoreTemplate(template: template, reason: '여행 · 미니멀'),
                ],
                onOpen: (item) => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(body: Text('선택한 디자인 ${item.id}')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('여행 · 미니멀'), findsOneWidget);
      expect(find.text('1800P'), findsOneWidget);
      expect(documentReads, 0);
      final card = find.byKey(const ValueKey('template-related-2201'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('선택한 디자인 2201'), findsOneWidget);
      expect(documentReads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty related results leave no empty section', (tester) async {
    await tester.pumpWidget(
      _wrap(TemplateRelatedSection(recommendations: const [], onOpen: (_) {})),
    );
    expect(
      find.byKey(const ValueKey('template-related-section')),
      findsNothing,
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'related shelf reveals more designs horizontally at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        int? opened;
        final designs = [
          for (var n = 0; n < 6; n++)
            _template(2201 + n, title: '사진과 글로 이어지는 조용한 여행의 이야기 ${n + 1}'),
        ];
        await tester.pumpWidget(
          _wrap(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TemplateRelatedSection(
                  recommendations: [
                    for (final design in designs)
                      RelatedStoreTemplate(
                        template: design,
                        reason: '여행 · 미니멀',
                      ),
                  ],
                  onOpen: (design) => opened = design.id,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rail = find.byKey(const ValueKey('template-related-rail'));
        final first = find.byKey(const ValueKey('template-related-2201'));
        final second = find.byKey(const ValueKey('template-related-2202'));
        expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
        if (scale == 1) {
          final visibleCards =
              tester.getSize(rail).width / tester.getSize(first).width;
          expect(visibleCards, inInclusiveRange(1.6, 1.9));
        }
        final previous = find.byKey(
          const ValueKey('template-related-previous'),
        );
        final next = find.byKey(const ValueKey('template-related-next'));
        expect(tester.widget<IconButton>(previous).onPressed, isNull);
        await tester.ensureVisible(next);
        await tester.pumpAndSettle();
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(previous).onPressed, isNotNull);
        final target = find.byKey(const ValueKey('template-related-2206'));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        expect(opened, 2206);
        final title = tester.widget<Text>(find.text(designs.last.title));
        expect(title.maxLines, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  storeDetailTestWidgets(
    'detail excludes current and unavailable designs and opens an eligible related detail',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      final current = _template(2200);
      final related = _template(2201);
      final inactive = _template(2202);
      final unpriced = _template(2203);
      final repository = MockTemplateRepository();
      when(() => repository.getTemplate(2200)).thenAnswer((_) async => current);
      when(() => repository.getTemplate(2201)).thenAnswer((_) async => related);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateRepositoryProvider.overrideWithValue(repository),
            storeTemplateDiscoveryCandidatesProvider.overrideWithValue(
              AsyncData([current, related, inactive, unpriced]),
            ),
            pointShopCatalogProvider.overrideWith(
              (_) async => [
                _product(2200),
                _product(2201),
                _product(2202, active: false),
              ],
            ),
            ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) =>
                MaterialApp(home: TemplateDetailScreen(template: current)),
          ),
        ),
      );
      await settleStoreDetail(tester);
      expect(find.byKey(const ValueKey('template-related-2200')), findsNothing);
      expect(find.byKey(const ValueKey('template-related-2202')), findsNothing);
      expect(find.byKey(const ValueKey('template-related-2203')), findsNothing);
      final card = find.byKey(const ValueKey('template-related-2201'));
      expect(card, findsOneWidget);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await settleStoreDetail(tester);
      expect(
        tester
            .widget<TemplateDetailScreen>(find.byType(TemplateDetailScreen))
            .template
            .id,
        2201,
      );
      expect(tester.takeException(), isNull);
    },
  );

  // The native creation picker uses CreationTemplatePreview instead of the
  // store detail. The related-detail return path is exercised in the browser.
  storeDetailTestWidgets(
    'web related selection returns the chosen book to the creation caller',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      CatalogFavorites.instance = CatalogFavorites();
      await CatalogFavorites.instance.load();
      addTearDown(() => CatalogFavorites.instance.dispose());
      final current = _template(2200);
      final related = _template(2201);
      final repository = MockTemplateRepository();
      when(() => repository.getTemplate(2200)).thenAnswer((_) async => current);
      when(() => repository.getTemplate(2201)).thenAnswer((_) async => related);
      AlbumCreationTemplate? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateRepositoryProvider.overrideWithValue(repository),
            storeTemplateDiscoveryCandidatesProvider.overrideWithValue(
              AsyncData([current, related]),
            ),
            pointShopCatalogProvider.overrideWith(
              (_) async => [_product(2200), _product(2201)],
            ),
            ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
            pointShopAccessGateProvider.overrideWithValue(
              (context, ref, {required productKey, required title}) async =>
                  true,
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, __) => MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    child: const Text('디자인 고르기'),
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<AlbumCreationTemplate>(
                            MaterialPageRoute(
                              builder: (_) => TemplateDetailScreen(
                                template: current,
                                selectForCreation: true,
                              ),
                            ),
                          );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('디자인 고르기'));
      await settleStoreDetail(tester);
      final relatedCard = find.byKey(const ValueKey('template-related-2201'));
      await tester.ensureVisible(relatedCard);
      await tester.pumpAndSettle();
      await tester.tap(relatedCard);
      await settleStoreDetail(tester);
      final use = find.byKey(const ValueKey('template-detail-use')).first;
      await tester.ensureVisible(use);
      await tester.tap(use);
      await settleStoreDetail(tester);
      expect(find.byType(TemplateDetailScreen), findsNothing);
      expect(result?.title, related.title);
      expect(result?.sourceTemplateProductKey, 'template:server-2201');
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );
}
