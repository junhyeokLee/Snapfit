import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/home_news.dart';

abstract class HomeNewsRepository {
  String? get currentUserId;
  Stream<String?> get authChanges;
  Future<HomeNewsExposureState> getExposureState();
  Future<List<HomeNewsExposure>> getHistory();
  Future<bool> claimExposure(String campaignId);
  Future<void> recordInteraction(
    String campaignId,
    HomeNewsInteraction interaction,
  );
}

/// Separate capabilities keep existing injected repositories source compatible.
abstract interface class HomeNewsDeliveryRepository {
  Future<HomeNewsDeliveryClaim> claimDelivery(List<String> campaignIds);
  Future<bool> recordDeliveryView(String deliveryId, String campaignId);
}

extension HomeNewsDeliveryCapabilities on HomeNewsRepository {
  Future<HomeNewsDeliveryClaim> claimDelivery(List<String> campaignIds) async {
    final repository = this;
    if (repository is HomeNewsDeliveryRepository) {
      return (repository as HomeNewsDeliveryRepository).claimDelivery(
        campaignIds,
      );
    }
    if (campaignIds.isEmpty) return const HomeNewsDeliveryClaim(claimed: false);
    final claimed = await claimExposure(campaignIds.first);
    return HomeNewsDeliveryClaim(
      claimed: claimed,
      campaignIds: claimed ? List.unmodifiable(campaignIds) : const [],
    );
  }

  Future<bool> recordDeliveryView(String deliveryId, String campaignId) async {
    final repository = this;
    if (repository is HomeNewsDeliveryRepository) {
      return (repository as HomeNewsDeliveryRepository).recordDeliveryView(
        deliveryId,
        campaignId,
      );
    }
    return true;
  }
}

class SupabaseHomeNewsRepository
    implements HomeNewsRepository, HomeNewsDeliveryRepository {
  SupabaseHomeNewsRepository(this.client) {
    _actor = currentUserId;
    _subscription = client.auth.onAuthStateChange.listen((state) {
      final next = _personalUserId(state.session?.user);
      if (next != _actor) {
        _actor = next;
        _sessionRevision++;
      }
    });
  }

  final SupabaseClient client;
  late final StreamSubscription<AuthState> _subscription;
  String? _actor;
  int _sessionRevision = 0;

  @override
  String? get currentUserId => _personalUserId(client.auth.currentUser);

  @override
  Stream<String?> get authChanges => client.auth.onAuthStateChange
      .map((state) => _personalUserId(state.session?.user))
      .distinct();

  Future<Map<String, dynamic>> _request(
    String name, [
    Map<String, dynamic>? params,
  ]) async {
    final owner = currentUserId;
    if (owner == null) throw StateError('로그인 후 새 소식을 확인할 수 있어요.');
    final revision = _sessionRevision;
    final raw = await client
        .rpc(name, params: params)
        .timeout(const Duration(seconds: 15));
    if (owner != currentUserId || revision != _sessionRevision) {
      throw StateError('계정이 변경됐어요. 새 소식을 다시 열어주세요.');
    }
    if (raw is! Map || raw['userId'] != owner) {
      throw const FormatException('새 소식 계정 정보를 확인할 수 없어요.');
    }
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<HomeNewsExposureState> getExposureState() async =>
      HomeNewsExposureState.fromJson(await _request('get_home_news_state'));

  @override
  Future<List<HomeNewsExposure>> getHistory() async =>
      (await getExposureState()).history;

  @override
  Future<bool> claimExposure(String campaignId) async {
    final raw = await _request('claim_home_news_exposure', {
      'p_campaign_id': campaignId,
    });
    final state = HomeNewsExposureState.fromJson(raw);
    final claimed = raw['claimed'];
    if (claimed is! bool ||
        (claimed && (!state.hasSeen(campaignId) || state.dailyCount != 1))) {
      throw const FormatException('새 소식 노출 결과를 확인할 수 없어요.');
    }
    return claimed;
  }

  @override
  Future<HomeNewsDeliveryClaim> claimDelivery(List<String> campaignIds) async {
    if (campaignIds.isEmpty ||
        campaignIds.length > HomeNewsKind.values.length ||
        campaignIds.toSet().length != campaignIds.length) {
      throw const FormatException('함께 볼 소식을 다시 확인해 주세요.');
    }
    final raw = await _request('claim_home_news_delivery', {
      'p_campaign_ids': campaignIds,
    });
    final state = HomeNewsExposureState.fromJson(raw);
    final claimed = raw['claimed'];
    final deliveryId = raw['deliveryId'];
    final allowed = raw['allowedCampaignIds'];
    if (claimed is! bool ||
        allowed is! List ||
        allowed.any((id) => id is! String)) {
      throw const FormatException('소식 묶음 노출 결과를 확인할 수 없어요.');
    }
    final ids = allowed.cast<String>();
    if (ids.toSet().length != ids.length ||
        ids.any((id) => !campaignIds.contains(id)) ||
        (claimed &&
            (ids.isEmpty ||
                ids.first != campaignIds.first ||
                deliveryId is! String ||
                !state.deliveries.any((row) => row.id == deliveryId) ||
                !state.hasSeen(ids.first) ||
                state.dailyCount != 1)) ||
        (!claimed && (deliveryId != null || ids.isNotEmpty))) {
      throw const FormatException('소식 묶음 기록을 다시 확인해 주세요.');
    }
    return HomeNewsDeliveryClaim(
      claimed: claimed,
      deliveryId: deliveryId as String?,
      campaignIds: List.unmodifiable(ids),
    );
  }

  @override
  Future<bool> recordDeliveryView(String deliveryId, String campaignId) async {
    final raw = await _request('record_home_news_delivery_view', {
      'p_delivery_id': deliveryId,
      'p_campaign_id': campaignId,
    });
    HomeNewsExposureState.fromJson(raw);
    final viewed = raw['viewed'];
    if (viewed is! bool) {
      throw const FormatException('소식 보기 결과를 확인할 수 없어요.');
    }
    return viewed;
  }

  @override
  Future<void> recordInteraction(
    String campaignId,
    HomeNewsInteraction interaction,
  ) async {
    final raw = await _request('record_home_news_interaction', {
      'p_campaign_id': campaignId,
      'p_interaction': interaction.name,
    });
    HomeNewsExposureState.fromJson(raw);
  }

  static String? _personalUserId(User? user) =>
      user == null || user.isAnonymous ? null : user.id;

  void dispose() => unawaited(_subscription.cancel());
}
