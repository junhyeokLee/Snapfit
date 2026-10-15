import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/supabase/supabase_provider.dart';

class StoreCuration {
  const StoreCuration({
    required this.placement,
    required this.title,
    required this.subtitle,
    required this.productKeys,
    this.enabled = true,
  });
  final String placement, title, subtitle;
  final List<String> productKeys;
  final bool enabled;

  factory StoreCuration.fromJson(Map<String, dynamic> row) => StoreCuration(
    placement: row['placement'] as String,
    title: row['title'] as String,
    subtitle: row['subtitle'] as String? ?? '',
    enabled: row['enabled'] == true,
    productKeys: List<String>.unmodifiable(
      (row['product_keys'] as List).cast<String>().toSet().take(12),
    ),
  );

  List<T> resolve<T>(Iterable<T> available, String Function(T) key) {
    if (!enabled) return [];
    final byKey = {for (final item in available) key(item): item};
    return [
      for (final id in productKeys)
        if (byKey.containsKey(id)) byKey[id] as T,
    ];
  }

  static const templates = StoreCuration(
    placement: 'templates',
    title: '오래 간직하고 싶은 장면들',
    subtitle: '사진이 한 권의 이야기가 되는 디자인',
    productKeys: [
      'template:shore-days',
      'template:silk-vows',
      'template:lightbound',
      'template:reading-room',
    ],
  );
  static const materials = StoreCuration(
    placement: 'materials',
    title: '한 끗을 더하는 소재',
    subtitle: '종이의 결부터 작은 매듭까지',
    productKeys: [
      'frame:materialLinenOval',
      'sticker:atelierColorSlips',
      'sticker:atelierRibbonPlate',
      'phrase:collage-atelier-ribbon',
    ],
  );
}

/// A successful hidden/empty response is cached too. Network errors must not
/// bring back a promotion that an administrator deliberately removed.
final storeCurationsProvider = FutureProvider<Map<String, StoreCuration>>((
  ref,
) async {
  const cacheKey = 'store_curations_v1';
  SharedPreferences? prefs;
  Map<String, StoreCuration> parse(List rows) => {
    for (final row in rows)
      (row['placement'] as String): StoreCuration.fromJson(
        Map<String, dynamic>.from(row as Map),
      ),
  };
  Map<String, StoreCuration>? cached;
  try {
    prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw != null) cached = parse(jsonDecode(raw) as List);
  } catch (_) {
    /* An invalid old cache is not a catalog failure. */
  }
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('store_curations')
        .select('placement,title,subtitle,enabled,product_keys')
        .timeout(const Duration(seconds: 4));
    final result = parse(rows);
    try {
      await prefs?.setString(cacheKey, jsonEncode(rows));
    } catch (_) {}
    return result;
  } catch (_) {
    return cached ??
        {
          'templates': StoreCuration.templates,
          'materials': StoreCuration.materials,
        };
  }
});
