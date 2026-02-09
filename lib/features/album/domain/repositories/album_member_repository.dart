import '../../data/dto/response/invite_accept_response.dart';
import '../../data/dto/response/invite_info_response.dart';
import '../../data/dto/response/invite_link_response.dart';

abstract class AlbumMemberRepository {
  Future<InviteLinkResponse> invite(int albumId, {String role = 'EDITOR'});
  Future<InviteInfoResponse> getInviteInfo(String token);
  Future<InviteAcceptResponse> acceptInvite(String token);
}
