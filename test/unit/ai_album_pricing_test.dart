import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/config/env.dart';

void main() {
  test('advanced AI defaults to generous premium point cost', () {
    expect(Env.aiAlbumDraftPointCost, 700);
  });

  test(
    'point package migration seeds generous native store consumable products',
    () {
      final sql = File(
        'supabase/migrations/20260905200000_ai_album_pricing_adjustment.sql',
      ).readAsStringSync();

      expect(sql, contains('SNAPFIT_AI_DRAFT_HYBRID_COST = 700'));
      expect(sql, contains('snapfit_points_3500'));
      expect(sql, contains('snapfit_points_11000'));
      expect(sql, contains('snapfit_points_25000'));
      expect(sql, contains('snapfit_points_1500'));
      expect(sql, contains('is_active = false'));
    },
  );
}
