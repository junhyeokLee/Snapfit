import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_reports_admin_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_report_sheet.dart';

import '../helpers/memory_moment_draft_store.dart';

class _Repository extends Mock implements SocialRepository {}

class _Moments extends Mock implements MomentsRepository {}

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'me';
  void change(String? id) => state = id;
}

class _Admin extends Notifier<bool> {
  @override
  bool build() => true;
  void change(bool allowed) => state = allowed;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);
final _admin = NotifierProvider<_Admin, bool>(_Admin.new);

SocialWork _work({
  String id = 'public-record',
  String author = 'me',
  bool published = true,
  int revision = 7,
}) => SocialWork(
  id: id,
  author: SocialProfile(
    userId: author,
    displayName: '사진을 담는 나',
    handle: 'days',
  ),
  title: '오래된 9월의 기록',
  createdAt: DateTime.utc(2026, 10, 28),
  recordDate: DateTime.utc(2026, 9, 13),
  kind: 'moment',
  status: published ? 'published' : 'private',
  publicationRevision: revision,
);
SocialReport _report(String id, {String status = 'open'}) => SocialReport(
  id: id,
  targetKind: 'work',
  targetId: 'public-record',
  reason: 'privacy',
  details: '사진 속 연락처',
  status: status,
  revision: 4,
  createdAt: DateTime.utc(2026, 10, 28),
);

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository, {
  Widget screen = const SocialWorkDetailScreen(workId: 'public-record'),
  SocialWork Function()? work,
  List<SocialComment> comments = const [],
  bool allowed = true,
  bool settle = true,
  FutureOr<SocialWorkPage> Function(SocialFeedQuery)? feed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final moments = _Moments();
  when(() => moments.currentUserId).thenReturn('me');
  when(() => moments.authChanges).thenAnswer((_) => const Stream.empty());
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository),
      pointShopAdminAccessProvider.overrideWith(
        (ref) => allowed && ref.watch(_admin),
      ),
      socialWorkProvider.overrideWith((_, _) async => work?.call() ?? _work()),
      socialFeedProvider.overrideWith(
        (_, query) async => feed == null
            ? SocialWorkPage(
                items: [_work(author: 'other')],
                hasMore: false,
                nextOffset: 1,
              )
            : await feed(query),
      ),
      socialProfileProvider.overrideWith(
        (_, id) async =>
            SocialProfile(userId: id, displayName: '공개 프로필', handle: 'profile'),
      ),
      socialProfileMomentMonthsPageProvider.overrideWith(
        (_, _) async => const SocialMomentMonthsPage(
          items: [],
          hasMore: false,
          nextOffset: 0,
        ),
      ),
      socialBlockedProfilesProvider.overrideWith((_) async => []),
      socialCommentsPageProvider.overrideWith(
        (_, _) async => SocialCommentPage(
          items: comments,
          hasMore: false,
          nextOffset: comments.length,
        ),
      ),
      momentsCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      momentsRepositoryProvider.overrideWithValue(moments),
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
      momentPublicationStateProvider.overrideWith((_, _) async => null),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: SnapFitTheme.light(), home: screen),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'feed uses opaque cursors before numeric offsets and stops on a repeated cursor',
    (tester) async {
      const firstCursor = {'at': '2026-10-28T10:00:00Z', 'id': 'boundary-one'};
      const secondCursor = {'at': '2026-10-27T10:00:00Z', 'id': 'boundary-two'};
      final queries = <SocialFeedQuery>[];
      await _mount(
        tester,
        _Repository(),
        screen: const SocialFeedScreen(),
        feed: (query) {
          queries.add(query);
          final first = query.cursor == null;
          final second = query.cursor?['id'] == 'boundary-one';
          return SocialWorkPage(
            items: [
              _work(
                id: first
                    ? 'first'
                    : second
                    ? 'second'
                    : 'third',
                author: 'other',
              ),
            ],
            hasMore: true,
            nextOffset: 999,
            nextCursor: first ? firstCursor : secondCursor,
          );
        },
      );
      expect(find.widgetWithText(TextButton, '최신'), findsOneWidget);
      expect(find.widgetWithText(TextButton, '추천'), findsNothing);
      await _tap(tester, 'social-feed-more');
      await _tap(tester, 'social-feed-more');
      expect(queries.map((query) => query.cursor).toList(), [
        null,
        firstCursor,
        secondCursor,
      ]);
      expect(
        queries.every((query) => query.offset == 0 && query.limit == 12),
        isTrue,
      );
      expect(find.byKey(const ValueKey('social-feed-more')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'old feed load more callbacks cannot append pages after the filter changes',
    (tester) async {
      final pending = Completer<SocialWorkPage>();
      final queries = <SocialFeedQuery>[];
      await _mount(
        tester,
        _Repository(),
        screen: const SocialFeedScreen(),
        feed: (query) {
          queries.add(query);
          if (query.following)
            return SocialWorkPage(
              items: [_work(id: 'following-only', author: 'other')],
              hasMore: false,
              nextOffset: 1,
            );
          if (query.offset == 37) return pending.future;
          return SocialWorkPage(
            items: [_work(author: 'other')],
            hasMore: true,
            nextOffset: 37,
          );
        },
      );
      final more = find.byKey(const ValueKey('social-feed-more'));
      await tester.ensureVisible(more);
      final stale = tester.widget<OutlinedButton>(more).onPressed!;
      stale();
      await tester.pump();
      final feedScroll = find
          .descendant(
            of: find.byType(SocialFeedScreen),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      tester.state<ScrollableState>(feedScroll).position.jumpTo(0);
      await tester.pump();
      final following = find.widgetWithText(TextButton, '팔로잉');
      await Scrollable.ensureVisible(tester.element(following), alignment: .5);
      await tester.pump();
      expect(following.hitTestable(), findsOneWidget);
      await tester.tap(following);
      await tester.pump(const Duration(milliseconds: 100));
      expect(queries.last.following, isTrue);
      pending.complete(
        SocialWorkPage(
          items: [_work(id: 'late-old-page', author: 'other')],
          hasMore: false,
          nextOffset: 38,
        ),
      );
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(
        queries
            .where((query) => query.following)
            .every((query) => query.offset == 0 && query.cursor == null),
        isTrue,
      );
      expect(find.byKey(const ValueKey('late-old-page')), findsNothing);
      expect(find.byKey(const ValueKey('following-only')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('feed plus opens writing directly instead of the journal list', (
    tester,
  ) async {
    await _mount(tester, _Repository(), screen: const SocialFeedScreen());
    await tester.tap(find.byTooltip('한 장의 기록 남기기'));
    await tester.pumpAndSettle();
    expect(find.byType(MomentComposeScreen), findsOneWidget);
    expect(
      tester
          .widget<MomentComposeScreen>(find.byType(MomentComposeScreen))
          .record,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  for (final profile in [false, true]) {
    testWidgets(
      '${profile ? 'profile' : 'feed'} report targets only the selected public identity',
      (tester) async {
        final repository = _Repository();
        final targets = <(String, String)>[];
        when(
          () => repository.reportContent(
            targetKind: any(named: 'targetKind'),
            targetId: any(named: 'targetId'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
            requestId: any(named: 'requestId'),
          ),
        ).thenAnswer((invocation) async {
          targets.add((
            invocation.namedArguments[#targetKind] as String,
            invocation.namedArguments[#targetId] as String,
          ));
          return _report('sent');
        });
        await _mount(
          tester,
          repository,
          screen: profile
              ? const SocialProfileScreen(userId: 'other')
              : const SocialFeedScreen(),
        );
        if (profile) {
          await tester.tap(find.byTooltip('프로필 더보기'));
        } else {
          await _tap(tester, 'social-feed-more-public-record');
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text(profile ? '사용자 신고' : '기록 신고'));
        await tester.pumpAndSettle();
        await _tap(tester, 'social-report-reason-spam');
        await _tap(tester, 'social-report-submit');
        expect(targets, [
          (profile ? 'user' : 'work', profile ? 'other' : 'public-record'),
        ]);
        expect(find.byType(SocialReportSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'owner privacy confirmation cancels without writing then sends the viewed CAS revision',
    (tester) async {
      final repository = _Repository();
      var published = true;
      when(
        () => repository.setMomentPublicationVisibility(
          'public-record',
          false,
          expectedPublicationRevision: 7,
        ),
      ).thenAnswer((_) async => published = false);
      await _mount(tester, repository, work: () => _work(published: published));
      await _tap(tester, 'social-moment-make-private');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.setMomentPublicationVisibility(
          'public-record',
          false,
          expectedPublicationRevision: 7,
        ),
      );
      await _tap(tester, 'social-moment-make-private');
      await _tap(tester, 'social-moment-private-confirm');
      verify(
        () => repository.setMomentPublicationVisibility(
          'public-record',
          false,
          expectedPublicationRevision: 7,
        ),
      ).called(1);
      expect(find.text('나만 보는 기록으로 바꿨어요.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('social-moment-make-private')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a new publication revision dismisses an old confirmation without writing',
    (tester) async {
      final repository = _Repository();
      var revision = 7;
      final container = await _mount(
        tester,
        repository,
        work: () => _work(revision: revision),
      );
      await _tap(tester, 'social-moment-make-private');
      revision = 8;
      container.invalidate(socialWorkProvider('public-record'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-moment-private-confirm')),
        findsNothing,
      );
      verifyNever(
        () => repository.setMomentPublicationVisibility(
          any(),
          any(),
          expectedPublicationRevision: any(
            named: 'expectedPublicationRevision',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a private mutation completing after A B A does not announce success to a new session',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<void>();
      when(
        () => repository.setMomentPublicationVisibility(
          'public-record',
          false,
          expectedPublicationRevision: 7,
        ),
      ).thenAnswer((_) => pending.future);
      final container = await _mount(tester, repository);
      await _tap(tester, 'social-moment-make-private');
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('social-moment-private-confirm')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('other');
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('me');
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('나만 보는 기록으로 바꿨어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing a historical public record opens the exact private original',
    (tester) async {
      final repository = _Repository();
      final record = MomentRecord(
        id: 'original-record',
        recordDate: DateTime.utc(2026, 9, 13),
        caption: '원본의 9월 이야기',
        photos: const [],
        revision: 11,
      );
      when(
        () => repository.fetchOwnMomentRecord('public-record'),
      ).thenAnswer((_) async => record);
      await _mount(tester, repository);
      await _tap(tester, 'social-owner-edit');
      final composer = tester.widget<MomentComposeScreen>(
        find.byType(MomentComposeScreen),
      );
      expect(composer.record, same(record));
      expect(find.text('원본의 9월 이야기'), findsOneWidget);
      verify(() => repository.fetchOwnMomentRecord('public-record')).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a late original record lookup after account change never opens private content',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<MomentRecord?>();
      when(
        () => repository.fetchOwnMomentRecord('public-record'),
      ).thenAnswer((_) => pending.future);
      final container = await _mount(tester, repository);
      final edit = find.byKey(const ValueKey('social-owner-edit'));
      await tester.ensureVisible(edit);
      tester.widget<OutlinedButton>(edit).onPressed!();
      await tester.pump();
      container.read(_viewer.notifier).change('other');
      await tester.pumpAndSettle();
      container.read(_viewer.notifier).change('me');
      await tester.pumpAndSettle();
      pending.complete(
        MomentRecord(
          id: 'secret',
          recordDate: DateTime.utc(2026, 9),
          caption: '늦게 온 비공개 글',
          photos: const [],
          revision: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MomentComposeScreen), findsNothing);
      expect(find.text('늦게 온 비공개 글'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'work and comment reports target the selected public content and own comments keep delete',
    (tester) async {
      final repository = _Repository();
      final targets = <(String, String)>[];
      when(
        () => repository.reportContent(
          targetKind: any(named: 'targetKind'),
          targetId: any(named: 'targetId'),
          reason: any(named: 'reason'),
          details: any(named: 'details'),
          requestId: any(named: 'requestId'),
        ),
      ).thenAnswer((invocation) async {
        targets.add((
          invocation.namedArguments[#targetKind] as String,
          invocation.namedArguments[#targetId] as String,
        ));
        return _report('accepted');
      });
      await _mount(
        tester,
        repository,
        work: () => _work(author: 'other'),
        comments: [
          SocialComment(
            id: 'foreign-comment',
            author: const SocialProfile(
              userId: 'other',
              displayName: '다른 사람',
              handle: 'other',
            ),
            body: '신고 대상 댓글',
            createdAt: DateTime.utc(2026, 10, 28),
          ),
          SocialComment(
            id: 'my-comment',
            author: const SocialProfile(
              userId: 'me',
              displayName: '내 댓글',
              handle: 'me',
            ),
            body: '내가 남긴 글',
            createdAt: DateTime.utc(2026, 10, 28),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey('social-moment-make-private')),
        findsNothing,
      );
      await _tap(tester, 'social-work-report');
      await _tap(tester, 'social-report-reason-privacy');
      await _tap(tester, 'social-report-submit');
      await _tap(tester, 'social-comment-report-foreign-comment');
      await _tap(tester, 'social-report-reason-harassment');
      await _tap(tester, 'social-report-submit');
      expect(targets, [
        ('work', 'public-record'),
        ('comment', 'foreign-comment'),
      ]);
      expect(
        find.byKey(const ValueKey('social-comment-report-my-comment')),
        findsNothing,
      );
      expect(find.byTooltip('내 댓글 삭제'), findsOneWidget);
      expect(find.byType(SocialReportSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'non administrators cannot query reports even with a direct screen route',
    (tester) async {
      final repository = _Repository();
      await _mount(
        tester,
        repository,
        screen: const SocialReportsAdminScreen(),
        allowed: false,
      );
      expect(find.text('신고를 확인할 관리자 권한이 필요해요.'), findsOneWidget);
      verifyNever(
        () => repository.fetchAdminReportsPage(
          status: any(named: 'status'),
          offset: any(named: 'offset'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'administrator follows server offsets and resolves only confirmed report revision',
    (tester) async {
      final repository = _Repository();
      var handled = false;
      final reads = <(String, int)>[];
      when(
        () => repository.fetchAdminReportsPage(
          status: any(named: 'status'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((invocation) async {
        final status = invocation.namedArguments[#status] as String;
        final offset = invocation.namedArguments[#offset] as int;
        reads.add((status, offset));
        return SocialReportsPage(
          items: handled
              ? []
              : [_report(offset == 0 ? 'first' : 'second', status: status)],
          hasMore: offset == 0 && !handled,
          nextOffset: 37,
        );
      });
      when(
        () => repository.resolveReport(
          id: 'first',
          decision: 'hide',
          expectedRevision: 4,
        ),
      ).thenAnswer((_) async {
        handled = true;
        return _report('first', status: 'hidden');
      });
      await _mount(
        tester,
        repository,
        screen: const SocialReportsAdminScreen(),
      );
      await _tap(tester, 'social-report-admin-more');
      expect(reads, [('open', 0), ('open', 37)]);
      await _tap(tester, 'social-report-admin-hide-first');
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.resolveReport(
          id: 'first',
          decision: 'hide',
          expectedRevision: 4,
        ),
      );
      await _tap(tester, 'social-report-admin-hide-first');
      await _tap(tester, 'social-report-admin-confirm');
      verify(
        () => repository.resolveReport(
          id: 'first',
          decision: 'hide',
          expectedRevision: 4,
        ),
      ).called(1);
      expect(find.text('이 상태의 신고가 없어요.'), findsOneWidget);
      expect(reads.last, ('open', 0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin permission loss removes cached report details and ignores a delayed page',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<SocialReportsPage>();
      when(
        () => repository.fetchAdminReportsPage(
          status: any(named: 'status'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => pending.future);
      final container = await _mount(
        tester,
        repository,
        screen: const SocialReportsAdminScreen(),
        settle: false,
      );
      container.read(_admin.notifier).change(false);
      await tester.pumpAndSettle();
      pending.complete(
        SocialReportsPage(
          items: [_report('private-admin')],
          hasMore: false,
          nextOffset: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('신고를 확인할 관리자 권한이 필요해요.'), findsOneWidget);
      expect(find.text('사진 속 연락처'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
