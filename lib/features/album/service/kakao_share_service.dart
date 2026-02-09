import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

/// 카카오톡 공유 서비스
class KakaoShareService {
  /// 앱 로고 이미지 URL (실제 서버에 업로드된 이미지 URL 사용 권장)
  /// TODO: 실제 앱 로고 이미지를 서버에 업로드하고 URL로 변경
  /// 현재는 카카오톡 기본 이미지 사용, 추후 앱 로고로 교체 필요
  static const String _appLogoUrl = 'https://developers.kakao.com/assets/img/about/logos/kakaolink/kakaolink_btn_medium.png';
  
  /// 카카오톡으로 초대 링크 공유 (실서비스 스타일)
  /// 
  /// [inviteLink] 초대 링크 URL
  /// [albumTitle] 앨범 제목
  /// [description] 공유 메시지 설명
  static Future<bool> shareInviteLink({
    required String inviteLink,
    required String albumTitle,
    String? description,
  }) async {
    try {
      // 카카오톡이 설치되어 있는지 확인
      final isAvailable = await ShareClient.instance.isKakaoTalkSharingAvailable();
      if (!isAvailable) {
        return false;
      }

      // 실서비스 스타일의 매력적인 메시지 작성
      final shareTitle = '$albumTitle 앨범에 초대했어요! 📸';
      final shareDescription = description ?? 
          '함께 소중한 추억을 담은 앨범을 만들어보세요.\n사진을 추가하고 예쁘게 꾸며보아요! ✨';

      // 카카오톡으로 공유 (FeedTemplate 사용)
      final template = FeedTemplate(
        content: Content(
          title: shareTitle,
          description: shareDescription,
          imageUrl: Uri.parse(_appLogoUrl), // TODO: 실제 앱 로고 이미지 URL로 변경
          link: Link(
            webUrl: Uri.parse(inviteLink),
            mobileWebUrl: Uri.parse(inviteLink),
          ),
        ),
        social: Social(
          likeCount: 0,
          commentCount: 0,
          sharedCount: 0,
        ),
        buttons: [
          Button(
            title: '앨범 참여하기',
            link: Link(
              webUrl: Uri.parse(inviteLink),
              mobileWebUrl: Uri.parse(inviteLink),
            ),
          ),
        ],
      );

      final uri = await ShareClient.instance.shareDefault(template: template);
      await ShareClient.instance.launchKakaoTalk(uri);
      return true;
    } catch (e) {
      // 에러 발생 시 false 반환
      return false;
    }
  }

  /// 시스템 기본 공유 다이얼로그로 공유 (카카오톡이 없을 때 대안)
  static Future<bool> shareViaSystem({
    required String inviteLink,
    required String albumTitle,
  }) async {
    try {
      final uri = Uri.parse('sms:?body=${Uri.encodeComponent('$albumTitle 앨범에 초대되었습니다. $inviteLink')}');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
