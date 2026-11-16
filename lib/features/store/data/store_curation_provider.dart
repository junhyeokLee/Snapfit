import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../domain/store_template_editorial_selection.dart';

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
    subtitle: '일상의 무료 앨범부터 새로운 주제의 프리미엄까지, 열한 가지 취향',
    productKeys: storeTemplateEditorialProductKeys,
  );
  static const materials = StoreCuration(
    placement: 'materials',
    title: '한 끗을 더하는 소재',
    subtitle: '프레임·종이·스티커·문구를 세 가지씩, 서로 다른 꾸밈의 시작',
    productKeys: [
      // Each group of four introduces one frame, paper, sticker and phrase.
      // Both the latest artwork and established free starters remain visible.
      'frame:pq9841a',
      'sticker:atelierWritingLetter',
      'sticker:story-premium-hanbok-vows-keepsake',
      'phrase:collage-atelier-laughter',
      'frame:cafeLedgerMat',
      'sticker:story-premium-thesis-new-sentence-paper',
      'sticker:cafeRoastedLeaf',
      'phrase:collage-story-premium-first-words-caption',
      'frame:pq9807b',
      'sticker:materialScallopNote',
      'sticker:materialLace',
      'phrase:collage-atelier-boarding',
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
