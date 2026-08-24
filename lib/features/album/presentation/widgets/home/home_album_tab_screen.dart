import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
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
            child: _AlbumStudioHeader(totalCount: tabData.allAlbums.length),
          ),
          SliverToBoxAdapter(
            child: _AlbumSegmentTabs(
              selectedIndex: albumTabIndex,
              labels: const ['전체', '진행중', '완료', '즐겨찾기', '공유'],
              onChanged: onAlbumTabChanged,
            ),
          ),
          SliverToBoxAdapter(
            child: _AlbumSectionHeader(
              count: tabData.tabAlbums.length,
              onMore: () {
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

class _AlbumStudioHeader extends StatelessWidget {
  const _AlbumStudioHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return SnapFitFadeIn(
      child: Container(
        margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
        padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 16.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.r),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF18212D), Color(0xFF11151D)]
                : const [Color(0xFFFFF8EC), Color(0xFFEAFBFD)],
          ),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.26 : 0.07),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Album Studio',
                    style: TextStyle(
                      fontSize: 11.sp,
                      letterSpacing: 0.4,
                      color: SnapFitColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '내 앨범',
                    style: TextStyle(
                      fontSize: 24.sp,
                      height: 1.05,
                      color: SnapFitColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    '추억을 고르고, 편집하고, 완성하는 나만의 작업실',
                    style: TextStyle(
                      fontSize: 11.sp,
                      height: 1.35,
                      color: SnapFitColors.textSecondaryOf(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 58.w,
              height: 58.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    SnapFitColors.primaryGradientStart,
                    SnapFitColors.primaryGradientEnd,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: SnapFitColors.accent.withOpacity(0.26),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$totalCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumSegmentTabs extends StatelessWidget {
  const _AlbumSegmentTabs({
    required this.selectedIndex,
    required this.labels,
    required this.onChanged,
  });

  final int selectedIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return SnapFitPressable(
            onTap: () => onChanged(index),
            pressedScale: 0.94,
            borderRadius: BorderRadius.circular(999.r),
            child: AnimatedContainer(
              duration: SnapFitMotion.medium,
              curve: SnapFitMotion.settle,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: selected
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(999.r),
                border: Border.all(
                  color: selected
                      ? SnapFitColors.textPrimaryOf(context)
                      : SnapFitColors.overlayLightOf(context),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            SnapFitColors.isDark(context) ? 0.26 : 0.10,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                  color: selected
                      ? SnapFitColors.backgroundOf(context)
                      : SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlbumSectionHeader extends StatelessWidget {
  const _AlbumSectionHeader({required this.count, required this.onMore});

  final int count;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 12.h),
      child: Row(
        children: [
          Text(
            '앨범 컬렉션',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: SnapFitColors.accentLight,
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              '$count개',
              style: TextStyle(
                fontSize: 10.sp,
                color: SnapFitColors.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          SnapFitPressable(
            onTap: onMore,
            borderRadius: BorderRadius.circular(999.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Row(
                children: [
                  Text(
                    '더보기',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: SnapFitColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10.sp,
                    color: SnapFitColors.accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlbumShelf extends StatelessWidget {
  const _EmptyAlbumShelf();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 4.h),
      child: Container(
        height: 148.h,
        padding: EdgeInsets.all(18.w),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 54.w,
              height: 72.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE4C7), Color(0xFFDFF8FF)],
                ),
              ),
              child: Icon(
                Icons.photo_album_outlined,
                color: SnapFitColors.textPrimaryOf(context).withOpacity(0.62),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '아직 여기에 앨범이 없어요',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '다른 탭을 보거나 새 앨범을 만들면 이 공간이 채워져요.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      return const SliverToBoxAdapter(child: _EmptyAlbumShelf());
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
        ? softenedAlbumCardToneForBrightness(tone, Theme.of(context).brightness)
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
      child: SnapFitPressable(
        onTap: onTap,
        pressedScale: 0.965,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  SnapFitColors.isDark(context) ? 0.24 : 0.06,
                ),
                blurRadius: 18,
                offset: const Offset(0, 10),
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
                padding: EdgeInsets.fromLTRB(13.w, 11.h, 13.w, 12.h),
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
