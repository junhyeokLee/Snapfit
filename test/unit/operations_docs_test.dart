import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AI album operations checklist includes end-to-end sandbox QA', () {
    final doc = File(
      'docs/AI_ALBUM_OPERATIONS_CHECKLIST.md',
    ).readAsStringSync();

    expect(doc, contains('Android sandbox'));
    expect(doc, contains('iOS sandbox'));
    expect(doc, contains('duplicate purchase update'));
    expect(doc, contains('metadata rollback'));
    expect(doc, contains('No secret values'));
    expect(doc, contains('AI_ALBUM_DRAFT_PROVIDER'));
  });

  test('admin SQL runbook documents support and metrics queries', () {
    final doc = File('docs/AI_ALBUM_ADMIN_SQL_RUNBOOK.md').readAsStringSync();

    expect(doc, contains('get_ai_album_operations_summary'));
    expect(doc, contains('ai_album_daily_metrics'));
    expect(doc, contains('ai_album_product_metrics'));
    expect(doc, contains('admin_adjust_user_points'));
    expect(doc, contains('admin_get_user_point_ledger'));
    expect(doc, contains('No secret values'));
    expect(doc, contains('USER_UUID_HERE'));
  });
}
