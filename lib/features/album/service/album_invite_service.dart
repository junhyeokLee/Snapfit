import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api/album_provider.dart';
import 'kakao_share_service.dart';

typedef KakaoInviteShare =
    Future<bool> Function({
      required String inviteLink,
      required String albumTitle,
      String? description,
    });

final kakaoInviteShareProvider = Provider<KakaoInviteShare>(
  (_) => KakaoShareService.shareInviteLink,
);

/// 앨범 초대 서비스
/// 앨범 생성 후 초대 링크를 생성하고 공유하는 기능 제공
class AlbumInviteService {
  static void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String normalizeInviteLink(String raw) {
    final link = raw.trim();
    final uri = Uri.tryParse(link);
    final isWeb = KakaoShareService.parseShareableInviteUri(link) != null;
    final isAppInvite =
        uri?.scheme.toLowerCase() == 'snapfit' &&
        uri?.host.toLowerCase() == 'invite' &&
        (uri?.queryParameters['token']?.trim().isNotEmpty ?? false);
    if (!isWeb && !isAppInvite) {
      throw const FormatException('Invalid album invite link');
    }
    return link;
  }

  static String inviteErrorMessage(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('forbidden')) {
      return '앨범 소유자만 멤버를 초대할 수 있어요.';
    }
    if (text.contains('unauthorized') ||
        text.contains('jwt') ||
        text.contains('auth') ||
        text.contains('permission')) {
      return '로그인이 만료되었어요. 다시 로그인한 뒤 초대 링크를 만들어주세요.';
    }
    if (text.contains('socket') ||
        text.contains('timeout') ||
        text.contains('network') ||
        text.contains('host lookup')) {
      return '연결이 불안정해요. 네트워크 상태를 확인한 뒤 다시 시도해주세요.';
    }
    return '초대 링크를 만들지 못했어요. 잠시 후 다시 시도해주세요.';
  }

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
    String? inviteLink,
    required BuildContext context,
  }) async {
    if (!context.mounted) return false;
    final share = ref.read(kakaoInviteShareProvider);
    try {
      var resolvedInviteLink = inviteLink;
      if (resolvedInviteLink == null || resolvedInviteLink.isEmpty) {
        final memberRepository = ref.read(albumMemberRepositoryProvider);
        final inviteResponse = await memberRepository.invite(
          albumId,
          role: allowEditing ? 'EDITOR' : 'VIEWER',
        );
        if (inviteResponse.albumId != albumId) {
          throw const FormatException('Invite album mismatch');
        }
        resolvedInviteLink = inviteResponse.link;
      }
      resolvedInviteLink = normalizeInviteLink(resolvedInviteLink);
      if (!context.mounted) return false;

      var success = false;
      try {
        success = await share(
          inviteLink: resolvedInviteLink,
          albumTitle: albumTitle,
          description: allowEditing
              ? '사진과 문구를 함께 편집하며 우리의 앨범을 완성해요.'
              : '소중한 순간을 담은 앨범을 함께 감상해요.',
        );
      } catch (_) {
        success = false;
      }

      if (!success) {
        if (context.mounted) {
          try {
            await Clipboard.setData(ClipboardData(text: resolvedInviteLink));
          } catch (_) {
            if (!context.mounted) return false;
            _showMessage(context, '공유와 복사를 완료하지 못했어요. 다시 시도해주세요.');
            return false;
          }
          if (!context.mounted) return false;
          _showMessage(context, '카카오톡 공유를 열지 못해 초대 링크를 복사했어요.');
        }
      }

      return success;
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, inviteErrorMessage(e));
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
    if (!context.mounted) return null;
    try {
      final memberRepository = ref.read(albumMemberRepositoryProvider);

      // 초대 링크 생성
      final inviteResponse = await memberRepository.invite(
        albumId,
        role: allowEditing ? 'EDITOR' : 'VIEWER',
      );
      if (inviteResponse.albumId != albumId) {
        throw const FormatException('Invite album mismatch');
      }

      final link = normalizeInviteLink(inviteResponse.link);
      if (!context.mounted) return null;
      await Clipboard.setData(ClipboardData(text: link));

      if (context.mounted) {
        _showMessage(context, '초대 링크가 클립보드에 복사되었습니다.');
      }

      return link;
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, inviteErrorMessage(e));
      }
      return null;
    }
  }
}
