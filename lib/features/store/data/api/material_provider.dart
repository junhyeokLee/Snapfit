import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_provider.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../core/templates/story_edition_catalog.dart';
import '../../../../core/templates/premium_quartet_frame_catalog.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart'
    show imageFrameStyles;
import '../../domain/entities/catalog_material.dart';
import '../../domain/repositories/material_repository.dart';
import '../repositories/supabase_material_repository.dart';

final materialRepositoryProvider = Provider<MaterialRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);
  return SupabaseMaterialRepository(supabase);
});

/// Converts the bundled Dart catalogs to a flat CatalogMaterial list.
/// Rendering logic stays in Dart; only metadata can be overridden by the DB.
List<CatalogMaterial> get bundledMaterials => [
  for (final spec in studioDecorations)
    CatalogMaterial(
      productKey: 'sticker:${spec.id}',
      label: spec.label,
      type: spec.category == StudioDecorationCategory.paper ? '종이' : '스티커',
      collection: spec.collection,
      isPremium: storyEditionForMaterial(spec.id)?.isPremium ?? false,
    ),
  for (final frame in imageFrameStyles.where((f) => f.key.isNotEmpty))
    CatalogMaterial(
      productKey: 'frame:${frame.key}',
      label: frame.label,
      type: '프레임',
      collection:
          storyEditionsById[premiumQuartetFrameBookIds[frame.key]]?.title ??
          frame.category,
      isPremium: premiumQuartetFramesById.containsKey(frame.key),
    ),
  for (final phrase in studioPhrases)
    CatalogMaterial(
      productKey: 'phrase:${phrase.id}',
      label: phrase.text.replaceAll('\n', ' '),
      type: '문구',
      collection: phrase.category,
    ),
  for (final art in studioWordArts)
    CatalogMaterial(
      productKey: art.productKey,
      label: art.label,
      type: '문구',
      collection: storyEditionForMaterial(art.id)?.title,
      isPremium: storyEditionForMaterial(art.id)?.isPremium ?? false,
    ),
];

/// Three-phase material catalog load:
///  1. Return bundled materials IMMEDIATELY — renders on frame 1.
///  2. Background: sync live metadata (isNew, isBest, likeCount, weeklyScore,
///     isActive) from Supabase and overlay onto bundled items.
///
/// Items hidden by the server (isActive=false) are filtered out.
/// Bundled-only items (not yet in DB) remain visible with default metadata.
final materialListProvider =
    AsyncNotifierProvider<_MaterialCatalogNotifier, List<CatalogMaterial>>(
      _MaterialCatalogNotifier.new,
    );

/// Test helper — returns a fixed list, skipping all background work.
dynamic mockMaterialList(FutureOr<List<CatalogMaterial>> Function() data) =>
    materialListProvider.overrideWith(
      () => _FixedMaterialCatalogNotifier(data),
    );

class _FixedMaterialCatalogNotifier extends _MaterialCatalogNotifier {
  _FixedMaterialCatalogNotifier(this._data);
  final FutureOr<List<CatalogMaterial>> Function() _data;

  @override
  Future<List<CatalogMaterial>> build() async => _data();

  @override
  void _syncInBackground(bool Function() _) {
    /* no-op in tests */
  }
}

class _MaterialCatalogNotifier extends AsyncNotifier<List<CatalogMaterial>> {
  @override
  Future<List<CatalogMaterial>> build() {
    var disposed = false;
    ref.onDispose(() => disposed = true);
    _syncInBackground(() => disposed);
    return Future.value(bundledMaterials);
  }

  void _syncInBackground(bool Function() isDisposed) {
    Future.microtask(() async {
      if (isDisposed()) return;
      try {
        final serverMaterials = await ref
            .read(materialRepositoryProvider)
            .getMaterials();
        if (isDisposed()) return;
        final merged = _mergeWithServer(bundledMaterials, serverMaterials);
        state = AsyncData(List.unmodifiable(merged));
      } catch (_) {
        // Server unavailable — bundled metadata is sufficient for display.
      }
    });
  }

  /// Overlays server metadata onto bundled items.
  /// - Server controls isNew, isBest, likeCount, weeklyScore.
  /// - Server can deactivate items (isActive=false) to hide them.
  /// - Bundled-only items remain visible with default metadata.
  static List<CatalogMaterial> _mergeWithServer(
    List<CatalogMaterial> bundled,
    List<CatalogMaterial> server,
  ) {
    final serverByKey = {for (final m in server) m.productKey: m};
    // Items the server explicitly deactivated are excluded.
    final deactivated = {
      for (final m in server)
        if (!m.isActive) m.productKey,
    };
    return [
      for (final b in bundled)
        if (!deactivated.contains(b.productKey))
          () {
            final s = serverByKey[b.productKey];
            if (s == null) return b;
            return b.copyWith(
              isNew: s.isNew,
              isBest: s.isBest,
              likeCount: s.likeCount,
              userCount: s.userCount,
              weeklyScore: s.weeklyScore,
              isPremium: b.isPremium || s.isPremium,
              isLiked: s.isLiked,
            );
          }(),
    ];
  }
}
