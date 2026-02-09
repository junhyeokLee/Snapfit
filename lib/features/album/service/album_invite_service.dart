import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api/album_provider.dart';
import 'kakao_share_service.dart';

/// 앨범 초대 서비스
/// 앨범 생성 후 초대 링크를 생성하고 공유하는 기능 제공
class AlbumInviteService {
  /// 초대 링크 생성 및 카카오톡 공유
  /// 
  /// [ref] WidgetRef (Provider 접근용)
  /// [albumId] 앨범 ID
  /// [albumTitle] 앨범 제목
  /// [allowEditing] 편집 권한 허용 여부
  /// [context] BuildContext (스낵바 표시용)
  static Future<bool> inviteViaKakaoTalk({
    required WidgetRef ref,
    required int albumId,
    required String albumTitle,
    required bool allowEditing,
    required BuildContext context,
  }) async {
    try {
      final memberRepository = ref.read(albumMemberRepositoryProvider);
      
      // 초대 링크 생성
      final inviteResponse = await memberRepository.invite(
        albumId,
        role: allowEditing ? 'EDITOR' : 'VIEWER',
      );

      // 카카오톡으로 공유 (실서비스 스타일 메시지)
      final success = await KakaoShareService.shareInviteLink(
        inviteLink: inviteResponse.link,
        albumTitle: albumTitle,
        description: '함께 소중한 추억을 담은 앨범을 만들어보세요.\n사진을 추가하고 예쁘게 꾸며보아요! ✨',
      );

      if (!success) {
        // 카카오톡이 설치되어 있지 않으면 링크 복사 안내
        if (context.mounted) {
          await Clipboard.setData(ClipboardData(text: inviteResponse.link));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('카카오톡이 설치되어 있지 않습니다. 초대 링크가 클립보드에 복사되었습니다.'),
            ),
          );
        }
      }

      return success;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 링크 생성 실패: $e')),
        );
      }
      return false;
    }
  }

  /// 초대 링크 생성 및 복사
  /// 
  /// [ref] WidgetRef (Provider 접근용)
  /// [albumId] 앨범 ID
  /// [allowEditing] 편집 권한 허용 여부
  /// [context] BuildContext (스낵바 표시용)
  static Future<String?> copyInviteLink({
    required WidgetRef ref,
    required int albumId,
    required bool allowEditing,
    required BuildContext context,
  }) async {
    try {
      final memberRepository = ref.read(albumMemberRepositoryProvider);
      
      // 초대 링크 생성
      final inviteResponse = await memberRepository.invite(
        albumId,
        role: allowEditing ? 'EDITOR' : 'VIEWER',
      );

      // 클립보드에 복사
      await Clipboard.setData(ClipboardData(text: inviteResponse.link));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대 링크가 클립보드에 복사되었습니다.')),
        );
      }

      return inviteResponse.link;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('초대 링크 생성 실패: $e')),
        );
      }
      return null;
    }
  }
}
