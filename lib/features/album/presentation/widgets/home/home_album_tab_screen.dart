import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/platform_ui.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/experience_style.dart';
import '../../../domain/entities/album.dart';
import '../../utils/home_album_section_builder.dart';
import '../../views/album_category_screen.dart';
import '../../../../profile/presentation/widgets/personal_collection_shelf.dart';
import 'home_album_actions.dart';
import 'home_album_helpers.dart';

class HomeAlbumTabScreen extends ConsumerWidget {
  const HomeAlbumTabScreen({
    super.key,
    required this.allAlbums,
    required this.currentUserId,
    required this.albumTabIndex,
    required this.favoriteAlbumIds,
    required this.onAlbumTabChanged,
    required this.onToggleFavorite,
    required this.onRefresh,
  });
  final List<Album> allAlbums;
  final String currentUserId;
  final int albumTabIndex;
  final Set<int> favoriteAlbumIds;
  final ValueChanged<int> onAlbumTabChanged, onToggleFavorite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = buildHomeAlbumTabData(
      allAlbums: allAlbums,
      currentUserId: currentUserId,
      favoriteAlbumIds: favoriteAlbumIds,
      albumTabIndex: albumTabIndex,
    );
    void openSearch() => Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AlbumCategoryScreen(
          category: AlbumCategory.recent,
          initialAlbums: data.allAlbums,
          currentUserId: currentUserId,
          initialTabIndex: 0,
        ),
      ),
    );
    return Column(
      children: [
        ExperienceHeader(
          title: '내 앨범',
          actions: [
            IconButton(
              tooltip: '앨범 검색 및 관리',
              onPressed: openSearch,
              icon: const ExperienceIcon('Search', size: 21),
            ),
          ],
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              key: const PageStorageKey('home-album-collection'),
              cacheExtent: 240,
              physics: platformScrollPhysics(alwaysScrollable: true),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Text(
                      '${data.tabAlbums.length}권',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                  ),
                ),
                if (data.tabAlbums.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          '아직 이곳에 모인 앨범이 없어요.',
                          textAlign: TextAlign.center,
                          style: ExperienceFormStyle.text(
                            context,
                            15,
                            secondary: true,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverLayoutBuilder(
                      builder: (context, box) {
                        final scale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final wide =
                            MediaQuery.orientationOf(context) ==
                            Orientation.landscape;
                        final columns =
                            (box.crossAxisExtent /
                                    (wide
                                        ? 340
                                        : scale > 1.5
                                        ? 220
                                        : 164))
                                .floor()
                                .clamp(1, 5);
                        final width =
                            (box.crossAxisExtent - 20 * (columns - 1)) /
                            columns;
                        final stage = wide
                            ? 156.0
                            : (width * 1.12).clamp(160.0, 270.0);
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 24,
                                mainAxisExtent: wide
                                    ? (112 * scale).clamp(stage, 320)
                                    : stage + 22 + 92 * scale,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final album = data.tabAlbums[index];
                              final favorite = favoriteAlbumIds.contains(
                                album.id,
                              );
                              final progress = calculateAlbumProgress(album);
                              return InkWell(
                                key: ValueKey(
                                  'home-collection-album-${album.id}',
                                ),
                                onTap: () => HomeAlbumActions.openAlbum(
                                  context,
                                  ref,
                                  album,
                                ),
                                child: Flex(
                                  direction: wide
                                      ? Axis.horizontal
                                      : Axis.vertical,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: stage,
                                      width: wide ? width * .43 : width,
                                      child: SavedAlbumArtwork(album: album),
                                    ),
                                    SizedBox(
                                      height: wide ? 0 : 12,
                                      width: wide ? 16 : 0,
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: wide
                                            ? MainAxisAlignment.center
                                            : MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  album.title.isEmpty
                                                      ? '제목 없는 앨범'
                                                      : album.title,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      ExperienceFormStyle.text(
                                                        context,
                                                        14,
                                                        weight: FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: favorite
                                                    ? '즐겨찾기 해제'
                                                    : '즐겨찾기',
                                                onPressed: () =>
                                                    onToggleFavorite(album.id),
                                                icon: Icon(
                                                  favorite
                                                      ? Icons.star_rounded
                                                      : Icons
                                                            .star_outline_rounded,
                                                  size: 21,
                                                  color: favorite
                                                      ? ExperienceFormStyle.selectionInk(
                                                          context,
                                                        )
                                                      : ExperienceFormStyle.muted(
                                                          context,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isCompletedAlbum(album)
                                                ? '완성한 앨범'
                                                : progress.pageProgressLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ExperienceFormStyle.text(
                                              context,
                                              12,
                                              secondary: true,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            formatAlbumDate(album.createdAt),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: ExperienceFormStyle.text(
                                              context,
                                              11,
                                              secondary: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: data.tabAlbums.length,
                            addAutomaticKeepAlives: false,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
