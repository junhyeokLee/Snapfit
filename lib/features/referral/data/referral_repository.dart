import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/referral_link.dart';
import '../domain/referral_status.dart';

abstract class ReferralRepository {
  String? get currentUserId;
  Stream<String?> get authChanges;
  Future<ReferralStatus> fetchStatus();
  Future<ReferralStatus> redeem(String code);
}

class SupabaseReferralRepository implements ReferralRepository {
  SupabaseReferralRepository(this.client) {
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

  Future<ReferralStatus> _request(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    final owner = currentUserId;
    if (owner == null) throw StateError('로그인 후 초대 혜택을 받을 수 있어요.');
    final revision = _sessionRevision;
    final connection = _connectionRevision;
    final raw = await client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 15));
    if (owner != currentUserId || revision != _sessionRevision) {
      throw StateError('계정이 변경됐어요. 친구 초대를 다시 열어주세요.');
    }
    if (connection != _connectionRevision) {
      throw StateError('연결 상태를 확인하지 못했어요. 친구 초대를 다시 열어주세요.');
    }
    return ReferralStatus.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  @override
  Future<ReferralStatus> fetchStatus() => _request('get_referral_status');
  @override
  Future<ReferralStatus> redeem(String code) {
    final normalized = normalizeReferralCode(code);
    if (normalized == null) throw const FormatException('10자리 초대 코드를 확인해주세요.');
    return _request('redeem_referral_code', {'p_code': normalized});
  }

  void dispose() => unawaited(_subscription.cancel());
}
