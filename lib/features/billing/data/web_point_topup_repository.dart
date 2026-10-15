import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_provider.dart';
import '../domain/web_point_topup.dart';

final webPointTopupRepositoryProvider = Provider<WebPointTopupRepository>((ref) =>
  WebPointTopupRepository(ref.read(supabaseClientProvider)));

class WebPointTopupRepository {
  WebPointTopupRepository(this.client);
  final SupabaseClient client;
  void _requireOwner(String owner) {
    if (owner.isEmpty || client.auth.currentUser?.id != owner) {
      throw const WebPointTopupException('web_point_owner_changed');
    }
  }
  Future<Map<String, dynamic>> _call(String owner, Map<String, dynamic> body) async {
    _requireOwner(owner);
    try {
      final result = await client.functions.invoke('web-point-topup', body: body)
        .timeout(const Duration(seconds: 25));
      _requireOwner(owner);
      if (result.status != 200 || result.data is! Map) {
        throw const WebPointTopupException('web_point_unavailable');
      }
      return Map<String, dynamic>.from(result.data as Map);
    } on FunctionException catch (error) {
      _requireOwner(owner);
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      // No raw server/PG response or customer details enter UI/logs.
      throw WebPointTopupException(code is String && code.startsWith('web_point_')
        ? code : 'web_point_unavailable');
    }
  }
  Future<WebPointCatalog> catalog(String owner) async => WebPointCatalog.fromJson(
    await _call(owner, {'action': 'catalog'}));
  Future<List<WebPointTopup>> history(String owner) async {
    final data = await _call(owner, {'action': 'history'});
    if (data['liveCheckoutReleased'] != webPointTopupLiveCheckoutReleased ||
        data['topups'] is! List || (data['topups'] as List).length > 50) {
      throw const FormatException('web_point_history_invalid');
    }
    return (data['topups'] as List).map((raw) => _session(owner, raw)).toList(growable: false);
  }
  WebPointTopup _session(String owner, Object? value) {
    if (value is! Map) throw const FormatException('web_point_topup_invalid');
    final session = WebPointTopup.fromJson(Map<String, dynamic>.from(value));
    if (session.ownerId != owner) throw const WebPointTopupException('web_point_owner_changed');
    return session;
  }
  Future<WebPointTopup> prepare(String owner, String requestId, WebPointProduct product, {String environment = 'test'}) async {
    if (environment != 'test' && environment != 'live' || environment == 'live' && !webPointTopupLiveCheckoutReleased) {
      throw const WebPointTopupException('web_point_checkout_closed');
    }
    final session = _session(owner, await _call(owner, {'action': 'prepare', 'requestId': requestId,
      'productId': product.id, 'expectedAmount': product.amount, 'expectedPoints': product.points, 'environment': environment}));
    if (session.environment != environment || session.productId != product.id || session.amount != product.amount || session.points != product.points) {
      throw const WebPointTopupException('web_point_price_changed');
    }
    return session;
  }
  Future<WebPointSdkRequest> authorizeLaunch(String owner, WebPointTopup session) async {
    if (session.ownerId != owner || !session.canLaunch) {
      throw const WebPointTopupException('web_point_launch_not_available');
    }
    final raw = await _call(owner, {'action': 'launch', 'paymentId': session.paymentId});
    final request = WebPointSdkRequest.fromAuthorized(raw);
    if (request.topup.ownerId != owner || request.topup.paymentId != session.paymentId ||
        request.topup.amount != session.amount || request.topup.points != session.points ||
        request.topup.productId != session.productId || request.topup.environment != session.environment ||
        request.topup.storeId != session.storeId || request.topup.channelKey != session.channelKey) {
      throw const FormatException('web_point_sdk_identity_mismatch');
    }
    return request;
  }
  Future<WebPointTopup> status(String owner, String id) async =>
    _session(owner, await _call(owner, {'action': 'status', 'paymentId': id}));
  Future<WebPointTopup> confirm(String owner, String id) async =>
    _session(owner, await _call(owner, {'action': 'confirm', 'paymentId': id}));
}
