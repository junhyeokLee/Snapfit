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
    final id = await tokenStorage.getResolvedUserId();
    if (id == null || id.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }
    return id.trim();
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
    await _userId();
    final response = await client.functions.invoke(
      'album-invites',
      body: {'action': 'create', 'albumId': albumId, 'role': role},
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
    await _userId();
    final response = await client.functions.invoke(
      'album-invites',
      body: {'action': 'accept', 'token': token},
    );
    return InviteAcceptResponse.fromJson(
      (response.data as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  @override
  Future<List<AlbumMemberResponse>> fetchMembers(int albumId) async {
    await _userId();
    final rows = await client
        .from('album_members')
        .select('id,user_id,role,status')
        .eq('album_id', albumId)
        .order('created_at');
    return rows
        .map<AlbumMemberResponse>((row) {
          final map = Map<String, dynamic>.from(row);
          final userId = map['user_id']?.toString() ?? '';
          return AlbumMemberResponse(
            id: (map['id'] as num?)?.toInt() ?? _stableInt('$albumId:$userId'),
            userId: _stableInt(userId),
            userName: null,
            userEmail: null,
            profileImageUrl: null,
            role: map['role']?.toString() ?? 'EDITOR',
            status: map['status']?.toString() ?? 'ACCEPTED',
          );
        })
        .toList(growable: false);
  }
}
