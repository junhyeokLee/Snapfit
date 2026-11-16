import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_moment_month_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover_picker.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_profile_moments.dart';

class _Repository extends Mock implements SocialRepository {}

class _Viewer extends Notifier<String?> {
  @override
  String? build() => 'author';
  void change(String? next) => state = next;
}

final _viewer = NotifierProvider<_Viewer, String?>(_Viewer.new);
final _october = DateTime.utc(2026, 10);
const _author = SocialProfile(
  userId: 'author',
  displayName: '오늘을 남기는 사람',
  handle: 'today',
);
SocialWork _record(String id, DateTime date) => SocialWork(
  id: id,
  author: _author,
  title: '기록 $id',
  kind: 'moment',
  recordDate: date,
  createdAt: DateTime.utc(2026, 10, 28),
);
SocialMomentMonth _collection(DateTime month, {String? selected}) =>
    SocialMomentMonth(
      month: month,
      recordCount: 3,
      selectedWorkId: selected,
      cover: _record(
        selected ?? 'cover-${month.month}',
        DateTime.utc(month.year, month.month, 18),
      ),
    );

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  required Widget child,
  FutureOr<SocialMomentMonthsPage> Function(SocialProfileWorksQuery)? months,
  FutureOr<SocialWorkPage> Function(SocialMomentMonthQuery)? records,
  _Repository? repository,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((ref) => ref.watch(_viewer)),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
      socialRepositoryProvider.overrideWithValue(repository ?? _Repository()),
      socialProfileProvider.overrideWith((_, __) async => _author),
      socialProfileMomentMonthsPageProvider.overrideWith(
        (_, query) async =>
            await months?.call(query) ??
            const SocialMomentMonthsPage(
              items: [],
              hasMore: false,
              nextOffset: 0,
            ),
      ),
      socialMomentMonthPageProvider.overrideWith(
        (_, query) async =>
            await records?.call(query) ??
            const SocialWorkPage(items: [], hasMore: false, nextOffset: 0),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: SnapFitTheme.light(), home: child),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      500,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 60,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Widget _profile({bool own = false}) => Scaffold(
  body: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: SocialProfileMoments(userId: 'author', own: own),
  ),
);

void main() {
  testWidgets(
    'deleting an earlier month does not skip the next month with a cursor',
    (tester) async {
      final available = [
        for (var month = 10; month >= 4; month--) DateTime.utc(2026, month),
      ];
      final queries = <SocialProfileWorksQuery>[];
      await _mount(
        tester,
        child: _profile(),
        months: (query) {
          queries.add(query);
          final boundary = query.cursor?['month'] as String?;
          final remaining = boundary == null
              ? available.skip(query.offset).toList()
              : available
                    .where(
                      (month) => month.isBefore(
                        DateTime.parse('${boundary}T00:00:00Z'),
                      ),
                    )
                    .toList();
          final selected = remaining.take(query.limit).toList();
          return SocialMomentMonthsPage(
            items: selected.map(_collection).toList(),
            hasMore: remaining.length > query.limit,
            nextOffset: query.offset + selected.length,
            nextCursor: remaining.length > query.limit
                ? {'month': socialMomentMonthKey(selected.last)}
                : null,
          );
        },
      );
      available.removeAt(0);
      await _tap(tester, 'social-profile-more-moments');
      expect(
        find.byKey(const ValueKey('social-moment-month-2026-04-01')),
        findsOneWidget,
      );
      expect(queries.last.offset, 0);
      expect(queries.last.cursor, {'month': '2026-05-01'});
      expect(queries.every((query) => query.limit == 6), isTrue);
    },
  );

  testWidgets(
    'deleting a record before the next page does not skip either remaining record',
    (tester) async {
      final available = [
        for (var index = 0; index < 14; index++)
          _record('entry-$index', DateTime.utc(2026, 10, 28 - index)),
      ];
      final queries = <SocialMomentMonthQuery>[];
      await _mount(
        tester,
        child: SocialMomentMonthScreen(userId: 'author', month: _october),
        records: (query) {
          queries.add(query);
          final boundary = query.cursor?['recordDate'] as String?;
          final remaining = boundary == null
              ? available.skip(query.offset).toList()
              : available
                    .where(
                      (record) => record.recordDate!.isBefore(
                        DateTime.parse('${boundary}T00:00:00Z'),
                      ),
                    )
                    .toList();
          final selected = remaining.take(query.limit).toList();
          return SocialWorkPage(
            items: selected,
            hasMore: remaining.length > query.limit,
            nextOffset: query.offset + selected.length,
            nextCursor: remaining.length > query.limit
                ? {'recordDate': '2026-10-17', 'id': selected.last.id}
                : null,
          );
        },
      );
      available.removeAt(0);
      await _tap(tester, 'social-month-more');
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-month-record-entry-12')),
      );
      expect(
        find.byKey(const ValueKey('social-month-record-entry-12')),
        findsOneWidget,
      );
      await _reveal(
        tester,
        find.byKey(const ValueKey('social-month-record-entry-13')),
      );
      expect(
        find.byKey(const ValueKey('social-month-record-entry-13')),
        findsOneWidget,
      );
      expect(queries.last.offset, 0);
      expect(queries.last.cursor?['id'], 'entry-11');
      expect(queries.every((query) => query.limit == 12), isTrue);
    },
  );

  testWidgets(
    'refreshing the first month window drops an outdated downstream cursor',
    (tester) async {
      final available = [
        for (var month = 9; month >= 3; month--) DateTime.utc(2026, month),
      ];
      final queries = <SocialProfileWorksQuery>[];
      final container = await _mount(
        tester,
        child: _profile(),
        months: (query) {
          queries.add(query);
          final boundary = query.cursor?['month'] as String?;
          final remaining = boundary == null
              ? available.toList()
              : available
                    .where(
                      (month) => month.isBefore(
                        DateTime.parse('${boundary}T00:00:00Z'),
                      ),
                    )
                    .toList();
          final selected = remaining.take(query.limit).toList();
          return SocialMomentMonthsPage(
            items: selected.map(_collection).toList(),
            hasMore: remaining.length > query.limit,
            nextOffset: selected.length,
            nextCursor: remaining.length > query.limit
                ? {'month': socialMomentMonthKey(selected.last)}
                : null,
          );
        },
      );
      await _tap(tester, 'social-profile-more-moments');
      available.insert(0, DateTime.utc(2026, 10));
      container.invalidate(socialProfileMomentMonthsPageProvider);
      await tester.pumpAndSettle();
      await _tap(tester, 'social-profile-more-moments');
      expect(queries.last.cursor, {'month': '2026-05-01'});
      expect(
        find.byKey(const ValueKey('social-moment-month-2026-04-01')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('social-moment-month-2026-03-01')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'own monthly cover footer selects a public photo without changing book open behavior',
    (tester) async {
      final repository = _Repository();
      String? selected;
      when(() => repository.setMomentMonthCover(_october, 'chosen')).thenAnswer(
        (_) async {
          selected = 'chosen';
        },
      );
      await _mount(
        tester,
        child: _profile(own: true),
        repository: repository,
        months: (_) => SocialMomentMonthsPage(
          items: [_collection(_october, selected: selected)],
          hasMore: false,
          nextOffset: 1,
        ),
        records: (_) => SocialWorkPage(
          items: [_record('chosen', DateTime.utc(2026, 10, 18))],
          hasMore: false,
          nextOffset: 1,
        ),
      );
      await _tap(tester, 'social-moment-month-cover-action-2026-10-01');
      await _tap(tester, 'month-cover-photo-chosen');
      await _tap(tester, 'month-cover-apply');
      verify(
        () => repository.setMomentMonthCover(_october, 'chosen'),
      ).called(1);
      expect(
        tester
            .widget<SocialMomentMonthCover>(find.byType(SocialMomentMonthCover))
            .collection
            .selectedWorkId,
        'chosen',
      );
      await _tap(tester, 'social-moment-month-2026-10-01');
      expect(find.byType(SocialMomentMonthScreen), findsOneWidget);
    },
  );

  testWidgets('a retained cover callback cannot write after viewer A B A', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _mount(
      tester,
      child: _profile(own: true),
      repository: repository,
      months: (_) => SocialMomentMonthsPage(
        items: [_collection(_october)],
        hasMore: false,
        nextOffset: 1,
      ),
    );
    await _tap(tester, 'social-moment-month-cover-action-2026-10-01');
    final stale = tester
        .widget<SocialMomentMonthCoverPicker>(
          find.byType(SocialMomentMonthCoverPicker),
        )
        .onSelect;
    container.read(_viewer.notifier).change('other');
    await tester.pumpAndSettle();
    container.read(_viewer.notifier).change('author');
    await tester.pumpAndSettle();
    await expectLater(stale('chosen'), throwsStateError);
    verifyNever(() => repository.setMomentMonthCover(_october, 'chosen'));
  });

  testWidgets('another public profile never offers a monthly cover mutation', (
    tester,
  ) async {
    await _mount(
      tester,
      child: _profile(),
      months: (_) => SocialMomentMonthsPage(
        items: [_collection(_october)],
        hasMore: false,
        nextOffset: 1,
      ),
    );
    expect(
      find.byKey(const ValueKey('social-moment-month-cover-action-2026-10-01')),
      findsNothing,
    );
  });
}
