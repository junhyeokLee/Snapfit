import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/config/env.dart';

void main() {
  test(
    'advanced AI defaults to premium point cost for hybrid quality model',
    () {
      expect(Env.aiAlbumDraftPointCost, 900);
    },
  );

  test('point package migration seeds native store consumable products', () {
    final sql = File(
      'supabase/migrations/20260905193000_ai_album_hybrid_pricing.sql',
    ).readAsStringSync();

    expect(sql, contains('SNAPFIT_AI_DRAFT_HYBRID_COST'));
    expect(sql, contains('snapfit_points_1500'));
    expect(sql, contains('snapfit_points_4500'));
    expect(sql, contains('snapfit_points_10000'));
    expect(sql, contains('POINT_PURCHASE'));
    expect(sql, contains('grant_point_purchase'));
  });
}
