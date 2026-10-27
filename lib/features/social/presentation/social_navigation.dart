import 'package:flutter/material.dart';
import '../../../core/navigation/web_app_location.dart';
import 'views/social_profile_screen.dart';
import 'views/social_publish_screen.dart';
import 'views/social_work_detail_screen.dart';
import 'views/social_works_manage_screen.dart';
import '../../album/domain/entities/album.dart';

Future<T?> openSocialWork<T>(
  BuildContext context,
  String id, {
  bool showComments = false,
}) => Navigator.push<T>(
  context,
  MaterialPageRoute<T>(
    settings: WebAppRouteSettings(WebAppLocation(WebAppPage.socialWork, id)),
    builder: (_) =>
        SocialWorkDetailScreen(workId: id, showComments: showComments),
  ),
);

Future<T?> openSocialProfile<T>(BuildContext context, String id) =>
    Navigator.push<T>(
      context,
      MaterialPageRoute<T>(
        settings: WebAppRouteSettings(
          WebAppLocation(WebAppPage.socialProfile, id),
        ),
        builder: (_) => SocialProfileScreen(userId: id),
      ),
    );

Future<T?> openSocialPublish<T>(BuildContext context, {Album? album}) =>
    Navigator.push<T>(
      context,
      MaterialPageRoute<T>(
        settings: WebAppRouteSettings(
          album == null
              ? WebAppLocation.socialPublish
              : WebAppLocation(WebAppPage.socialPublish, '${album.id}'),
        ),
        builder: (_) => SocialPublishScreen(album: album),
      ),
    );

Future<T?> openSocialManage<T>(BuildContext context) => Navigator.push<T>(
  context,
  MaterialPageRoute<T>(
    settings: const WebAppRouteSettings(WebAppLocation.socialManage),
    builder: (_) => const SocialWorksManageScreen(),
  ),
);
