import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../helpers/mock_repositories.dart';
import '../support/store_detail_loading.dart';

class _Storage extends TokenStorage {
  Future<String?> Function() resolve = () async => 'account-a';
  int reads = 0;

  @override
  Future<String?> getResolvedUserId() {
    reads++;
    return resolve();
  }
}

class _SessionRepository extends MockTemplateRepository
    implements TemplateSessionSource {
  String? owner = 'account-a';

  @override
  String? get currentTemplateUserId => owner;

  @override
  Stream<String?> get templateUserChanges => const Stream.empty();
}

class _DelayedStore extends InMemorySharedPreferencesStore {
  _DelayedStore() : super.withData({});
  final release = Completer<void>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    await release.future;
    return super.setValue(type, key, value);
  }
}

PremiumTemplate _template({bool liked = false, int count = 1}) =>
    PremiumTemplate(
      id: 440100,
      title: 'Detail like lifecycle fixture',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 2,
      userCount: 0,
      isLiked: liked,
      likeCount: count,
      templateJson: jsonEncode({
        'designWidth': 500,
        'designHeight': 500,
        'pages': [
          for (var page = 0; page < 3; page++)
            {
              'layers': [
                {
                  'id': 'like-lifecycle-$page',
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

Finder get _likeButton => find.byWidgetPredicate(
  (widget) =>
      widget is IconButton &&
      widget.icon is Icon &&
      [
        Icons.favorite,
        Icons.favorite_border,
      ].contains((widget.icon as Icon).icon),
);

bool _liked(WidgetTester tester) =>
    (tester.widget<IconButton>(_likeButton).icon as Icon).icon ==
    Icons.favorite;

Future<void> _mount(
  WidgetTester tester,
  MockTemplateRepository repository,
  _Storage storage,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        templateRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(storage),
        mockTemplateList(() => <PremiumTemplate>[]),
        pointShopCatalogProvider.overrideWith((_) async => []),
        ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
      ],
      child: MaterialApp(home: TemplateDetailScreen(template: _template())),
    ),
  );
  await settleStoreDetail(tester);
  // Initial hydration reads the native asset catalog outside the frame clock.
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await settleStoreDetail(tester);
    if (_likeButton.evaluate().isNotEmpty) break;
  }
  expect(_likeButton, findsOneWidget);
}

Future<Map<String, dynamic>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString('template_like_state_v1') ?? '{}')
      as Map<String, dynamic>;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  storeDetailTestWidgets(
    'rapid repeated likes share the pending account resolution and submission',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final owner = Completer<String?>();
      storage.resolve = () => owner.future;
      stubGetTemplates(repository, [_template()]);
      await _mount(tester, repository, storage);
      final callback = tester.widget<IconButton>(_likeButton).onPressed!;
      callback();
      callback();
      await tester.pump();
      owner.complete('account-a');
      await settleStoreDetail(tester);

      expect(storage.reads, 1);
      verify(() => repository.likeTemplate(440100)).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'closing during account resolution cancels the not-yet-submitted like',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final owner = Completer<String?>();
      storage.resolve = () => owner.future;
      stubGetTemplates(repository, [_template()]);
      await _mount(tester, repository, storage);
      tester.widget<IconButton>(_likeButton).onPressed!();
      await tester.pumpWidget(const SizedBox.shrink());
      owner.complete('account-a');
      await tester.pump();
      await tester.pump();

      verifyNever(() => repository.likeTemplate(440100));
      expect(await _stored(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'an older like reconciliation cannot replace the latest unlike intent',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final firstSync = Completer<PremiumTemplate>();
      final latestSync = Completer<PremiumTemplate>();
      var reads = 0;
      stubGetTemplates(repository, [_template()]);
      when(() => repository.getTemplate(440100)).thenAnswer((_) {
        return ++reads == 1 ? firstSync.future : latestSync.future;
      });
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isTrue);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isFalse);
      firstSync.complete(_template(liked: true, count: 2));
      await settleStoreDetail(tester);
      final afterOldResponse = _liked(tester);
      final persistedAfterOldResponse = await _stored();
      latestSync.complete(_template());
      await settleStoreDetail(tester);

      expect(afterOldResponse, isFalse);
      expect(persistedAfterOldResponse['account-a:id:440100'], {
        'isLiked': false,
        'likeCount': 1,
      });
      verify(() => repository.likeTemplate(440100)).called(2);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'a reconciliation from a previous account is ignored',
    (tester) async {
      final repository = _SessionRepository();
      final storage = _Storage();
      final pending = Completer<PremiumTemplate>();
      stubGetTemplates(repository, [_template()]);
      when(
        () => repository.getTemplate(440100),
      ).thenAnswer((_) => pending.future);
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      repository.owner = 'account-b';
      pending.complete(_template(count: 8));
      await settleStoreDetail(tester);

      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 2,
      });
      expect((await _stored()).containsKey('account-b:id:440100'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'initial metadata arriving after a like preserves the newer selection',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final initial = Completer<List<PremiumTemplate>>();
      var reads = 0;
      stubGetTemplates(repository, [_template()]);
      when(() => repository.getTemplates()).thenAnswer((_) {
        reads++;
        return initial.future;
      });
      when(
        () => repository.getTemplate(440100),
      ).thenAnswer((_) async => _template(liked: true, count: 2));
      await _mount(tester, repository, storage);
      expect(reads, 1);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isTrue);
      initial.complete([_template()]);
      await settleStoreDetail(tester);

      expect(_liked(tester), isTrue);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 2,
      });
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'account lookup failure releases the lock and a retry can succeed',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      storage.resolve = () async => throw StateError('Expected lookup failure');
      stubGetTemplates(repository, [_template(liked: true, count: 2)]);
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      verifyNever(() => repository.likeTemplate(440100));
      expect(await _stored(), isEmpty);
      expect(find.textContaining('Expected lookup failure'), findsOneWidget);
      expect(tester.takeException(), isNull);

      storage.resolve = () async => 'account-a';
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      verify(() => repository.likeTemplate(440100)).called(1);
      expect(storage.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'a failed server toggle rolls back once and permits the next submission',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      stubGetTemplates(repository, [_template()]);
      var posts = 0;
      when(() => repository.likeTemplate(440100)).thenAnswer((_) async {
        if (++posts == 1) throw StateError('Expected toggle failure');
      });
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isFalse);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': false,
        'likeCount': 1,
      });
      when(
        () => repository.getTemplate(440100),
      ).thenAnswer((_) async => _template(liked: true, count: 2));
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isTrue);
      expect(posts, 2);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 2,
      });
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'closing during a submitted toggle does not start a reconciliation',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final post = Completer<void>();
      stubGetTemplates(repository, [_template()]);
      when(
        () => repository.likeTemplate(440100),
      ).thenAnswer((_) => post.future);
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      verify(() => repository.likeTemplate(440100)).called(1);
      await tester.pumpWidget(const SizedBox.shrink());
      post.complete();
      await tester.pump();
      await tester.pump();

      verify(() => repository.getTemplates()).called(1);
      verifyNever(() => repository.getTemplate(440100));
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'an account change during the toggle prevents a follow-up in the new account',
    (tester) async {
      final repository = _SessionRepository();
      final storage = _Storage();
      storage.resolve = () async => 'stale-secure-storage-owner';
      final post = Completer<void>();
      stubGetTemplates(repository, [_template()]);
      when(
        () => repository.likeTemplate(440100),
      ).thenAnswer((_) => post.future);
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      verify(() => repository.likeTemplate(440100)).called(1);
      repository.owner = 'account-b';
      post.complete();
      await settleStoreDetail(tester);

      verify(() => repository.getTemplates()).called(1);
      verifyNever(() => repository.getTemplate(440100));
      expect(storage.reads, 0);
      expect((await _stored()).keys, ['account-a:id:440100']);
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'closing and reopening does not apply the previous detail reconciliation',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      final oldSync = Completer<PremiumTemplate>();
      stubGetTemplates(repository, [_template()]);
      when(
        () => repository.getTemplate(440100),
      ).thenAnswer((_) => oldSync.future);
      await _mount(tester, repository, storage);
      await tester.tap(_likeButton);
      await settleStoreDetail(tester);
      expect(_liked(tester), isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await _mount(tester, repository, storage);
      expect(_liked(tester), isFalse);
      oldSync.complete(_template(liked: true, count: 90));
      await settleStoreDetail(tester);

      expect(_liked(tester), isFalse);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 2,
      });
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'slow local persistence does not gate or drop an already requested toggle',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      stubGetTemplates(repository, [_template()]);
      var posts = 0;
      when(() => repository.likeTemplate(440100)).thenAnswer((_) async {
        posts++;
      });
      await _mount(tester, repository, storage);
      final previousStore = SharedPreferencesStorePlatform.instance;
      final delayed = _DelayedStore();
      SharedPreferencesStorePlatform.instance = delayed;
      addTearDown(
        () => SharedPreferencesStorePlatform.instance = previousStore,
      );
      int beforeRelease;
      try {
        await tester.tap(_likeButton);
        await settleStoreDetail(tester);
        beforeRelease = posts;
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        delayed.release.complete();
        await settleStoreDetail(tester);
      }

      expect(beforeRelease, 1);
      expect(posts, 1);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 2,
      });
      verify(() => repository.getTemplates()).called(1);
      verifyNever(() => repository.getTemplate(440100));
      expect(tester.takeException(), isNull);
    },
  );

  storeDetailTestWidgets(
    'confirmed toggles fetch only the changed server record',
    (tester) async {
      final repository = MockTemplateRepository();
      final storage = _Storage();
      var liked = false;
      var catalogReads = 0;
      var recordReads = 0;
      var rowsReturned = 0;
      var unexpectedDocumentBuilds = 0;
      PremiumTemplate current() =>
          _template(liked: liked, count: liked ? 17 : 16);
      final unrelated = [
        for (var index = 0; index < 255; index++)
          PremiumTemplate(
            id: 450000 + index,
            title: 'Unrelated record $index',
            coverImageUrl: '',
            previewImages: const [],
            pageCount: 24,
            userCount: 0,
            documentBuilder: () {
              unexpectedDocumentBuilds++;
              throw StateError('Unrelated documents must remain lazy');
            },
          ),
      ];
      stubGetTemplates(repository, []);
      when(() => repository.getTemplates()).thenAnswer((_) async {
        catalogReads++;
        rowsReturned += 256;
        return [...unrelated, current()];
      });
      when(() => repository.getTemplate(440100)).thenAnswer((_) async {
        recordReads++;
        rowsReturned++;
        return current();
      });
      when(() => repository.likeTemplate(440100)).thenAnswer((_) async {
        liked = !liked;
      });
      await _mount(tester, repository, storage);
      for (var toggle = 0; toggle < 5; toggle++) {
        await tester.tap(_likeButton);
        await settleStoreDetail(tester);
      }

      expect(
        catalogReads,
        1,
        reason: 'Only initial legacy title hydration may scan',
      );
      expect(recordReads, 5);
      expect(rowsReturned, 261);
      expect(unexpectedDocumentBuilds, 0);
      expect(_liked(tester), isTrue);
      expect((await _stored())['account-a:id:440100'], {
        'isLiked': true,
        'likeCount': 17,
      });
      expect(tester.takeException(), isNull);
    },
  );

  for (final response in ['failed', 'retired', 'different ID']) {
    storeDetailTestWidgets(
      'a $response record keeps confirmed likes without a full catalog fallback',
      (tester) async {
        final repository = MockTemplateRepository();
        final storage = _Storage();
        stubGetTemplates(repository, [_template()]);
        when(() => repository.getTemplate(440100)).thenAnswer((_) async {
          if (response == 'failed') {
            throw StateError('Expected record read failure');
          }
          return _template(count: 90).copyWith(
            id: response == 'different ID' ? 440101 : 440100,
            title: response == 'retired' ? '제주의 기록' : 'Another server record',
          );
        });
        await _mount(tester, repository, storage);
        await tester.tap(_likeButton);
        await settleStoreDetail(tester);

        verify(() => repository.getTemplates()).called(1);
        verify(() => repository.getTemplate(440100)).called(1);
        expect(_liked(tester), isTrue);
        expect(find.text(_template().title), findsOneWidget);
        expect((await _stored())['account-a:id:440100'], {
          'isLiked': true,
          'likeCount': 2,
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
}
