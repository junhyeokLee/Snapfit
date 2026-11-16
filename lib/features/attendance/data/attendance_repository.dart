import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/attendance_status.dart';

abstract class AttendanceRepository {
  String? get currentUserId;
  Stream<String?> get authChanges;
  Future<AttendanceStatus> fetchStatus();
  Future<AttendanceStatus> claim();
}

class SupabaseAttendanceRepository implements AttendanceRepository {
  SupabaseAttendanceRepository(this.client) {
    _actor = currentUserId;
    _subscription = client.auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        if (next != _actor) {
          _actor = next;
          _sessionRevision++;
        }
      },
      onError: (Object _, StackTrace __) {
        // A failed token refresh is not a sign-out. Invalidate pending replies
        // while retaining the SDK's real account for a fresh authorized retry.
        _connectionRevision++;
      },
    );
  }

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  String? _actor;
  int _sessionRevision = 0;
  int _connectionRevision = 0;

  @override
  String? get currentUserId => client.auth.currentUser?.id;
  @override
  Stream<String?> get authChanges => client.auth.onAuthStateChange
      .handleError((Object _, StackTrace __) {})
      .map((state) => state.session?.user.id)
      .distinct();

  Future<AttendanceStatus> _request(String function) async {
    final actor = currentUserId;
    if (actor == null) throw StateError('로그인 후 출석할 수 있어요.');
    final revision = _sessionRevision;
    final connection = _connectionRevision;
    final raw = await client.rpc(function).timeout(const Duration(seconds: 15));
    if (actor != currentUserId || revision != _sessionRevision) {
      throw StateError('계정이 변경됐어요. 출석 화면을 다시 열어주세요.');
    }
    if (connection != _connectionRevision) {
      throw StateError('연결 상태를 확인하지 못했어요. 출석 화면을 다시 열어주세요.');
    }
    return AttendanceStatus.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<AttendanceStatus> fetchStatus() => _request('get_attendance_status');
  @override
  Future<AttendanceStatus> claim() => _request('claim_daily_attendance');

  void dispose() => unawaited(_subscription.cancel());
}
