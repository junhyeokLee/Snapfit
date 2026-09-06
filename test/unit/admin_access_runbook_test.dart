import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin access runbook explains how admin is granted and verified', () {
    final doc = File(
      'docs/SUPABASE_ADMIN_ACCESS_RUNBOOK.md',
    ).readAsStringSync();

    expect(doc, contains("app_metadata"));
    expect(doc, contains("role"));
    expect(doc, contains("admin"));
    expect(doc, contains('public.is_admin()'));
    expect(doc, contains('auth.users'));
    expect(doc, contains('Do not paste'));
    expect(doc, contains('get_ai_album_operations_summary'));
    expect(doc, contains('admin_adjust_user_points'));
  });

  test('schema defines admin by auth app metadata role', () {
    final sql = File(
      'supabase/migrations/20260820140500_initial_snapfit_schema.sql',
    ).readAsStringSync();

    expect(sql, contains("auth.jwt() -> 'app_metadata' ->> 'role'"));
    expect(sql, contains("= 'admin'"));
  });
}
