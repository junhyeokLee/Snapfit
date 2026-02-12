// lib/features/album/presentation/viewmodels/album_view_model.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api/album_provider.dart';
import '../../data/dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';

part 'album_view_model.g.dart';

@Riverpod(keepAlive: true)
class AlbumViewModel extends _$AlbumViewModel {
  @override
  FutureOr<Album?> build() {
    return null;
  }

  Future<void> createAlbum({
    required String coverLayersJson,
    required String ratio,
    String title = '', // 앨범 제목
    required String coverImageUrl,
    required String coverThumbnailUrl,
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    String coverTheme = '',
  }) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(albumRepositoryProvider);
      final album = await repository.createAlbum(
        CreateAlbumRequest(
          ratio: ratio,
          title: title, // 앨범 제목 전달
          coverLayersJson: coverLayersJson,
          coverImageUrl: coverImageUrl,
          coverThumbnailUrl: coverThumbnailUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverPreviewUrl: coverPreviewUrl,
          coverTheme: coverTheme,
        ),
      );
      state = AsyncData(album);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateAlbum({
    required int albumId,
    required String coverLayersJson,
    required String ratio,
    String title = '', // 앨범 제목
    required String coverImageUrl,
    required String coverThumbnailUrl,
    String? coverOriginalUrl,
    String? coverPreviewUrl,
    String coverTheme = '',
  }) async {
    state = const AsyncLoading();

    try {
      final repository = ref.read(albumRepositoryProvider);
      final album = await repository.updateAlbum(
        albumId,
        CreateAlbumRequest(
          ratio: ratio,
          title: title, // 앨범 제목 전달
          coverLayersJson: coverLayersJson,
          coverImageUrl: coverImageUrl,
          coverThumbnailUrl: coverThumbnailUrl,
          coverOriginalUrl: coverOriginalUrl,
          coverPreviewUrl: coverPreviewUrl,
          coverTheme: coverTheme,
        ),
      );
      state = AsyncData(album);
    } on DioException catch (e, st) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 405) {
        state = AsyncError(
          Exception('서버에서 앨범 수정을 지원하지 않습니다. (PUT /api/albums/{id} 필요)'),
          st,
        );
      } else if (statusCode == 500) {
        state = AsyncError(
          Exception('서버 오류가 발생했습니다. 백엔드 로그를 확인해주세요.'),
          st,
        );
      } else {
        state = AsyncError(e, st);
      }
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}