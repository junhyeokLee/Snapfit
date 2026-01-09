import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../dto/request/create_album_request.dart';
import '../../domain/entities/album.dart';

part 'album_api.g.dart';

@RestApi()
abstract class AlbumApi {
  factory AlbumApi(Dio dio) = _AlbumApi;

  /// 앨범 생성
  @POST('/albums')
  Future<Album> createAlbum(
      @Body() CreateAlbumRequest request,
      );

  /// 앨범 상세 조회
  @GET('/albums/{albumId}')
  Future<Album> fetchAlbum(
      @Path('albumId') String albumId,
      );
}