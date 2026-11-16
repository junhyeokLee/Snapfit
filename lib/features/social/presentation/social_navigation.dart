import 'package:flutter/material.dart';
import '../../../core/navigation/web_app_location.dart';
import '../../../shared/widgets/snapfit_motion.dart';
import 'views/social_profile_screen.dart';
import 'views/social_publish_screen.dart';
import 'views/social_work_detail_screen.dart';
import 'views/social_works_manage_screen.dart';
import '../../album/domain/entities/album.dart';

Future<T?> openSocialWork<T>(
  BuildContext context,
  String id, {
  bool showComments = false,
  int initialPage = 0,
}) => Navigator.push<T>(
  context,
  snapFitRoute<T>(
    settings: WebAppRouteSettings(WebAppLocation(WebAppPage.socialWork, id)),
    page: SocialWorkDetailScreen(
      workId: id,
      showComments: showComments,
      initialPage: initialPage,
    ),
  ),
);

Future<T?> openSocialProfile<T>(BuildContext context, String id) =>
    Navigator.push<T>(
      context,
      snapFitRoute<T>(
        settings: WebAppRouteSettings(
          WebAppLocation(WebAppPage.socialProfile, id),
        ),
        page: SocialProfileScreen(userId: id),
      ),
    );

Future<T?> openSocialPublish<T>(BuildContext context, {Album? album}) =>
    Navigator.push<T>(
      context,
      snapFitRoute<T>(
        settings: WebAppRouteSettings(
          album == null
              ? WebAppLocation.socialPublish
              : WebAppLocation(WebAppPage.socialPublish, '${album.id}'),
        ),
        page: SocialPublishScreen(album: album),
      ),
    );

Future<T?> openSocialManage<T>(BuildContext context) => Navigator.push<T>(
  context,
  snapFitRoute<T>(
    settings: const WebAppRouteSettings(WebAppLocation.socialManage),
    page: const SocialWorksManageScreen(),
  ),
);
