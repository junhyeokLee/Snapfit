import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import '../../../social/data/social_repository.dart';

import '../../../social/domain/social_models.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../domain/order_visibility_owner.dart';

/// Identity, rather than an account id alone, fences an A → B → A return.
class SafetyManagementSession {
  const SafetyManagementSession(this.ownerId, {this.authSession});
  final String? ownerId;
  final Session? authSession;
}

bool safetySessionMatchesSdk(
  SafetyManagementSession session,
  SocialRepository repository,
) =>
    session.ownerId != null &&
    repository.client.auth.currentUser?.id == session.ownerId &&
    identical(repository.client.auth.currentSession, session.authSession);

final safetyManagementSessionProvider = Provider<SafetyManagementSession>((
  ref,
) {
  ref.watch(socialAuthStateProvider);
  final actor = ref.watch(socialCurrentUserIdProvider);
  final account = ref.watch(visibleOrderOwnerProvider);
  final sdk = ref.watch(socialRepositoryProvider).client.auth;
  return SafetyManagementSession(
    actor != null && actor == account && sdk.currentUser?.id == actor
        ? actor
        : null,
    authSession: sdk.currentSession,
  );
});

final safetyBlockedProfilesProvider = FutureProvider.autoDispose
    .family<List<SocialProfile>, String>((ref, owner) async {
      final session = ref.watch(safetyManagementSessionProvider);
      if (session.ownerId != owner ||
          !safetySessionMatchesSdk(session, ref.read(socialRepositoryProvider)))
        return const [];
      final profiles = await ref
          .read(socialRepositoryProvider)
          .fetchBlockedProfiles()
          .timeout(const Duration(seconds: 12));
      if (!ref.mounted ||
          !identical(ref.read(safetyManagementSessionProvider), session) ||
          !safetySessionMatchesSdk(
            session,
            ref.read(socialRepositoryProvider),
          )) {
        return const [];
      }
      return profiles;
    });

final safetyOwnReportsProvider = FutureProvider.autoDispose
    .family<SocialReportsPage, SocialPageQuery>((ref, query) async {
      final session = ref.watch(safetyManagementSessionProvider);
      if (session.ownerId == null ||
          session.ownerId != query.ownerId ||
          !safetySessionMatchesSdk(
            session,
            ref.read(socialRepositoryProvider),
          )) {
        return const SocialReportsPage(
          items: [],
          hasMore: false,
          nextOffset: 0,
        );
      }
      final page = await ref
          .read(socialRepositoryProvider)
          .fetchOwnReportsPage(offset: query.offset, limit: query.limit)
          .timeout(const Duration(seconds: 12));
      if (!ref.mounted ||
          !identical(ref.read(safetyManagementSessionProvider), session) ||
          !safetySessionMatchesSdk(
            session,
            ref.read(socialRepositoryProvider),
          )) {
        return const SocialReportsPage(
          items: [],
          hasMore: false,
          nextOffset: 0,
        );
      }
      return page;
    });

/// A completed domain mutation outlives its page, but never its SDK session.
void invalidateSafetyManagementDomain(
  ProviderContainer container,
  SafetyManagementSession session,
) {
  try {
    if (!identical(container.read(safetyManagementSessionProvider), session) ||
        !safetySessionMatchesSdk(
          session,
          container.read(socialRepositoryProvider),
        ))
      return;
    container.invalidate(safetyBlockedProfilesProvider(session.ownerId!));
    container.invalidate(socialBlockedProfilesProvider);
    container.invalidate(socialFeedProvider);
    container.invalidate(socialOwnWorksProvider);
    container.invalidate(socialOwnWorksPageProvider);
    container.invalidate(socialSavedWorksProvider);
    container.invalidate(socialSavedWorksPageProvider);
    container.invalidate(socialProfileWorksProvider);
    container.invalidate(socialProfileWorksPageProvider);
    container.invalidate(socialProfileMomentsPageProvider);
    container.invalidate(socialProfileMomentMonthsPageProvider);
    container.invalidate(socialMomentMonthPageProvider);
    container.invalidate(socialProfileProvider);
    container.invalidate(ownSocialProfileProvider);
    container.invalidate(socialRelationsProvider);
    container.invalidate(socialRelationsPageProvider);
  } on StateError {
    // Riverpod's public API throws on reads after container disposal.
  }
}
