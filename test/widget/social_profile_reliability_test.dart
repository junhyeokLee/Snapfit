import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_edit_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_relations_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_widgets.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_widgets.dart';

final _emptyMomentPages = socialProfileMomentsPageProvider.overrideWith(
  (_, _) async =>
      const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
);
final _emptyMomentMonths = socialProfileMomentMonthsPageProvider.overrideWith(
  (_, _) async =>
      const SocialMomentMonthsPage(items: [], hasMore: false, nextOffset: 0),
);

Future<void> _openAlbums(WidgetTester tester) async {
  final tab = find.byKey(const ValueKey('profile-collection-albums'));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
  await tester.pumpAndSettle();
}

Override _profileWorksOverride(
  String userId,
  FutureOr<List<SocialWork>> Function(Ref) load,
) => socialProfileWorksPageProvider(SocialProfileWorksQuery(userId))
    .overrideWith((ref) async {
      final works = await load(ref);
      return SocialWorkPage(
        items: works,
        hasMore: false,
        nextOffset: works.length,
      );
    });

Override _relationsOverride(
  SocialRelationsQuery query,
  FutureOr<List<SocialProfile>> Function(Ref) load,
) => socialRelationsPageProvider(query).overrideWith((ref) async {
  final people = await load(ref);
  return SocialProfilePage(
    items: people,
    hasMore: false,
    nextOffset: people.length,
  );
});

class _Repository extends Mock implements SocialRepository {}

class _Actor extends Notifier<String?> {
  @override
  String? build() => 'me';

  void change(String? value) => state = value;
}

final _actor = NotifierProvider<_Actor, String?>(_Actor.new);

const _creator = SocialProfile(
  userId: 'creator',
  displayName: '여행 작가',
  handle: 'travel.note',
);
const _followingCreator = SocialProfile(
  userId: 'creator',
  displayName: '여행 작가',
  handle: 'travel.note',
  isFollowing: true,
);
const _second = SocialProfile(
  userId: 'second',
  displayName: '새로운 작가',
  handle: 'next.note',
);

Widget _app(Widget home) => MaterialApp(
  theme: SnapFitTheme.light().copyWith(splashFactory: NoSplash.splashFactory),
  home: home,
);

ProviderContainer _container(
  _Repository repository, {
  bool following = false,
  VoidCallback? onProfileRead,
}) => ProviderContainer(
  overrides: [
    _emptyMomentPages,
    _emptyMomentMonths,
    socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_actor)),
    socialRepositoryProvider.overrideWithValue(repository),
    socialBlockedProfilesProvider.overrideWith((_) async => []),
    socialProfileProvider('creator').overrideWith((ref) async {
      ref.watch(_actor);
      onProfileRead?.call();
      return following ? _followingCreator : _creator;
    }),
    socialProfileProvider('second').overrideWith((ref) async {
      ref.watch(_actor);
      return _second;
    }),
    _profileWorksOverride('creator', (ref) async {
      ref.watch(_actor);
      return [];
    }),
    _profileWorksOverride('second', (ref) async {
      ref.watch(_actor);
      return [];
    }),
    for (final owner in ['me', 'creator', 'second'])
      for (final followers in [true, false])
        _relationsOverride(SocialRelationsQuery(owner, followers: followers), (
          ref,
        ) async {
          ref.watch(_actor);
          return [following ? _followingCreator : _creator];
        }),
  ],
);

Future<void> _mount(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  bool disposeContainer = true,
}) async {
  if (disposeContainer) addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: _app(child)),
  );
  await tester.pumpAndSettle();
}

Future<void> _cycleAccount(
  WidgetTester tester,
  ProviderContainer container,
) async {
  container.read(_actor.notifier).change('second-account');
  await tester.pumpAndSettle();
  container.read(_actor.notifier).change('me');
  await tester.pumpAndSettle();
}

ProviderContainer _pagedContainer(_Repository repository) => ProviderContainer(
  overrides: [
    _emptyMomentPages,
    _emptyMomentMonths,
    socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_actor)),
    socialAuthStateProvider.overrideWith((_) => const Stream<String?>.empty()),
    socialRepositoryProvider.overrideWithValue(repository),
    socialBlockedProfilesProvider.overrideWith((_) async => []),
    socialProfileProvider('creator').overrideWith((ref) async {
      ref.watch(_actor);
      return _creator;
    }),
  ],
);

SocialWorkPage _workPage(List<SocialWork> works, int offset, int limit) {
  final items = works.skip(offset).take(limit).toList();
  return SocialWorkPage(
    items: items,
    hasMore: offset + items.length < works.length,
    nextOffset: offset + items.length,
  );
}

void main() {
  testWidgets('an old profile follow reply cannot finish a new account cycle', (
    tester,
  ) async {
    final repository = _Repository();
    final first = Completer<bool>();
    final second = Completer<bool>();
    var calls = 0;
    var profileReads = 0;
    when(
      () => repository.setFollowing('creator', true),
    ).thenAnswer((_) => calls++ == 0 ? first.future : second.future);
    final container = _container(
      repository,
      onProfileRead: () => profileReads++,
    );
    await _mount(
      tester,
      container,
      const SocialProfileScreen(userId: 'creator'),
    );
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    await _cycleAccount(tester, container);
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    final readsBeforeOldReply = profileReads;
    first.complete(true);
    await tester.pumpAndSettle();
    expect(profileReads, readsBeforeOldReply);
    expect(find.text('변경 중…'), findsOneWidget);
    second.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('변경 중…'), findsNothing);
    verify(() => repository.setFollowing('creator', true)).called(2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an old profile failure cannot announce an error after A B A', (
    tester,
  ) async {
    final repository = _Repository();
    final request = Completer<bool>();
    when(
      () => repository.setFollowing('creator', true),
    ).thenAnswer((_) => request.future);
    final container = _container(repository);
    await _mount(
      tester,
      container,
      const SocialProfileScreen(userId: 'creator'),
    );
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    await _cycleAccount(tester, container);
    request.completeError(StateError('old account request failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('변경 결과를 확인하지 못했어요.'), findsNothing);
    expect(find.text('팔로우'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile identity replacement cancels only its confirmation', (
    tester,
  ) async {
    final repository = _Repository();
    final target = ValueNotifier('creator');
    addTearDown(target.dispose);
    final container = _container(repository, following: true);
    await _mount(
      tester,
      container,
      ValueListenableBuilder<String>(
        valueListenable: target,
        builder: (_, value, _) => SocialProfileScreen(userId: value),
      ),
    );
    await tester.tap(find.text('팔로잉'));
    await tester.pumpAndSettle();
    expect(find.text('팔로우를 해제할까요?'), findsOneWidget);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    unawaited(
      navigator.push<void>(
        DialogRoute<void>(
          context: tester.element(find.byType(SocialProfileScreen)),
          builder: (_) => const AlertDialog(title: Text('별도 안내')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    target.value = 'second';
    await tester.pumpAndSettle();
    expect(find.text('별도 안내'), findsOneWidget);
    expect(find.text('팔로우를 해제할까요?', skipOffstage: false), findsNothing);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('새로운 작가'), findsOneWidget);
    verifyNever(() => repository.setFollowing(any(), any()));
    expect(tester.takeException(), isNull);
  });

  for (final block in [false, true]) {
    testWidgets(
      'account change closes profile ${block ? 'block' : 'unfollow'} confirmation',
      (tester) async {
        final repository = _Repository();
        final container = _container(repository, following: true);
        await _mount(
          tester,
          container,
          const SocialProfileScreen(userId: 'creator'),
        );
        if (block) {
          await tester.tap(find.byTooltip('프로필 더보기'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('사용자 차단'));
        } else {
          await tester.tap(find.text('팔로잉'));
        }
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await _cycleAccount(tester, container);
        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => repository.setFollowing(any(), any()));
        verifyNever(() => repository.setBlocked(any(), any()));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'late profile reply cannot change a replacement profile busy state',
    (tester) async {
      final repository = _Repository();
      final first = Completer<bool>();
      final second = Completer<bool>();
      when(
        () => repository.setFollowing('creator', true),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.setFollowing('second', true),
      ).thenAnswer((_) => second.future);
      final container = _container(repository);
      final target = ValueNotifier('creator');
      addTearDown(target.dispose);
      await _mount(
        tester,
        container,
        ValueListenableBuilder<String>(
          valueListenable: target,
          builder: (_, value, _) => SocialProfileScreen(userId: value),
        ),
      );
      await tester.tap(find.text('팔로우'));
      await tester.pumpAndSettle();
      target.value = 'second';
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로우'));
      await tester.pumpAndSettle();
      first.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('변경 중…'), findsOneWidget);
      second.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('변경 중…'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an old relation reply cannot finish the new account follow', (
    tester,
  ) async {
    final repository = _Repository();
    final first = Completer<bool>();
    final second = Completer<bool>();
    var calls = 0;
    when(
      () => repository.setFollowing('creator', true),
    ).thenAnswer((_) => calls++ == 0 ? first.future : second.future);
    final container = _container(repository);
    await _mount(tester, container, const SocialRelationsScreen(userId: 'me'));
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    await _cycleAccount(tester, container);
    await tester.tap(find.text('팔로우'));
    await tester.pumpAndSettle();
    first.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('변경 중…'), findsOneWidget);
    second.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('변경 중…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'relation owner changes reset the tab and discard stale confirmation',
    (tester) async {
      final repository = _Repository();
      final target = ValueNotifier('me');
      addTearDown(target.dispose);
      final container = _container(repository, following: true);
      await _mount(
        tester,
        container,
        ValueListenableBuilder<String>(
          valueListenable: target,
          builder: (_, value, _) =>
              SocialRelationsScreen(userId: value, followers: value == 'me'),
        ),
      );
      await tester.tap(find.byTooltip('여행 작가 관계 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로워 삭제'));
      await tester.pumpAndSettle();
      expect(find.text('팔로워에서 삭제할까요?'), findsOneWidget);
      target.value = 'second';
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '팔로잉'))
            .selected,
        isTrue,
      );
      verifyNever(() => repository.removeFollower(any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account changes discard the relation follower removal confirmation',
    (tester) async {
      final repository = _Repository();
      final container = _container(repository, following: true);
      await _mount(
        tester,
        container,
        const SocialRelationsScreen(userId: 'me'),
      );
      await tester.tap(find.byTooltip('여행 작가 관계 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('팔로워 삭제'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _cycleAccount(tester, container);
      expect(find.byType(AlertDialog), findsNothing);
      verifyNever(() => repository.removeFollower(any()));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'relation avatars can resolve a fresh public photo after expiry',
    (tester) async {
      const avatarProfile = SocialProfile(
        userId: 'creator',
        displayName: '여행 작가',
        handle: 'travel.note',
        avatarUrl: 'https://example.test/expired-relation.png',
      );
      final repository = _Repository();
      when(() => repository.fetchProfile('creator')).thenAnswer(
        (_) async => const SocialProfile(
          userId: 'creator',
          displayName: '여행 작가',
          handle: 'travel.note',
          avatarUrl: 'https://example.test/renewed-relation.png',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_actor)),
          socialRepositoryProvider.overrideWithValue(repository),
          socialBlockedProfilesProvider.overrideWith((_) async => []),
          _relationsOverride(
            const SocialRelationsQuery('me'),
            (_) async => [avatarProfile],
          ),
        ],
      );
      await _mount(
        tester,
        container,
        const SocialRelationsScreen(userId: 'me'),
      );
      final tile = tester.widget<SocialRelationTile>(
        find.byType(SocialRelationTile),
      );
      expect(tile.refreshImageUrl, isNotNull);
      expect(
        await tile.refreshImageUrl!(),
        'https://example.test/renewed-relation.png',
      );
      verify(
        () => repository.fetchProfile('creator'),
      ).called(greaterThanOrEqualTo(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile work image retry remains a separate accessible action', (
    tester,
  ) async {
    var retries = 0;
    final work = SocialWork(
      id: 'retry-work',
      author: _creator,
      title: '사진이 있는 작품',
      imageUrls: const ['https://example.test/unavailable-work.png'],
      createdAt: DateTime(2026, 10, 26),
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: SocialProfileGallery(
                works: [work],
                onOpenWork: (_) {},
                onRetry: (_) => retries++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<SocialWorkImage>(
        find.byType(SocialWorkImage),
      );
      expect(image.onRetry, isNotNull);
      expect(image.excludeImageSemantics, isTrue);
      image.onRetry!();
      expect(retries, greaterThanOrEqualTo(1));
      final retry = find.text('이미지 다시 불러오기');
      await tester.pumpAndSettle();
      expect(retry, findsOneWidget);
      final retryNode = tester.getSemantics(retry);
      expect(
        retryNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(retryNode.label, contains('이미지 다시 불러오기'));
      expect(find.bySemanticsLabel('사진이 있는 작품, 1쪽 앨범 보기'), findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(retries, greaterThanOrEqualTo(2));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets(
    'profile galleries can load their 31st work without losing earlier pages',
    (tester) async {
      final repository = _Repository();
      final works = List.generate(
        31,
        (index) => SocialWork(
          id: 'profile-paged-$index',
          author: _creator,
          title: '공개 작품 $index',
          createdAt: DateTime(2026, 10, 26),
        ),
      );
      final offsets = <int>[];
      when(
        () => repository.fetchProfileWorksPage(
          'creator',
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        final limit = invocation.namedArguments[#limit] as int;
        offsets.add(offset);
        return _workPage(works, offset, limit);
      });
      final container = _pagedContainer(repository);
      await _mount(
        tester,
        container,
        const SocialProfileScreen(userId: 'creator'),
      );
      await _openAlbums(tester);
      expect(find.byType(SocialProfileWorkTile), findsNWidgets(12));
      final more = find.byKey(const ValueKey('social-profile-more-works'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileWorkTile), findsNWidgets(24));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileWorkTile), findsNWidgets(31));
      expect(
        find.byKey(const ValueKey('social-profile-work-profile-paged-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-profile-work-profile-paged-30')),
        findsOneWidget,
      );
      expect(more, findsNothing);
      expect(offsets, [0, 12, 24]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'later profile page errors retain loaded works and can be retried',
    (tester) async {
      final repository = _Repository();
      final works = List.generate(
        13,
        (index) => SocialWork(
          id: 'retry-paged-$index',
          author: _creator,
          title: '다시 볼 작품 $index',
          createdAt: DateTime(2026, 10, 26),
        ),
      );
      var failed = false;
      when(
        () => repository.fetchProfileWorksPage(
          'creator',
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
        final offset = invocation.namedArguments[#offset] as int;
        if (offset == 12 && !failed) {
          failed = true;
          throw StateError('Synthetic second-page failure');
        }
        return _workPage(
          works,
          offset,
          invocation.namedArguments[#limit] as int,
        );
      });
      final container = _pagedContainer(repository);
      await _mount(
        tester,
        container,
        const SocialProfileScreen(userId: 'creator'),
      );
      await _openAlbums(tester);
      final more = find.byKey(const ValueKey('social-profile-more-works'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileWorkTile), findsNWidgets(12));
      expect(find.text('앨범을 더 불러오지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialProfileWorkTile), findsNWidgets(13));
      expect(more, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('signed page renewal preserves the gallery state while waiting', (
    tester,
  ) async {
    final repository = _Repository();
    final renewal = Completer<SocialWorkPage>();
    final works = [
      SocialWork(
        id: 'renewed-work',
        author: _creator,
        title: '크게 보는 사진',
        createdAt: DateTime(2026, 10, 26),
      ),
    ];
    var reads = 0;
    when(
      () => repository.fetchProfileWorksPage('creator', offset: 0, limit: 12),
    ).thenAnswer((_) async {
      if (reads++ > 0) return renewal.future;
      return _workPage(works, 0, 12);
    });
    final container = _pagedContainer(repository);
    await _mount(
      tester,
      container,
      const SocialProfileScreen(userId: 'creator'),
    );
    await _openAlbums(tester);
    await tester.ensureVisible(find.byTooltip('모아 보기'));
    await tester.tap(find.byTooltip('모아 보기'));
    await tester.pumpAndSettle();
    final state = tester.state(find.byType(SocialProfileGallery));
    tester
        .widget<SocialProfileGallery>(find.byType(SocialProfileGallery))
        .onRetry!(works.single);
    await tester.pump();
    expect(
      identical(tester.state(find.byType(SocialProfileGallery)), state),
      isTrue,
    );
    expect(find.byType(SocialProfileWorkTile), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    renewal.complete(_workPage(works, 0, 12));
    await tester.pumpAndSettle();
    expect(
      identical(tester.state(find.byType(SocialProfileGallery)), state),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'relationship lists reveal the 13th person and reset on tab changes',
    (tester) async {
      final repository = _Repository();
      final people = List.generate(
        13,
        (index) => SocialProfile(
          userId: 'person-$index',
          displayName: '기록하는 사람 $index',
          handle: 'person.$index',
        ),
      );
      final requests = <(bool, int)>[];
      when(
        () => repository.fetchRelationsPage(
          'me',
          followers: any(named: 'followers'),
          offset: any(named: 'offset'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((invocation) async {
        final followers = invocation.namedArguments[#followers] as bool;
        final offset = invocation.namedArguments[#offset] as int;
        final limit = invocation.namedArguments[#limit] as int;
        requests.add((followers, offset));
        final items = people.skip(offset).take(limit).toList();
        return SocialProfilePage(
          items: items,
          hasMore: offset + items.length < people.length,
          nextOffset: offset + items.length,
        );
      });
      final container = _pagedContainer(repository);
      await _mount(
        tester,
        container,
        const SocialRelationsScreen(userId: 'me'),
      );
      expect(find.byType(SocialRelationTile), findsNWidgets(12));
      final more = find.byKey(const ValueKey('social-relations-more'));
      await tester.ensureVisible(more);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byType(SocialRelationTile), findsNWidgets(13));
      expect(
        find.byKey(const ValueKey('social-relation-person-12')),
        findsOneWidget,
      );
      expect(more, findsNothing);
      final following = find.widgetWithText(ChoiceChip, '팔로잉');
      await tester.ensureVisible(following);
      await tester.tap(following);
      await tester.pumpAndSettle();
      expect(find.byType(SocialRelationTile), findsNWidgets(12));
      expect(requests, [(true, 0), (true, 12), (false, 0)]);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'blocking from profiles and relationships refreshes open saved and comment pages',
    (tester) async {
      for (final fromRelations in [false, true]) {
        final repository = _Repository();
        var blocked = false;
        var savedReads = 0;
        var commentReads = 0;
        final work = SocialWork(
          id: 'creator-work',
          author: _creator,
          title: '차단 전 저장한 작품',
          createdAt: DateTime(2026, 10, 26),
        );
        final comment = SocialComment(
          id: 'creator-comment',
          author: _creator,
          body: '차단 전 공개 댓글',
          createdAt: DateTime(2026, 10, 26),
        );
        const savedQuery = SocialPageQuery();
        const commentsQuery = SocialCommentsQuery('open-work');
        when(() => repository.setBlocked('creator', true)).thenAnswer((
          _,
        ) async {
          blocked = true;
        });
        final container = ProviderContainer(
          overrides: [
            _emptyMomentPages,
            _emptyMomentMonths,
            socialCurrentUserIdProvider.overrideWith((_) => 'me'),
            socialRepositoryProvider.overrideWithValue(repository),
            socialBlockedProfilesProvider.overrideWith(
              (_) async => blocked ? [_creator] : [],
            ),
            socialProfileProvider(
              'creator',
            ).overrideWith((_) async => _creator),
            _profileWorksOverride('creator', (_) async => []),
            _relationsOverride(
              const SocialRelationsQuery('me'),
              (_) async => blocked ? [] : [_creator],
            ),
            socialSavedWorksPageProvider(savedQuery).overrideWith((_) async {
              savedReads++;
              return SocialWorkPage(
                items: blocked ? [] : [work],
                hasMore: false,
                nextOffset: blocked ? 0 : 1,
              );
            }),
            socialCommentsPageProvider(commentsQuery).overrideWith((_) async {
              commentReads++;
              return SocialCommentPage(
                items: blocked ? [] : [comment],
                hasMore: false,
                nextOffset: blocked ? 0 : 1,
              );
            }),
          ],
        );
        final savedSubscription = container.listen(
          socialSavedWorksPageProvider(savedQuery),
          (_, _) {},
        );
        final commentsSubscription = container.listen(
          socialCommentsPageProvider(commentsQuery),
          (_, _) {},
        );
        try {
          expect(
            (await container.read(
              socialSavedWorksPageProvider(savedQuery).future,
            )).items.single.id,
            work.id,
          );
          expect(
            (await container.read(
              socialCommentsPageProvider(commentsQuery).future,
            )).items.single.id,
            comment.id,
          );
          await _mount(
            tester,
            container,
            fromRelations
                ? const SocialRelationsScreen(userId: 'me')
                : const SocialProfileScreen(userId: 'creator'),
            disposeContainer: false,
          );
          await tester.tap(
            find.byTooltip(fromRelations ? '여행 작가 관계 관리' : '프로필 더보기'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('사용자 차단'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, '차단'));
          await tester.pumpAndSettle();
          expect(
            savedReads,
            2,
            reason: 'Saved pages must recheck visibility after blocking.',
          );
          expect(
            commentReads,
            2,
            reason: 'Open comment pages must remove the blocked author.',
          );
          expect(
            (await container.read(
              socialSavedWorksPageProvider(savedQuery).future,
            )).items,
            isEmpty,
          );
          expect(
            (await container.read(
              socialCommentsPageProvider(commentsQuery).future,
            )).items,
            isEmpty,
          );
          verify(() => repository.setBlocked('creator', true)).called(1);
          expect(tester.takeException(), isNull);
        } finally {
          savedSubscription.close();
          commentsSubscription.close();
          // Unmount while this test still owns FakeAsync, then drain Riverpod's
          // auto-dispose work before releasing its externally owned container.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          container.dispose();
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets(
    'saving a public name refreshes every open paginated author cache',
    (tester) async {
      final repository = _Repository();
      var profile = const SocialProfile(
        userId: 'me',
        displayName: '바꾸기 전 이름',
        handle: 'my.public',
      );
      final reads = <String, int>{};
      void read(String key) => reads[key] = (reads[key] ?? 0) + 1;
      SocialWork work() => SocialWork(
        id: 'own-work',
        author: profile,
        title: '내 공개 작품',
        createdAt: DateTime(2026, 10, 26),
      );
      SocialWorkPage works(String key) {
        read(key);
        return SocialWorkPage(items: [work()], hasMore: false, nextOffset: 1);
      }

      when(
        () => repository.upsertOwnProfile(
          displayName: '새로운 공개 이름',
          handle: 'my.public',
          bio: '',
        ),
      ).thenAnswer((_) async {
        profile = const SocialProfile(
          userId: 'me',
          displayName: '새로운 공개 이름',
          handle: 'my.public',
        );
        return profile;
      });
      const relationsQuery = SocialRelationsQuery('creator');
      const worksQuery = SocialProfileWorksQuery('me');
      const ownQuery = SocialOwnWorksQuery();
      const savedQuery = SocialPageQuery();
      const commentsQuery = SocialCommentsQuery('open-work');
      final container = ProviderContainer(
        overrides: [
          _emptyMomentPages,
          _emptyMomentMonths,
          socialCurrentUserIdProvider.overrideWith((_) => 'me'),
          socialRepositoryProvider.overrideWithValue(repository),
          ownSocialProfileProvider.overrideWith((_) async => profile),
          socialRelationsPageProvider(relationsQuery).overrideWith((_) async {
            read('relations');
            return SocialProfilePage(
              items: [profile],
              hasMore: false,
              nextOffset: 1,
            );
          }),
          socialProfileWorksPageProvider(
            worksQuery,
          ).overrideWith((_) async => works('profileWorks')),
          socialOwnWorksPageProvider(
            ownQuery,
          ).overrideWith((_) async => works('ownWorks')),
          socialSavedWorksPageProvider(
            savedQuery,
          ).overrideWith((_) async => works('savedWorks')),
          socialCommentsPageProvider(commentsQuery).overrideWith((_) async {
            read('comments');
            return SocialCommentPage(
              items: [
                SocialComment(
                  id: 'own-comment',
                  author: profile,
                  body: '내 댓글',
                  createdAt: DateTime(2026, 10, 26),
                ),
              ],
              hasMore: false,
              nextOffset: 1,
            );
          }),
        ],
      );
      final subscriptions = [
        container.listen(
          socialRelationsPageProvider(relationsQuery),
          (_, _) {},
        ),
        container.listen(socialProfileWorksPageProvider(worksQuery), (_, _) {}),
        container.listen(socialOwnWorksPageProvider(ownQuery), (_, _) {}),
        container.listen(socialSavedWorksPageProvider(savedQuery), (_, _) {}),
        container.listen(socialCommentsPageProvider(commentsQuery), (_, _) {}),
      ];
      try {
        await _mount(tester, container, const SocialProfileEditScreen());
        expect(reads.values, everyElement(1));
        await tester.enterText(
          find.byKey(const ValueKey('social-profile-name')),
          '새로운 공개 이름',
        );
        final save = find.widgetWithText(FilledButton, '프로필 저장');
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(
          reads.keys,
          unorderedEquals([
            'relations',
            'profileWorks',
            'ownWorks',
            'savedWorks',
            'comments',
          ]),
        );
        expect(reads.values, everyElement(2));
        expect(
          (await container.read(
            socialRelationsPageProvider(relationsQuery).future,
          )).items.single.displayName,
          '새로운 공개 이름',
        );
        expect(
          (await container.read(
            socialCommentsPageProvider(commentsQuery).future,
          )).items.single.author.displayName,
          '새로운 공개 이름',
        );
        for (final page in [
          await container.read(
            socialProfileWorksPageProvider(worksQuery).future,
          ),
          await container.read(socialOwnWorksPageProvider(ownQuery).future),
          await container.read(socialSavedWorksPageProvider(savedQuery).future),
        ]) {
          expect(page.items.single.author.displayName, '새로운 공개 이름');
        }
        expect(tester.takeException(), isNull);
      } finally {
        for (final subscription in subscriptions) {
          subscription.close();
        }
      }
    },
  );
}
