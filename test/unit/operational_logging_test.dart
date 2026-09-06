import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration creates operations log table for AI and billing events', () {
    final sql = File(
      'supabase/migrations/20260905204500_ai_album_operational_events.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.ai_album_operational_events'),
    );
    expect(sql, contains('event_type'));
    expect(sql, contains('AI_DRAFT_PROVIDER_RESULT'));
    expect(sql, contains('POINT_PURCHASE_VERIFIED'));
    expect(sql, contains('POINT_PURCHASE_DUPLICATE'));
    expect(sql, contains('request_id text'));
    expect(sql, contains('metadata jsonb'));
    expect(sql, contains('ai_album_operational_events_admin_read'));
  });

  test(
    'point purchase RPC returns idempotency status for duplicate delivery',
    () {
      final sql = File(
        'supabase/migrations/20260905201000_fix_grant_point_purchase_ambiguity.sql',
      ).readAsStringSync();

      expect(sql, contains('already_granted boolean'));
      expect(sql, contains('v_already_granted'));
      expect(sql, contains('return query select'));
    },
  );

  test(
    'edge functions write best-effort operational events without secrets',
    () {
      final iap = File(
        'supabase/functions/iap-verify/index.ts',
      ).readAsStringSync();
      final ai = File(
        'supabase/functions/ai-album-draft/index.ts',
      ).readAsStringSync();

      expect(iap, contains('logOperationalEvent'));
      expect(iap, contains('POINT_PURCHASE_VERIFIED'));
      expect(iap, contains('POINT_PURCHASE_DUPLICATE'));

      expect(ai, contains('logOperationalEvent'));
      expect(ai, contains('AI_DRAFT_PROVIDER_RESULT'));
      expect(ai, contains('fallbackUsed'));
    },
  );
}
