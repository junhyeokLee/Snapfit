import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/supabase/supabase_provider.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/data/repositories/supabase_template_repository.dart';
import 'package:snap_fit/features/store/domain/entities/template_summary_page.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Tokens extends TokenStorage {
  _Tokens(this.owner);
  final String? Function() owner;
  @override
  Future<String?> getResolvedUserId() async => owner();
}

class _Repository extends SupabaseTemplateRepository {
  _Repository(super.client, {required super.tokenStorage});
  int started = 0;
  int finished = 0;
  int fullStarted = 0;
  int fullFinished = 0;
  int authListeners = 0;

  @override
  Stream<String?> get templateUserChanges => Stream<String?>.multi((events) {
    authListeners++;
    final subscription = super.templateUserChanges.listen(
      events.addSync,
      onError: events.addErrorSync,
      onDone: events.closeSync,
    );
    events.onCancel = () async {
      authListeners--;
      await subscription.cancel();
    };
  });

  @override
  Future<List<PremiumTemplate>> getTemplates() {
    fullStarted++;
    return super.getTemplates().whenComplete(() => fullFinished++);
  }

  @override
  Future<TemplateSummaryPage> getTemplateSummaries({
    int page = 0,
    int size = 20,
    String? category,
    String? query,
    bool? isPaid,
  }) {
    started++;
    return super
        .getTemplateSummaries(
          page: page,
          size: size,
          category: category,
          query: query,
          isPaid: isPaid,
        )
        .whenComplete(() => finished++);
  }
}

class _Read {
  _Read(this.request);
  final http.Request request;
  final response = Completer<http.Response>();
  void complete(Object? body, {int status = 200}) => response.complete(
    http.Response(
      jsonEncode(body),
      status,
      request: request,
      headers: {'content-type': 'application/json'},
    ),
  );
}

Map<String, Object> _row(
  int id, {
  String category = '일상',
  String likedBy = 'account-a',
}) => {
  'id': id,
  'title': 'Review $id',
  'category': category,
  'is_active': true,
  'template_likes': [
    {'user_id': likedBy},
  ],
};

Future<void> _until(
  bool Function() condition, {
  String reason = 'Controlled SDK/provider work did not finish',
}) async {
  for (var attempt = 0; !condition() && attempt < 500; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue, reason: reason);
}

class _Fixture {
  final reads = <_Read>[];
  final scopes = <ProviderContainer>[];
  late final client = SupabaseClient(
    'https://fixture.invalid',
    'public-test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) {
      if (request.url.path.endsWith('/logout')) {
        return Future.value(http.Response('{}', 200));
      }
      final read = _Read(request);
      reads.add(read);
      return read.response.future;
    }),
  );
  late final tokens = _Tokens(() => client.auth.currentUser?.id);
  late final repository = _Repository(client, tokenStorage: tokens);

  ProviderContainer root() {
    final scope = ProviderContainer(
      overrides: [
        templateRepositoryProvider.overrideWithValue(repository),
        tokenStorageProvider.overrideWithValue(tokens),
        supabaseClientProvider.overrideWithValue(client),
      ],
    );
    scopes.add(scope);
    scope.read(storeTemplateFeedProvider);
    return scope;
  }

  ProviderContainer search(ProviderContainer root) {
    final scope = ProviderContainer(
      parent: root,
      overrides: [
        storeTemplateFeedProvider.overrideWith(StoreTemplateFeedNotifier.new),
      ],
    );
    scopes.add(scope);
    scope.read(storeTemplateFeedProvider);
    return scope;
  }

  void close(ProviderContainer scope) {
    if (scopes.remove(scope)) scope.dispose();
  }

  Future<void> session(String account, {String version = '1'}) async {
    String encode(Object json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    final token =
        '${encode({'alg': 'none'})}.'
        '${encode({'sub': account, 'session_id': version, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.fixture';
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': token,
        'token_type': 'bearer',
        'refresh_token': 'fixture-refresh',
        'user': {'id': account, 'app_metadata': {}, 'aud': 'authenticated'},
      }),
    );
  }

  Future<void> count(int count) async {
    await _until(() => reads.length >= count);
    expect(reads, hasLength(count));
  }

  Future<void> dispose() async {
    for (final scope in scopes.reversed.toList()) {
      close(scope);
    }
    for (final read in reads) {
      if (!read.response.isCompleted) read.complete([]);
    }
    await _until(() => repository.finished == repository.started);
    await _until(() => repository.fullFinished == repository.fullStarted);
    await _until(() => repository.authListeners == 0);
    await client.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Fixture fixture;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
    fixture = _Fixture();
  });
  tearDown(() async {
    await fixture.dispose();
    CatalogFavorites.instance.dispose();
  });

  test(
    'review: simultaneous refreshes share transport; a closed different filter cannot change browse rows',
    () async {
      final root = fixture.root();
      await fixture.count(1);
      final search = fixture.search(root);
      await _until(() => fixture.repository.started == 2);
      final parent = root.read(storeTemplateFeedProvider.notifier);
      final child = search.read(storeTemplateFeedProvider.notifier);
      final refresh = parent.refresh();
      expect(parent.refresh(), same(refresh));
      final childRefresh = child.refresh();
      await _until(() => fixture.repository.started == 4);
      expect(fixture.reads, hasLength(1));
      final differentFilter = child.setFilters(category: '여행');
      await fixture.count(2);
      expect(
        fixture.reads.last.request.url.queryParameters['category'],
        'eq.여행',
      );
      fixture.close(search);
      fixture.reads.first.complete([_row(88001)]);
      await Future.wait([refresh, childRefresh]);
      final snapshot = root.read(storeTemplateFeedProvider).items;
      expect(snapshot.any((t) => t.id == 88001), isTrue);
      fixture.reads.last.complete([_row(99001, category: '여행')]);
      await differentFilter;
      await _until(
        () => fixture.repository.finished == fixture.repository.started,
      );
      expect(root.read(storeTemplateFeedProvider).items, same(snapshot));
      expect(root.read(storeTemplateFeedProvider).filterCategory, '');
      expect(() => search.read(storeTemplateFeedProvider), throwsStateError);
    },
  );

  test(
    'review: changing account during refresh must start a new owner generation',
    () async {
      await fixture.session('account-a');
      final root = fixture.root();
      await fixture.count(1);
      fixture.reads.first.complete([_row(88001)]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      final notifier = root.read(storeTemplateFeedProvider.notifier);
      final oldRefresh = notifier.refresh();
      await fixture.count(2);
      await fixture.session('account-b');
      final newRefresh = notifier.refresh();
      final reused = identical(oldRefresh, newRefresh);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final requestCountAfterSwitch = fixture.reads.length;
      for (final read in fixture.reads.skip(1)) {
        if (!read.response.isCompleted) read.complete([_row(88001)]);
      }
      await Future.wait([oldRefresh, newRefresh]);
      final current = root
          .read(storeTemplateFeedProvider)
          .items
          .singleWhere((t) => t.id == 88001);
      final currentOwner = fixture.client.auth.currentUser!.id;
      debugPrint(
        'account refresh review: owner=$currentOwner reused=$reused requests=$requestCountAfterSwitch liked=${current.isLiked}',
      );
      expect(
        reused,
        isFalse,
        reason: 'Account B must not reuse the pending account A refresh',
      );
      expect(requestCountAfterSwitch, 3);
      expect(
        current.isLiked,
        isFalse,
        reason: 'The returned row is liked only by account A',
      );
    },
  );

  test(
    'review: a late previous page error cannot replace a newer filter refresh',
    () async {
      final root = fixture.root();
      await fixture.count(1);
      fixture.reads.first.complete([
        for (var i = 0; i < 20; i++) _row(88000 + i),
      ]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      final notifier = root.read(storeTemplateFeedProvider.notifier);
      final more = notifier.loadMore();
      await fixture.count(2);
      expect(fixture.reads.last.request.url.queryParameters['offset'], '20');
      final filter = notifier.setFilters(category: '여행');
      await fixture.count(3);
      final refresh = notifier.refresh();
      await _until(() => fixture.repository.started == 4);
      expect(fixture.reads, hasLength(3));
      fixture.reads.last.complete([_row(89001, category: '여행')]);
      await Future.wait([filter, refresh]);
      final snapshot = root.read(storeTemplateFeedProvider).items;
      fixture.reads[1].complete({'message': 'Late old page'}, status: 400);
      await more;
      final state = root.read(storeTemplateFeedProvider);
      expect(state.items, same(snapshot));
      expect(state.items.any((t) => t.id == 89001), isTrue);
      expect(state.items.any((t) => t.id >= 88000 && t.id < 88020), isFalse);
      expect(state.error, isNull);
      expect(state.page, 0);
      expect(state.filterCategory, '여행');
      expect(state.isInitialLoading || state.isLoadingMore, isFalse);
    },
  );

  test(
    'review: many disposed searches release interests while the parent completes and refreshes normally',
    () async {
      final root = fixture.root();
      await fixture.count(1);
      final closed = <ProviderContainer>[];
      for (var visit = 0; visit < 20; visit++) {
        final search = fixture.search(root);
        await _until(() => fixture.repository.started == visit + 2);
        fixture.close(search);
        closed.add(search);
      }
      expect(fixture.reads, hasLength(1));
      fixture.reads.first.complete([_row(88001)]);
      await _until(() => fixture.repository.finished == 21);
      expect(root.read(storeTemplateFeedProvider).isInitialLoading, isFalse);
      for (final scope in closed) {
        expect(() => scope.read(storeTemplateFeedProvider), throwsStateError);
      }
      final refresh = root.read(storeTemplateFeedProvider.notifier).refresh();
      await fixture.count(2);
      fixture.reads.last.complete([_row(88002)]);
      await refresh;
      final state = root.read(storeTemplateFeedProvider);
      expect(state.items.any((t) => t.id == 88002), isTrue);
      expect(state.items.any((t) => t.id == 88001), isFalse);
      expect(fixture.repository.finished, fixture.repository.started);
    },
  );

  for (final order in ['old first', 'old error first', 'old last']) {
    test(
      'account refresh rejects the previous owner response: $order',
      () async {
        await fixture.session('account-a');
        final root = fixture.root();
        final notifier = root.read(storeTemplateFeedProvider.notifier);
        final initial = notifier.setFilters(category: '여행', query: 'Review');
        await fixture.count(1);
        fixture.reads.first.complete([_row(88001, category: '여행')]);
        await initial;
        final old = notifier.refresh();
        await fixture.count(2);
        await fixture.session('account-b');
        final fresh = notifier.refresh();
        expect(fresh, isNot(same(old)));
        expect(notifier.refresh(), same(fresh));
        await fixture.count(3);
        final loading = root.read(storeTemplateFeedProvider);
        expect(loading.items.any((t) => t.id == 88001), isFalse);
        expect(loading.filterCategory, '여행');
        expect(loading.filterQuery, 'Review');
        expect(loading.lastSyncedAt, isNull);
        expect(loading.isInitialLoading, isTrue);
        if (order != 'old last') {
          if (order == 'old error first') {
            fixture.reads[1].complete({
              'message': 'Old account error',
            }, status: 400);
          } else {
            fixture.reads[1].complete([_row(88001, category: '여행')]);
          }
          await old;
          final stillLoading = root.read(storeTemplateFeedProvider);
          expect(stillLoading.isInitialLoading, isTrue);
          expect(stillLoading.error, isNull);
          expect(stillLoading.items.any((t) => t.id == 88001), isFalse);
        }
        fixture.reads[2].complete([
          _row(89001, category: '여행', likedBy: 'account-b'),
        ]);
        await fresh;
        final snapshot = root.read(storeTemplateFeedProvider).items;
        if (order == 'old last') {
          fixture.reads[1].complete([_row(88001, category: '여행')]);
          await old;
        }
        final state = root.read(storeTemplateFeedProvider);
        expect(state.items, same(snapshot));
        expect(state.items.singleWhere((t) => t.id == 89001).isLiked, isTrue);
        expect(state.items.any((t) => t.id == 88001), isFalse);
        expect(state.isInitialLoading || state.isLoadingMore, isFalse);
        expect(state.page, 0);
        expect(state.error, isNull);
        expect(fixture.reads, hasLength(3));
      },
    );
  }

  test(
    'account replacement and logout automatically restart a pending feed',
    () async {
      await fixture.session('account-a');
      final root = fixture.root();
      await fixture.count(1);
      await fixture.session('account-b');
      await fixture.count(2);
      fixture.reads.first.complete({
        'message': 'Old initial read',
      }, status: 400);
      await _until(() => fixture.repository.finished == 1);
      expect(root.read(storeTemplateFeedProvider).isInitialLoading, isTrue);
      expect(root.read(storeTemplateFeedProvider).error, isNull);
      fixture.reads[1].complete([_row(89001, likedBy: 'account-b')]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      await fixture.client.auth.signOut(scope: SignOutScope.local);
      await fixture.count(3);
      expect(
        root.read(storeTemplateFeedProvider).items.any((t) => t.id == 89001),
        isFalse,
      );
      fixture.reads[2].complete([_row(89001, likedBy: 'account-b')]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      expect(
        root
            .read(storeTemplateFeedProvider)
            .items
            .singleWhere((t) => t.id == 89001)
            .isLiked,
        isFalse,
      );
      expect(fixture.tokens.owner(), isNull);
    },
  );

  test(
    'same-account session renewal preserves the refresh and shares one disposable auth listener',
    () async {
      await fixture.session('account-a');
      final root = fixture.root();
      await fixture.count(1);
      fixture.reads.first.complete([_row(88001)]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      final notifier = root.read(storeTemplateFeedProvider.notifier);
      final refresh = notifier.refresh();
      await fixture.count(2);
      await fixture.session('account-a', version: 'renewed');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(notifier.refresh(), same(refresh));
      expect(fixture.reads, hasLength(2));
      // Keep searches on the same current SDK session as the pending read.
      // Different session identities intentionally do not share repository work.
      fixture.reads[1].complete([_row(88002)]);
      await refresh;
      final pending = notifier.refresh();
      await fixture.count(3);
      final started = fixture.repository.started;
      for (var visit = 0; visit < 12; visit++) {
        final search = fixture.search(root);
        await _until(() => fixture.repository.started == started + visit + 1);
        expect(fixture.repository.authListeners, 1);
        fixture.close(search);
      }
      expect(fixture.reads, hasLength(3));
      fixture.reads.last.complete([_row(88003)]);
      await pending;
      await _until(
        () => fixture.repository.finished == fixture.repository.started,
      );
      fixture.close(root);
      await _until(() => fixture.repository.authListeners == 0);
    },
  );

  test(
    'bundled persisted likes and late full catalogs cannot reapply an earlier owner',
    () async {
      final template = publishedCreationTemplates.first;
      final normalized = template.title.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9가-힣]'),
        '',
      );
      final key = template.id > 0 ? 'id:${template.id}' : 'title:$normalized';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'template_like_state_v1',
        jsonEncode({
          'account-a:$key': {'isLiked': true, 'likeCount': 9},
          'account-b:$key': {'isLiked': false, 'likeCount': 3},
          'guest:$key': {'isLiked': true, 'likeCount': 77},
        }),
      );
      await fixture.session('account-a');
      final root = fixture.root();
      await fixture.count(1);
      fixture.reads.first.complete([]);
      await _until(
        () =>
            root
                .read(storeTemplateFeedProvider)
                .items
                .singleWhere((t) => t.id == template.id)
                .likeCount ==
            9,
      );
      final fullWatch = root.listen(
        templateListProvider,
        (_, __) {},
        fireImmediately: true,
      );
      await root.read(templateListProvider.future);
      await fixture.count(2);
      expect(
        root
            .read(templateListProvider)
            .requireValue
            .singleWhere((t) => t.id == template.id)
            .isLiked,
        isTrue,
      );
      // Keep A's full-catalog response pending while both B consumers restart.
      await fixture.session('account-b');
      await fixture.count(4);
      expect(
        root
            .read(storeTemplateFeedProvider)
            .items
            .singleWhere((t) => t.id == template.id)
            .isLiked,
        isFalse,
      );
      for (final read in fixture.reads.skip(2)) {
        read.complete([]);
      }
      await _until(() => fixture.repository.fullFinished == 1);
      await _until(
        () =>
            root
                .read(storeTemplateFeedProvider)
                .items
                .singleWhere((t) => t.id == template.id)
                .likeCount ==
            3,
      );
      await _until(
        () =>
            root
                .read(templateListProvider)
                .asData
                ?.value
                .singleWhere((t) => t.id == template.id)
                .likeCount ==
            3,
      );
      fixture.reads[1].complete([_row(template.id)]);
      await _until(() => fixture.repository.fullFinished == 2);
      expect(
        root
            .read(templateListProvider)
            .requireValue
            .singleWhere((t) => t.id == template.id)
            .isLiked,
        isFalse,
      );
      expect(
        root
            .read(storeTemplateFeedProvider)
            .items
            .singleWhere((t) => t.id == template.id)
            .isLiked,
        isFalse,
      );
      expect(fixture.repository.authListeners, 1);
      fullWatch.close();
    },
  );

  test(
    'rapid account round trips reject both earlier account generations',
    () async {
      await fixture.session('account-a');
      final root = fixture.root();
      await fixture.count(1);
      await fixture.session('account-b');
      await fixture.count(2);
      await fixture.session('account-a', version: 'returned');
      await fixture.count(3);
      fixture.reads[0].complete([_row(88001)]);
      fixture.reads[1].complete([_row(89001, likedBy: 'account-b')]);
      await _until(() => fixture.repository.finished == 2);
      final loading = root.read(storeTemplateFeedProvider);
      expect(loading.isInitialLoading, isTrue);
      expect(loading.items.any((t) => t.id == 88001 || t.id == 89001), isFalse);
      fixture.reads[2].complete([_row(99001)]);
      await _until(
        () => !root.read(storeTemplateFeedProvider).isInitialLoading,
      );
      expect(
        root
            .read(storeTemplateFeedProvider)
            .items
            .singleWhere((t) => t.id == 99001)
            .isLiked,
        isTrue,
      );
      expect(fixture.repository.authListeners, 1);
    },
  );
}
