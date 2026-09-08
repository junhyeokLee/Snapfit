import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/point_shop_product.dart';
export '../domain/point_shop_product.dart';

abstract class PointShopRepository {
  String? get currentUserId;
  Stream<String?> get authChanges;
  Future<List<PointShopProduct>> loadCatalog();
  Future<Set<String>> loadOwnedKeys();
  Future<PointShopAccess> getAccess(String key);
  Future<PointShopPurchase> purchase(String key, int expectedPrice);
  Future<void> saveProduct(PointShopProduct product);
}

class SupabasePointShopRepository implements PointShopRepository {
  SupabasePointShopRepository(this.client);
  final SupabaseClient client;

  @override
  String? get currentUserId => client.auth.currentUser?.id;

  @override
  Stream<String?> get authChanges => client.auth.onAuthStateChange
      .map((event) => event.session?.user.id)
      .distinct();

  void _checkAccount(String? userId) {
    if (userId != currentUserId) {
      throw const PointShopException('account_changed');
    }
  }

  @override
  Future<List<PointShopProduct>> loadCatalog() async {
    final rows = await client
        .from('point_shop_products')
        .select()
        .order('title');
    return rows.map(PointShopProduct.fromJson).toList(growable: false);
  }

  @override
  Future<Set<String>> loadOwnedKeys() async {
    final userId = currentUserId;
    if (userId == null) return {};
    final rows = await client
        .from('point_shop_ownership')
        .select('product_key')
        .eq('user_id', userId);
    _checkAccount(userId);
    return rows.map((row) => row['product_key'] as String).toSet();
  }

  @override
  Future<PointShopAccess> getAccess(String key) async {
    final userId = currentUserId;
    final json = await _rpc('get_point_shop_access', {'p_product_key': key});
    _checkAccount(userId);
    return PointShopAccess.fromJson(json);
  }

  @override
  Future<PointShopPurchase> purchase(String key, int expectedPrice) async {
    final userId = currentUserId;
    if (userId == null)
      throw const PointShopException('authentication_required');
    final json = await _rpc('purchase_point_shop_product', {
      'p_product_key': key,
      'p_expected_price': expectedPrice,
    });
    _checkAccount(userId);
    final purchase = PointShopPurchase.fromJson(json);
    if (purchase.productKey != key || (!purchase.owned && !purchase.isFree)) {
      throw const PointShopException('invalid_purchase_response');
    }
    return purchase;
  }

  @override
  Future<void> saveProduct(PointShopProduct product) async {
    if (currentUserId == null)
      throw const PointShopException('authentication_required');
    await client
        .from('point_shop_products')
        .upsert(product.toJson(), onConflict: 'product_key');
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params,
  ) async {
    try {
      final result = await client.rpc(name, params: params);
      if (result is! Map) throw const PointShopException('invalid_response');
      return Map<String, dynamic>.from(result);
    } on PostgrestException catch (error) {
      const known = {
        'authentication_required',
        'invalid_point_shop_product_key',
        'point_shop_product_unavailable',
        'point_shop_price_changed',
        'insufficient_points',
      };
      throw PointShopException(
        known.contains(error.message) ? error.message : 'unavailable',
      );
    }
  }
}
