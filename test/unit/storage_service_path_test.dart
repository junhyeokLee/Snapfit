import 'package:flutter_test/flutter_test.dart';
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
}
