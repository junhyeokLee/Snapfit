import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../data/private_moment_archive_repository.dart';
import '../../domain/moment_record.dart';
import '../../domain/private_moment_archive.dart';
import 'moments_providers.dart';

export '../../domain/private_moment_archive.dart';
export '../../data/private_moment_archive_repository.dart';

final privateMomentArchiveRepositoryProvider =
    Provider<PrivateMomentArchiveRepository>((ref) {
      final repository = SupabasePrivateMomentArchiveRepository(
        ref.watch(supabaseClientProvider),
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final privateMomentArchiveSessionProvider = StreamProvider<int>((ref) {
  final repository = ref.watch(privateMomentArchiveRepositoryProvider);
  // Subscribe before queuing the initial value. An async* initial yield can
  // otherwise lose a rapid A → B → A transition on the broadcast stream.
  final events = StreamController<int>();
  final subscription = repository.sessionChanges.listen(
    events.add,
    onError: events.addError,
  );
  events.add(repository.sessionRevision);
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(events.close());
  });
  return events.stream;
});

void _checkOwner(Ref ref, String owner) {
  ref.watch(privateMomentArchiveSessionProvider);
  ref.watch(momentsSessionProvider);
  if (ref.watch(momentsCurrentUserIdProvider) != owner ||
      ref.watch(privateMomentArchiveRepositoryProvider).currentUserId !=
          owner) {
    throw const MomentException('현재 계정의 기록에서 다시 열어 주세요.');
  }
}

final privateMomentMonthsProvider = FutureProvider.autoDispose
    .family<List<MomentMonthSummary>, PrivateMomentMonthsQuery>((ref, query) {
      _checkOwner(ref, query.ownerId);
      return ref
          .watch(privateMomentArchiveRepositoryProvider)
          .listMonths(
            ownerId: query.ownerId,
            beforeMonth: query.beforeMonth,
            limit: query.limit,
          );
    });

final monthlyMomentPhotoChoicesProvider = FutureProvider.autoDispose
    .family<List<String>, MomentPhotoChoicesQuery>((ref, query) {
      _checkOwner(ref, query.ownerId);
      return ref
          .watch(privateMomentArchiveRepositoryProvider)
          .monthlyPhotoChoices(ownerId: query.ownerId, month: query.month);
    });

final weeklyMomentPhotoChoicesProvider = FutureProvider.autoDispose
    .family<List<String>, MomentWeeklyChoicesQuery>((ref, query) {
      _checkOwner(ref, query.ownerId);
      return ref
          .watch(privateMomentArchiveRepositoryProvider)
          .weeklyPhotoChoices(
            ownerId: query.ownerId,
            weekStart: query.weekStart,
          );
    });
