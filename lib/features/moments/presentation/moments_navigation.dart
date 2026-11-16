import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/navigation/web_app_location.dart';
import '../../../shared/widgets/snapfit_motion.dart';
import '../../album/presentation/viewmodels/home_view_model.dart';
import '../../album/presentation/widgets/home/home_album_actions.dart';
import '../domain/moment_record.dart';
import 'providers/moments_providers.dart';
import 'views/moment_compose_screen.dart';
import 'views/moment_saved_preview_screen.dart';
import 'views/moments_screen.dart';
import 'views/moment_reminder_settings_screen.dart';

final _activeMomentWrites = Expando<Object>('active direct moment writer');

/// Starts writing immediately while preserving the journal's existing draft
/// recovery and saved-record appreciation flow. No month lookup delays writing.
Future<void> openMomentCompose(
  BuildContext context,
  WidgetRef ref, {
  String? draftRecordId,
}) async {
  if (!context.mounted ||
      ModalRoute.of(context)?.isCurrent == false ||
      _activeMomentWrites[context] != null)
    return;
  final repository = ref.read(momentsRepositoryProvider);
  final owner = repository.currentUserId;
  if (owner == null) return;
  final operation = Object();
  _activeMomentWrites[context] = operation;
  var sessionChanged = false;
  void invalidateSession() {
    sessionChanged = true;
    if (identical(_activeMomentWrites[context], operation))
      _activeMomentWrites[context] = null;
  }

  // Observe every auth event, including A -> B -> A between widget rebuilds.
  final auth = repository.authChanges.listen((next) {
    if (next != owner) invalidateSession();
  }, onError: (Object _, StackTrace __) => invalidateSession());
  bool current() =>
      context.mounted && !sessionChanged && repository.currentUserId == owner;
  var editing = draftRecordId != null;
  try {
    if (draftRecordId != null) {
      try {
        final summaries = await ref
            .read(momentDraftStoreProvider)
            .summaries(owner);
        for (final draft in summaries) {
          if (draft.recordId == draftRecordId) editing = draft.isEditing;
        }
      } catch (_) {
        // The composer owns recovery errors; an unknown draft is conservatively
        // treated as an edit so it cannot receive a new-record reward screen.
      }
    }
    if (!current() || ModalRoute.of(context)?.isCurrent == false) return;
    final result = await Navigator.of(context).push<Object?>(
      snapFitRoute(
        settings: const WebAppRouteSettings(WebAppLocation.moments),
        page: MomentComposeScreen(draftRecordId: draftRecordId),
      ),
    );
    if (!current()) return;
    ref.invalidate(momentDraftsProvider);
    ref.invalidate(momentDraftsForOwnerProvider(owner));
    ref.invalidate(momentDraftSummariesForOwnerProvider(owner));
    ref.invalidate(momentsMonthProvider);
    if (result is! MomentRecord ||
        editing ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    await showMomentSavedPreview(
      context,
      record: result,
      hasCompleteJournal: false,
      journal: MomentJournal(
        today: momentToday(),
        weekStart: momentWeekStart(momentToday()),
        month: momentMonth(result.recordDate),
        records: [result],
        weekPhotoCount: result.photos.length,
      ),
      onAlbumCreated: (album) async {
        if (!current() || album.userId != owner) return;
        ref.invalidate(homeViewModelProvider);
        await HomeAlbumActions.onEditSelected(
          context,
          ref,
          album,
          startAtFirstIncompletePage: true,
        );
      },
    );
  } finally {
    if (identical(_activeMomentWrites[context], operation))
      _activeMomentWrites[context] = null;
    await auth.cancel();
  }
}

Future<void> openMoments(
  BuildContext context, {
  String? draftRecordId,
  DateTime? initialMonth,
  DateTime? initialDate,
}) => Navigator.of(context).push<void>(
  snapFitRoute(
    settings: const WebAppRouteSettings(WebAppLocation.moments),
    page: MomentsDestination(
      initialDraftRecordId: draftRecordId,
      initialMonth: initialMonth,
      initialDate: initialDate,
    ),
  ),
);

class MomentsDestination extends ConsumerWidget {
  const MomentsDestination({
    super.key,
    this.initialDraftRecordId,
    this.initialMonth,
    this.initialDate,
  });
  final String? initialDraftRecordId;
  final DateTime? initialMonth, initialDate;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MomentsScreen(
    initialDraftRecordId: initialDraftRecordId,
    initialMonth: initialMonth,
    initialDate: initialDate,
    onReminderSettings: () => Navigator.of(
      context,
    ).push<void>(snapFitRoute(page: const MomentReminderSettingsScreen())),
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
