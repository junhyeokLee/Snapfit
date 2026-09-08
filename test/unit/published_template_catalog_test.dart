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
import 'package:snap_fit/features/store/data/api/template_provider.dart';

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
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
            server: [stale, source.copyWith(id: 42)],
            local: [source.copyWith(id: -9201)],
          );
      expect(result.map((t) => t.id), _publishedIds);
      expect(result.first.title, source.title);
      expect(result.first.templateJson, source.templateJson);
      expect(result.every((t) => !t.isPremium), true);
      expect(stale.templateJson, '{bad');
    },
  );

  for (final offline in [false, true]) {
    test(
      'store, feed, runtime and editor publish the approved thirty-seven, offline=$offline',
      () async {
        final scope = container(offline: offline);
        final subscription = scope.listen(
          storeTemplateFeedProvider,
          (_, __) {},
        );
        addTearDown(subscription.close);
        expect(scope.read(storeTemplateFeedProvider).items.length, 37);
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
          bundledCreationTemplates.map((t) => t.title),
        );
        for (var i = 0; i < editor.length; i++) {
          for (final aspect in CollectionAspect.values) {
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
      final catalog = await scope.read(templateListProvider.future);
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
