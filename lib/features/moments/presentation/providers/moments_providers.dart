import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../billing/data/billing_provider.dart';
import '../../data/moments_repository.dart';
import '../../data/moment_draft_store.dart';
import '../../domain/moment_draft.dart';
import '../../domain/moment_record.dart';

final momentsRepositoryProvider = Provider<MomentsRepository>((ref) {
  final repository = SupabaseMomentsRepository(
    ref.watch(supabaseClientProvider),
    albums: ref.watch(albumRepositoryProvider),
    billing: ref.watch(billingRepositoryProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final momentsSessionProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(momentsRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.authChanges;
});

final momentsCurrentUserIdProvider = Provider<String?>((ref) {
  ref.watch(momentsSessionProvider);
  return ref.watch(momentsRepositoryProvider).currentUserId;
});

final momentDraftStoreProvider = Provider<MomentDraftStore>(
  (ref) => createMomentDraftStore(),
);

final momentDraftsProvider = FutureProvider.autoDispose<List<MomentDraft>>((
  ref,
) {
  final owner = ref.watch(momentsCurrentUserIdProvider);
  if (owner == null) return const <MomentDraft>[];
  return ref.watch(momentDraftsForOwnerProvider(owner).future);
});

final momentDraftsForOwnerProvider = FutureProvider.autoDispose
    .family<List<MomentDraft>, String>((ref, owner) {
      if (owner.trim().isEmpty) return const <MomentDraft>[];
      return ref.watch(momentDraftStoreProvider).list(owner);
    });

final momentDraftSummariesForOwnerProvider = FutureProvider.autoDispose
    .family<List<MomentDraftSummary>, String>((ref, owner) {
      if (owner.trim().isEmpty) return const <MomentDraftSummary>[];
      return ref.watch(momentDraftStoreProvider).summaries(owner);
    });

final momentsMonthProvider = FutureProvider.autoDispose
    .family<MomentJournal, DateTime?>((ref, month) {
      ref.watch(momentsSessionProvider);
      final owner = ref.watch(momentsCurrentUserIdProvider);
      if (owner == null) {
        throw const MomentException('로그인한 뒤 기록을 다시 열어 주세요.');
      }
      return ref
          .watch(momentsRepositoryProvider)
          .listMonth(month == null ? null : momentMonth(month));
    });
