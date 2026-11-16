import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_provider.dart';
import '../../profile/presentation/views/admin_point_shop_management_screen.dart';
import '../domain/home_news.dart';
import '../presentation/providers/home_news_providers.dart';

class AdminHomeNewsSnapshot {
  const AdminHomeNewsSnapshot({
    required this.serverNow,
    required this.campaigns,
  });

  factory AdminHomeNewsSnapshot.fromJson(Map<String, dynamic> json) {
    final rawNow = json['serverNow'];
    final rows = json['campaigns'];
    if (rawNow is! String ||
        !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(rawNow) ||
        rows is! List) {
      throw const FormatException('새 소식 운영 설정을 확인할 수 없어요.');
    }
    final campaigns = rows
        .map(
          (row) =>
              HomeNewsCampaign.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    if (campaigns.length != HomeNewsKind.values.length ||
        campaigns.map((campaign) => campaign.kind).toSet().length !=
            campaigns.length) {
      throw const FormatException('새 소식 운영 설정을 다시 확인해 주세요.');
    }
    campaigns.sort((a, b) {
      final order = a.sortOrder.compareTo(b.sortOrder);
      return order == 0 ? a.kind.name.compareTo(b.kind.name) : order;
    });
    return AdminHomeNewsSnapshot(
      serverNow: DateTime.parse(rawNow).toUtc(),
      campaigns: List.unmodifiable(campaigns),
    );
  }

  final DateTime serverNow;
  final List<HomeNewsCampaign> campaigns;
}

abstract class AdminHomeNewsRepository {
  String? get currentUserId;
  Future<AdminHomeNewsSnapshot> getCampaigns();
  Future<AdminHomeNewsSnapshot> updateCampaign(HomeNewsCampaign campaign);
}

/// Only the signed-in admin's access token is used. Every operation is also
/// authorized by the database, including an immediate server-side role check.
class SupabaseAdminHomeNewsRepository implements AdminHomeNewsRepository {
  SupabaseAdminHomeNewsRepository(this.client) {
    _actor = currentUserId;
    _subscription = client.auth.onAuthStateChange.listen(
      (event) {
        final next = _adminId(event.session?.user);
        if (next != _actor) {
          _actor = next;
          _revision++;
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
  int _revision = 0;
  int _connectionRevision = 0;

  @override
  String? get currentUserId => _adminId(client.auth.currentUser);

  Future<AdminHomeNewsSnapshot> _request(
    String rpc, [
    Map<String, dynamic>? params,
  ]) async {
    final owner = currentUserId;
    final revision = _revision;
    final connection = _connectionRevision;
    if (owner == null) throw StateError('새 소식을 관리할 권한이 필요합니다.');
    final raw = await client
        .rpc(rpc, params: params)
        .timeout(const Duration(seconds: 15));
    if (owner != currentUserId || revision != _revision) {
      throw StateError('계정이 변경됐습니다. 운영 화면을 다시 열어주세요.');
    }
    if (connection != _connectionRevision) {
      throw StateError('연결 상태를 확인하지 못했습니다. 운영 화면을 다시 열어주세요.');
    }
    if (raw is! Map || raw['userId'] != owner) {
      throw const FormatException('새 소식 운영 계정을 확인할 수 없어요.');
    }
    return AdminHomeNewsSnapshot.fromJson(Map<String, dynamic>.from(raw));
  }

  @override
  Future<AdminHomeNewsSnapshot> getCampaigns() =>
      _request('get_admin_home_news_campaigns');

  @override
  Future<AdminHomeNewsSnapshot> updateCampaign(HomeNewsCampaign campaign) {
    if (campaign.sortOrder < -1000 ||
        campaign.sortOrder > 1000 ||
        (campaign.startsAt != null &&
            campaign.endsAt != null &&
            !campaign.endsAt!.isAfter(campaign.startsAt!))) {
      throw ArgumentError('노출 기간과 순서를 다시 확인해 주세요.');
    }
    return _request('update_admin_home_news_campaign', {
      'p_kind': campaign.kind.name,
      'p_enabled': campaign.enabled,
      'p_starts_at': campaign.startsAt?.toUtc().toIso8601String(),
      'p_ends_at': campaign.endsAt?.toUtc().toIso8601String(),
      'p_sort_order': campaign.sortOrder,
    });
  }

  static String? _adminId(User? user) =>
      user == null || user.isAnonymous || user.appMetadata['role'] != 'admin'
      ? null
      : user.id;

  void dispose() => unawaited(_subscription.cancel());
}

final adminHomeNewsAccessProvider = Provider<bool>(
  (ref) =>
      ref.watch(homeNewsCurrentOwnerProvider) != null &&
      ref.watch(pointShopAdminAccessProvider),
);

final adminHomeNewsRepositoryProvider = Provider<AdminHomeNewsRepository>((
  ref,
) {
  final repository = SupabaseAdminHomeNewsRepository(
    ref.watch(supabaseClientProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final adminHomeNewsSnapshotProvider =
    FutureProvider.autoDispose<AdminHomeNewsSnapshot>((ref) async {
      final owner = ref.watch(homeNewsCurrentOwnerProvider);
      if (owner == null || !ref.watch(adminHomeNewsAccessProvider)) {
        throw StateError('새 소식을 관리할 권한이 필요합니다.');
      }
      final repository = ref.watch(adminHomeNewsRepositoryProvider);
      if (repository.currentUserId != owner)
        throw StateError('운영 계정을 확인해 주세요.');
      final snapshot = await repository.getCampaigns();
      if (!ref.mounted ||
          ref.read(homeNewsCurrentOwnerProvider) != owner ||
          !ref.read(adminHomeNewsAccessProvider) ||
          repository.currentUserId != owner) {
        throw StateError('계정이 변경됐습니다. 운영 화면을 다시 열어주세요.');
      }
      return snapshot;
    });
