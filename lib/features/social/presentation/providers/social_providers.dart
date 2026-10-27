import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

final socialAuthStateProvider = StreamProvider<String?>((ref) async* {
  final client = ref.watch(supabaseClientProvider);
  yield client.auth.currentUser?.id;
  yield* client.auth.onAuthStateChange.map((event) => event.session?.user.id);
});

final socialCurrentUserIdProvider = Provider<String?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  ref.watch(socialAuthStateProvider);
  return client.auth.currentUser?.id;
});

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(supabaseClientProvider)),
);

final socialFeedProvider = FutureProvider.autoDispose
    .family<SocialWorkPage, SocialFeedQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchFeed(
            following: query.following,
            topic: query.topic,
            offset: query.offset,
            limit: query.limit,
          );
    });
final socialProfileProvider = FutureProvider.autoDispose
    .family<SocialProfile?, String>((ref, userId) {
      ref.watch(socialAuthStateProvider);
      return ref.read(socialRepositoryProvider).fetchProfile(userId);
    });
final ownSocialProfileProvider = FutureProvider.autoDispose<SocialProfile?>((
  ref,
) {
  ref.watch(socialAuthStateProvider);
  if (ref.watch(socialCurrentUserIdProvider) == null) return null;
  return ref.read(socialRepositoryProvider).ensureOwnProfile();
});
final socialProfileWorksProvider = FutureProvider.autoDispose
    .family<List<SocialWork>, String>((ref, userId) {
      ref.watch(socialAuthStateProvider);
      return ref.read(socialRepositoryProvider).fetchProfileWorks(userId);
    });
final socialRelationsProvider = FutureProvider.autoDispose
    .family<List<SocialProfile>, SocialRelationsQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchRelations(query.userId, followers: query.followers);
    });
final socialWorkProvider = FutureProvider.autoDispose
    .family<SocialWork?, String>((ref, id) {
      ref.watch(socialAuthStateProvider);
      return ref.read(socialRepositoryProvider).fetchWork(id);
    });
final socialOwnWorksProvider = FutureProvider.autoDispose<List<SocialWork>>((
  ref,
) {
  ref.watch(socialAuthStateProvider);
  return ref.read(socialRepositoryProvider).fetchOwnWorks();
});
final socialSavedWorksProvider = FutureProvider.autoDispose<List<SocialWork>>((
  ref,
) {
  ref.watch(socialAuthStateProvider);
  return ref.read(socialRepositoryProvider).fetchSavedWorks();
});
final socialCommentsProvider = FutureProvider.autoDispose
    .family<List<SocialComment>, String>((ref, id) {
      ref.watch(socialAuthStateProvider);
      return ref.read(socialRepositoryProvider).fetchComments(id);
    });
final socialBlockedProfilesProvider =
    FutureProvider.autoDispose<List<SocialProfile>>((ref) {
      ref.watch(socialAuthStateProvider);
      return ref.read(socialRepositoryProvider).fetchBlockedProfiles();
    });

final socialOwnWorksPageProvider = FutureProvider.autoDispose
    .family<SocialWorkPage, SocialOwnWorksQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchOwnWorksPage(
            status: query.status,
            offset: query.offset,
            limit: query.limit,
          );
    });
final socialSavedWorksPageProvider = FutureProvider.autoDispose
    .family<SocialWorkPage, SocialPageQuery>((ref, query) async {
      ref.watch(socialAuthStateProvider);
      final owner = ref.watch(socialCurrentUserIdProvider);
      if (owner == null || (query.ownerId != null && query.ownerId != owner)) {
        return const SocialWorkPage(items: [], hasMore: false, nextOffset: 0);
      }
      final result = await ref
          .read(socialRepositoryProvider)
          .fetchSavedWorksPage(offset: query.offset, limit: query.limit);
      if (!ref.mounted || ref.read(socialCurrentUserIdProvider) != owner) {
        return const SocialWorkPage(items: [], hasMore: false, nextOffset: 0);
      }
      return result;
    });
final socialProfileWorksPageProvider = FutureProvider.autoDispose
    .family<SocialWorkPage, SocialProfileWorksQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchProfileWorksPage(
            query.userId,
            offset: query.offset,
            limit: query.limit,
          );
    });
final socialRelationsPageProvider = FutureProvider.autoDispose
    .family<SocialProfilePage, SocialRelationsQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchRelationsPage(
            query.userId,
            followers: query.followers,
            offset: query.offset,
            limit: query.limit,
          );
    });
final socialCommentsPageProvider = FutureProvider.autoDispose
    .family<SocialCommentPage, SocialCommentsQuery>((ref, query) {
      ref.watch(socialAuthStateProvider);
      return ref
          .read(socialRepositoryProvider)
          .fetchCommentsPage(
            query.workId,
            offset: query.offset,
            limit: query.limit,
          );
    });
