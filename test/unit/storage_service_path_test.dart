import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/storage_url_resolver.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';

void main() {
  test(
    'ai album preview bucket migration is private user scoped and expirable',
    () {
      final sql = File(
        'supabase/migrations/20260905170000_ai_album_previews_storage.sql',
      ).readAsStringSync();

      expect(sql, contains("'ai-album-previews'"));
      expect(sql, contains('public, file_size_limit, allowed_mime_types'));
      expect(sql, contains('false'));
      expect(sql, contains('image/webp'));
      expect(sql, contains('ai_album_previews_own_insert'));
      expect(sql, contains('ai_album_previews_own_read'));
      expect(sql, contains('ai_album_previews_own_delete'));
      expect(sql, contains('delete_expired_ai_album_previews'));
      expect(sql, contains("bucket_id = 'ai-album-previews'"));
      expect(sql, contains('(storage.foldername(name))[1] = auth.uid()::text'));
    },
  );

  test('advanced AI preview paths are scoped under user and draft folders', () {
    expect(
      StorageService.userScopedAiAlbumPreviewPath(
        userId: 'user-123',
        draftId: 'draft abc/../x',
        assetId: 'photo 1/orig',
      ),
      'user-123/draft-abc-x/photo-1-orig.jpg',
    );
  });

  test('advanced AI preview uri uses private preview bucket', () {
    expect(
      StorageService.aiAlbumPreviewStorageUri('user-123/draft-1/photo-1.jpg'),
      'supabase://ai-album-previews/user-123/draft-1/photo-1.jpg',
    );
  });

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
