import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../domain/entities/album.dart';
import '../widgets/home/home_album_slider.dart';
import '../widgets/home/home_album_tab_screen.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../widgets/home/home_empty_state.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/home_error_state.dart';
import 'album_create_flow_screen.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../../store/presentation/views/store_screen.dart';
import '../providers/home_ui_state_provider.dart';
import '../utils/home_album_section_builder.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _favoriteKey = 'album_favorite_ids_v1';
  Set<int> _favoriteAlbumIds = <int>{};
  final List<int> _bottomNavHistory = <int>[0];

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('HomeScreen', '홈 · 중앙 앨범 캐러셀');
    _loadFavoriteAlbumIds();
  }

  Future<void> _loadFavoriteAlbumIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoriteKey) ?? const <String>[];
    final ids = raw.map(int.tryParse).whereType<int>().toSet();
    if (!mounted) return;
    setState(() => _favoriteAlbumIds = ids);
  }

  Future<void> _toggleFavorite(int albumId) async {
    final next = Set<int>.from(_favoriteAlbumIds);
    if (next.contains(albumId)) {
      next.remove(albumId);
    } else {
      next.add(albumId);
    }
    setState(() => _favoriteAlbumIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteKey,
      next.map((e) => e.toString()).toList(),
    );
  }

  Future<void> _handlePullToRefresh() async {
    ref.invalidate(notificationUnreadCountProvider);
    await ref.read(homeViewModelProvider.notifier).refresh();
  }

  void _handleBottomNavTap(int index) {
    final uiStateNotifier = ref.read(homeUiStateProvider.notifier);
    final currentIndex = ref.read(homeUiStateProvider).bottomNavIndex;
    if (currentIndex == index) return;

    final existingIndex = _bottomNavHistory.lastIndexOf(index);
    if (existingIndex != -1) {
      _bottomNavHistory.removeAt(existingIndex);
    }
    _bottomNavHistory.add(index);
    uiStateNotifier.setBottomNavIndex(index);

    if (index == 3) {
      ref.invalidate(notificationUnreadCountProvider);
    }
  }

  void _handleSystemBack() {
    if (_bottomNavHistory.length <= 1) {
      return;
    }
    _bottomNavHistory.removeLast();
    final previousIndex = _bottomNavHistory.last;
    ref.read(homeUiStateProvider.notifier).setBottomNavIndex(previousIndex);
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
    final unreadNotificationCount = ref.watch(notificationUnreadCountProvider);
    final uiState = ref.watch(homeUiStateProvider);
    final uiStateNotifier = ref.read(homeUiStateProvider.notifier);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final hasUnreadNotification = unreadNotificationCount.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );
    Future<void> handleCreateAlbum() async {
      final created = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AlbumCreateFlowScreen()),
      );
      if (created == true && context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    }

    final baseBackground = SnapFitColors.backgroundOf(context);
    final homeBackground = baseBackground;

    return PopScope(
      canPop: !isAndroid || _bottomNavHistory.length <= 1,
      onPopInvoked: (didPop) {
        if (!isAndroid || didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
        backgroundColor: uiState.bottomNavIndex == 0
            ? homeBackground
            : baseBackground,
        bottomNavigationBar: HomeBottomNavigationBar(
          currentIndex: uiState.bottomNavIndex,
          hasUnreadNotification: hasUnreadNotification,
          onTap: _handleBottomNavTap,
        ),
        floatingActionButton: null,
        body: _buildBottomNavBody(
          context,
          currentBottomNavIndex: uiState.bottomNavIndex,
          homeBody: Container(
            color: uiState.bottomNavIndex == 0
                ? homeBackground
                : baseBackground,
            child: SafeArea(
              // SafeArea applied to the whole body
              child: albumsAsync.when(
                data: (albums) {
                  final currentUserId =
                      authAsync.asData?.value?.id.toString() ?? '';
                  final prepared = buildHomeAlbumsData(
                    albums: albums,
                    currentUserId: currentUserId,
                  );
                  final homeContent = RefreshIndicator(
                    onRefresh: _handlePullToRefresh,
                    child: CustomScrollView(
                      physics: platformScrollPhysics(alwaysScrollable: true),
                      slivers: [
                        if (prepared.baseAlbums.isNotEmpty) ...[
                          SliverToBoxAdapter(child: SizedBox(height: 18.h)),
                          SliverToBoxAdapter(
                            child: _buildHomeHeroHeader(context),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 14.h)),
                          SliverToBoxAdapter(
                            child: SizedBox(
                              width: double.infinity,
                              height: (MediaQuery.sizeOf(context).height * 0.47)
                                  .clamp(330.0, 560.0),
                              child: HomeAlbumSlider(
                                albums: List<Album>.from(prepared.baseAlbums)
                                  ..sort(compareAlbumByLatestDesc),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 18.h)),
                          SliverToBoxAdapter(
                            child: _buildHomePrimaryCta(
                              context,
                              onPressed: handleCreateAlbum,
                            ),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                        ] else
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: (MediaQuery.sizeOf(context).height * 0.68)
                                  .clamp(420.0, 760.0),
                              child: HomeEmptyState(
                                onCreate: handleCreateAlbum,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );

                  final albumTabContent = HomeAlbumTabScreen(
                    allAlbums: prepared.myRecordsAlbums,
                    currentUserId: currentUserId,
                    albumTabIndex: uiState.albumTabIndex,
                    favoriteAlbumIds: _favoriteAlbumIds,
                    onAlbumTabChanged: uiStateNotifier.setAlbumTabIndex,
                    onToggleFavorite: _toggleFavorite,
                    onRefresh: _handlePullToRefresh,
                  );

                  return uiState.bottomNavIndex == 1
                      ? albumTabContent
                      : homeContent;
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: SnapFitColors.accentLight,
                  ),
                ),
                error: (err, stack) => HomeErrorState(error: err),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeHeroHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : SnapFitColors.deepCharcoal)
                  .withOpacity(isDark ? 0.08 : 0.06),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              'SNAPFIT PHOTOBOOK',
              style: TextStyle(
                color: isDark
                    ? Colors.white.withOpacity(0.74)
                    : SnapFitColors.deepCharcoal.withOpacity(0.62),
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            '준자님의 추억을\n다시 펼쳐볼까요?',
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 26.sp,
              height: 1.18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          SizedBox(height: 9.h),
          Text(
            '사진 몇 장이면 포토북이 시작돼요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 14.sp,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomePrimaryCta(
    BuildContext context, {
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999.r),
          splashColor: Colors.white.withOpacity(0.12),
          highlightColor: Colors.white.withOpacity(0.08),
          child: Ink(
            height: 54.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999.r),
              gradient: const LinearGradient(
                colors: [Color(0xFF13C8EC), Color(0xFF8B5CF6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13C8EC).withOpacity(0.18),
                  blurRadius: 18.r,
                  offset: Offset(0, 9.h),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  color: SnapFitColors.pureWhite,
                  size: 20.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  '새 포토북 만들기',
                  style: TextStyle(
                    color: SnapFitColors.pureWhite,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBody(
    BuildContext context, {
    required int currentBottomNavIndex,
    required Widget homeBody,
  }) {
    switch (currentBottomNavIndex) {
      case 0:
      case 1:
        return homeBody;
      case 2:
        return const StoreScreen();
      case 3:
        return const NotificationScreen();
      case 4:
        return const MyPageScreen();
      default:
        return homeBody;
    }
  }
}
