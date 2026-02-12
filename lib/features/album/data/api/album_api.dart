import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';

part 'album_api.g.dart';

@RestApi()
abstract class AlbumApi {
  factory AlbumApi(Dio dio) = _AlbumApi;

  /// 앨범 생성
  @POST("/api/albums")
  Future<Album> createAlbum(
      @Body() CreateAlbumRequest request,
      );

  /// 앨범 상세 조회
  @GET('/api/albums/{albumId}')
  Future<Album> fetchAlbum(
      @Path('albumId') String albumId,
      @Query('userId') String userId,
      );

  /// 내 앨범 목록 조회
  @GET("/api/albums")
  Future<List<Album>> fetchMyAlbums(
      @Query('userId') String userId,
      );

  /// 앨범 수정
  @PUT('/api/albums/{albumId}')
  Future<Album> updateAlbum(
    @Path('albumId') int albumId,
    @Body() CreateAlbumRequest request,
    @Query('userId') String userId,
  );

  /// 앨범 삭제
  @DELETE('/api/albums/{albumId}')
  Future<void> deleteAlbum(
    @Path('albumId') int albumId,
    @Query('userId') String userId,
  );

  /// 앨범 순서 변경
  @PATCH('/api/albums/reorder')
  Future<void> reorderAlbums(
    @Body() Map<String, dynamic> body,
    @Query('userId') String userId,
  );
}