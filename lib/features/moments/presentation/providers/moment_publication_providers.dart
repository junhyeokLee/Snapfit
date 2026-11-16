import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../social/presentation/providers/social_providers.dart';
import '../../data/moment_publication_repository.dart';
import 'moments_providers.dart';

final momentPublicationRepositoryProvider =
    Provider<MomentPublicationRepository>((ref) {
      final records = ref.watch(momentsRepositoryProvider);
      final repository = MomentPublicationRepository(
        social: ref.watch(socialRepositoryProvider),
        currentUserId: () => records.currentUserId,
        authChanges: records.authChanges,
      );
      ref.onDispose(repository.dispose);
      return repository;
    });

final momentPublicationStateProvider = FutureProvider.autoDispose
    .family<MomentPublicationState?, String>((ref, recordId) {
      if (ref.watch(momentsCurrentUserIdProvider) == null) return null;
      return ref.watch(momentPublicationRepositoryProvider).state(recordId);
    });
