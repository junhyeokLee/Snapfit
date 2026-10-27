import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_saved_works_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_search_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_works_manage_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _creator = SocialProfile(
  userId: 'creator',
  displayName: '여행 창작자',
  handle: 'travel.creator',
);

SocialWork _work(
  String title, {
  List<String> imageUrls = const [],
  String status = 'published',
}) => SocialWork(
  id: title,
  title: title,
  topic: '여행',
  author: _creator,
  imageUrls: imageUrls,
  status: status,
  createdAt: DateTime(2026, 10, 26),
);

class _DiscoveryRepository extends SocialRepository {
  _DiscoveryRepository()
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'public-test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  List<SocialWork> works = [_work('여행의 기록')];
  List<SocialProfile> profiles = [_creator];
  bool failWorks = false, failProfiles = false, failSaved = false;
  bool failFeed = false;
  bool failOwn = false;
  bool expiredImages = false;
  int workSearches = 0, profileSearches = 0, savedReads = 0, ownReads = 0;
  final delayedSearches = <String, Completer<List<SocialWork>>>{};
  final saveBarriers = <Completer<void>>[];
  int saveWrites = 0;
  final workOffsets = <int>[];
  final profileOffsets = <int>[];
  final savedOffsets = <int>[];
  final failedWorkOffsets = <int>{};
  final ownQueries = <(String, int)>[];
  final visibilityWrites = <(String, bool)>[];
  final visibilityBarriers = <Completer<void>>[];

  List<SocialWork> _signedWorks(int signature) => expiredImages
      ? [
          _work(
            '서명이 만료된 기록',
            imageUrls: ['https://fixture.invalid/expired-$signature.png'],
          ),
        ]
      : works;

  @override
  Future<List<SocialWork>> search(String query) async {
    workSearches++;
    final barrier = delayedSearches[query];
    if (barrier != null) return barrier.future;
    if (failWorks) throw StateError('Synthetic work search failure');
    return _signedWorks(workSearches);
  }

  @override
  Future<List<SocialProfile>> searchProfiles(String query) async {
    profileSearches++;
    if (failProfiles) throw StateError('Synthetic profile search failure');
    return profiles;
  }

  SocialWorkPage _page(List<SocialWork> works, int offset, int limit) {
    final items = works.skip(offset).take(limit).toList();
    return SocialWorkPage(
      items: items,
      hasMore: offset + items.length < works.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<SocialWorkPage> searchPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) async {
    workOffsets.add(offset);
    if (failedWorkOffsets.remove(offset)) {
      throw StateError('Synthetic later-page failure');
    }
    return _page(await search(query), offset, limit);
  }

  @override
  Future<SocialProfilePage> searchProfilesPage(
    String query, {
    int offset = 0,
    int limit = 12,
  }) async {
    profileOffsets.add(offset);
    final all = await searchProfiles(query);
    final items = all.skip(offset).take(limit).toList();
    return SocialProfilePage(
      items: items,
      hasMore: offset + items.length < all.length,
      nextOffset: offset + items.length,
    );
  }

  @override
  Future<SocialWorkPage> fetchSavedWorksPage({
    int offset = 0,
    int limit = 12,
  }) async {
    savedOffsets.add(offset);
    return _page(await fetchSavedWorks(), offset, limit);
  }

  @override
  Future<SocialWorkPage> fetchOwnWorksPage({
    String status = 'all',
    int offset = 0,
    int limit = 12,
  }) async {
    ownReads++;
    ownQueries.add((status, offset));
    if (failOwn) throw StateError('Synthetic management loading failure');
    final filtered = _signedWorks(ownReads).where((work) {
      return work.status != 'draft' &&
          work.status != 'deleted' &&
          (status == 'all' ||
              (status == 'public' ? work.isPublished : !work.isPublished));
    }).toList();
    return _page(filtered, offset, limit);
  }

  @override
  Future<void> setWorkVisibility(String id, bool published) async {
    visibilityWrites.add((id, published));
    if (visibilityBarriers.isNotEmpty) {
      await visibilityBarriers.removeAt(0).future;
    }
    works = works.map((work) {
      return work.id == id
          ? _work(
              work.title,
              imageUrls: work.imageUrls,
              status: published ? 'published' : 'private',
            )
          : work;
    }).toList();
  }

  @override
  Future<void> deleteWork(String id) async {
    works = works.where((work) => work.id != id).toList();
  }

  @override
  Future<SocialWork?> fetchWork(String id) async =>
      works.where((work) => work.id == id).firstOrNull;

  @override
  Future<List<SocialComment>> fetchComments(String id) async => [];

  @override
  Future<List<SocialWork>> fetchSavedWorks() async {
    savedReads++;
    if (failSaved) throw StateError('Synthetic saved loading failure');
    return _signedWorks(savedReads);
  }

  @override
  Future<bool> setSaved(String id, bool saved) async {
    saveWrites++;
    if (saveBarriers.isNotEmpty) await saveBarriers.removeAt(0).future;
    return saved;
  }

  @override
  Future<SocialWorkPage> fetchFeed({
    bool following = false,
    String? topic,
    int offset = 0,
    int limit = 12,
  }) async {
    if (failFeed) throw StateError('Synthetic feed loading failure');
    return SocialWorkPage(
      items: works,
      hasMore: false,
      nextOffset: works.length,
    );
  }
}

Widget _app(
  Widget screen,
  _DiscoveryRepository repository, {
  String? Function()? actor,
  double textScale = 1,
}) => ProviderScope(
  overrides: [
    socialCurrentUserIdProvider.overrideWith((_) => actor?.call() ?? 'viewer'),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(
    theme: SnapFitTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: screen,
  ),
);

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField).first, query);
  await tester.tap(find.byTooltip('검색하기'));
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    450,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 160,
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a failed user search preserves successful work results', (
    tester,
  ) async {
    final repository = _DiscoveryRepository()..failProfiles = true;
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    expect(find.text('여행의 기록'), findsOneWidget);
    expect(repository.workSearches, 1);
    await tester.tap(find.text('사용자'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '다시 시도'), findsOneWidget);
    repository.failProfiles = false;
    await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text(_creator.displayName), findsOneWidget);
    expect(repository.workSearches, 1);
    expect(repository.profileSearches, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed work search preserves successful user results', (
    tester,
  ) async {
    final repository = _DiscoveryRepository()..failWorks = true;
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    await tester.tap(find.text('사용자'));
    await tester.pumpAndSettle();
    expect(find.text(_creator.displayName), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '다시 시도'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('resubmitting the same query fetches newly published works', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    repository.works = [_work('새로운 여행')];
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    expect(find.text('새로운 여행'), findsOneWidget);
    expect(find.text('여행의 기록'), findsNothing);
    expect(repository.workSearches, 2);
  });

  testWidgets('a late older search cannot overwrite the current query', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    final slow = Completer<List<SocialWork>>();
    repository.delayedSearches['오래된 검색'] = slow;
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '오래된 검색');
    repository.works = [_work('최신 검색 결과')];
    await _search(tester, '새 검색');
    await tester.pumpAndSettle();
    slow.complete([_work('뒤늦은 결과')]);
    await tester.pumpAndSettle();
    expect(find.text('최신 검색 결과'), findsOneWidget);
    expect(find.text('뒤늦은 결과'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from detail rechecks withdrawn search results', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    await tester.tap(find.text('여행의 기록'));
    await tester.pumpAndSettle();
    repository.works = [];
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('찾는 작품이 아직 없어요.'), findsOneWidget);
    expect(repository.workSearches, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old save completion cannot unlock a new session request', (
    tester,
  ) async {
    var actor = 'viewer';
    final repository = _DiscoveryRepository();
    final oldWrite = Completer<void>();
    final newWrite = Completer<void>();
    repository.saveBarriers.addAll([oldWrite, newWrite]);
    await tester.pumpWidget(
      _app(const SocialSavedWorksScreen(), repository, actor: () => actor),
    );
    await tester.pumpAndSettle();
    final remove = find.widgetWithText(TextButton, '저장 해제');
    await _scrollTo(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialSavedWorksScreen)),
    );
    actor = 'another-viewer';
    container.invalidate(socialCurrentUserIdProvider);
    container.invalidate(socialSavedWorksPageProvider);
    await tester.pumpAndSettle();
    actor = 'viewer';
    container.invalidate(socialCurrentUserIdProvider);
    container.invalidate(socialSavedWorksPageProvider);
    await tester.pumpAndSettle();
    await _scrollTo(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(repository.saveWrites, 2);
    oldWrite.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(remove).onPressed, isNull);
    newWrite.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextButton>(remove).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'saved' : 'feed'} refresh reports failure in the page',
      (tester) async {
        final repository = _DiscoveryRepository();
        await tester.pumpWidget(
          _app(
            saved ? const SocialSavedWorksScreen() : const SocialFeedScreen(),
            repository,
          ),
        );
        await tester.pumpAndSettle();
        repository.failSaved = saved;
        repository.failFeed = !saved;
        final refresh = tester.widget<RefreshIndicator>(
          find.byType(RefreshIndicator),
        );
        await refresh.onRefresh();
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, '다시 시도'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('saved artwork failures can request a fresh signed URL', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(_app(const SocialSavedWorksScreen(), repository));
    await tester.pumpAndSettle();
    expect(repository.savedReads, 1);
    final tile = tester.widget<SocialWorkTile>(find.byType(SocialWorkTile));
    expect(tile.onRetry, isNotNull);
    tile.onRetry!();
    await tester.pumpAndSettle();
    expect(repository.savedReads, 2);
  });

  testWidgets('search artwork retry leaves the creator search cache intact', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
    await tester.pumpAndSettle();
    await _search(tester, '여행');
    await tester.pumpAndSettle();
    final tile = tester.widget<SocialWorkTile>(find.byType(SocialWorkTile));
    expect(tile.onRetry, isNotNull);
    tile.onRetry!();
    await tester.pumpAndSettle();
    expect(repository.workSearches, 2);
    expect(repository.profileSearches, 1);
  });

  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'saved' : 'search'} permanent image failures renew only once',
      (tester) async {
        // The widget-test HTTP client returns 400 for these fixture URLs.
        final repository = _DiscoveryRepository()..expiredImages = true;
        await tester.pumpWidget(
          _app(
            saved ? const SocialSavedWorksScreen() : const SocialSearchScreen(),
            repository,
          ),
        );
        if (!saved) {
          await tester.pumpAndSettle();
          await _search(tester, '여행');
        }
        for (var attempt = 0; attempt < 12; attempt++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(saved ? repository.savedReads : repository.workSearches, 2);
        expect(find.text('이미지 다시 불러오기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final saved in [false, true]) {
    testWidgets(
      '${saved ? 'saved' : 'search'} reaches works after the old 30-item cap',
      (tester) async {
        final repository = _DiscoveryRepository()
          ..works = List.generate(31, (index) => _work('기록 ${index + 1}'));
        await tester.pumpWidget(
          _app(
            saved ? const SocialSavedWorksScreen() : const SocialSearchScreen(),
            repository,
          ),
        );
        await tester.pumpAndSettle();
        if (!saved) {
          await _search(tester, '기록');
          await tester.pumpAndSettle();
        }
        for (var page = 0; page < 2; page++) {
          final more = find.widgetWithText(OutlinedButton, '작품 더 보기');
          await _scrollTo(tester, more);
          await tester.tap(more);
          await tester.pumpAndSettle();
        }
        await _scrollTo(tester, find.text('기록 31'));
        expect(find.text('기록 31'), findsOneWidget);
        expect(saved ? repository.savedOffsets : repository.workOffsets, [
          0,
          12,
          24,
        ]);
        expect(find.widgetWithText(OutlinedButton, '작품 더 보기'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'creator search reaches the 31st user independently of work pages',
    (tester) async {
      final repository = _DiscoveryRepository()
        ..profiles = List.generate(
          31,
          (index) => SocialProfile(
            userId: 'creator-$index',
            displayName: '창작자 ${index + 1}',
            handle: 'creator.$index',
          ),
        );
      await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
      await tester.pumpAndSettle();
      await _search(tester, '창작자');
      await tester.pumpAndSettle();
      await tester.tap(find.text('사용자'));
      await tester.pumpAndSettle();
      for (var page = 0; page < 2; page++) {
        final more = find.widgetWithText(OutlinedButton, '사용자 더 보기');
        await _scrollTo(tester, more);
        await tester.tap(more);
        await tester.pumpAndSettle();
      }
      await _scrollTo(tester, find.text('창작자 31'));
      expect(find.text('창작자 31'), findsOneWidget);
      expect(repository.profileOffsets, [0, 12, 24]);
      expect(repository.workOffsets, [0]);
      expect(find.widgetWithText(OutlinedButton, '사용자 더 보기'), findsNothing);
    },
  );

  testWidgets(
    'a failed later search page keeps earlier results and retries its offset',
    (tester) async {
      final repository = _DiscoveryRepository()
        ..works = List.generate(13, (index) => _work('기록 ${index + 1}'))
        ..failedWorkOffsets.add(12);
      await tester.pumpWidget(_app(const SocialSearchScreen(), repository));
      await tester.pumpAndSettle();
      await _search(tester, '기록');
      await tester.pumpAndSettle();
      final more = find.widgetWithText(OutlinedButton, '작품 더 보기');
      await _scrollTo(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('기록 1'), findsOneWidget);
      final retry = find.widgetWithText(OutlinedButton, '다시 시도');
      await _scrollTo(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.text('기록 13'));
      expect(repository.workOffsets, [0, 12, 12]);
      expect(find.text('기록 13'), findsOneWidget);
      expect(find.text('기록 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('management reaches the 31st work with paged requests', (
    tester,
  ) async {
    final repository = _DiscoveryRepository()
      ..works = List.generate(31, (index) => _work('내 기록 ${index + 1}'));
    await tester.pumpWidget(
      _app(const SocialWorksManageScreen(), repository, actor: () => 'creator'),
    );
    await tester.pumpAndSettle();
    for (var page = 0; page < 2; page++) {
      final more = find.widgetWithText(OutlinedButton, '작품 더 보기');
      await _scrollTo(tester, more);
      await tester.tap(more);
      await tester.pumpAndSettle();
    }
    await _scrollTo(tester, find.text('내 기록 31'));
    expect(find.text('내 기록 31'), findsOneWidget);
    expect(repository.ownQueries, [('all', 0), ('all', 12), ('all', 24)]);
    expect(find.widgetWithText(OutlinedButton, '작품 더 보기'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management applies the status filter before pagination', (
    tester,
  ) async {
    final repository = _DiscoveryRepository()
      ..works = [
        for (var index = 0; index < 30; index++) _work('공개 기록 $index'),
        _work('오래된 비공개 기록', status: 'private'),
      ];
    await tester.pumpWidget(
      _app(const SocialWorksManageScreen(), repository, actor: () => 'creator'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '비공개 보관'));
    await tester.pumpAndSettle();
    expect(find.text('오래된 비공개 기록'), findsOneWidget);
    expect(repository.ownQueries.last, ('private', 0));
    expect(find.widgetWithText(OutlinedButton, '작품 더 보기'), findsNothing);
    expect(find.text('아직 이곳에 작품이 없어요.'), findsNothing);
  });

  testWidgets('management reserves an action before its confirmation opens', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(
      _app(const SocialWorksManageScreen(), repository, actor: () => 'creator'),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '비공개로 전환'),
    );
    button.onPressed!();
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '취소'));
    await tester.pumpAndSettle();
    expect(repository.visibilityWrites, isEmpty);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '비공개로 전환'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('management dismisses a stale confirmation across A to B to A', (
    tester,
  ) async {
    var actor = 'creator';
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(
      _app(const SocialWorksManageScreen(), repository, actor: () => actor),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SocialWorksManageScreen)),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, '비공개로 전환'));
    await tester.pumpAndSettle();
    expect(find.text('작품을 비공개로 바꿀까요?'), findsOneWidget);
    actor = 'other-owner';
    container.invalidate(socialCurrentUserIdProvider);
    container.invalidate(socialOwnWorksPageProvider);
    await tester.pumpAndSettle();
    actor = 'creator';
    container.invalidate(socialCurrentUserIdProvider);
    container.invalidate(socialOwnWorksPageProvider);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(repository.visibilityWrites, isEmpty);
    await tester.tap(find.widgetWithText(OutlinedButton, '비공개로 전환'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '비공개 전환'));
    await tester.pumpAndSettle();
    expect(repository.visibilityWrites, [('여행의 기록', false)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a prior management response cannot release a new session action',
    (tester) async {
      var actor = 'creator';
      final repository = _DiscoveryRepository();
      final oldWrite = Completer<void>();
      final newWrite = Completer<void>();
      repository.visibilityBarriers.addAll([oldWrite, newWrite]);
      await tester.pumpWidget(
        _app(const SocialWorksManageScreen(), repository, actor: () => actor),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialWorksManageScreen)),
      );
      Future<void> confirm() async {
        await tester.tap(find.widgetWithText(OutlinedButton, '비공개로 전환'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '비공개 전환'));
        await tester.pumpAndSettle();
      }

      await confirm();
      actor = 'other-owner';
      container.invalidate(socialCurrentUserIdProvider);
      container.invalidate(socialOwnWorksPageProvider);
      await tester.pumpAndSettle();
      actor = 'creator';
      container.invalidate(socialCurrentUserIdProvider);
      container.invalidate(socialOwnWorksPageProvider);
      await tester.pumpAndSettle();
      await confirm();
      expect(repository.visibilityWrites.length, 2);
      oldWrite.complete();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, '비공개로 전환'),
            )
            .onPressed,
        isNull,
      );
      newWrite.complete();
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(OutlinedButton, '같은 공개본으로 다시 공개'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'management identity changes dismiss only their own dialog route',
    (tester) async {
      var actor = 'creator';
      final repository = _DiscoveryRepository();
      await tester.pumpWidget(
        _app(const SocialWorksManageScreen(), repository, actor: () => actor),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(SocialWorksManageScreen));
      final container = ProviderScope.containerOf(context);
      await tester.tap(find.widgetWithText(OutlinedButton, '비공개로 전환'));
      await tester.pumpAndSettle();
      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('다른 화면의 안내'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('안내 닫기'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      actor = 'other-owner';
      container.invalidate(socialCurrentUserIdProvider);
      container.invalidate(socialOwnWorksPageProvider);
      await tester.pumpAndSettle();
      expect(find.text('다른 화면의 안내'), findsOneWidget);
      expect(find.text('작품을 비공개로 바꿀까요?'), findsNothing);
      expect(repository.visibilityWrites, isEmpty);
      await tester.tap(find.text('안내 닫기'));
      await tester.pumpAndSettle();
      expect(find.byType(SocialWorksManageScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('management refresh errors remain recoverable in the page', (
    tester,
  ) async {
    final repository = _DiscoveryRepository();
    await tester.pumpWidget(
      _app(const SocialWorksManageScreen(), repository, actor: () => 'creator'),
    );
    await tester.pumpAndSettle();
    repository.failOwn = true;
    final refresh = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, '다시 시도'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'management permanent image failures preserve one automatic renewal',
    (tester) async {
      final repository = _DiscoveryRepository()..expiredImages = true;
      await tester.pumpWidget(
        _app(
          const SocialWorksManageScreen(),
          repository,
          actor: () => 'creator',
        ),
      );
      for (var attempt = 0; attempt < 12; attempt++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      expect(repository.ownReads, 2);
      expect(find.byTooltip('이미지 다시 불러오기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('management image retry fits 320px with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _DiscoveryRepository()..expiredImages = true;
    await tester.pumpWidget(
      _app(
        const SocialWorksManageScreen(),
        repository,
        actor: () => 'creator',
        textScale: 2.2,
      ),
    );
    for (var attempt = 0; attempt < 12; attempt++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    final retry = find.byTooltip('이미지 다시 불러오기');
    await _scrollTo(tester, retry);
    expect(retry.hitTestable(), findsOneWidget);
    expect(repository.ownReads, 2);
    expect(tester.takeException(), isNull);
  });
}
