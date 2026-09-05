import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration creates admin KPI views for AI and billing operations', () {
    final sql = File(
      'supabase/migrations/20260905210000_ai_album_admin_metrics.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace view public.ai_album_daily_metrics'),
    );
    expect(
      sql,
      contains('create or replace view public.ai_album_product_metrics'),
    );
    expect(sql, contains('AI_DRAFT_PROVIDER_RESULT'));
    expect(sql, contains('POINT_PURCHASE_VERIFIED'));
    expect(sql, contains('POINT_PURCHASE_DUPLICATE'));
    expect(sql, contains('fallback_count'));
    expect(sql, contains('estimated_revenue_krw'));
  });

  test('migration creates admin RPC for compact operations summary', () {
    final sql = File(
      'supabase/migrations/20260905210000_ai_album_admin_metrics.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains(
        'create or replace function public.get_ai_album_operations_summary',
      ),
    );
    expect(sql, contains('security definer'));
    expect(sql, contains('if not public.is_admin() then'));
    expect(sql, contains('raise exception'));
    expect(sql, contains('jsonb_build_object'));
    expect(sql, contains('recent_events'));
  });
}
