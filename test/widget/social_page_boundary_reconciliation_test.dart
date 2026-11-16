import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_moment_month_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_moments.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover_picker.dart';
import 'package:snap_fit/shared/web/web_design.dart';

enum _Surface { feed, months, monthDetail, coverPicker }

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'owner';
  void change(String? id) => state = id;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);

const _owner = SocialProfile(
  userId: 'owner',
  displayName: '순간 수집가',
  handle: 'days',
);
final _october = DateTime.utc(2026, 10);
Map<String, dynamic> _cursor(String edge) => {'edge': edge};

class _Fixture {
  bool shifted = false;
  final reads = <String?>[];
  Completer<SocialWorkPage>? pendingWork;
  Completer<SocialMomentMonthsPage>? pendingMonths;

  ({List<String> ids, String? next}) data(String? edge) => switch (edge) {
    null => (ids: ['first'], next: 'one'),
    'one' => (
      ids: [shifted ? 'inserted' : 'second'],
      next: shifted ? 'two-new' : 'two-old',
    ),
    'two-old' => (ids: ['old-tail'], next: 'four-old'),
    'two-new' => (ids: ['second', 'old-tail'], next: null),
    _ => (ids: ['unexpected'], next: null),
  };

  DateTime month(String id) => DateTime.utc(2026, switch (id) {
    'first' => 10,
    'inserted' => 9,
    'second' => 8,
    'old-tail' => 6,
    _ => 5,
  });

  SocialWork record(String id, {DateTime? inMonth}) => SocialWork(
    id: id,
    kind: 'moment',
    author: _owner,
    title: '공개 기록 $id',
    createdAt: DateTime.utc(2026, 10, 28),
    recordDate: DateTime.utc(
      (inMonth ?? _october).year,
      (inMonth ?? _october).month,
      28,
    ),
  );

  Future<SocialWorkPage> workPage(Map<String, dynamic>? cursor) async {
    final edge = cursor?['edge'] as String?;
    reads.add(edge);
    if (edge == 'one' && pendingWork != null) return pendingWork!.future;
    final payload = data(edge);
    return SocialWorkPage(
      items: payload.ids.map(record).toList(),
      hasMore: payload.next != null,
      nextOffset: 12,
      nextCursor: payload.next == null ? null : _cursor(payload.next!),
    );
  }

  Future<SocialMomentMonthsPage> monthPage(Map<String, dynamic>? cursor) async {
    final edge = cursor?['edge'] as String?;
    reads.add(edge);
    if (edge == 'one' && pendingMonths != null) return pendingMonths!.future;
    final payload = data(edge);
    return SocialMomentMonthsPage(
      items: payload.ids
          .map(
            (id) => SocialMomentMonth(
              month: month(id),
              recordCount: 1,
              cover: record(id, inMonth: month(id)),
            ),
          )
          .toList(),
      hasMore: payload.next != null,
      nextOffset: 6,
      nextCursor: payload.next == null ? null : _cursor(payload.next!),
    );
  }
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Surface surface,
  _Fixture fixture, {
  ValueNotifier<DateTime>? monthSelection,
  Future<void> Function(DateTime, String?)? onSelect,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialProfileProvider.overrideWith((_, _) async => _owner),
      socialFeedProvider.overrideWith(
        (_, query) => fixture.workPage(query.cursor),
      ),
      socialMomentMonthPageProvider.overrideWith(
        (_, query) => monthSelection == null
            ? fixture.workPage(query.cursor)
            : Future.value(
                SocialWorkPage(
                  items: [
                    fixture.record(
                      'pick-${query.month.month}',
                      inMonth: query.month,
                    ),
                  ],
                  hasMore: false,
                  nextOffset: 1,
                ),
              ),
      ),
      socialProfileMomentMonthsPageProvider.overrideWith(
        (_, query) => fixture.monthPage(query.cursor),
      ),
    ],
  );
  addTearDown(container.dispose);
  final screen = switch (surface) {
    _Surface.feed => const SocialFeedScreen(),
    _Surface.monthDetail => SocialMomentMonthScreen(
      userId: 'owner',
      month: _october,
    ),
    _Surface.months => const Scaffold(
      body: SingleChildScrollView(
        child: SocialProfileMoments(userId: 'owner', own: false),
      ),
    ),
    _Surface.coverPicker => Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => monthSelection == null
                ? showSocialMomentMonthCoverPicker(
                    context,
                    userId: 'owner',
                    month: _october,
                    selectedWorkId: null,
                    onSelect: (_) async {},
                  )
                : showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    showDragHandle: true,
                    builder: (_) => ValueListenableBuilder<DateTime>(
                      valueListenable: monthSelection,
                      builder: (_, month, _) => SocialMomentMonthCoverPicker(
                        userId: 'owner',
                        month: month,
                        selectedWorkId: null,
                        onSelect: (id) => onSelect!(month, id),
                      ),
                    ),
                  ),
            child: const Text('표지 선택 열기'),
          ),
        ),
      ),
    ),
  };
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        builder: (context, child) => WebNavigationScope(
          onNavigate: (_) {},
          onNotifications: () {},
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (surface == _Surface.coverPicker) {
    await tester.tap(find.text('표지 선택 열기'));
    await tester.pumpAndSettle();
  }
  return container;
}

String _moreKey(_Surface surface) => switch (surface) {
  _Surface.feed => 'social-feed-more',
  _Surface.months => 'social-profile-more-moments',
  _Surface.monthDetail => 'social-month-more',
  _Surface.coverPicker => 'month-cover-more',
};

Finder _recordKey(_Surface surface, String id, _Fixture fixture) => find.byKey(
  ValueKey(switch (surface) {
    _Surface.feed => id,
    _Surface.months =>
      'social-moment-month-${socialMomentMonthKey(fixture.month(id))}',
    _Surface.monthDetail => 'social-month-record-$id',
    _Surface.coverPicker => 'month-cover-photo-$id',
  }),
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scroll = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  await tester.scrollUntilVisible(
    target,
    300,
    maxScrolls: 40,
    scrollable: scroll,
  );
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> _more(WidgetTester tester, _Surface surface) async {
  final target = find.byKey(ValueKey(_moreKey(surface)));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void _invalidateSecond(ProviderContainer container, _Surface surface) {
  switch (surface) {
    case _Surface.feed:
      container.invalidate(
        socialFeedProvider(SocialFeedQuery(cursor: _cursor('one'))),
      );
    case _Surface.months:
      container.invalidate(
        socialProfileMomentMonthsPageProvider(
          SocialProfileWorksQuery('owner', limit: 6, cursor: _cursor('one')),
        ),
      );
    case _Surface.monthDetail:
    case _Surface.coverPicker:
      container.invalidate(
        socialMomentMonthPageProvider(
          SocialMomentMonthQuery('owner', _october, cursor: _cursor('one')),
        ),
      );
  }
}

void _startSecond(ProviderContainer container, _Surface surface) {
  final Future<Object?> future = switch (surface) {
    _Surface.feed => container.read(
      socialFeedProvider(SocialFeedQuery(cursor: _cursor('one'))).future,
    ),
    _Surface.months => container.read(
      socialProfileMomentMonthsPageProvider(
        SocialProfileWorksQuery('owner', limit: 6, cursor: _cursor('one')),
      ).future,
    ),
    _Surface.monthDetail || _Surface.coverPicker => container.read(
      socialMomentMonthPageProvider(
        SocialMomentMonthQuery('owner', _october, cursor: _cursor('one')),
      ).future,
    ),
  };
  unawaited(future.then<void>((_) {}, onError: (Object _) {}));
}

void main() {
  for (final surface in _Surface.values) {
    testWidgets(
      '$surface invalidates the old last-page More callback even before a suffix exists',
      (tester) async {
        final fixture = _Fixture();
        final container = await _mount(tester, surface, fixture);
        await _more(tester, surface);
        final more = find.byKey(ValueKey(_moreKey(surface)));
        await _reveal(tester, more);
        final stale = tester.widget<OutlinedButton>(more).onPressed!;
        fixture.shifted = true;
        _invalidateSecond(container, surface);
        await tester.pumpAndSettle();
        stale();
        await tester.pumpAndSettle();
        expect(fixture.reads, [null, 'one', 'one']);
        await _more(tester, surface);
        expect(fixture.reads.last, 'two-new');
        expect(fixture.reads, isNot(contains('two-old')));
        await _reveal(tester, _recordKey(surface, 'second', fixture));
        expect(_recordKey(surface, 'second', fixture), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '$surface keeps first page but discards the stale suffix when the second outgoing cursor changes',
      (tester) async {
        final fixture = _Fixture();
        final container = await _mount(tester, surface, fixture);
        await _more(tester, surface);
        await _more(tester, surface);
        final more = find.byKey(ValueKey(_moreKey(surface)));
        await _reveal(tester, more);
        final stale = tester.widget<OutlinedButton>(more).onPressed!;
        expect(fixture.reads, [null, 'one', 'two-old']);

        fixture.shifted = true;
        _invalidateSecond(container, surface);
        await tester.pumpAndSettle();
        expect(fixture.reads, [null, 'one', 'two-old', 'one']);
        stale();
        await tester.pumpAndSettle();
        expect(fixture.reads, [null, 'one', 'two-old', 'one']);
        expect(_recordKey(surface, 'old-tail', fixture), findsNothing);
        await _more(tester, surface);
        expect(fixture.reads.last, 'two-new');
        expect(fixture.reads.where((edge) => edge == null), hasLength(1));
        await _reveal(tester, _recordKey(surface, 'second', fixture));
        expect(_recordKey(surface, 'second', fixture), findsOneWidget);
        await _reveal(tester, _recordKey(surface, 'old-tail', fixture));
        expect(_recordKey(surface, 'old-tail', fixture), findsOneWidget);
        expect(_recordKey(surface, 'unexpected', fixture), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final oldFailure in [false, true]) {
    testWidgets(
      'picker month replacement fences old ${oldFailure ? 'failure' : 'success'} while the next month is saving',
      (tester) async {
        final fixture = _Fixture();
        final selectedMonth = ValueNotifier(_october);
        addTearDown(selectedMonth.dispose);
        final oldSave = Completer<void>(), newSave = Completer<void>();
        final writes = <(int, String?)>[];
        await _mount(
          tester,
          _Surface.coverPicker,
          fixture,
          monthSelection: selectedMonth,
          onSelect: (month, id) {
            writes.add((month.month, id));
            return month.month == 10 ? oldSave.future : newSave.future;
          },
        );
        final october = find.byKey(const ValueKey('month-cover-photo-pick-10'));
        await _reveal(tester, october);
        await tester.tap(october);
        await tester.pumpAndSettle();
        final apply = find.byKey(const ValueKey('month-cover-apply'));
        tester.widget<FilledButton>(apply).onPressed!();
        await tester.pump();
        selectedMonth.value = DateTime.utc(2026, 11);
        await tester.pumpAndSettle();
        final november = find.byKey(
          const ValueKey('month-cover-photo-pick-11'),
        );
        await _reveal(tester, november);
        await tester.tap(november);
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(apply).onPressed, isNotNull);
        tester.widget<FilledButton>(apply).onPressed!();
        await tester.pump();
        if (oldFailure) {
          oldSave.completeError(StateError('old month save failed'));
        } else {
          oldSave.complete();
        }
        await tester.pumpAndSettle();
        expect(find.byType(SocialMomentMonthCoverPicker), findsOneWidget);
        expect(tester.widget<FilledButton>(apply).onPressed, isNull);
        expect(find.text('표지를 저장하지 못했어요. 선택한 사진으로 다시 시도해 주세요.'), findsNothing);
        expect(writes, [(10, 'pick-10'), (11, 'pick-11')]);
        newSave.complete();
        await tester.pumpAndSettle();
        expect(find.byType(SocialMomentMonthCoverPicker), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final surface in [
    _Surface.months,
    _Surface.monthDetail,
    _Surface.coverPicker,
  ]) {
    testWidgets(
      '$surface explains a middle failure and retries only that exact page',
      (tester) async {
        final fixture = _Fixture();
        final container = await _mount(tester, surface, fixture);
        await _more(tester, surface);
        await _more(tester, surface);
        if (surface == _Surface.months) {
          fixture.pendingMonths = Completer<SocialMomentMonthsPage>();
        } else {
          fixture.pendingWork = Completer<SocialWorkPage>();
        }
        _invalidateSecond(container, surface);
        _startSecond(container, surface);
        await tester.pump(const Duration(milliseconds: 16));
        expect(fixture.reads, [null, 'one', 'two-old', 'one']);
        if (surface == _Surface.months) {
          fixture.pendingMonths!.completeError(
            StateError('middle month page unavailable'),
          );
        } else {
          fixture.pendingWork!.completeError(
            StateError('middle record page unavailable'),
          );
        }
        await tester.pumpAndSettle();
        final retryKey = switch (surface) {
          _Surface.months => 'social-profile-middle-retry-1',
          _Surface.monthDetail => 'social-month-middle-retry-1',
          _Surface.coverPicker => 'month-cover-middle-retry-1',
          _ => throw StateError('not tested'),
        };
        final message = switch (surface) {
          _Surface.months => '일부 월간 기록을 불러오지 못했어요.',
          _Surface.monthDetail => '일부 기록을 불러오지 못했어요.',
          _Surface.coverPicker => '일부 공개 사진을 불러오지 못했어요.',
          _ => throw StateError('not tested'),
        };
        final retry = find.byKey(ValueKey(retryKey));
        await _reveal(tester, retry);
        expect(find.text(message), findsOneWidget);
        expect(retry.hitTestable(), findsOneWidget);
        final oldRetry = tester.widget<OutlinedButton>(retry).onPressed!;
        expect(fixture.reads.where((edge) => edge == null), hasLength(1));
        expect(fixture.reads.where((edge) => edge == 'two-old'), hasLength(1));
        fixture.pendingMonths = null;
        fixture.pendingWork = null;
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(fixture.reads, [null, 'one', 'two-old', 'one', 'one']);
        expect(find.text(message), findsNothing);
        final scroll = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await _reveal(tester, _recordKey(surface, 'first', fixture));
        expect(_recordKey(surface, 'first', fixture), findsOneWidget);
        await _reveal(tester, _recordKey(surface, 'second', fixture));
        expect(_recordKey(surface, 'second', fixture), findsOneWidget);
        await _reveal(tester, _recordKey(surface, 'old-tail', fixture));
        expect(_recordKey(surface, 'old-tail', fixture), findsOneWidget);
        container.read(_viewer.notifier).change('another-viewer');
        await tester.pumpAndSettle();
        final beforeStale = fixture.reads.length;
        oldRetry();
        await tester.pumpAndSettle();
        expect(fixture.reads, hasLength(beforeStale));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a middle page loading or failing does not discard known downstream query boundaries',
    (tester) async {
      final fixture = _Fixture();
      final container = await _mount(tester, _Surface.feed, fixture);
      await _more(tester, _Surface.feed);
      await _more(tester, _Surface.feed);
      fixture.pendingWork = Completer<SocialWorkPage>();
      _invalidateSecond(container, _Surface.feed);
      _startSecond(container, _Surface.feed);
      await tester.pump(const Duration(milliseconds: 16));
      expect(fixture.reads, [null, 'one', 'two-old', 'one']);
      fixture.pendingWork!.completeError(
        StateError('temporary connection failure'),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const ValueKey('social-feed-more')));
      expect(_recordKey(_Surface.feed, 'old-tail', fixture), findsOneWidget);
      expect(fixture.reads.where((edge) => edge == 'two-old'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
}
