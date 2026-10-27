import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/web_app_location.dart';
import '../../album/presentation/viewmodels/home_view_model.dart';
import '../../album/presentation/widgets/home/home_album_actions.dart';
import 'providers/moments_providers.dart';
import 'views/moments_screen.dart';
import 'views/moment_reminder_settings_screen.dart';

Future<void> openMoments(BuildContext context, {String? draftRecordId}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const WebAppRouteSettings(WebAppLocation.moments),
        builder: (_) => MomentsDestination(initialDraftRecordId: draftRecordId),
      ),
    );

class MomentsDestination extends ConsumerWidget {
  const MomentsDestination({super.key, this.initialDraftRecordId});
  final String? initialDraftRecordId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MomentsScreen(
    initialDraftRecordId: initialDraftRecordId,
    onReminderSettings: () => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const MomentReminderSettingsScreen()),
    ),
    onAlbumCreated: (album) async {
      final actor = ref.read(momentsCurrentUserIdProvider);
      ref.invalidate(homeViewModelProvider);
      if (!context.mounted || actor == null || album.userId != actor) return;
      await HomeAlbumActions.onEditSelected(
        context,
        ref,
        album,
        startAtFirstIncompletePage: true,
      );
    },
  );
}
