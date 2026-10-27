import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/attendance/data/attendance_repository.dart';
import 'package:snap_fit/features/attendance/domain/attendance_status.dart';
import 'package:snap_fit/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:snap_fit/features/attendance/presentation/views/attendance_screen.dart';
import 'package:snap_fit/features/attendance/presentation/widgets/attendance_widgets.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';

AttendanceStatus _status({
  DateTime? date,
  DateTime? time,
  bool checked = false,
  bool claimed = false,
  int awarded = 0,
  int balance = 340,
  int cycleDay = 3,
  int streak = 2,
}) {
  final day = date ?? DateTime.utc(2026, 10, 26);
  const rewards = [10, 10, 20, 10, 10, 10, 30];
  final history = [
    AttendanceRecord(
      date: DateTime.utc(day.year, day.month, day.day - 1),
      points: 10,
      cycleDay: 2,
      streak: 2,
    ),
    if (checked)
      AttendanceRecord(
        date: day,
        points: rewards[cycleDay - 1],
        cycleDay: cycleDay,
        streak: streak,
      ),
  ];
  return AttendanceStatus(
    serverTime: time ?? DateTime.utc(day.year, day.month, day.day, 3),
    serverDate: day,
    timezone: 'Asia/Seoul',
    nextResetAt: DateTime.utc(day.year, day.month, day.day, 15),
    checkedInToday: checked,
    currentStreak: streak,
    cycleDay: cycleDay,
    todayReward: rewards[cycleDay - 1],
    weeklyRewards: rewards,
    month: '${day.year}-${day.month.toString().padLeft(2, '0')}',
    monthPoints: history.fold(0, (sum, record) => sum + record.points),
    monthAttendanceCount: history.length,
    history: history,
    claimed: claimed,
    awardedPoints: awarded,
    balance: balance,
  );
}

class _Repository implements AttendanceRepository {
  String? actor = 'owner-a';
  AttendanceStatus status = _status();
  Future<AttendanceStatus> Function()? read;
  Future<AttendanceStatus> Function()? checkIn;
  final _changes = StreamController<String?>.broadcast();
  int reads = 0, claims = 0;

  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => _changes.stream;
  void changeAccount(String? value) {
    actor = value;
    _changes.add(value);
  }

  @override
  Future<AttendanceStatus> fetchStatus() {
    reads++;
    return read?.call() ?? Future.value(status);
  }

  @override
  Future<AttendanceStatus> claim() {
    claims++;
    return checkIn?.call() ??
        Future.value(
          _status(
            checked: true,
            claimed: true,
            awarded: 20,
            balance: 360,
            streak: 3,
          ),
        );
  }

  Future<void> close() => _changes.close();
}

Future<ProviderContainer> _mount(
  WidgetTester tester,
  _Repository repository, {
  bool dark = false,
  double scale = 1,
  bool walletFails = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      attendanceRepositoryProvider.overrideWithValue(repository),
      myPointBalanceProvider.overrideWith((_) async {
        if (walletFails) throw StateError('Synthetic wallet read failure');
        return 340;
      }),
      myPointLedgerProvider.overrideWith((_) async {
        if (walletFails) throw StateError('Synthetic ledger read failure');
        return [];
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: (dark ? SnapFitTheme.dark() : SnapFitTheme.light()).copyWith(
          splashFactory: NoSplash.splashFactory,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const AttendanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _unmount(
  WidgetTester tester,
  ProviderContainer container,
  _Repository repository,
) async {
  // Own the unmount while FakeAsync is active, so both the midnight timer and
  // Riverpod's external-container disposal are drained before test teardown.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  container.dispose();
  await repository.close();
  await tester.pumpAndSettle();
}

Finder get _claimButton => find.byKey(const ValueKey('attendance-check-in'));
Future<void> _revealClaim(WidgetTester tester) async {
  await tester.ensureVisible(_claimButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'guest attendance explains login without reading a private record',
    (tester) async {
      final repository = _Repository()..actor = null;
      final container = await _mount(tester, repository);
      try {
        expect(find.text('매일의 기록으로 포인트를 모아요'), findsOneWidget);
        expect(find.text('로그인'), findsOneWidget);
        expect(_claimButton, findsNothing);
        expect(repository.reads, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'one tap records attendance and updates the confirmed balance and calendar',
    (tester) async {
      final repository = _Repository();
      final container = await _mount(tester, repository);
      try {
        expect(find.text('출석하고 20P 받기'), findsOneWidget);
        expect(find.text('7일의 기록을 채우면 총 100P'), findsOneWidget);
        await _revealClaim(tester);
        await tester.tap(_claimButton);
        await tester.pumpAndSettle();
        expect(repository.claims, 1);
        expect(find.text('오늘 출석 완료'), findsOneWidget);
        expect(tester.widget<FilledButton>(_claimButton).onPressed, isNull);
        expect(find.text('보유 포인트 360P'), findsOneWidget);
        expect(find.text('이번 달 2일 출석'), findsOneWidget);
        expect(find.text('+30P 모았어요'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets('rapid taps share one in-flight claim', (tester) async {
    final pending = Completer<AttendanceStatus>();
    final repository = _Repository()..checkIn = () => pending.future;
    final container = await _mount(tester, repository);
    try {
      await _revealClaim(tester);
      await tester.tap(_claimButton);
      await tester.tap(_claimButton);
      await tester.pumpAndSettle();
      expect(repository.claims, 1);
      expect(find.text('출석 확인 중…'), findsOneWidget);
      expect(tester.widget<FilledButton>(_claimButton).onPressed, isNull);
      pending.complete(
        _status(
          checked: true,
          claimed: true,
          awarded: 20,
          balance: 360,
          streak: 3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets(
    'an already-claimed response is a completed day without another award',
    (tester) async {
      final repository = _Repository()
        ..checkIn = () async => _status(
          checked: true,
          claimed: false,
          awarded: 0,
          balance: 360,
          streak: 3,
        );
      final container = await _mount(tester, repository);
      try {
        await _revealClaim(tester);
        await tester.tap(_claimButton);
        await tester.pumpAndSettle();
        expect(find.text('오늘 출석 완료'), findsOneWidget);
        expect(find.text('오늘 출석은 이미 완료했어요.'), findsOneWidget);
        expect(find.textContaining('0P를 받았어요'), findsNothing);
        expect(repository.claims, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets(
    'a lost claim response can be retried without an optimistic award',
    (tester) async {
      final repository = _Repository();
      repository.checkIn = () async {
        if (repository.claims == 1)
          throw StateError('Synthetic lost claim response');
        return _status(checked: true, claimed: false, balance: 360, streak: 3);
      };
      final container = await _mount(tester, repository);
      try {
        await _revealClaim(tester);
        await tester.tap(_claimButton);
        await tester.pumpAndSettle();
        expect(find.text('출석 결과를 확인하지 못했어요. 다시 눌러 확인해 주세요.'), findsOneWidget);
        expect(find.text('보유 포인트 340P'), findsOneWidget);
        await _revealClaim(tester);
        await tester.tap(_claimButton);
        await tester.pumpAndSettle();
        expect(repository.claims, 2);
        expect(find.text('오늘 출석 완료'), findsOneWidget);
        expect(find.textContaining('출석 결과를 확인하지 못했어요.'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets('a failed initial read has an explicit retry', (tester) async {
    var fail = true;
    final repository = _Repository()
      ..read = () async {
        if (fail) throw StateError('Synthetic status read failure');
        return _status();
      };
    final container = await _mount(tester, repository);
    try {
      expect(find.text('출석 기록을 불러오지 못했어요'), findsOneWidget);
      fail = false;
      await tester.tap(find.byKey(const ValueKey('attendance-retry')));
      await tester.pumpAndSettle();
      expect(_claimButton, findsOneWidget);
      expect(find.text('출석하고 20P 받기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('an old A B A claim cannot complete the new account request', (
    tester,
  ) async {
    final first = Completer<AttendanceStatus>();
    final second = Completer<AttendanceStatus>();
    final repository = _Repository();
    repository.checkIn = () =>
        repository.claims == 1 ? first.future : second.future;
    final container = await _mount(tester, repository);
    try {
      await _revealClaim(tester);
      await tester.tap(_claimButton);
      await tester.pumpAndSettle();
      repository.changeAccount('owner-b');
      await tester.pumpAndSettle();
      repository.changeAccount('owner-a');
      await tester.pumpAndSettle();
      await _revealClaim(tester);
      await tester.tap(_claimButton);
      await tester.pumpAndSettle();
      first.complete(
        _status(checked: true, claimed: true, awarded: 20, balance: 9999),
      );
      await tester.pumpAndSettle();
      expect(find.text('출석 확인 중…'), findsOneWidget);
      expect(find.text('보유 포인트 9,999P'), findsNothing);
      second.complete(
        _status(checked: true, claimed: true, awarded: 20, balance: 360),
      );
      await tester.pumpAndSettle();
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(find.text('보유 포인트 360P'), findsOneWidget);
      expect(repository.claims, 2);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('logout discards a late private attendance response', (
    tester,
  ) async {
    final pending = Completer<AttendanceStatus>();
    final repository = _Repository()..checkIn = () => pending.future;
    final container = await _mount(tester, repository);
    try {
      await _revealClaim(tester);
      await tester.tap(_claimButton);
      await tester.pumpAndSettle();
      repository.changeAccount(null);
      await tester.pumpAndSettle();
      pending.complete(
        _status(checked: true, claimed: true, awarded: 20, balance: 9999),
      );
      await tester.pumpAndSettle();
      expect(_claimButton, findsNothing);
      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('보유 포인트 9,999P'), findsNothing);
      expect(find.textContaining('20P를 받았어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('wallet refresh failures cannot replace a confirmed attendance', (
    tester,
  ) async {
    final repository = _Repository();
    final container = await _mount(tester, repository, walletFails: true);
    final balance = container.listen(myPointBalanceProvider, (_, _) {});
    final ledger = container.listen(myPointLedgerProvider, (_, _) {});
    try {
      await tester.pumpAndSettle();
      await _revealClaim(tester);
      await tester.tap(_claimButton);
      await tester.pumpAndSettle();
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(find.text('보유 포인트 360P'), findsOneWidget);
      expect(find.textContaining('출석 결과를 확인하지 못했어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      balance.close();
      ledger.close();
      await _unmount(tester, container, repository);
    }
  });

  testWidgets('the server midnight refresh opens the next attendance day', (
    tester,
  ) async {
    final repository = _Repository()
      ..status = _status(
        checked: true,
        time: DateTime.utc(2026, 10, 26, 14, 59, 58),
      );
    final container = await _mount(tester, repository);
    try {
      final initialReads = repository.reads;
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      repository.status = _status(
        date: DateTime.utc(2026, 10, 27),
        cycleDay: 4,
        streak: 3,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(repository.reads, greaterThan(initialReads));
      expect(find.text('10월 27일의 기록'), findsOneWidget);
      expect(find.text('출석하고 10P 받기'), findsOneWidget);
      expect(tester.widget<FilledButton>(_claimButton).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  testWidgets(
    'a midnight during a claim rechecks the new day after its response',
    (tester) async {
      final pending = Completer<AttendanceStatus>();
      final repository = _Repository()
        ..status = _status(time: DateTime.utc(2026, 10, 26, 14, 59, 58))
        ..checkIn = () => pending.future;
      final container = await _mount(tester, repository);
      try {
        await _revealClaim(tester);
        await tester.tap(_claimButton);
        await tester.pumpAndSettle();
        repository.status = _status(
          date: DateTime.utc(2026, 10, 27),
          cycleDay: 4,
          streak: 3,
        );
        await tester.pump(const Duration(seconds: 3));
        pending.complete(
          _status(checked: true, claimed: true, awarded: 20, balance: 360),
        );
        await tester.pumpAndSettle();
        expect(find.text('10월 27일의 기록'), findsOneWidget);
        expect(find.text('출석하고 10P 받기'), findsOneWidget);
        expect(tester.widget<FilledButton>(_claimButton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      } finally {
        await _unmount(tester, container, repository);
      }
    },
  );

  testWidgets('returning to the app revalidates attendance', (tester) async {
    final repository = _Repository();
    final container = await _mount(tester, repository);
    try {
      final reads = repository.reads;
      repository.status = _status(checked: true, balance: 360);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.reads, greaterThan(reads));
      expect(find.text('오늘 출석 완료'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await _unmount(tester, container, repository);
    }
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'attendance keeps its stamps and calendar usable at $width and text $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final repository = _Repository();
          final container = await _mount(
            tester,
            repository,
            dark: scale > 1,
            scale: scale,
          );
          try {
            expect(find.byType(AttendanceTodayCard), findsOneWidget);
            expect(find.byType(AttendanceRewardStrip), findsOneWidget);
            expect(find.byType(AttendanceCalendarCard), findsOneWidget);
            await _revealClaim(tester);
            expect(_claimButton.hitTestable(), findsOneWidget);
            expect(
              tester.getSize(_claimButton).height,
              greaterThanOrEqualTo(56),
            );
            await tester.ensureVisible(find.text('2026년 10월의 기록'));
            await tester.pumpAndSettle();
            expect(find.text('이번 달 1일 출석'), findsOneWidget);
            expect(find.text('+10P 모았어요'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            await _unmount(tester, container, repository);
          }
        },
      );
    }
  }
}
