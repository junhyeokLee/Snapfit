import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/api/album_provider.dart';
import '../../data/dto/request/create_album_request.dart';
import '../../data/models/album.dart';
// TODO: albumApiProvider 가 선언된 파일을 올바른 경로로 import 하세요.
// 예) import '../../data/api/album_api_provider.dart';

part 'album_view_model.g.dart';

@riverpod
class AlbumViewModel extends _$AlbumViewModel {
  @override
  FutureOr<Album?> build() {
    return null;
  }

  Future<void> createAlbum({
    required String coverLayersJson,
    required double coverRatio,
  }) async {
    state = const AsyncLoading();

    try {
      final api = ref.read(albumApiProvider);

      final album = await api.createAlbum(
        CreateAlbumRequest(
          coverLayersJson: coverLayersJson,
          coverRatio: coverRatio,
        ),
      );

      state = AsyncData(album);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}