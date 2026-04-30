import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../../domain/entities/album.dart';
import '../../utils/home_album_section_builder.dart';
import '../../views/album_category_screen.dart';
import 'home_album_actions.dart';
import 'home_album_card_tone.dart';
import 'home_album_cover_thumbnail.dart';
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
  final ValueChanged<int> onAlbumTabChanged;
  final ValueChanged<int> onToggleFavorite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final tabData = buildHomeAlbumTabData(
      allAlbums: allAlbums,
      currentUserId: currentUserId,
      favoriteAlbumIds: favoriteAlbumIds,
      albumTabIndex: albumTabIndex,
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        cacheExtent: 1000,
        physics: platformScrollPhysics(alwaysScrollable: true),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
              child: Text(
                '내 앨범',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                ),
              ),
              child: Row(
                children: ['전체', '진행중', '완료', '즐겨찾기', '공유'].asMap().entries.map((
                  entry,
                ) {
                  final idx = entry.key;
                  final selected = idx == albumTabIndex;
                  return GestureDetector(
                    onTap: () => onAlbumTabChanged(idx),
                    child: Container(
                      margin: EdgeInsets.only(right: 18.w),
                      padding: EdgeInsets.only(bottom: 10.h),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? SnapFitColors.accent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: selected ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Row(
                children: [
                  Text(
                    '앨범',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${tabData.tabAlbums.length}개',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: () {
                      final category = switch (albumTabIndex) {
                        4 => AlbumCategory.shared,
                        _ => AlbumCategory.recent,
                      };
                      final initialTabIndex = switch (albumTabIndex) {
                        1 => 0,
                        2 => 1,
                        3 => 2,
                        _ => 0,
                      };
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumCategoryScreen(
                            category: category,
                            initialAlbums: albumTabIndex == 4
                                ? tabData.tabAlbums
                                : tabData.allAlbums,
                            currentUserId: currentUserId,
                            initialTabIndex: initialTabIndex,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      '더보기',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: SnapFitColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _HomeAlbumGridSliver(
            albums: tabData.tabAlbums,
            favoriteAlbumIds: favoriteAlbumIds,
            onToggleFavorite: onToggleFavorite,
          ),
          SliverToBoxAdapter(child: SizedBox(height: 90.h)),
        ],
      ),
    );
  }
}

class _HomeAlbumGridSliver extends ConsumerWidget {
  const _HomeAlbumGridSliver({
    required this.albums,
    required this.favoriteAlbumIds,
    required this.onToggleFavorite,
  });

  final List<Album> albums;
  final Set<int> favoriteAlbumIds;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 4.h),
          child: Container(
            height: 110.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
            child: Text(
              '표시할 앨범이 없습니다.',
              style: TextStyle(
                fontSize: 10.sp,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      );
    }

    final leftCol = <MapEntry<int, Album>>[];
    final rightCol = <MapEntry<int, Album>>[];
    for (int i = 0; i < albums.length; i++) {
      (i % 2 == 0 ? leftCol : rightCol).add(MapEntry(i, albums[i]));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: leftCol
                    .map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: SizedBox(
                          height: _albumMasonryHeight(entry.value, entry.key),
                          child: _HomeAlbumGridCard(
                            album: entry.value,
                            isFavorite: favoriteAlbumIds.contains(
                              entry.value.id,
                            ),
                            onToggleFavorite: () =>
                                onToggleFavorite(entry.value.id),
                            onTap: () => HomeAlbumActions.openAlbum(
                              context,
                              ref,
                              entry.value,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                children: rightCol
                    .map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: SizedBox(
                          height: _albumMasonryHeight(entry.value, entry.key),
                          child: _HomeAlbumGridCard(
                            album: entry.value,
                            isFavorite: favoriteAlbumIds.contains(
                              entry.value.id,
                            ),
                            onToggleFavorite: () =>
                                onToggleFavorite(entry.value.id),
                            onTap: () => HomeAlbumActions.openAlbum(
                              context,
                              ref,
                              entry.value,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _albumMasonryHeight(Album album, int index) {
    final columnWidth = (1.sw - 50.w) / 2;
    final coverType = _coverTypeOf(album);
    final baseAspect = switch (coverType) {
      _CoverType.landscape => 0.76,
      _CoverType.square => 0.67,
      _CoverType.portrait => 0.59,
    };
    final microJitter = <double>[0.00, -0.01, 0.01, -0.015][index % 4];
    return columnWidth / (baseAspect + microJitter);
  }

  _CoverType _coverTypeOf(Album album) {
    final ratio = parseCoverRatio(album.ratio);
    if (ratio > 1.12) return _CoverType.landscape;
    if (ratio < 0.88) return _CoverType.portrait;
    return _CoverType.square;
  }
}

class _HomeAlbumGridCard extends StatelessWidget {
  const _HomeAlbumGridCard({
    required this.album,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final Album album;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = calculateAlbumProgress(album);
    final tone = albumCardToneOrNull(album);
    final cardBg = tone != null
        ? softenedAlbumCardToneForBrightness(
            tone,
            Theme.of(context).brightness,
          )
        : SnapFitColors.surfaceOf(context);
    final coverType = _coverTypeOf(album);
    final thumbnailHeight = switch (coverType) {
      _CoverType.landscape => 126.h,
      _CoverType.square => 142.h,
      _CoverType.portrait => 160.h,
    };
    final thumbnailMaxWidth = switch (coverType) {
      _CoverType.landscape => 132.w,
      _CoverType.square => 124.w,
      _CoverType.portrait => 114.w,
    };

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  SnapFitColors.isDark(context) ? 0.24 : 0.06,
                ),
                blurRadius: 9,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.26),
                                  blurRadius: 22,
                                  spreadRadius: 1.2,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.14),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: HomeAlbumCoverThumbnail(
                              album: album,
                              height: thumbnailHeight,
                              maxWidth: thumbnailMaxWidth,
                              showShadow: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10.h,
                      right: 10.w,
                      child: GestureDetector(
                        onTap: onToggleFavorite,
                        child: CircleAvatar(
                          radius: 14.r,
                          backgroundColor: SnapFitColors.pureWhite.withOpacity(
                            0.92,
                          ),
                          child: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFavorite
                                ? SnapFitColors.accent
                                : SnapFitColors.textSecondaryOf(context),
                            size: 16.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title.isEmpty ? '제목 없음' : album.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.2,
                        fontSize: 14.sp,
                        color: SnapFitColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      formatAlbumDate(album.createdAt),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: SnapFitColors.overlayLightOf(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 14.sp,
                            color: SnapFitColors.textSecondaryOf(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${progress.completedPages} 페이지',
                          style: TextStyle(
                            color: SnapFitColors.accent,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _CoverType _coverTypeOf(Album album) {
    final ratio = parseCoverRatio(album.ratio);
    if (ratio > 1.12) return _CoverType.landscape;
    if (ratio < 0.88) return _CoverType.portrait;
    return _CoverType.square;
  }
}

enum _CoverType { landscape, square, portrait }
