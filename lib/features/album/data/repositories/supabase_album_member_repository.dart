import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/interceptors/token_storage.dart';
import '../../domain/repositories/album_member_repository.dart';
import '../dto/album_member_response.dart';
import '../dto/response/invite_accept_response.dart';
import '../dto/response/invite_info_response.dart';
import '../dto/response/invite_link_response.dart';

class SupabaseAlbumMemberRepository implements AlbumMemberRepository {
  SupabaseAlbumMemberRepository(this.client, {required this.tokenStorage});

  final SupabaseClient client;
  final TokenStorage tokenStorage;

  Future<String> _userId() async {
    final id = client.auth.currentUser?.id.trim();
    if (id == null || id.isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id;
  }

  int _stableInt(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  @override
  Future<InviteLinkResponse> invite(
    int albumId, {
    String role = 'EDITOR',
  }) async {
    final actor = await _userId();
    final response = await client.functions.invoke(
      'album-invites',
      body: {
        'action': 'create',
        'albumId': albumId,
        'role': role,
        'expectedActorId': actor,
      },
    );
    return InviteLinkResponse.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  Future<InviteInfoResponse> getInviteInfo(String token) async {
    final response = await client.functions.invoke(
      'album-invites',
      body: {'action': 'info', 'token': token},
    );
    return InviteInfoResponse.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  Future<InviteAcceptResponse> acceptInvite(String token) async {
    final actor = await _userId();
    final response = await client.functions.invoke(
      'album-invites',
      body: {'action': 'accept', 'token': token, 'expectedActorId': actor},
    );
    return InviteAcceptResponse.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  Future<List<AlbumMemberResponse>> fetchMembers(int albumId) async {
    final actor = await _userId();
    final rows =
        await client.rpc(
              'album_collaboration',
              params: {
                'p_action': 'members',
                'p_payload': {'albumId': albumId, 'expectedActorId': actor},
              },
            )
            as List;
    return rows
        .map<AlbumMemberResponse>((row) {
          final map = Map<String, dynamic>.from(row);
          final userId = map['userId']?.toString() ?? '';
          return AlbumMemberResponse(
            id: (map['id'] as num?)?.toInt() ?? _stableInt('$albumId:$userId'),
            userId: _stableInt(userId),
            userUuid: userId,
            isOwner: map['isOwner'] == true,
            userName: map['displayName']?.toString(),
            userEmail: null,
            profileImageUrl: null,
            role: map['role']?.toString() ?? 'UNKNOWN',
            status: map['status']?.toString() ?? 'UNKNOWN',
          );
        })
        .toList(growable: false);
  }

  Future<dynamic> _memberAction(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final actor = await _userId();
    return await client.rpc(
      'album_collaboration',
      params: {
        'p_action': action,
        'p_payload': {...payload, 'expectedActorId': actor},
      },
    );
  }

  @override
  Future<void> setMemberRole(int albumId, String userUuid, String role) async {
    if (!['EDITOR', 'VIEWER'].contains(role))
      throw const FormatException('Invalid member role');
    await _memberAction('setMemberRole', {
      'albumId': albumId,
      'userId': userUuid,
      'role': role,
    });
  }

  @override
  Future<void> removeMember(int albumId, String userUuid) async {
    await _memberAction('removeMember', {
      'albumId': albumId,
      'userId': userUuid,
    });
  }

  @override
  Future<void> leave(int albumId) async {
    await _memberAction('leave', {'albumId': albumId});
  }

  @override
  Future<int> revokeInvites(int albumId) async {
    final count = await _memberAction('revokeInvites', {'albumId': albumId});
    if (count is! num || count < 0 || count != count.toInt())
      throw const FormatException('Invalid revoked invitation count');
    return count.toInt();
  }
}
