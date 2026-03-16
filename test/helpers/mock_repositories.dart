import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}
class MockTemplateRepository extends Mock implements TemplateRepository {}

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
  registerFallbackValue(<int>[]);
  registerFallbackValue(<String, String>{});
}

/// [MockAlbumRepository]를 stub해서 [fetchMyAlbums]가 [albums]를 반환하도록 설정합니다.
void stubFetchMyAlbums(MockAlbumRepository mock, List<Album> albums) {
  _ensureMockFallbacksRegistered();
  when(() => mock.fetchMyAlbums()).thenAnswer((_) async => albums);
  when(() => mock.fetchAlbum(any())).thenThrow(UnimplementedError('stub if needed'));
  when(() => mock.createAlbum(any())).thenThrow(UnimplementedError('stub if needed'));
  when(() => mock.deleteAlbum(any())).thenAnswer((_) async {});
}

void stubGetTemplates(MockTemplateRepository mock, List<PremiumTemplate> templates) {
  _ensureMockFallbacksRegistered();
  when(() => mock.getTemplates()).thenAnswer((_) async => templates);
  when(() => mock.getTemplate(any())).thenThrow(UnimplementedError('stub if needed'));
  when(() => mock.likeTemplate(any())).thenAnswer((_) async {});
  when(() => mock.createAlbumFromTemplate(any(), replacements: any(named: 'replacements')))
      .thenThrow(UnimplementedError('stub if needed'));
}
