import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/storage_url_resolver.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';

void main() {
  test('album asset uploads are scoped under authenticated user folder', () {
    expect(
      StorageService.userScopedAlbumAssetPath(
        userId: 'user-123',
        relativePath: 'albums/covers/cover.jpg',
      ),
      'user-123/albums/covers/cover.jpg',
    );
  });

  test('album asset path helper does not double-prefix user folder', () {
    expect(
      StorageService.userScopedAlbumAssetPath(
        userId: 'user-123',
        relativePath: '/user-123/albums/images/photo.jpg',
      ),
      'user-123/albums/images/photo.jpg',
    );
  });

  test('legacy migration keeps already-installed clients unblocked', () {
    final sql = File(
      'supabase/migrations/20260825113929_repair_album_assets_storage_policies.sql',
    ).readAsStringSync();

    expect(sql, contains('album_assets_legacy_authenticated_insert'));
    expect(sql, contains("bucket_id = 'album-assets'"));
    expect(sql, contains("(storage.foldername(name))[1] = 'albums'"));
  });

  test('supabase storage uri parser extracts bucket and object path', () {
    final parsed = parseSupabaseStorageUri(
      'supabase://album-assets/user-123/albums/covers/cover.jpg',
    );

    expect(parsed?.bucket, 'album-assets');
    expect(parsed?.path, 'user-123/albums/covers/cover.jpg');
  });
}
