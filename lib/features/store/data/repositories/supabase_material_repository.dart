import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/catalog_material.dart';
import '../../domain/repositories/material_repository.dart';

class SupabaseMaterialRepository implements MaterialRepository {
  SupabaseMaterialRepository(this.client);

  final SupabaseClient client;

  String get _userId => client.auth.currentUser?.id.trim() ?? '';

  CatalogMaterial _fromRow(Map<String, dynamic> row, {bool isLiked = false}) =>
      CatalogMaterial(
        productKey: row['product_key']?.toString() ?? '',
        label: row['label']?.toString() ?? '',
        type: row['type']?.toString() ?? '',
        collection: row['collection']?.toString(),
        isActive: row['is_active'] != false,
        isPremium: row['is_premium'] == true,
        weeklyScore: (row['weekly_score'] as num?)?.toInt() ?? 0,
        likeCount: (row['like_count'] as num?)?.toInt() ?? 0,
        userCount: (row['user_count'] as num?)?.toInt() ?? 0,
        isLiked: isLiked,
      );

  @override
  Future<List<CatalogMaterial>> getMaterials() async {
    final userId = _userId;
    final rows = await client
        .from('materials')
        .select('*, material_likes(user_id)')
        .eq('is_active', true)
        .order('weekly_score', ascending: false)
        .order('product_key', ascending: true);
    return rows
        .map<CatalogMaterial>((row) {
          final likes = row['material_likes'];
          final isLiked =
              userId.isNotEmpty &&
              likes is List &&
              likes.any((l) => l is Map && l['user_id']?.toString() == userId);
          return _fromRow(Map<String, dynamic>.from(row), isLiked: isLiked);
        })
        .toList(growable: false);
  }

  @override
  Future<void> likeMaterial(String productKey) async {
    final userId = _userId;
    if (userId.isEmpty) throw Exception('로그인이 필요합니다.');
    final existing = await client
        .from('material_likes')
        .select('product_key')
        .eq('product_key', productKey)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing == null) {
      await client.from('material_likes').insert({
        'product_key': productKey,
        'user_id': userId,
      });
    } else {
      await client
          .from('material_likes')
          .delete()
          .eq('product_key', productKey)
          .eq('user_id', userId);
    }
  }
}
