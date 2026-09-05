import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env.dart';

// Album member repository provider
import '../../../../core/supabase/supabase_provider.dart';
import '../../service/album_persistence_service.dart';
import '../../../billing/data/billing_provider.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../domain/repositories/album_repository.dart';
import '../../domain/repositories/album_member_repository.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../../ai_album/data/ai_album_photo_candidate_collector.dart';
import '../../ai_album/data/supabase_ai_album_draft_provider.dart';
import '../../ai_album/domain/ai_album_draft_generation_service.dart';
import '../../service/album_editor_service.dart';
import '../repositories/supabase_album_repository.dart';
import '../repositories/supabase_album_member_repository.dart';
import '../repositories/gallery_repository_impl.dart';
import 'storage_service.dart';

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final supabase = ref.read(supabaseClientProvider);
  return SupabaseAlbumRepository(supabase, tokenStorage: tokenStorage);
});

/// 앨범 멤버 리포지토리 Provider
final albumMemberRepositoryProvider = Provider<AlbumMemberRepository>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  final supabase = ref.read(supabaseClientProvider);
  return SupabaseAlbumMemberRepository(supabase, tokenStorage: tokenStorage);
});

final galleryRepositoryProvider = Provider<GalleryRepository>((ref) {
  return GalleryRepositoryImpl();
});

final aiAlbumPhotoCandidateCollectorProvider =
    Provider<AiAlbumPhotoCandidateCollector>((ref) {
      return AiAlbumPhotoCandidateCollector(
        repository: ref.read(galleryRepositoryProvider),
      );
    });

final aiAlbumDraftProviderProvider = Provider<AiAlbumDraftProvider>((ref) {
  if (Env.useServerAiAlbumDraft) {
    return SupabaseAiAlbumDraftProvider(
      supabase: ref.read(supabaseClientProvider),
    );
  }
  return const MetadataFirstAiAlbumDraftProvider();
});

final aiAlbumDraftGenerationServiceProvider =
    Provider<AiAlbumDraftGenerationService>((ref) {
      final collector = ref.read(aiAlbumPhotoCandidateCollectorProvider);
      final draftProvider = ref.read(aiAlbumDraftProviderProvider);
      return AiAlbumDraftGenerationService(
        collectCandidates: (range) => collector.collect(range: range),
        draftProvider: draftProvider,
      );
    });

final storageServiceProvider = Provider<StorageService>((ref) {
  final billingRepository = ref.read(billingRepositoryProvider);
  final supabase = ref.read(supabaseClientProvider);
  return StorageService(
    billingRepository: billingRepository,
    supabase: supabase,
  );
});

final albumEditorServiceProvider = Provider<AlbumEditorService>((ref) {
  return const AlbumEditorService();
});

final albumPersistenceServiceProvider = Provider<AlbumPersistenceService>((
  ref,
) {
  final storage = ref.read(storageServiceProvider);
  final repository = ref.read(albumRepositoryProvider);
  return AlbumPersistenceService(storage, repository);
});
