import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/data/api/album_api.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/data/repositories/album_repository_impl.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';

class MockAlbumApi extends Mock implements AlbumApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1:1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
    registerFallbackValue(<String, dynamic>{});
  });

  test('createAlbum injects userId from token storage', () async {
    final api = MockAlbumApi();
    final storage = MockTokenStorage();
    final repository = AlbumRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-1');
    when(() => api.createAlbum(any())).thenAnswer((_) async => const Album());

    await repository.createAlbum(
      const CreateAlbumRequest(
        ratio: '1:1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );

    final captured =
        verify(() => api.createAlbum(captureAny())).captured.single
            as CreateAlbumRequest;
    expect(captured.userId, 'user-1');
  });

  test('fetchMyAlbums passes userId to api', () async {
    final api = MockAlbumApi();
    final storage = MockTokenStorage();
    final repository = AlbumRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-2');
    when(() => api.fetchMyAlbums('user-2')).thenAnswer((_) async => <Album>[]);

    await repository.fetchMyAlbums();

    verify(() => api.fetchMyAlbums('user-2')).called(1);
  });

  test('reorderAlbums passes userId and albumIds', () async {
    final api = MockAlbumApi();
    final storage = MockTokenStorage();
    final repository = AlbumRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-3');
    when(() => api.reorderAlbums(any(), 'user-3')).thenAnswer((_) async {});

    await repository.reorderAlbums([1, 2]);

    verify(
      () => api.reorderAlbums({
        'albumIds': [1, 2],
      }, 'user-3'),
    ).called(1);
  });
}
