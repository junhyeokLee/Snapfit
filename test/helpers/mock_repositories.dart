import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

bool _mockFallbacksRegistered = false;

void _ensureMockFallbacksRegistered() {
  if (_mockFallbacksRegistered) return;
  _mockFallbacksRegistered = true;
  registerFallbackValue(const CreateAlbumRequest(
    ratio: '',
    coverLayersJson: '{}',
    coverImageUrl: '',
    coverThumbnailUrl: '',
  ));
}

/// [MockAlbumRepository]를 stub해서 [fetchMyAlbums]가 [albums]를 반환하도록 설정합니다.
void stubFetchMyAlbums(MockAlbumRepository mock, List<Album> albums) {
  _ensureMockFallbacksRegistered();
  when(() => mock.fetchMyAlbums()).thenAnswer((_) async => albums);
  when(() => mock.fetchAlbum(any())).thenThrow(UnimplementedError('stub if needed'));
  when(() => mock.createAlbum(any())).thenThrow(UnimplementedError('stub if needed'));
  when(() => mock.deleteAlbum(any())).thenAnswer((_) async {});
}
