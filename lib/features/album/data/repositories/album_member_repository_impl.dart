import '../../domain/repositories/album_member_repository.dart';
import '../api/album_member_api.dart';
import '../dto/album_member_response.dart';
import '../dto/request/accept_invite_request.dart';
import '../dto/request/invite_album_request.dart';
import '../dto/response/invite_accept_response.dart';
import '../dto/response/invite_info_response.dart';
import '../dto/response/invite_link_response.dart';

import '../../../../core/interceptors/token_storage.dart';

class AlbumMemberRepositoryImpl implements AlbumMemberRepository {
  final AlbumMemberApi api;
  final TokenStorage tokenStorage;

  AlbumMemberRepositoryImpl(this.api, {required this.tokenStorage});

  Future<String> _getUserId() async {
    final id = await tokenStorage.getUserId();
    if (id == null || id.isEmpty) {
      return '';
    }
    return id;
  }

  @override
  Future<InviteLinkResponse> invite(
    int albumId, {
    String role = 'EDITOR',
  }) async {
    final userId = await _getUserId();
    return api.invite(albumId, userId, InviteAlbumRequest(role: role));
  }

  @override
  Future<InviteInfoResponse> getInviteInfo(String token) async {
    return api.getInviteInfo(token);
  }

  @override
  Future<InviteAcceptResponse> acceptInvite(String token) async {
    final userId = await _getUserId();
    return api.acceptInvite(token, AcceptInviteRequest(userId: userId));
  }

  @override
  Future<List<AlbumMemberResponse>> fetchMembers(int albumId) async {
    final userId = await _getUserId();
    return api.fetchMembers(albumId, userId);
  }
}
