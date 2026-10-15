import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/album_stage_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/presentation/point_shop_artwork.dart';
import '../../../store/presentation/widgets/material_original_preview.dart';

class CollectionHeading extends StatelessWidget {
  const CollectionHeading({
    super.key,
    required this.title,
    required this.onOpen,
  });
  final String title;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: ExperienceFormStyle.text(context, 18, weight: FontWeight.w600),
        ),
      ),
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
      CollectionHeading(title: '내 앨범', onOpen: onShowAll),
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
              final count = box.maxWidth < 340 ? 2 : 3;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < sorted.take(count).length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        key: ValueKey('personal-album-${sorted[i].id}'),
                        onTap: () => onOpen(sorted[i]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 152,
                              width: double.infinity,
                              child: SavedAlbumArtwork(album: sorted[i]),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              sorted[i].title.isEmpty
                                  ? '제목 없는 앨범'
                                  : sorted[i].title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceFormStyle.text(
                                context,
                                13,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isCompletedAlbum(sorted[i]) ? '완료한 기록' : '만드는 중',
                              style: ExperienceFormStyle.text(
                                context,
                                11,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionHeading(title: '내 보관함', onOpen: () => onOpen('전체')),
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
              ...templates.take(2),
              ...materials.take(3),
            ].take(4).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 124,
                  child: Row(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(
                          child: Semantics(
                            label: '구매한 ${_type(shown[i])}',
                            button: true,
                            child: InkWell(
                              key: ValueKey('personal-design-${shown[i]}'),
                              onTap: () => onOpen(_type(shown[i])),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: shown[i].startsWith('template:')
                                      ? AlbumStageStyle.gradient(context)
                                      : null,
                                  color: shown[i].startsWith('template:')
                                      ? null
                                      : MaterialOriginalPreview.backgroundFor(
                                          shown[i],
                                        ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: RepaintBoundary(
                                    child: Center(
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: PointShopArtwork(
                                          productKey: shown[i],
                                          showBookMaterial: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '템플릿 ${templates.length}종 · 소재 ${materials.length}종',
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
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
    _ => '전체',
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
