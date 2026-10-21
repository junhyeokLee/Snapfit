import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart'
    show imageFrameStyles;
import '../../../album/data/bundled_creation_templates.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/presentation/point_shop_artwork.dart';
import '../../../store/data/api/template_provider.dart';
import '../../../store/presentation/widgets/library_design_tile.dart';

class CollectionHeading extends StatelessWidget {
  const CollectionHeading({
    super.key,
    required this.title,
    required this.onOpen,
    this.count,
  });
  final String title;
  final VoidCallback onOpen;
  final int? count;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: ExperienceFormStyle.text(context, 18, weight: FontWeight.w700),
        ),
      ),
      if (count != null)
        Text(
          '$count',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: '$title 모두 보기',
        onPressed: onOpen,
        icon: const ExperienceIcon('ArrowRight', size: 21),
      ),
    ],
  );
}

class PersonalAlbumShelf extends StatelessWidget {
  const PersonalAlbumShelf({
    super.key,
    required this.albums,
    required this.onOpen,
    required this.onShowAll,
    required this.onRetry,
  });
  final AsyncValue<List<Album>> albums;
  final ValueChanged<Album> onOpen;
  final VoidCallback onShowAll, onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CollectionHeading(
        title: '내 앨범',
        count: albums.asData?.value.length,
        onOpen: onShowAll,
      ),
      const SizedBox(height: 8),
      albums.when(
        loading: () => const _CollectionState(title: '앨범을 불러오고 있어요'),
        error: (_, __) =>
            _CollectionState(title: '앨범을 불러오지 못했어요', onRetry: onRetry),
        data: (items) {
          if (items.isEmpty)
            return const _CollectionState(title: '아직 만든 앨범이 없어요');
          final sorted = [...items]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return LayoutBuilder(
            builder: (context, box) {
              final scaler = MediaQuery.textScalerOf(context);
              final wide =
                  MediaQuery.orientationOf(context) == Orientation.landscape;
              final width = (box.maxWidth * .59).clamp(
                154.0,
                wide ? 190.0 : 224.0,
              );
              final artworkHeight = wide ? 180.0 : 216.0;
              final titleHeight = (scaler.scale(13) * 2.9).ceilToDouble();
              final statusHeight = (scaler.scale(11) * 1.5).ceilToDouble();
              return SizedBox(
                height: artworkHeight + 18 + titleHeight + statusHeight,
                child: ListView.separated(
                  key: const PageStorageKey('personal-album-shelf'),
                  scrollDirection: Axis.horizontal,
                  itemCount: sorted.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: width,
                    child: InkWell(
                      key: ValueKey('personal-album-${sorted[i].id}'),
                      onTap: () => onOpen(sorted[i]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: artworkHeight,
                            width: double.infinity,
                            child: SavedAlbumArtwork(album: sorted[i]),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: titleHeight,
                            child: Text(
                              sorted[i].title.isEmpty
                                  ? '제목 없는 앨범'
                                  : sorted[i].title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                weight: FontWeight.w600,
                              ).copyWith(height: 1.45),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCompletedAlbum(sorted[i]) ? '완료한 기록' : '만드는 중',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExperienceFormStyle.text(
                              context,
                              11,
                              secondary: true,
                            ).copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ],
  );
}

/// A current saved cover, never a reconstructed print-order snapshot.
class SavedAlbumArtwork extends StatelessWidget {
  const SavedAlbumArtwork({super.key, this.album});
  final Album? album;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(gradient: AlbumStageStyle.gradient(context)),
    child: LayoutBuilder(
      builder: (context, box) => Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: album == null
              ? ExperienceIcon(
                  'BookOpen',
                  size: 32,
                  color: ExperienceFormStyle.muted(context),
                )
              : RepaintBoundary(
                  child: HomeAlbumCoverThumbnail(
                    album: album!,
                    height: (box.maxHeight - 24).clamp(1, double.infinity),
                    maxWidth: (box.maxWidth - 24).clamp(1, double.infinity),
                    showBookDepth: true,
                    shadowScaleMultiplier: .55,
                  ),
                ),
        ),
      ),
    ),
  );
}

class OwnedDesignShelf extends ConsumerWidget {
  const OwnedDesignShelf({super.key, required this.onOpen});
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owned = ref.watch(ownedPointShopKeysProvider);
    final templatesByKey = {
      for (final template in publishedCreationTemplates)
        pointShopTemplateKey(template): template,
    };
    final needsRemoteTemplates =
        owned.asData?.value.any(
          (key) =>
              key.startsWith('template:') && !templatesByKey.containsKey(key),
        ) ??
        false;
    if (needsRemoteTemplates) {
      for (final template
          in ref.watch(templateListProvider).asData?.value ?? const []) {
        templatesByKey[pointShopTemplateKey(template)] = template;
      }
    }
    final titles = {
      for (final product
          in ref.watch(pointShopCatalogProvider).asData?.value ?? [])
        product.productKey: product.title,
      for (final spec in studioDecorations) 'sticker:${spec.id}': spec.label,
      for (final frame in imageFrameStyles) 'frame:${frame.key}': frame.label,
      for (final phrase in studioPhrases)
        'phrase:${phrase.id}': phrase.text.replaceAll('\n', ' '),
      for (final art in studioWordArts) art.productKey: art.label,
      for (final entry in templatesByKey.entries) entry.key: entry.value.title,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionHeading(
          title: '내 보관함',
          count: owned.asData?.value.length,
          onOpen: () => onOpen('전체'),
        ),
        const SizedBox(height: 8),
        owned.when(
          loading: () => const _CollectionState(title: '구매한 디자인을 확인하고 있어요'),
          error: (_, __) => _CollectionState(
            title: '구매한 디자인을 확인하지 못했어요',
            onRetry: () => ref.invalidate(ownedPointShopKeysProvider),
          ),
          data: (keys) {
            if (keys.isEmpty)
              return const _CollectionState(title: '구매한 템플릿과 소재가 여기에 모여요.');
            final templates =
                keys.where((k) => k.startsWith('template:')).toList()..sort();
            final materials =
                keys.where((k) => !k.startsWith('template:')).toList()..sort();
            final shown = [
              for (var i = 0; i < 4; i++) ...[
                if (i < templates.length && i < 3) templates[i],
                if (i < materials.length) materials[i],
              ],
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '템플릿 ${templates.length}종 · 소재 ${materials.length}종',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: LibraryDesignTile.extent(
                    174,
                    MediaQuery.textScalerOf(context),
                  ),
                  child: ListView.separated(
                    key: const PageStorageKey('personal-design-shelf'),
                    scrollDirection: Axis.horizontal,
                    itemCount: shown.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, i) {
                      final key = shown[i], template = templatesByKey[shown[i]];
                      final type = _type(key);
                      final thumbnail = catalogPreviewAssets[key];
                      return SizedBox(
                        width: 156,
                        child: LibraryDesignTile(
                          key: ValueKey('personal-design-$key'),
                          productKey: key,
                          title: titles[key] ?? '구매한 $type',
                          type: type,
                          template: template,
                          owned: true,
                          previewHeight: 174,
                          preview: thumbnail != null && template == null
                              ? Image.asset(
                                  thumbnail,
                                  fit: BoxFit.contain,
                                  cacheWidth: 320,
                                )
                              : PointShopArtwork(
                                  productKey: key,
                                  showBookMaterial: true,
                                ),
                          onOpen: () => onOpen(type),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _type(String key) => switch (key.split(':').first) {
    'template' => '템플릿',
    'frame' => '프레임',
    'phrase' => '문구',
    _ =>
      studioDecorationById(key.split(':').last)?.category ==
              StudioDecorationCategory.paper
          ? '종이'
          : '스티커',
  };
}

class _CollectionState extends StatelessWidget {
  const _CollectionState({required this.title, this.onRetry});
  final String title;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
      ],
    ),
  );
}
