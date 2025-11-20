// lib/features/album/data/api/album_api.dart
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../models/album_dto.dart';

/// 앨범 관련 API 호출 전담
class AlbumApi {
  final DioClient _client;

  AlbumApi(this._client);

  /// 앨범 상세 조회
  Future<AlbumDto> fetchAlbum(String albumId) async {
    final Response res = await _client.get('/albums/$albumId');
    return AlbumDto.fromJson(res.data as Map<String, dynamic>);
  }

  /// 앨범 저장/업데이트
  Future<void> saveAlbum(AlbumDto dto) async {
    await _client.post(
      '/albums/${dto.id}',
      data: dto.toJson(),
    );
  }
}