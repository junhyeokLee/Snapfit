import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin point operations migration creates guarded adjustment RPC', () {
    final sql = File(
      'supabase/migrations/20260905211500_admin_point_operations.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.admin_adjust_user_points'),
    );
    expect(sql, contains('security definer'));
    expect(sql, contains('if not public.is_admin() then'));
    expect(sql, contains('ADMIN_ADJUSTMENT'));
    expect(sql, contains('admin_adjustment:'));
    expect(sql, contains('amount_delta integer'));
    expect(sql, contains('new_balance integer'));
    expect(
      sql,
      contains('on conflict on constraint point_wallets_pkey do nothing'),
    );
  });

  test('admin point operations migration creates CS ledger lookup RPC', () {
    final sql = File(
      'supabase/migrations/20260905211500_admin_point_operations.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create or replace function public.admin_get_user_point_ledger'),
    );
    expect(sql, contains('remaining_balance'));
    expect(sql, contains('point_ledger'));
    expect(sql, contains('order by pl.created_at desc'));
    expect(sql, contains('limit greatest(1, least'));
  });
}
