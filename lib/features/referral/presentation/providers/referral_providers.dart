import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/referral_repository.dart';
import '../../domain/referral_status.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  final repository = SupabaseReferralRepository(
    ref.watch(supabaseClientProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
final referralSessionProvider = StreamProvider<String?>((ref) async* {
  final repository = ref.watch(referralRepositoryProvider);
  yield repository.currentUserId;
  yield* repository.authChanges;
});
final referralCurrentUserIdProvider = Provider<String?>((ref) {
  ref.watch(referralSessionProvider);
  return ref.watch(referralRepositoryProvider).currentUserId;
});
final referralStatusProvider = FutureProvider.autoDispose<ReferralStatus>((
  ref,
) {
  ref.watch(referralSessionProvider);
  ref.watch(referralCurrentUserIdProvider);
  return ref.watch(referralRepositoryProvider).fetchStatus();
});
