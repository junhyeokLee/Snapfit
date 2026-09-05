import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/config/env.dart';

void main() {
  test('advanced AI defaults to profit-safe premium point cost', () {
    expect(Env.aiAlbumDraftPointCost, 700);
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
}
