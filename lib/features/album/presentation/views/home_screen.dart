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
import '../widgets/home/home_create_album_fab.dart';
import '../widgets/home/home_album_card_tone.dart';
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
  Color? _focusedHomeAlbumTone;

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

  void _onFocusedHomeAlbumChanged(Album album) {
    final baseTone = albumCardToneOrNull(album);
    final nextTone = baseTone != null
        ? softenedHomeBackgroundToneForBrightness(
            baseTone,
            Theme.of(context).brightness,
          )
        : null;
    if (_focusedHomeAlbumTone == nextTone) return;
    if (!mounted) return;
    setState(() => _focusedHomeAlbumTone = nextTone);
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
    final homeBackground = _focusedHomeAlbumTone ?? baseBackground;

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
        floatingActionButton: uiState.bottomNavIndex == 0
            ? HomeCreateAlbumFab(onPressed: handleCreateAlbum)
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: _buildBottomNavBody(
          context,
          currentBottomNavIndex: uiState.bottomNavIndex,
          homeBody: Container(
            color: uiState.bottomNavIndex == 0 ? homeBackground : baseBackground,
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
                  if (prepared.baseAlbums.isEmpty &&
                      _focusedHomeAlbumTone != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted || _focusedHomeAlbumTone == null) return;
                      setState(() => _focusedHomeAlbumTone = null);
                    });
                  }
                  final homeContent = RefreshIndicator(
                    onRefresh: _handlePullToRefresh,
                    child: CustomScrollView(
                      physics: platformScrollPhysics(alwaysScrollable: true),
                      slivers: [
                        if (prepared.baseAlbums.isNotEmpty) ...[
                          SliverToBoxAdapter(child: SizedBox(height: 14.h)),
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.h),
                                child: SizedBox(
                                  width: double.infinity,
                                  height:
                                      (MediaQuery.sizeOf(context).height * 0.54)
                                          .clamp(360.0, 640.0),
                                  child: HomeAlbumSlider(
                                    albums:
                                        List<Album>.from(prepared.baseAlbums)
                                          ..sort(compareAlbumByLatestDesc),
                                    onFocusedAlbumChanged:
                                        _onFocusedHomeAlbumChanged,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ] else
                          SliverToBoxAdapter(
                            child: SizedBox(
                              height: (MediaQuery.sizeOf(context).height * 0.68)
                                  .clamp(420.0, 760.0),
                              child: HomeEmptyState(onCreate: handleCreateAlbum),
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
