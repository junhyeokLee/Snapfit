import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/config/env.dart';

void main() {
  test('AI base cost matches the current 20-page server pricing policy', () {
    final basePricing = File(
      'supabase/migrations/20261019120000_ai_template_cost_500.sql',
    ).readAsStringSync();
    final pagePricing = File(
      'supabase/migrations/20261019130000_ai_template_page_cost.sql',
    ).readAsStringSync();
    expect(Env.aiAlbumDraftPointCost, 500);
    expect(basePricing, contains('select 500;'));
    expect(
      pagePricing,
      contains(
        '300 + least(80, greatest(20, coalesce(p_page_count, 20))) * 10',
      ),
    );
    expect(
      pagePricing,
      contains('public.ai_album_draft_point_cost_for_pages(p_page_count)'),
    );
  });

  test(
    'point package migration seeds profit-safe native store consumables',
    () {
      final sql = File(
        'supabase/migrations/20260905203000_ai_album_profit_pricing.sql',
      ).readAsStringSync();

      expect(sql, contains('SNAPFIT_AI_DRAFT_HYBRID_COST = 700'));
      expect(sql, contains('snapfit_points_2500'));
      expect(sql, contains('snapfit_points_8000'));
      expect(sql, contains('snapfit_points_18000'));
      expect(sql, contains('snapfit_points_3500'));
      expect(sql, contains('is_active = false'));
    },
  );

  test('Flutter env defaults to active profit-safe point products', () {
    expect(Env.iapPointProductIds, [
      'snapfit_points_2500',
      'snapfit_points_8000',
      'snapfit_points_18000',
    ]);
  });
}
