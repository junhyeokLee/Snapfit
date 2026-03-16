import 'package:flutter_riverpod/flutter_riverpod.dart';

// Album member repository provider
import '../../../../core/network/dio_provider.dart';
import '../../service/album_persistence_service.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/repositories/album_repository.dart';
import '../../domain/repositories/album_member_repository.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../service/album_editor_service.dart';
import '../repositories/album_repository_impl.dart';
import '../repositories/album_member_repository_impl.dart';
import '../repositories/gallery_repository_impl.dart';
import 'album_api.dart';
import 'album_member_api.dart';
import 'storage_service.dart';

final albumApiProvider = Provider<AlbumApi>((ref) {
  final dio = ref.read(dioProvider);
  return AlbumApi(dio);
});

final albumMemberApiProvider = Provider<AlbumMemberApi>((ref) {
  final dio = ref.read(dioProvider);
  return AlbumMemberApi(dio);
});

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  final api = ref.read(albumApiProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  return AlbumRepositoryImpl(api, tokenStorage: tokenStorage);
});

/// 앨범 멤버 리포지토리 Provider
final albumMemberRepositoryProvider = Provider<AlbumMemberRepository>((ref) {
  final api = ref.read(albumMemberApiProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  return AlbumMemberRepositoryImpl(api, tokenStorage: tokenStorage);
});

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepositoryImpl();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final albumEditorServiceProvider = Provider<AlbumEditorService>((ref) {
  return const AlbumEditorService();
});

final albumPersistenceServiceProvider = Provider<AlbumPersistenceService>((
  ref,
) {
  final storage = ref.read(storageServiceProvider);
  final repository = ref.read(albumRepositoryProvider);
  return AlbumPersistenceService(storage, repository);
});
