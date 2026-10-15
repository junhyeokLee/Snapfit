import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/viewmodels/auth_view_model.dart';
import '../domain/entities/album_creation_draft.dart';
import 'album_creation_draft_store_base.dart';
import 'album_creation_draft_store_io.dart'
    if (dart.library.js_interop) 'album_creation_draft_store_web.dart' as platform;

export 'album_creation_draft_store_base.dart';
export 'album_creation_draft_store_io.dart'
    if (dart.library.js_interop) 'album_creation_draft_store_web.dart';

final albumCreationDraftStoreProvider = Provider<AlbumCreationDraftStore>(
  (ref) => platform.createAlbumCreationDraftStore(),
);
final albumCreationDraftProvider = FutureProvider<AlbumCreationDraft?>((
  ref,
) async {
  final owner = ref.watch(authViewModelProvider).asData?.value?.id;
  if (owner == null || owner.isEmpty) return null;
  return ref.watch(albumCreationDraftStoreProvider).load(owner);
});
