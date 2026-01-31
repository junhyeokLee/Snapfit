import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/user/user_id_service.dart';
import '../../domain/repositories/album_repository.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../service/album_editor_service.dart';
import '../repositories/album_repository_impl.dart';
import '../repositories/gallery_repository_impl.dart';
import 'album_api.dart';
import 'storage_service.dart';

final albumApiProvider = Provider<AlbumApi>((ref) {
  final dio = ref.read(dioProvider);
  return AlbumApi(dio);
});

final userIdServiceProvider = Provider<UserIdService>((ref) {
  return UserIdService();
});

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  final api = ref.read(albumApiProvider);
  final userIdService = ref.read(userIdServiceProvider);
  return AlbumRepositoryImpl(api, userIdService: userIdService);
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