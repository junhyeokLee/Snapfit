import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/data/api/album_member_api.dart';
import 'package:snap_fit/features/album/data/dto/request/accept_invite_request.dart';
import 'package:snap_fit/features/album/data/dto/request/invite_album_request.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_accept_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_info_response.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/data/repositories/album_member_repository_impl.dart';

class MockAlbumMemberApi extends Mock implements AlbumMemberApi {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(const InviteAlbumRequest(role: 'EDITOR'));
    registerFallbackValue(const AcceptInviteRequest(userId: ''));
  });

  test('invite uses userId from token storage', () async {
    final api = MockAlbumMemberApi();
    final storage = MockTokenStorage();
    final repository = AlbumMemberRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-1');
    when(() => api.invite(1, 'user-1', any())).thenAnswer(
      (_) async =>
          const InviteLinkResponse(albumId: 1, token: 't', link: 'link'),
    );

    final response = await repository.invite(1, role: 'VIEWER');

    expect(response.link, 'link');
    verify(() => api.invite(1, 'user-1', any())).called(1);
  });

  test('getInviteInfo delegates to api', () async {
    final api = MockAlbumMemberApi();
    final storage = MockTokenStorage();
    final repository = AlbumMemberRepositoryImpl(api, tokenStorage: storage);

    when(() => api.getInviteInfo('token')).thenAnswer(
      (_) async => const InviteInfoResponse(
        albumId: 1,
        albumTitle: 'Title',
        inviterName: 'Owner',
        role: 'EDITOR',
      ),
    );

    final response = await repository.getInviteInfo('token');

    expect(response.albumId, 1);
    verify(() => api.getInviteInfo('token')).called(1);
  });

  test('acceptInvite uses userId from token storage', () async {
    final api = MockAlbumMemberApi();
    final storage = MockTokenStorage();
    final repository = AlbumMemberRepositoryImpl(api, tokenStorage: storage);

    when(() => storage.getUserId()).thenAnswer((_) async => 'user-2');
    when(() => api.acceptInvite('token', any())).thenAnswer(
      (_) async =>
          const InviteAcceptResponse(albumId: 2, role: 'EDITOR', success: true),
    );

    final response = await repository.acceptInvite('token');

    expect(response.albumId, 2);
    verify(() => api.acceptInvite('token', any())).called(1);
  });
}
