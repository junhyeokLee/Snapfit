import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/moment_record.dart';
import '../domain/private_moment_archive.dart';

abstract class PrivateMomentArchiveRepository {
  String? get currentUserId;
  int get sessionRevision;
  Stream<int> get sessionChanges;
  Future<List<MomentMonthSummary>> listMonths({
    required String ownerId,
    DateTime? beforeMonth,
    int limit = 6,
  });
  Future<List<String>> monthlyPhotoChoices({
    required String ownerId,
    required DateTime month,
  });
  Future<List<String>> weeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
  });
  Future<void> saveWeeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
    required List<String> photoIds,
  });
}

/// The server derives the owner from auth.uid(), never from an arbitrary ID.
/// The local owner and monotonic revision additionally discard A → B → A work.
class SupabasePrivateMomentArchiveRepository
    implements PrivateMomentArchiveRepository {
  SupabasePrivateMomentArchiveRepository(this.client) {
    _owner = currentUserId;
    _subscription = client.auth.onAuthStateChange.listen(
      (event) {
        final next = event.session?.user.id;
        if (!_disposed && next != _owner) {
          _owner = next;
          _revision++;
          _changes.add(_revision);
        }
      },
      onError: (Object _, StackTrace __) {
        // Offline refresh errors must invalidate in-flight private reads, not
        // become unhandled zone exceptions or permission to reuse old results.
        if (_disposed) return;
        _revision++;
        _changes.add(_revision);
      },
    );
  }
  final SupabaseClient client;
  final _changes = StreamController<int>.broadcast(sync: true);
  late final StreamSubscription<AuthState> _subscription;
  String? _owner;
  int _revision = 0;
  bool _disposed = false;
  @override
  String? get currentUserId => client.auth.currentUser?.id;
  @override
  int get sessionRevision => _revision;
  @override
  Stream<int> get sessionChanges => _changes.stream;

  void _check(String owner, int revision) {
    if (_disposed ||
        owner.isEmpty ||
        currentUserId != owner ||
        _revision != revision) {
      throw const MomentException('계정이 변경됐어요. 현재 계정의 기록에서 다시 열어 주세요.');
    }
  }

  Future<dynamic> _rpc(
    String owner,
    String name,
    Map<String, dynamic> params,
  ) async {
    final revision = _revision;
    _check(owner, revision);
    try {
      final result = await client
          .rpc(name, params: params)
          .timeout(const Duration(seconds: 25));
      _check(owner, revision);
      return result;
    } on PostgrestException {
      _check(owner, revision);
      throw const MomentException('기록을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } on TimeoutException {
      _check(owner, revision);
      throw const MomentException('연결이 지연되고 있어요. 잠시 후 다시 확인해 주세요.');
    }
  }

  @override
  Future<List<MomentMonthSummary>> listMonths({
    required String ownerId,
    DateTime? beforeMonth,
    int limit = 6,
  }) async {
    final raw = await _rpc(ownerId, 'get_my_moment_months', {
      'p_before_month': beforeMonth == null
          ? null
          : momentDateKey(momentMonth(beforeMonth)),
      'p_limit': limit,
    });
    return List.unmodifiable(
      (raw as List).map(
        (entry) => MomentMonthSummary.fromJson(
          Map<String, dynamic>.from(entry as Map),
        ),
      ),
    );
  }

  Future<List<String>> _choices(
    String owner,
    String name,
    Map<String, dynamic> params,
  ) async => List<String>.unmodifiable(
    (await _rpc(owner, name, params) as List).cast<String>(),
  );

  @override
  Future<List<String>> monthlyPhotoChoices({
    required String ownerId,
    required DateTime month,
  }) => _choices(ownerId, 'get_moment_month_photo_choices', {
    'p_month': momentDateKey(momentMonth(month)),
  });

  @override
  Future<List<String>> weeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
  }) => _choices(ownerId, 'get_moment_week_photo_choices', {
    'p_week_start': momentDateKey(momentDate(weekStart)),
  });

  @override
  Future<void> saveWeeklyPhotoChoices({
    required String ownerId,
    required DateTime weekStart,
    required List<String> photoIds,
  }) async {
    if (photoIds.length > 3 || photoIds.toSet().length != photoIds.length) {
      throw const MomentException('한 주에 사진 세 장까지 골라 주세요.');
    }
    await _rpc(ownerId, 'save_moment_week_photo_choices', {
      'p_week_start': momentDateKey(momentDate(weekStart)),
      'p_photo_ids': List<String>.of(photoIds),
    });
  }

  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_subscription.cancel());
    unawaited(_changes.close());
  }
}
