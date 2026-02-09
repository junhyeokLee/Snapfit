import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import '../dto/request/invite_album_request.dart';
import '../dto/request/accept_invite_request.dart';
import '../dto/response/invite_link_response.dart';
import '../dto/response/invite_info_response.dart';
import '../dto/response/invite_accept_response.dart';

part 'album_member_api.g.dart';

@RestApi()
abstract class AlbumMemberApi {
  factory AlbumMemberApi(Dio dio) = _AlbumMemberApi;

  /// 앨범 초대 링크 생성
  @POST("/api/albums/{albumId}/members/invite")
  Future<InviteLinkResponse> invite(
    @Path('albumId') int albumId,
    @Query('userId') String userId,
    @Body() InviteAlbumRequest request,
  );

  /// 초대 정보 조회 (토큰으로)
  @GET("/api/invites/{token}")
  Future<InviteInfoResponse> getInviteInfo(
    @Path('token') String token,
  );

  /// 초대 수락
  @POST("/api/invites/{token}/accept")
  Future<InviteAcceptResponse> acceptInvite(
    @Path('token') String token,
    @Body() AcceptInviteRequest request,
  );
}
