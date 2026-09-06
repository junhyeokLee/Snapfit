import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';

void main() {
  test('AuthResponse toString redacts access and refresh tokens', () {
    const response = AuthResponse(
      accessToken: 'access-token-secret-123',
      refreshToken: 'refresh-token-secret-456',
      expiresIn: 3600,
      user: UserInfo(
        id: 'user-1',
        email: 'admin@snapfit.app',
        name: 'Admin',
        provider: 'supabase',
      ),
    );

    final value = response.toString();

    expect(value, isNot(contains('access-token-secret-123')));
    expect(value, isNot(contains('refresh-token-secret-456')));
    expect(value, contains('[REDACTED]'));
  });

  test('operations runbook documents preview cleanup before release', () {
    final checklist = File(
      'docs/AI_ALBUM_OPERATIONS_CHECKLIST.md',
    ).readAsStringSync();
    final previewMigration = File(
      'supabase/migrations/20260905170000_ai_album_previews_storage.sql',
    ).readAsStringSync();

    expect(previewMigration, contains('delete_expired_ai_album_previews'));
    expect(checklist, contains('delete_expired_ai_album_previews'));
    expect(checklist, contains('ai-album-previews'));
    expect(checklist, contains('2 hours'));
  });
}
