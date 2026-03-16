import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/store/data/api/template_api.dart';
import 'package:snap_fit/features/store/data/repositories/template_repository_impl.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

class MockTemplateApi extends Mock implements TemplateApi {}
class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  test('getTemplates passes userId when available', () async {
    final api = MockTemplateApi();
    final storage = MockTokenStorage();
    final repository = TemplateRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-1');
    when(() => api.getTemplates('user-1'))
        .thenAnswer((_) async => const <PremiumTemplate>[]);

    await repository.getTemplates();

    verify(() => api.getTemplates('user-1')).called(1);
  });

  test('likeTemplate throws when userId missing', () async {
    final api = MockTemplateApi();
    final storage = MockTokenStorage();
    final repository = TemplateRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => '');

    expect(() => repository.likeTemplate(1), throwsException);
  });

  test('createAlbumFromTemplate passes userId and replacements', () async {
    final api = MockTemplateApi();
    final storage = MockTokenStorage();
    final repository = TemplateRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-2');
    when(() => api.createAlbumFromTemplate(2, 'user-2', any()))
        .thenAnswer((_) async => const Album());

    await repository.createAlbumFromTemplate(2, replacements: {'x': 'y'});

    verify(() => api.createAlbumFromTemplate(2, 'user-2', {'x': 'y'})).called(1);
  });
}
