import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/templates/authored_collections.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/providers/design_template_catalog_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import '../../tool/template_studio/export_price_application.dart';

class _TokenStorage extends Mock implements TokenStorage {}

const _publishedIds = [
  -9301,
  -9302,
  -9303,
  -9401,
  -9402,
  -9403,
  -9404,
  -9411,
  -9412,
  -9413,
  -9414,
  -9421,
  -9422,
  -9423,
  -9424,
  -9431,
  -9432,
  -9433,
  -9434,
  -9435,
  -9441,
  -9442,
  -9443,
  -9444,
  -9445,
  -9451,
  -9452,
  -9453,
  -9454,
  -9455,
  -9461,
  -9462,
  -9463,
  -9464,
  -9465,
  -9304,
  -9305,
  -9471,
  -9472,
  -9473,
  -9474,
  -9475,
  -9761,
  -9721,
  -9722,
  -9723,
  -9724,
  -9725,
  -9771,
  -9772,
  -9773,
  -9775,
  -9781,
  -9782,
  -9501,
  -9502,
  -9503,
  -9504,
  -9505,
  -9506,
  -9507,
  -9511,
  -9512,
  -9513,
  -9514,
  -9515,
  -9516,
  -9517,
  -9521,
  -9522,
  -9523,
  -9524,
  -9525,
  -9526,
  -9527,
  -9531,
  -9532,
  -9533,
  -9534,
  -9535,
  -9801,
  -9802,
  -9803,
  -9804,
  -9805,
  -9806,
  -9807,
  -9808,
  -9809,
  -9810,
  -9811,
  -9812,
  -9813,
  -9814,
  -9815,
  -9816,
  -9817,
  -9818,
  -9819,
  -9820,
  -9821,
  -9822,
  -9823,
  -9824,
  -9825,
  -9826,
  -9827,
  -9828,
  -9829,
  -9830,
  -9831,
  -9832,
  -9833,
  -9834,
  -9835,
  -9836,
  -9837,
  -9838,
  -9839,
  -9840,
  -9841,
  -9842,
  -9843,
  -9844,
  -9762,
  -9601,
  -9602,
  -9603,
  -9604,
  -9605,
  -9611,
  -9612,
  -9613,
  -9614,
  -9615,
  -9621,
  -9622,
  -9623,
  -9624,
  -9625,
  -9631,
  -9632,
  -9633,
  -9634,
  -9635,
  -9641,
  -9642,
  -9643,
  -9644,
  -9645,
  -9651,
  -9652,
  -9653,
  -9654,
  -9655,
  -9661,
  -9662,
  -9663,
  -9664,
  -9665,
  -9701,
  -9702,
  -9703,
  -9704,
  -9705,
  -9711,
  -9712,
  -9713,
  -9714,
  -9715,
  -9731,
  -9732,
  -9733,
  -9734,
  -9735,
  -9741,
  -9742,
  -9743,
  -9744,
  -9745,
  -9751,
  -9752,
  -9753,
  -9754,
  -9755,
  -9774,
  -9776,
  -9777,
  -9778,
  -9779,
  -9780,
  -9783,
  -9784,
  -9785,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'all 194 released identities retain their tier after stale server metadata',
    () {
      final rows = {
        for (final row in pointShopPriceApplicationRows())
          row['product_key']: row,
      };
      final merged = mergeTemplatesWithServer(
        publishedCreationTemplates,
        publishedCreationTemplates
            .map((t) => t.copyWith(isPremium: !t.isPremium))
            .toList(),
      );
      expect(merged, hasLength(194));
      expect(merged.where((t) => !t.isPremium), hasLength(54));
      expect(merged.where((t) => t.isPremium), hasLength(140));
      for (final t in merged) {
        final canonical = publishedCreationTemplates.singleWhere(
          (p) => p.id == t.id,
        );
        final row = rows[pointShopTemplateKey(t)]!;
        expect(row['is_active'], true, reason: t.title);
        expect(
          row['point_price'],
          t.isPremium ? greaterThan(0) : 0,
          reason: t.title,
        );
        expect(t.documentBuilder, same(canonical.documentBuilder));
        expect(t.title, canonical.title);
      }
    },
  );

  ProviderContainer container({bool offline = false}) {
    final storage = _TokenStorage();
    when(() => storage.getResolvedUserId()).thenAnswer((_) async {
      if (offline) throw StateError('No credentials');
      return 'reader';
    });
    final result = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        templateRepositoryProvider.overrideWith(
          (ref) =>
              throw StateError('Public catalog must not query the old store'),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  test(
    'remote payloads cannot add products or replace approved free artwork',
    () {
      final source = bundledCreationTemplates.first;
      final stale = source.copyWith(
        title: 'Old paid artwork',
        isPremium: true,
        templateJson: '{bad',
      );
      final result =
          StoreTemplateFeedNotifier.mergeServerSummaryWithLocalStatic(
            server: [
              stale,
              ...publishedCreationTemplates
                  .skip(1)
                  .map(
                    (template) =>
                        template.copyWith(isPremium: !template.isPremium),
                  ),
              source.copyWith(id: 42),
            ],
            local: [source.copyWith(id: -9201)],
          );
      expect(result.map((t) => t.id), _publishedIds);
      expect(result.first.title, source.title);
      expect(result.first.templateJson, source.templateJson);
      // The fixed first 54 IDs identify the approved free collection. A
      // presentation flag is not a server price or a collection membership.
      final freeOriginalIds = _publishedIds.take(54).toList();
      expect(bundledCreationTemplates.map((t) => t.id), freeOriginalIds);
      expect(
        result.where((t) => freeOriginalIds.contains(t.id)).map((t) => t.id),
        freeOriginalIds,
      );
      expect(
        result.where((t) => !freeOriginalIds.contains(t.id)).map((t) => t.id),
        _publishedIds.skip(54),
      );
      for (final template in bundledCreationTemplates) {
        expect(
          pointShopRequiresFreePrice(pointShopTemplateKey(template)),
          isTrue,
          reason: template.title,
        );
      }
      expect(
        result.map((t) => t.isPremium),
        publishedCreationTemplates.map((t) => t.isPremium),
      );
      expect(
        result.map((t) => t.documentBuilder),
        publishedCreationTemplates.map((t) => t.documentBuilder),
      );
      expect(stale.templateJson, '{bad');
    },
  );

  for (final offline in [false, true]) {
    test(
      'store, feed, runtime and editor expose all 194, offline=$offline',
      () async {
        final scope = container(offline: offline);
        final subscription = scope.listen(
          storeTemplateFeedProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        expect(scope.read(storeTemplateFeedProvider).items.length, 194);
        for (var refresh = 0; refresh < 3; refresh++) {
          final catalog = await scope.read(templateListProvider.future);
          expect(catalog.map((t) => t.id), _publishedIds);
          final feed = scope.read(storeTemplateFeedProvider);
          expect(feed.items.map((t) => t.id), _publishedIds);
          expect(feed.hasNext, false);
          await scope.read(storeTemplateFeedProvider.notifier).loadMore();
          await scope.read(storeTemplateFeedProvider.notifier).refresh();
        }
        expect(
          (await loadCanonicalStoreTemplatesForRuntime()).map((t) => t.id),
          _publishedIds,
        );
        final editor = await scope.read(designTemplateCatalogProvider.future);
        expect(
          editor.map((t) => t.name),
          publishedCreationTemplates.map((t) => t.title),
        );
        for (var i = 0; i < authoredCollections.length; i++) {
          for (final aspect in CollectionAspect.printable) {
            final layers = editor[i].buildLayers(aspect.canvas);
            final doc = authoredCollections[i].document(aspect);
            expect(layers.length, (doc['cover']['layers'] as List).length);
            expect(layers, isNotEmpty);
          }
        }
      },
    );
  }

  test(
    'favorites survive refresh but old cached products stay hidden',
    () async {
      SharedPreferences.setMockInitialValues({
        'template_like_state_v1': jsonEncode({
          'reader:id:12': {'isLiked': true, 'likeCount': 300},
        }),
      });
      await persistTemplateLikeState(
        bundledCreationTemplates[1].copyWith(isLiked: true, likeCount: 1),
        userId: 'reader',
      );
      final scope = container();
      await scope.read(templateListProvider.future);
      // Allow background enrichment (phases 2 & 3a) to complete.
      for (var i = 0; i < 5; i++) await Future<void>.delayed(Duration.zero);
      final catalog = scope.read(templateListProvider).requireValue;
      expect(catalog.map((t) => t.id), _publishedIds);
      expect(catalog[1].isLiked, true);
      expect(catalog[1].likeCount, 1);
      expect(withBundledCreationTemplates(catalog)[1].isLiked, true);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('template_like_state_v1'),
        contains('reader:id:12'),
      );
    },
  );
}
