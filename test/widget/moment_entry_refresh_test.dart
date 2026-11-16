import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';

MomentJournal journal(DateTime today, DateTime month) => MomentJournal(
  today: today,
  weekStart: momentWeekStart(today),
  month: month,
  records: const [],
  weekPhotoCount: 0,
);

void main() {
  testWidgets('a guest entry never creates the midnight refresh provider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [momentsCurrentUserIdProvider.overrideWithValue(null)],
    );
    try {
      container.listen(momentEntryJournalProvider, (_, __) {});
      expect(await container.read(momentEntryJournalProvider.future), isNull);
      expect(container.exists(momentEntryRefreshProvider), isFalse);
      expect(container.exists(momentEntryClockProvider), isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(container.exists(momentEntryRefreshProvider), isFalse);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    }
  });

  testWidgets(
    'an unavailable owner never creates the midnight refresh provider',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          momentsCurrentUserIdProvider.overrideWith(
            (_) => throw StateError('The personal session is unavailable.'),
          ),
        ],
      );
      try {
        container.listen(momentEntryJournalProvider, (_, __) {});
        await expectLater(
          container.read(momentEntryJournalProvider.future),
          throwsA(anything),
        );
        expect(container.read(momentEntryJournalProvider).hasError, isTrue);
        expect(container.exists(momentEntryRefreshProvider), isFalse);
        expect(container.exists(momentEntryClockProvider), isFalse);
        await tester.pump();
        expect(container.exists(momentEntryRefreshProvider), isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'Korean midnight refreshes the month once and never presents the cached yesterday as today',
    (tester) async {
      var now = DateTime.utc(2026, 10, 31, 14, 59, 59);
      final oldToday = DateTime.utc(2026, 10, 31);
      final newToday = DateTime.utc(2026, 11, 1);
      var reads = 0;
      final pending = Completer<MomentJournal>();
      final requested = <DateTime?>[];
      final container = ProviderContainer(
        overrides: [
          momentEntryClockProvider.overrideWithValue(() => now),
          momentsCurrentUserIdProvider.overrideWithValue('owner'),
          momentsMonthProvider.overrideWith((ref, month) {
            reads++;
            requested.add(month);
            return reads == 1
                ? Future.value(
                    journal(oldToday, month ?? momentMonth(oldToday)),
                  )
                : pending.future;
          }),
        ],
      );
      try {
        // Two consumers still share one entry provider and its monthly request.
        container.listen(momentEntryJournalProvider, (_, __) {});
        container.listen(momentEntryJournalProvider, (_, __) {});
        final first = await container.read(momentEntryJournalProvider.future);
        expect(first!.today, oldToday);
        expect(reads, 1);
        now = DateTime.utc(2026, 10, 31, 15);
        await tester.pump(const Duration(seconds: 1));
        expect(container.read(momentEntryJournalProvider).isLoading, isTrue);
        expect(reads, 2);
        pending.complete(journal(newToday, DateTime.utc(2026, 11)));
        await tester.pump();
        final fresh = await container.read(momentEntryJournalProvider.future);
        expect(fresh!.today, newToday);
        expect(fresh.month, DateTime.utc(2026, 11));
        expect(requested, [null, null]);
        expect(reads, 2);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        // Flush only zero-duration provider cleanup. The test invariant still
        // verifies that disposing the provider cancelled its midnight timer.
        await tester.pump();
      }
    },
  );

  testWidgets('future device clock still requests the server current month', (
    tester,
  ) async {
    final serverToday = DateTime.utc(2026, 11, 11);
    var reads = 0;
    final container = ProviderContainer(
      overrides: [
        momentEntryClockProvider.overrideWithValue(
          () => DateTime.utc(2099, 12, 31),
        ),
        momentsCurrentUserIdProvider.overrideWithValue('owner'),
        momentsMonthProvider.overrideWith((ref, month) async {
          reads++;
          expect(month, isNull);
          return journal(serverToday, momentMonth(serverToday));
        }),
      ],
    );
    try {
      container.listen(momentEntryJournalProvider, (_, __) {});
      final result = await container.read(momentEntryJournalProvider.future);
      expect(result!.today, serverToday);
      expect(result.month, DateTime.utc(2026, 11));
      expect(reads, 1);
    } finally {
      container.dispose();
      await tester.pump();
    }
  });

  testWidgets(
    'resume reads fresh server date and corrects a device month without a query loop',
    (tester) async {
      var now = DateTime.utc(2026, 10, 28, 3);
      var serverToday = DateTime.utc(2026, 10, 28);
      var reads = 0;
      final requested = <DateTime?>[];
      final container = ProviderContainer(
        overrides: [
          momentEntryClockProvider.overrideWithValue(() => now),
          momentsCurrentUserIdProvider.overrideWithValue('owner'),
          momentsMonthProvider.overrideWith((ref, month) async {
            reads++;
            requested.add(month);
            return journal(serverToday, month ?? momentMonth(serverToday));
          }),
        ],
      );
      try {
        container.listen(momentEntryJournalProvider, (_, __) {});
        expect(
          (await container.read(momentEntryJournalProvider.future))!.today,
          serverToday,
        );
        expect(reads, 1);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        // The device jumps ahead a month. The calendar still follows the server.
        now = DateTime.utc(2026, 11, 28, 3);
        serverToday = DateTime.utc(2026, 10, 29);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        final fresh = await container.read(momentEntryJournalProvider.future);
        expect(fresh!.today, DateTime.utc(2026, 10, 29));
        expect(fresh.month, DateTime.utc(2026, 10));
        expect(reads, 2);
        expect(requested, [null, null]);
        await tester.pump();
        expect(reads, 2);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        // Flush only zero-duration provider cleanup. The test invariant still
        // verifies that disposing the provider cancelled its midnight timer.
        await tester.pump();
      }
    },
  );
}
