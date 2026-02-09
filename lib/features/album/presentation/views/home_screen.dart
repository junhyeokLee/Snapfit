import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_primary_gradient_background.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../widgets/cover/cover.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../widgets/home/home_greeting_header.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_status_chip.dart';
import '../widgets/home/home_collaborator_widgets.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_icon_buttons.dart';
import '../widgets/home/home_avatar_dot.dart';
import '../widgets/home/home_create_album_fab.dart';
import '../widgets/home/home_album_list_view.dart';
import '../widgets/home/home_featured_album_card.dart';
import '../widgets/home/home_grid_album_card.dart';
import '../widgets/home/home_album_cover_thumbnail.dart';
import '../widgets/home/home_cover_frame.dart';
import '../widgets/home/home_focus_wrap.dart';
import '../widgets/home/home_album_helpers.dart';
import '../widgets/home/home_error_state.dart';
import '../widgets/home/home_album_slider.dart';
import '../widgets/home/home_bottom_nav_placeholder.dart';
import '../widgets/home/home_album_actions.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'add_cover_screen.dart';
import 'album_reader_screen.dart';
import 'album_create_flow_screen.dart';
import 'fanned_pages_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  int _bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
    Future<void> handleCreateAlbum() async {
      final created = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AlbumCreateFlowScreen(),
        ),
      );
      if (created == true && context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    }
    final albums = albumsAsync.asData?.value;
    final sortedAlbums = albums == null
        ? null
        : (List<Album>.from(albums)
          ..sort((a, b) => (b.createdAt).compareTo(a.createdAt)));
    final selectedAlbum = (sortedAlbums == null || sortedAlbums.isEmpty)
        ? null
        : sortedAlbums[_selectedIndex.clamp(0, sortedAlbums.length - 1)];

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      bottomNavigationBar: HomeBottomNavigationBar(
        currentIndex: _bottomNavIndex,
        onTap: (index) {
          setState(() => _bottomNavIndex = index);
        },
        onCreate: handleCreateAlbum,
      ),
      body: _buildBottomNavBody(
        context,
        Container(
          color: SnapFitColors.backgroundOf(context),
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 10.h),
                  decoration: BoxDecoration(
                    color: SnapFitColors.backgroundOf(context),
                    border: Border(
                      bottom: BorderSide(
                        color: SnapFitColors.overlayLightOf(context),
                      ),
                    ),
                  ),
                  child: HomeHeader(
                    onSearch: () {},
                    onNotification: () {},
                  ),
                ),
                Expanded(
                  child: albumsAsync.when(
                    data: (albums) {
                      final sorted = List<Album>.from(albums)
                        ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
                      return HomeAlbumListView(
                        albums: sorted,
                        selectedIndex: _selectedIndex,
                        userInfo: authAsync.value,
                        emptyState: const HomeEmptyState(),
                        onSelect: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onOpen: (album, index) async {
                          setState(() => _selectedIndex = index);
                          await HomeAlbumActions.openAlbum(context, ref, album);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: SnapFitColors.accentLight),
                    ),
                    error: (err, stack) => HomeErrorState(error: err),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBody(BuildContext context, Widget homeBody) {
    switch (_bottomNavIndex) {
      case 0:
      case 1:
        return homeBody;
      case 2:
        return const HomeBottomNavPlaceholder(label: "알림");
      case 3:
        return const MyPageScreen();
      default:
        return homeBody;
    }
  }

}

/// 홈 화면 상단 헤더 (제목 + 아이콘)
class _HomeHeader extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onNotification;

  const _HomeHeader({
    required this.onSearch,
    required this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Row(
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: SnapFitColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                Icons.photo_album_outlined,
                size: 18.sp,
                color: SnapFitColors.accentLight,
              ),
            ),
            SizedBox(width: 10.w),
            Text(
              'SnapFit',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
          ],
        ),
        const Spacer(),
        HomeRoundIconButton(icon: Icons.search, onTap: onSearch),
        SizedBox(width: 10.w),
        HomeRoundIconButton(icon: Icons.notifications_none, onTap: onNotification),
        SizedBox(width: 10.w),
        _AvatarDot(),
      ],
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  final UserInfo? userInfo;

  const _GreetingHeader({required this.userInfo});

  @override
  Widget build(BuildContext context) {
    final rawName = userInfo?.name ?? '';
    final email = userInfo?.email ?? '';
    final provider = (userInfo?.provider ?? '').toUpperCase();
    final isPlaceholder = rawName.isEmpty ||
        rawName == provider ||
        rawName.endsWith('_USER') ||
        rawName.contains(provider);
    final emailName = email.contains('@') ? email.split('@').first : email;
    final name = !isPlaceholder && rawName.isNotEmpty
        ? rawName
        : (emailName.isNotEmpty ? emailName : '사용자');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '당신의 추억이 기다리고 있어요.',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _AvatarDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        color: SnapFitColors.overlayLightOf(context),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'A',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
    );
  }
}

/// 홈 화면 앨범 리스트 뷰
/// 홈 하단 바텀 네비게이션
class _HomeBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onCreate;

  const _HomeBottomNavigationBar({
    required this.currentIndex,
    required this.onTap,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
        decoration: BoxDecoration(
          color: SnapFitColors.isDark(context)
              ? SnapFitColors.surfaceOf(context)
              : SnapFitColors.pureWhite,
          border: Border(
            top: BorderSide(
              color: SnapFitColors.isDark(context)
                  ? SnapFitColors.overlayLightOf(context)
                  : SnapFitColors.overlayStrongOf(context),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                icon: Icons.home_rounded,
                label: '홈',
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.photo_album_rounded,
                label: '커넥트',
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
            ),
            SizedBox(width: 6.w),
            _CreateNavButton(onTap: onCreate),
            SizedBox(width: 6.w),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.people_alt_rounded,
                label: '알림',
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon: Icons.person_rounded,
                label: '마이',
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 바텀 네비게이션 중앙 액션 버튼
class _CreateNavButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32.r),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 12.r,
                offset: Offset(0, 6.h),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: SnapFitPrimaryGradientBackground(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  width: 52.w,
                  height: 52.w,
                  child: Icon(
                    Icons.add,
                    size: 28.sp,
                    color: SnapFitColors.pureWhite,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 바텀 네비게이션 아이템
class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final color = isSelected
        ? (isDark ? SnapFitColors.accent : SnapFitColors.accentLight)
        : (isDark
            ? SnapFitColors.textMutedOf(context)
            : SnapFitColors.deepCharcoal.withOpacity(0.7));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22.sp, color: color),
              SizedBox(height: 4.h),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _AlbumListView extends StatelessWidget {
  final List<Album> albums;
  final int selectedIndex;
  final UserInfo? userInfo;
  final Widget emptyState;
  final ValueChanged<int> onSelect;
  final Future<void> Function(Album album, int index) onOpen;

  const _AlbumListView({
    required this.albums,
    required this.selectedIndex,
    required this.userInfo,
    required this.emptyState,
    required this.onSelect,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final featured = albums.isNotEmpty ? albums.first : null;
    final rest = albums.length > 1 ? albums.sublist(1) : const <Album>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 160.h),
      clipBehavior: Clip.hardEdge,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: HomeGreetingHeader(userInfo: userInfo),
        ),
        if (albums.isEmpty) ...[
          SizedBox(height: 12.h),
          emptyState,
        ],
        if (featured != null) ...[
          _FeaturedAlbumCard(
            album: featured,
            onTap: () async {
              final index = albums.indexOf(featured);
              onSelect(index);
              await onOpen(featured, index);
            },
          ),
          SizedBox(height: 16.h),
        ],
        if (rest.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rest.length,
            clipBehavior: Clip.none,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 14.w,
              childAspectRatio: 0.6,
            ),
            itemBuilder: (context, i) {
              final album = rest[i];
              final index = i + 1;
              return _GridAlbumCard(
                album: album,
                onTap: () async {
                  onSelect(index);
                  await onOpen(album, index);
                },
              );
            },
          ),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '앨범이 비어있습니다.',
        style: TextStyle(
          fontSize: 18.sp,
          color: SnapFitColors.textPrimaryOf(context).withOpacity(0.9),
        ),
      ),
    );
  }
}

class _FeaturedAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _FeaturedAlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final created = formatAlbumDate(album.createdAt);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: SnapFitColors.isDark(context)
              ? SnapFitColors.surfaceOf(context)
              : SnapFitColors.pureWhite,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeStatusChip(
                    label: 'LIVE EDITING',
                    background: SnapFitColors.accent.withOpacity(0.16),
                    foreground: SnapFitColors.accentLight,
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    album.coverTheme?.isNotEmpty == true
                        ? album.coverTheme!
                        : '앨범',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '$created 업데이트',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  HomeCollaboratorSummary(
                    count: 12,
                    textColor: SnapFitColors.textMutedOf(context),
                  ),
                  SizedBox(height: 12.h),
                  SnapFitPrimaryGradientBackground(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '편집 계속하기',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: SnapFitColors.pureWhite,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.arrow_forward,
                            size: 14.sp,
                            color: SnapFitColors.pureWhite,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: _AlbumCoverThumbnail(
                album: album,
                height: 96.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _GridAlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final coverUrl =
        album.coverThumbnailUrl ?? album.coverPreviewUrl ?? album.coverImageUrl;
    final hasCoverUrl = coverUrl?.isNotEmpty == true;
    final hasLayers = album.coverLayersJson.isNotEmpty;
    final hasTheme = album.coverTheme?.isNotEmpty == true;
    final showDraft = !(hasCoverUrl || hasLayers || hasTheme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color:
              isDark ? SnapFitColors.surfaceOf(context) : SnapFitColors.pureWhite,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDraft) ...[
              HomeStatusChip(
                label: 'DRAFT',
                background: isDark
                    ? SnapFitColors.overlayLightOf(context)
                    : const Color(0xFFF2F2F2),
                foreground: isDark
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.deepCharcoal,
              ),
              SizedBox(height: 10.h),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = parseCoverRatio(album.ratio);
                  final maxHeight = constraints.maxHeight;
                  final height = ratio > 1
                      ? maxHeight * 0.82
                      : maxHeight * 0.7;
                  return Align(
                    alignment: Alignment.center,
                    child: _AlbumCoverThumbnail(
                      album: album,
                      height: height,
                      maxWidth: constraints.maxWidth,
                    ),
                  );
                },
              ),
            ),
            Text(
              album.coverTheme?.isNotEmpty == true ? album.coverTheme! : '앨범',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.deepCharcoal,
              ),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 14.sp,
                  color: SnapFitColors.textMutedOf(context),
                ),
                SizedBox(width: 4.w),
                Text(
                  '공동작업자 12명',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 앨범 커버 썸네일
class _AlbumCoverThumbnail extends StatelessWidget {
  final Album album;
  final double height;
  final double? maxWidth;
  final bool showShadow;

  const _AlbumCoverThumbnail({
    required this.album,
    required this.height,
    this.maxWidth,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = parseCoverRatio(album.ratio);
    double width;
    double scaledHeight;
    final resolvedMaxWidth = maxWidth ?? (ratio > 1 ? 140.w : 150.w);
    if (ratio >= 1) {
      width = resolvedMaxWidth;
      scaledHeight = width / ratio;
      if (scaledHeight > height) {
        final scale = height / scaledHeight;
        scaledHeight = height;
        width = width * scale;
      }
    } else {
      scaledHeight = height;
      width = scaledHeight * ratio;
      if (width > resolvedMaxWidth) {
        final scale = resolvedMaxWidth / width;
        width = resolvedMaxWidth;
        scaledHeight = scaledHeight * scale;
      }
    }
    final shadowScale = (scaledHeight / 280).clamp(0.35, 0.7);
    final theme = resolveCoverTheme(album.coverTheme);
    final canvasSize = Size(width, scaledHeight);

    final layers = parseCoverLayers(
      album.coverLayersJson,
      canvasSize: canvasSize,
    );

    if (layers != null && layers.isNotEmpty) {
      return _CoverFrame(
        width: width,
        height: scaledHeight,
        shadowScale: shadowScale,
        showShadow: showShadow,
        child: CoverLayout(
          aspect: ratio,
          layers: layers,
          isInteracting: false,
          leftSpine: 12.w,
          onCoverSizeChanged: (_) {},
          buildImage: (layer) => buildStaticImage(layer),
          buildText: (layer) => buildStaticText(layer),
          sortedByZ: (list) => list..sort((a, b) => a.id.compareTo(b.id)),
          theme: theme,
        ),
      );
    }

    final imageUrl = album.coverThumbnailUrl ??
        album.coverPreviewUrl ??
        album.coverImageUrl;
    final hasUrl = imageUrl?.isNotEmpty == true;

    return _CoverFrame(
      width: width,
      height: scaledHeight,
      shadowScale: shadowScale,
      showShadow: showShadow,
      child: hasUrl
          ? SnapfitImage(
              urlOrGs: imageUrl!,
              fit: BoxFit.cover,
              cacheManager: snapfitImageCacheManager,
            )
          : Container(
              color: Colors.grey[300],
              child: Icon(
                Icons.photo_album_outlined,
                size: 28.sp,
                color: Colors.grey[600],
              ),
            ),
    );
  }
}

class _CoverFrame extends StatelessWidget {
  final double width;
  final double height;
  final double shadowScale;
  final bool showShadow;
  final Widget child;

  const _CoverFrame({
    required this.width,
    required this.height,
    required this.shadowScale,
    required this.showShadow,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.zero,
          ),
          boxShadow: showShadow
              ? HomeFocusWrap.coverStyleShadowForScale(shadowScale, 0.5)
              : null,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.zero,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 역할 배지
class _StatusChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: foreground,
        ),
      ),
    );
  }
}

/// 협업자 요약 표시
class _CollaboratorSummary extends StatelessWidget {
  final int count;
  final Color textColor;

  const _CollaboratorSummary({
    required this.count,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AvatarStack(borderColor: SnapFitColors.backgroundOf(context)),
        SizedBox(width: 8.w),
        Text(
          '공동작업자 $count명',
          style: TextStyle(
            fontSize: 11.sp,
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final Color borderColor;

  const _AvatarStack({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46.w,
      height: 20.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            child: _Dot(
              color: SnapFitColors.accent.withOpacity(0.6),
              borderColor: borderColor,
              size: 18.w,
            ),
          ),
          Positioned(
            left: 12.w,
            child: _Dot(
              color: SnapFitColors.accentLight.withOpacity(0.6),
              borderColor: borderColor,
              size: 18.w,
            ),
          ),
          Positioned(
            left: 24.w,
            child: _PlusDot(
              label: '+3',
              borderColor: borderColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 협업자 표시 점(디자인용 자리)
class _CollaboratorDots extends StatelessWidget {
  const _CollaboratorDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 6.w),
        _Dot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 6.w),
        _Dot(
          color: SnapFitColors.textMuted.withOpacity(0.7),
          borderColor: SnapFitColors.backgroundOf(context),
          size: 14.w,
        ),
        SizedBox(width: 8.w),
        _PlusDot(label: '+3', borderColor: SnapFitColors.backgroundOf(context)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final double size;

  const _Dot({
    required this.color,
    required this.borderColor,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.w),
      ),
    );
  }
}

class _PlusDot extends StatelessWidget {
  final String label;
  final Color borderColor;

  const _PlusDot({
    required this.label,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24.w,
      height: 24.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SnapFitColors.accent,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2.w),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.textPrimary,
        ),
      ),
    );
  }
}

List<BoxShadow> _homeCardShadow(BuildContext context) {
  final isDark = SnapFitColors.isDark(context);
  return [
    BoxShadow(
      color: isDark
          ? SnapFitColors.accent.withOpacity(0.22)
          : Colors.black.withOpacity(0.08),
      blurRadius: isDark ? 20.r : 28.r,
      offset: Offset(0, isDark ? 10.h : 16.h),
    ),
  ];
}

/// 홈 화면 우측 하단 새 앨범 버튼
class _CreateAlbumFab extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateAlbumFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'create_album_fab',
          onPressed: onPressed,
          backgroundColor: SnapFitColors.accent,
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        SizedBox(height: 6.h),
        Text(
          '앨범 만들기',
          style: TextStyle(
            fontSize: 11.sp,
            color: SnapFitColors.accentLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}



