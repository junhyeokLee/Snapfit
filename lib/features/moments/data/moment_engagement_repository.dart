import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/moment_record.dart';

enum MomentActivity {
  recapViewed('recap_viewed'),
  monthlyPreviewed('monthly_previewed'),
  rewardViewed('reward_viewed');

  const MomentActivity(this.value);
  final String value;
}

class MomentReminder {
  const MomentReminder({
    this.enabled = false,
    this.weekday = 7,
    this.hour = 20,
    this.minute = 0,
  });
  final bool enabled;
  final int weekday, hour, minute;

  factory MomentReminder.fromJson(Map<String, dynamic> json) => MomentReminder(
    enabled: json['enabled'] == true,
    weekday: (json['weekday'] as num?)?.toInt() ?? 7,
    hour: (json['hour'] as num?)?.toInt() ?? 20,
    minute: (json['minute'] as num?)?.toInt() ?? 0,
  );

  bool get valid =>
      weekday >= 1 &&
      weekday <= 7 &&
      hour >= 8 &&
      hour <= 21 &&
      minute >= 0 &&
      minute <= 59;
}

class MomentEngagement {
  const MomentEngagement({
    required this.reminder,
    required this.hasRecords,
    this.canRemind = true,
  });
  final MomentReminder reminder;
  final bool hasRecords, canRemind;

  factory MomentEngagement.fromJson(Map<String, dynamic> json) =>
      MomentEngagement(
        reminder: MomentReminder.fromJson(
          Map<String, dynamic>.from(json['reminder'] as Map? ?? const {}),
        ),
        hasRecords: json['hasRecords'] == true,
        canRemind: json['canRemind'] != false,
      );
}

abstract class MomentEngagementRepository {
  Future<MomentEngagement> load();
  Future<MomentEngagement> saveReminder(MomentReminder reminder);
  Future<bool> recordActivity(MomentActivity activity, {DateTime? month});
}

/// Only enum events and a month reach the server. Photos, captions and paths
/// never form part of usage measurement. View tracking cannot block editing.
class SupabaseMomentEngagementRepository implements MomentEngagementRepository {
  SupabaseMomentEngagementRepository(this.client) {
    _actor = client.auth.currentUser?.id;
    _subscription = client.auth.onAuthStateChange.listen(
      (event) {
        final next = event.session?.user.id;
        if (next != _actor) {
          _actor = next;
          _generation++;
        }
      },
      onError: (Object _, StackTrace __) {
        // Consume recoverable SDK errors without inventing a sign-out. A read
        // or acknowledgement started before that error must be retried fresh.
        _generation++;
      },
    );
  }

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  String? _actor;
  int _generation = 0;

  (String, int) _session() {
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw const MomentException('로그인한 뒤 다시 열어 주세요.');
    return (owner, _generation);
  }

  void _check((String, int) session) {
    if (client.auth.currentUser?.id != session.$1 ||
        _generation != session.$2) {
      throw const MomentException('계정이 변경됐어요. 기록 화면을 다시 열어 주세요.');
    }
  }

  Future<MomentEngagement> _request(
    String rpc, {
    Map<String, dynamic>? params,
  }) async {
    final session = _session();
    try {
      final value = await client
          .rpc(rpc, params: params)
          .timeout(const Duration(seconds: 12));
      _check(session);
      return MomentEngagement.fromJson(Map<String, dynamic>.from(value as Map));
    } on MomentException {
      rethrow;
    } catch (_) {
      _check(session);
      throw const MomentException('설정을 불러오거나 저장하지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  Future<MomentEngagement> load() => _request('get_moment_engagement');

  @override
  Future<MomentEngagement> saveReminder(MomentReminder reminder) async {
    if (!reminder.valid) {
      throw const MomentException('알림 시간은 오전 8시부터 오후 9시 59분 사이로 선택해 주세요.');
    }
    return _request(
      'save_moment_reminder',
      params: {
        'p_enabled': reminder.enabled,
        'p_weekday': reminder.weekday,
        'p_hour': reminder.hour,
        'p_minute': reminder.minute,
      },
    );
  }

  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async {
    try {
      final session = _session();
      await client
          .rpc(
            'record_moment_activity',
            params: {
              'p_event_id': const Uuid().v4(),
              'p_event': activity.value,
              if (month != null) 'p_month': momentDateKey(momentMonth(month)),
            },
          )
          .timeout(const Duration(seconds: 3));
      _check(session);
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _generation++;
    unawaited(_subscription.cancel());
  }
}
