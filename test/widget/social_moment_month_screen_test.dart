import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_moment_month_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_work_detail_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_page_header.dart';
import 'package:snap_fit/shared/web/web_design.dart';

class _Repository extends Mock implements SocialRepository {}

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'viewer-a';
  void change(String? id) => state = id;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);
final _october = DateTime.utc(2026, 10);
const _author = SocialProfile(
  userId: 'creator',
  displayName: '하루를 담는 유진',
  handle: 'yujin.days',
);

SocialWork _record(
  String id, {
  int day = 28,
  int month = 10,
  String status = 'published',
  String kind = 'moment',
  SocialProfile author = _author,
  bool liked = false,
  bool saved = false,
}) => SocialWork(
  id: id,
  author: author,
  title: '기억 $id',
  caption: '오래 간직하고 싶은 하루',
  createdAt: DateTime.utc(2026, 10, 28),
  recordDate: DateTime.utc(2026, month, day),
  kind: kind,
  status: status,
  aspectRatio: 1,
  isLiked: liked,
  isSaved: saved,
);
SocialWorkPage _page(
  List<SocialWork> records, {
  bool more = false,
  int? next,
}) => SocialWorkPage(
  items: records,
  hasMore: more,
  nextOffset: next ?? records.length,
);

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  required FutureOr<SocialWorkPage> Function(SocialMomentMonthQuery, String?)
  load,
  Widget? screen,
  _Repository? repository,
  List<SocialMomentMonthQuery>? queries,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository ?? _Repository()),
      socialProfileProvider.overrideWith(
        (_, userId) async => SocialProfile(
          userId: userId,
          displayName: _author.displayName,
          handle: _author.handle,
        ),
      ),
      socialMomentMonthPageProvider.overrideWith((ref, query) async {
        queries?.add(query);
        return await load(query, ref.read(_viewer));
      }),
      socialWorkProvider.overrideWith((_, id) async => _record(id)),
      socialCommentsPageProvider.overrideWith(
        (_, _) async =>
            const SocialCommentPage(items: [], hasMore: false, nextOffset: 0),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: WebNavigationScope(
            onNavigate: (_) {},
            onNotifications: () {},
            child: child!,
          ),
        ),
        home:
            screen ??
            SocialMomentMonthScreen(userId: 'creator', month: _october),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final scroll = find
      .descendant(
        of: find.byType(SocialMomentMonthScreen),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
  await tester.scrollUntilVisible(
    finder,
    600,
    maxScrolls: 100,
    scrollable: scroll,
  );
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester, {bool settle = true}) async {
  final button = find.byKey(const ValueKey('social-month-more'));
  await _reveal(tester, button);
  await tester.tap(button);
  if (settle)
    await tester.pumpAndSettle();
  else
    await tester.pump();
}

void main() {
  testWidgets(
    'public month keeps large photos, server date order and excludes private content',
    (tester) async {
      final queries = <SocialMomentMonthQuery>[];
      final container = await _mount(
        tester,
        queries: queries,
        load: (_, _) => _page([
          _record('late-day', day: 28),
          _record('early-day', day: 3),
          _record('private', status: 'private'),
          _record('album', kind: 'album'),
          _record('wrong-month', month: 9),
          _record(
            'wrong-owner',
            author: const SocialProfile(
              userId: 'someone-else',
              displayName: '다른 작가',
              handle: 'else',
            ),
          ),
        ]),
      );
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('공개 기록만 보여요.'), findsOneWidget);
      expect(find.text('${_author.displayName}님의 기록'), findsOneWidget);
      expect(find.byType(SocialPageHeader), findsOneWidget);
      final art = find.byKey(const ValueKey('social-feed-artwork-late-day'));
      expect(tester.getSize(art).width, greaterThanOrEqualTo(350));
      expect(tester.getTopLeft(art).dy, lessThan(450));
      final visible = tester
          .widgetList<SocialFeedCard>(find.byType(SocialFeedCard))
          .map((card) => card.work.id)
          .toList();
      expect(visible.first, 'late-day');
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-month-record-early-day')),
      );
      expect(find.text('10월 3일'), findsOneWidget);
      for (final id in ['private', 'album', 'wrong-month', 'wrong-owner']) {
        expect(find.byKey(ValueKey('social-month-record-$id')), findsNothing);
      }
      expect(queries.single.limit, 12);
      expect(container.exists(momentsRepositoryProvider), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    '31 records paginate in twelves, deduplicate and retain earlier pages after retry',
    (tester) async {
      final records = List.generate(
        31,
        (index) => _record('record-$index', day: 28 - index ~/ 2),
      );
      final queries = <SocialMomentMonthQuery>[];
      var failed = false;
      await _mount(
        tester,
        queries: queries,
        load: (query, _) {
          if (query.offset == 0)
            return _page(records.take(12).toList(), more: true, next: 12);
          if (query.offset == 12) {
            if (!failed) {
              failed = true;
              throw StateError('second page unavailable');
            }
            return _page(records.sublist(11, 23), more: true, next: 24);
          }
          return _page(records.sublist(23), next: 32);
        },
      );
      await _more(tester);
      expect(find.text('다음 기록을 불러오지 못했어요.'), findsOneWidget);
      await _more(tester);
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-month-record-record-11')),
      );
      expect(
        find.byKey(const ValueKey('social-month-record-record-11')),
        findsOneWidget,
      );
      await _more(tester);
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-month-record-record-30')),
      );
      expect(
        find.byKey(const ValueKey('social-month-record-record-30')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('social-month-more')), findsNothing);
      expect(queries.where((query) => query.offset == 0).length, 2);
      expect(queries.where((query) => query.offset == 12).length, 2);
      expect(queries.last.offset, 24);
      expect(queries.every((query) => query.limit == 12), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile or month replacement resets pagination and rejects the old reply and callback',
    (tester) async {
      final pending = Completer<SocialWorkPage>();
      final selection = ValueNotifier(('creator', _october));
      addTearDown(selection.dispose);
      final queries = <SocialMomentMonthQuery>[];
      await _mount(
        tester,
        queries: queries,
        screen: ValueListenableBuilder<(String, DateTime)>(
          valueListenable: selection,
          builder: (_, value, _) =>
              SocialMomentMonthScreen(userId: value.$1, month: value.$2),
        ),
        load: (query, _) {
          if (query.userId == 'creator' && query.month.month == 10) {
            if (query.offset == 12) return pending.future;
            return _page([_record('old-first')], more: true, next: 12);
          }
          return _page([
            _record(
              'new-first',
              month: 11,
              author: const SocialProfile(
                userId: 'second',
                displayName: '새 작가',
                handle: 'next',
              ),
            ),
          ]);
        },
      );
      await _reveal(tester, find.byKey(const ValueKey('social-month-more')));
      final stale = tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('social-month-more')),
          )
          .onPressed!;
      await _more(tester, settle: false);
      selection.value = ('second', DateTime.utc(2026, 11));
      await tester.pumpAndSettle();
      expect(find.text('2026년 11월'), findsOneWidget);
      expect(queries.last.userId, 'second');
      expect(queries.last.offset, 0);
      pending.complete(_page([_record('old-late')]));
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-month-record-old-late')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('social-month-record-new-first')),
        findsOneWidget,
      );
      expect(
        queries
            .where((query) => query.userId == 'second')
            .every((query) => query.offset == 0),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'viewer A B A refreshes first page and never restores the old pending page',
    (tester) async {
      final pending = Completer<SocialWorkPage>();
      var phase = 0;
      final container = await _mount(
        tester,
        load: (query, _) {
          if (query.offset == 12) return pending.future;
          return _page([_record('phase-$phase')], more: phase == 0, next: 12);
        },
      );
      await _more(tester, settle: false);
      phase = 1;
      container.read(_viewer.notifier).change('viewer-b');
      await tester.pumpAndSettle();
      phase = 2;
      container.read(_viewer.notifier).change('viewer-a');
      await tester.pumpAndSettle();
      pending.complete(_page([_record('old-account-page')]));
      await tester.pumpAndSettle();
      expect(find.byType(SocialMomentMonthScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('social-month-record-phase-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-month-record-old-account-page')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('social-month-more')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'first page retry and empty state stay on the same public month',
    (tester) async {
      var reads = 0;
      await _mount(
        tester,
        load: (_, _) {
          if (++reads == 1) throw StateError('offline');
          return _page([]);
        },
      );
      await tester.tap(find.byKey(const ValueKey('social-month-first-retry')));
      await tester.pumpAndSettle();
      expect(find.text('2026년 10월'), findsOneWidget);
      expect(find.text('이달에 공개한 기록이 없어요.'), findsOneWidget);
      expect(find.byType(SocialFeedCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'shared reactions, detail and signed image retry update this monthly page',
    (tester) async {
      final repository = _Repository();
      var liked = false, saved = false, reads = 0;
      when(
        () => repository.setLiked('interactive', true),
      ).thenAnswer((_) async => liked = true);
      when(
        () => repository.setSaved('interactive', true),
      ).thenAnswer((_) async => saved = true);
      await _mount(
        tester,
        repository: repository,
        load: (_, _) {
          reads++;
          return _page([_record('interactive', liked: liked, saved: saved)]);
        },
      );
      for (final id in ['social-like-interactive', 'social-save-interactive']) {
        final action = find.byKey(ValueKey(id));
        await _reveal(tester, action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }
      expect(liked, isTrue);
      expect(saved, isTrue);
      final before = reads;
      tester.widget<SocialFeedCard>(find.byType(SocialFeedCard)).onRetry!();
      await tester.pumpAndSettle();
      expect(reads, greaterThan(before));
      final open = find.byKey(const ValueKey('social-feed-open-interactive'));
      await _reveal(tester, open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SocialWorkDetailScreen>(find.byType(SocialWorkDetailScreen))
            .workId,
        'interactive',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(1440, 1000)]) {
    testWidgets('public month fits dark large type and wide browser at $size', (
      tester,
    ) async {
      await _mount(
        tester,
        size: size,
        dark: true,
        scale: size.width == 320 ? 1.8 : 1,
        load: (_, _) => _page([_record('responsive')]),
      );
      expect(find.byType(SocialPageHeader), findsOneWidget);
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-feed-open-responsive')),
      );
      expect(
        find.byKey(const ValueKey('social-feed-open-responsive')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
