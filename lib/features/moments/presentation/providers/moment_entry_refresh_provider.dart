import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/moment_record.dart';
import 'moments_providers.dart';

final momentEntryClockProvider = Provider<DateTime Function()>(
  (_) =>
      () => DateTime.now().toUtc(),
);

final momentEntryRefreshProvider =
    NotifierProvider.autoDispose<MomentEntryRefresh, int>(
      MomentEntryRefresh.new,
    );

/// Shared by every mounted entry, with no background task after they unmount.
/// Device time schedules a fresh read; only the server supplies the shown date.
class MomentEntryRefresh extends Notifier<int> with WidgetsBindingObserver {
  Timer? _midnight;
  String? _owner;
  final _prepared = <DateTime?, int>{};

  @override
  int build() {
    ref.watch(momentEntryClockProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _midnight?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed)
      _schedule();
    return 0;
  }

  bool prepare(String owner, DateTime? month, int epoch) {
    if (_owner != owner) {
      _owner = owner;
      _prepared.clear();
    }
    if (_prepared[month] == epoch) return false;
    _prepared[month] = epoch;
    return true;
  }

  void _schedule() {
    _midnight?.cancel();
    final now = ref.read(momentEntryClockProvider)().toUtc();
    final day = momentToday(now);
    final next = DateTime.utc(
      day.year,
      day.month,
      day.day + 1,
    ).subtract(const Duration(hours: 9));
    _midnight = Timer(next.difference(now), _refresh);
  }

  void _refresh() {
    if (!ref.mounted) return;
    state++;
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _midnight?.cancel();
    if (state == AppLifecycleState.resumed) _refresh();
  }
}

final momentEntryJournalProvider = FutureProvider.autoDispose<MomentJournal?>((
  ref,
) async {
  // Resolve the personal session before starting a midnight timer. A guest or
  // an unavailable session still has a useful entry, without background work.
  final owner = ref.watch(momentsCurrentUserIdProvider);
  if (owner == null) return null;
  final epoch = ref.watch(momentEntryRefreshProvider);
  final refresh = ref.read(momentEntryRefreshProvider.notifier);
  Future<MomentJournal?> currentMonth(DateTime? month) async {
    if (refresh.prepare(owner, month, epoch)) {
      // Exactly once per owner/month/epoch, and outside widget build. A saved
      // record can still invalidate this family without an invalidate loop.
      await Future<void>.value();
      if (!ref.mounted || ref.read(momentsCurrentUserIdProvider) != owner)
        return null;
      ref.invalidate(momentsMonthProvider(month));
    }
    if (!ref.mounted) return null;
    return ref.watch(momentsMonthProvider(month).future);
  }

  // 기기 시계는 새로고침 예약에만 쓴다. 현재 월과 날짜는 서버가 정한다.
  return currentMonth(null);
});
