import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../domain/entities/album.dart';
import '../../utils/home_album_section_builder.dart';
import '../../views/album_category_screen.dart';
import 'home_album_actions.dart';
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
            child: _AlbumSegmentTabs(
              selectedIndex: albumTabIndex,
              labels: const ['전체', '작업 중', '완성본', '즐겨찾기', '함께 만든'],
              onChanged: onAlbumTabChanged,
            ),
          ),
          if (tabData.tabAlbums.isNotEmpty)
            SliverToBoxAdapter(
              child: _AlbumSectionHeader(
                selectedIndex: albumTabIndex,
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
            selectedIndex: albumTabIndex,
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
      height: 42.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return SnapFitPressable(
            onTap: () => onChanged(index),
            pressedScale: 0.98,
            borderRadius: BorderRadius.circular(999.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: SnapFitMotion.settle,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
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
  const _AlbumSectionHeader({
    required this.selectedIndex,
    required this.count,
    required this.onMore,
  });

  final int selectedIndex;
  final int count;
  final VoidCallback onMore;

  String get _title => switch (selectedIndex) {
    1 => '이어 만들 포토북',
    2 => '완성된 포토북',
    3 => '자주 꺼내보는 앨범',
    4 => '함께 만든 앨범',
    _ => '최근에 만진 포토북',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22.w, 22.h, 22.w, 12.h),
      child: Row(
        children: [
          Text(
            _title,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
              letterSpacing: -0.25,
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '${count}권',
            style: TextStyle(
              fontSize: 12.sp,
              color: SnapFitColors.textMutedOf(context),
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (count > 0)
            SnapFitPressable(
              onTap: onMore,
              borderRadius: BorderRadius.circular(999.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Text(
                  '전체 보기',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: SnapFitColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyAlbumShelf extends StatelessWidget {
  const _EmptyAlbumShelf({required this.selectedIndex});

  final int selectedIndex;
  static bool _logged = false;

  ({String title, String body}) get _copy => switch (selectedIndex) {
    1 => (title: '이어 만들 앨범 없음', body: '진행 중인 앨범은 여기에 정리돼요.'),
    2 => (title: '완성본 없음', body: '완성한 앨범은 이곳에 모여요.'),
    3 => (title: '즐겨찾기 없음', body: '자주 보는 앨범에 별표를 눌러보세요.'),
    4 => (title: '공유 앨범 없음', body: '함께 만든 앨범은 이곳에 모여요.'),
    _ => (title: '앨범 없음', body: '오른쪽 아래 + 버튼으로 새 앨범을 시작하세요.'),
  };

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('EmptyAlbumShelf', '앨범 탭 빈 서재 상태');
    }
    final isDark = SnapFitColors.isDark(context);
    final copy = _copy;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 8.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 22.h, 20.w, 20.h),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF171A22) : const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.24 : 0.07),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            const _ShelfAlbumStack(),
            SizedBox(height: 18.h),
            Text(
              copy.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21.sp,
                height: 1.18,
                fontWeight: FontWeight.w900,
                color: SnapFitColors.textPrimaryOf(context),
                letterSpacing: -0.4,
              ),
            ),
            SizedBox(height: 9.h),
            Text(
              copy.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfAlbumStack extends StatelessWidget {
  const _ShelfAlbumStack();

  @override
  Widget build(BuildContext context) {
    Widget book(
      double w,
      double h,
      List<Color> colors,
      double angle,
      Offset offset,
    ) {
      return Transform.translate(
        offset: offset,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.r),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 132.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          book(
            88.w,
            116.h,
            const [Color(0xFFFCE7C8), Color(0xFFFFFAF1)],
            -0.14,
            Offset(-48.w, 8.h),
          ),
          book(
            96.w,
            126.h,
            const [Color(0xFFDFF8FF), Color(0xFFFFF7F0)],
            0.12,
            Offset(48.w, 10.h),
          ),
          book(
            104.w,
            132.h,
            const [Color(0xFFFFF3F7), Color(0xFFECE7FF)],
            0.0,
            Offset.zero,
          ),
        ],
      ),
    );
  }
}

class _HomeAlbumGridSliver extends ConsumerWidget {
  const _HomeAlbumGridSliver({
    required this.selectedIndex,
    required this.albums,
    required this.favoriteAlbumIds,
    required this.onToggleFavorite,
  });

  final int selectedIndex;
  final List<Album> albums;
  final Set<int> favoriteAlbumIds;
  final ValueChanged<int> onToggleFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) {
      return SliverToBoxAdapter(
        child: _EmptyAlbumShelf(selectedIndex: selectedIndex),
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
                        padding: EdgeInsets.only(bottom: 12.h),
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
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                children: rightCol
                    .map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
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
    final columnWidth = (1.sw - 52.w) / 2;
    final coverType = _coverTypeOf(album);
    final baseAspect = switch (coverType) {
      _CoverType.landscape => 0.78,
      _CoverType.square => 0.68,
      _CoverType.portrait => 0.60,
    };
    final microJitter = <double>[0.00, -0.006, 0.006, -0.01][index % 4];
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
    final cardBg = SnapFitColors.isDark(context)
        ? SnapFitColors.surfaceOf(context)
        : const Color(0xFFFFFCF7);
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
        pressedScale: 0.98,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  SnapFitColors.isDark(context) ? 0.24 : 0.06,
                ),
                blurRadius: 22,
                offset: const Offset(0, 12),
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
                        padding: EdgeInsets.fromLTRB(10.w, 10.h, 14.w, 4.h),
                        child: Center(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.14),
                                  blurRadius: 18,
                                  spreadRadius: 0.4,
                                  offset: const Offset(0, 10),
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
                      right: 8.w,
                      top: 18.h,
                      bottom: 18.h,
                      child: Container(
                        width: 4.w,
                        decoration: BoxDecoration(
                          color:
                              (SnapFitColors.isDark(context)
                                      ? Colors.white
                                      : Colors.black)
                                  .withOpacity(
                                    SnapFitColors.isDark(context)
                                        ? 0.06
                                        : 0.045,
                                  ),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7.h,
                      right: 7.w,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: onToggleFavorite,
                        child: SizedBox(
                          width: 36.w,
                          height: 36.w,
                          child: Center(
                            child: CircleAvatar(
                              radius: 15.r,
                              backgroundColor: SnapFitColors.pureWhite
                                  .withOpacity(0.92),
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
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 13.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title.isEmpty ? '제목 없음' : album.title,
                      maxLines: 1,
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
                      '최근 편집 ${formatAlbumDate(album.updatedAt)}',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w600,
                      ),
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
