import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/navigation/web_app_location.dart';
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
import '../../../store/presentation/views/store_hub_screen.dart';
import '../providers/home_ui_state_provider.dart';
import '../utils/home_album_section_builder.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../web/web_album_library_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _favoriteKey = 'album_favorite_ids_v1';
  Set<int> _favoriteAlbumIds = <int>{};
  final List<int> _bottomNavHistory = <int>[0];
  final _destinationBodyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('HomeScreen', kIsWeb ? '웹 · 앨범 보관함' : '홈 · 중앙 앨범 캐러셀');
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

  Future<void> _resumeDraft(AlbumCreationDraft draft) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: const WebAppRouteSettings(WebAppLocation.create),
        builder: (_) => AlbumCreateFlowScreen(initialDraft: draft),
      ),
    );
    if (mounted) ref.invalidate(albumCreationDraftProvider);
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
    if (kIsWeb) return const WebAlbumLibraryScreen();
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
    final draft = ref.watch(albumCreationDraftProvider).asData?.value;
    final unreadNotificationCount = ref.watch(notificationUnreadCountProvider);
    final uiState = ref.watch(homeUiStateProvider);
    final uiStateNotifier = ref.read(homeUiStateProvider.notifier);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final hasUnreadNotification = unreadNotificationCount.maybeWhen(
      data: (count) => count > 0,
      orElse: () => false,
    );
    Future<void> handleCreateAlbum() async {
      if (draft != null) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('만들던 앨범이 있어요'),
            content: Text(
              '${draft.title.trim().isEmpty ? '제목 없는 앨범' : draft.title}\n새 앨범을 임시 저장하면 기존 임시 저장을 대체해요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('새 앨범'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이어 만들기'),
              ),
            ],
          ),
        );
        if (!context.mounted || resume == null) return;
        if (resume) return _resumeDraft(draft);
      }
      final created = await Navigator.push(
        context,
        MaterialPageRoute(
          settings: const WebAppRouteSettings(WebAppLocation.create),
          builder: (_) => const AlbumCreateFlowScreen(),
        ),
      );
      if (created == true && context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    }

    final baseBackground = SnapFitColors.backgroundOf(context);
    final homeBackground = uiState.bottomNavIndex == 0
        ? AlbumStageStyle.top(context)
        : baseBackground;
    final homeOverlayStyle = AlbumStageStyle.overlay(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: homeOverlayStyle,
      child: PopScope(
        canPop: !isAndroid || _bottomNavHistory.length <= 1,
        onPopInvoked: (didPop) {
          if (!isAndroid || didPop) return;
          _handleSystemBack();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape =
                constraints.maxWidth >= 600 &&
                constraints.maxWidth > constraints.maxHeight;
            final destination = _buildBottomNavBody(
              context,
              currentBottomNavIndex: uiState.bottomNavIndex,
              homeBody: DecoratedBox(
                decoration: BoxDecoration(
                  color: uiState.bottomNavIndex == 0
                      ? AlbumStageStyle.top(context)
                      : baseBackground,
                  gradient: uiState.bottomNavIndex == 0
                      ? AlbumStageStyle.gradient(context)
                      : null,
                ),
                child: SafeArea(
                  left: !isLandscape,
                  // SafeArea applied to the whole body
                  child: albumsAsync.when(
                    data: (albums) {
                      final currentUserId =
                          authAsync.asData?.value?.id.toString() ?? '';
                      final prepared = buildHomeAlbumsData(
                        albums: albums,
                        currentUserId: currentUserId,
                      );
                      final sortedBaseAlbums = List<Album>.from(
                        prepared.baseAlbums,
                      )..sort(compareAlbumByLatestDesc);
                      final homeContent = sortedBaseAlbums.isNotEmpty
                          ? HomeAlbumSlider(
                              albums: sortedBaseAlbums,
                              onCreateAlbum: handleCreateAlbum,
                              onResumeDraft: draft == null
                                  ? null
                                  : () => _resumeDraft(draft),
                              onOpenAlbumTab: () => _handleBottomNavTap(1),
                            )
                          : HomeEmptyState(
                              onCreate: handleCreateAlbum,
                              onResumeDraft: draft == null
                                  ? null
                                  : () => _resumeDraft(draft),
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
                        color: SnapFitColors.accent,
                      ),
                    ),
                    error: (err, stack) {
                      final state = HomeErrorState(
                        error: err,
                        onRetry: _handlePullToRefresh,
                      );
                      return state;
                    },
                  ),
                ),
              ),
            );
            // Keep carousel selection and catalog filters when navigation moves to a rail.
            final body = KeyedSubtree(
              key: _destinationBodyKey,
              child: destination,
            );

            return Scaffold(
              backgroundColor: uiState.bottomNavIndex == 0
                  ? homeBackground
                  : baseBackground,
              bottomNavigationBar: isLandscape
                  ? null
                  : HomeBottomNavigationBar(
                      currentIndex: uiState.bottomNavIndex,
                      hasUnreadNotification: hasUnreadNotification,
                      onTap: _handleBottomNavTap,
                    ),
              body: ExperienceNavigationScope(
                onNavigate: _handleBottomNavTap,
                onBack: _handleSystemBack,
                child: isLandscape
                    ? Row(
                        children: [
                          HomeBottomNavigationBar(
                            currentIndex: uiState.bottomNavIndex,
                            hasUnreadNotification: hasUnreadNotification,
                            onTap: _handleBottomNavTap,
                            rail: true,
                          ),
                          Expanded(child: body),
                        ],
                      )
                    : body,
              ),
            );
          },
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
        return const StoreHubScreen(key: ValueKey('store-hub'));
      case 3:
        return const NotificationScreen();
      case 4:
        return const MyPageScreen();
      case 5:
        return const StoreHubScreen(
          key: ValueKey('store-materials-entry'),
          initialMaterials: true,
        );
      case 6:
        return const MaterialCatalogScreen(library: true);
      default:
        return homeBody;
    }
  }
}
