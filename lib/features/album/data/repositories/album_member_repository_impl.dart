import '../../domain/repositories/album_member_repository.dart';
import '../api/album_member_api.dart';
import '../dto/request/accept_invite_request.dart';
import '../dto/request/invite_album_request.dart';
import '../dto/response/invite_accept_response.dart';
import '../dto/response/invite_info_response.dart';
import '../dto/response/invite_link_response.dart';
import '../../../../core/user/user_id_service.dart';

class AlbumMemberRepositoryImpl implements AlbumMemberRepository {
  final AlbumMemberApi api;
  final UserIdService userIdService;

  AlbumMemberRepositoryImpl(
    this.api, {
    required this.userIdService,
  });

  @override
  Future<InviteLinkResponse> invite(int albumId, {String role = 'EDITOR'}) async {
    final userId = await userIdService.getOrCreate();
    return api.invite(
      albumId,
      userId,
      InviteAlbumRequest(role: role),
    );
  }

  @override
  Future<InviteInfoResponse> getInviteInfo(String token) async {
    return api.getInviteInfo(token);
  }

  @override
  Future<InviteAcceptResponse> acceptInvite(String token) async {
    final userId = await userIdService.getOrCreate();
    return api.acceptInvite(token, AcceptInviteRequest(userId: userId));
  }
}
