import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_moment_month_cover_picker.dart';

final _month = DateTime.utc(2026, 10);
const _author = SocialProfile(
  userId: 'author',
  displayName: '하루를 남기는 사람',
  handle: 'daily',
);

SocialWork _record(int day) => SocialWork(
  id: 'entry-$day',
  author: _author,
  title: '10월 $day일의 기록',
  kind: 'moment',
  recordDate: DateTime.utc(2026, 10, day),
  createdAt: DateTime.utc(2026, 10, 28),
);

SocialWorkPage _page(
  List<SocialWork> available,
  SocialMomentMonthQuery query, {
  bool useCursor = true,
}) {
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
  final more = remaining.length > selected.length;
  return SocialWorkPage(
    items: selected,
    hasMore: more,
    nextOffset: query.offset + selected.length,
    nextCursor: useCursor && more
        ? {
            'recordDate':
                '2026-10-${selected.last.recordDate!.day.toString().padLeft(2, '0')}',
            'id': selected.last.id,
          }
        : null,
  );
}

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  required FutureOr<SocialWorkPage> Function(SocialMomentMonthQuery) records,
  Future<void> Function(String?)? onSelect,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      socialCurrentUserIdProvider.overrideWith((_) => 'author'),
      socialMomentMonthPageProvider.overrideWith(
        (_, query) async => records(query),
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
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        home: Scaffold(
          body: SocialMomentMonthCoverPicker(
            userId: 'author',
            month: _month,
            selectedWorkId: null,
            onSelect: onSelect ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'cover cursor keeps remaining photos after an earlier withdrawal',
    (tester) async {
      final available = [for (var day = 28; day >= 15; day--) _record(day)];
      final queries = <SocialMomentMonthQuery>[];
      String? selected;
      await _mount(
        tester,
        records: (query) {
          queries.add(query);
          return _page(available, query);
        },
        onSelect: (id) async => selected = id,
      );
      available.removeAt(0);
      await _tap(tester, 'month-cover-more');
      expect(queries.last.offset, 0);
      expect(queries.last.cursor, {
        'recordDate': '2026-10-17',
        'id': 'entry-17',
      });
      expect(queries.every((query) => query.limit == 12), isTrue);
      await _tap(tester, 'month-cover-photo-entry-16');
      await _tap(tester, 'month-cover-apply');
      expect(selected, 'entry-16');
    },
  );

  testWidgets(
    'cover refresh drops old continuation when first boundary moves',
    (tester) async {
      final available = [for (var day = 27; day >= 14; day--) _record(day)];
      final queries = <SocialMomentMonthQuery>[];
      final container = await _mount(
        tester,
        records: (query) {
          queries.add(query);
          return _page(available, query);
        },
      );
      await _tap(tester, 'month-cover-more');
      expect(queries.last.cursor?['id'], 'entry-16');
      available.insert(0, _record(28));
      container.invalidate(
        socialMomentMonthPageProvider(
          SocialMomentMonthQuery('author', _month, limit: 12),
        ),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'month-cover-more');
      expect(queries.last.cursor?['id'], 'entry-17');
      await _tap(tester, 'month-cover-photo-entry-16');
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('month-cover-apply')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('cover continuation retry uses the same cursor only', (
    tester,
  ) async {
    final available = [for (var day = 28; day >= 15; day--) _record(day)];
    final queries = <SocialMomentMonthQuery>[];
    var attempts = 0;
    await _mount(
      tester,
      records: (query) {
        queries.add(query);
        if (query.cursor != null && attempts++ == 0) {
          throw StateError('temporary page failure');
        }
        return _page(available, query);
      },
    );
    await _tap(tester, 'month-cover-more');
    final failed = queries.last;
    await _tap(tester, 'month-cover-more');
    expect(queries.last, failed);
    expect(queries.where((query) => query.cursor == null), hasLength(1));
    await _tap(tester, 'month-cover-photo-entry-16');
  });

  testWidgets('cover pagination supports responses without a cursor', (
    tester,
  ) async {
    final available = [for (var day = 28; day >= 15; day--) _record(day)];
    final queries = <SocialMomentMonthQuery>[];
    await _mount(
      tester,
      records: (query) {
        queries.add(query);
        return _page(available, query, useCursor: false);
      },
    );
    await _tap(tester, 'month-cover-more');
    expect(queries.last.offset, 12);
    expect(queries.last.cursor, isNull);
    await _tap(tester, 'month-cover-photo-entry-16');
  });
}
