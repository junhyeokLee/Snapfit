import 'package:flutter/material.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/album_stage_style.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../social/presentation/views/social_feed_screen.dart';
import '../../../social/presentation/views/social_profile_screen.dart';
import '../widgets/home/home_album_destination.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../viewmodels/home_view_model.dart';
import 'album_create_flow_screen.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../../store/presentation/views/store_hub_screen.dart';
import '../providers/home_ui_state_provider.dart';
import '../utils/album_creation_entry.dart';
import '../widgets/create_flow/album_creation_start_sheet.dart';
import '../../data/album_creation_draft_store.dart';
import '../../domain/entities/album_creation_draft.dart';
import '../web/web_album_library_screen.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';
import '../../../../shared/widgets/deferred_content.dart';
import '../../../home_news/presentation/widgets/home_news_gate.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final List<int> _bottomNavHistory;
  final _destinationBodyKey = GlobalKey();
  final _coverScroll = ScrollController();
  final _collectionScroll = ScrollController();
  ScrollController? _fallbackScroll;
  bool _creatingAlbum = false;
  final _visitedDestinations = <int>{};

  @override
  void initState() {
    super.initState();
    _bottomNavHistory = [ref.read(homeUiStateProvider).bottomNavIndex];
    ScreenLogger.enter('HomeScreen', '앨범 · 스토어');
  }

  @override
  void dispose() {
    _coverScroll.dispose();
    _collectionScroll.dispose();
    _fallbackScroll?.dispose();
    super.dispose();
  }

  Future<void> _resumeDraft(AlbumCreationDraft draft) =>
      _createAlbum(requestedDraftId: draft.id);

  Future<void> _createAlbum({String? requestedDraftId}) async {
    if (_creatingAlbum) return;
    _creatingAlbum = true;
    final destination = ref.read(homeUiStateProvider).bottomNavIndex;
    try {
      // 초안의 명시적 이어쓰기는 선택 화면을 건너뛰고 기존 복구 경로를 따른다.
      final startMode = requestedDraftId == null
          ? await showAlbumCreationStartSheet(context)
          : null;
      if (!mounted ||
          (requestedDraftId == null && startMode == null) ||
          ref.read(homeUiStateProvider).bottomNavIndex != destination)
        return;
      final decision = await resolveAlbumCreationEntry(
        context,
        ref,
        requestedDraftId: requestedDraftId,
        isStillCurrent: () =>
            mounted &&
            ref.read(homeUiStateProvider).bottomNavIndex == destination,
      );
      if (!mounted || decision == null) return;
      final created = await Navigator.push(
        context,
        snapFitRoute(page: AlbumCreateFlowScreen(
            initialDraft: decision.draft,
            initialStartMode: decision.draft == null ? startMode : null,
          ), settings: const WebAppRouteSettings(WebAppLocation.create)),
      );
      if (!mounted) return;
      ref.invalidate(albumCreationDraftProvider);
      if (created == true) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    } finally {
      _creatingAlbum = false;
    }
  }

  void _handleBottomNavTap(int index) {
    final uiStateNotifier = ref.read(homeUiStateProvider.notifier);
    final currentIndex = ref.read(homeUiStateProvider).bottomNavIndex;
    if (currentIndex == index) return;
    HapticFeedback.selectionClick();

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
    final bottomNavIndex = ref.watch(
      homeUiStateProvider.select((state) => state.bottomNavIndex),
    );
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    Future<void> handleCreateAlbum() => _createAlbum();

    final baseBackground = SnapFitColors.backgroundOf(context);
    final homeBackground = bottomNavIndex == 0
        ? AlbumStageStyle.top(context)
        : baseBackground;
    final homeOverlayStyle = AlbumStageStyle.overlay(context);
    final albumDestination = bottomNavIndex == 0 || bottomNavIndex == 1;
    final primaryScroll = bottomNavIndex == 0
        ? _coverScroll
        : bottomNavIndex == 1
        ? _collectionScroll
        : PrimaryScrollController.maybeOf(context) ??
              (_fallbackScroll ??= ScrollController());

    final content = AnnotatedRegion<SystemUiOverlayStyle>(
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
              currentBottomNavIndex: bottomNavIndex,
              homeBody: (context) => DeferredContent(
                placeholder: SafeArea(
                  child: SnapFitShimmerHomeSlider(
                    scrollController: bottomNavIndex == 1
                        ? _collectionScroll
                        : _coverScroll,
                  ),
                ),
                builder: (_) => HomeAlbumDestination(
                  showCollection: bottomNavIndex == 1,
                  insetLeft: !isLandscape,
                  onCreateAlbum: handleCreateAlbum,
                  onResumeDraft: _resumeDraft,
                  onOpenAlbumTab: () => _handleBottomNavTap(1),
                  onShowAlbumCovers: () => _handleBottomNavTap(0),
                  coverScrollController: _coverScroll,
                  collectionScrollController: _collectionScroll,
                ),
              ),
            );
            // Keep carousel selection and catalog filters when navigation moves to a rail.
            final body = KeyedSubtree(
              key: _destinationBodyKey,
              child: destination,
            );

            return PrimaryScrollController(
              controller: primaryScroll,
              // Explicit controllers below keep hidden views independent.
              // The active controller is still available to header shortcuts
              // and Scaffold's iOS scroll-to-top action.
              automaticallyInheritForPlatforms: albumDestination
                  ? const {}
                  : const {
                      TargetPlatform.android,
                      TargetPlatform.iOS,
                      TargetPlatform.fuchsia,
                    },
              child: Scaffold(
                extendBody: true,
                backgroundColor: bottomNavIndex == 0
                    ? homeBackground
                    : baseBackground,
                bottomNavigationBar: isLandscape
                    ? null
                    : HomeBottomNavigationBar(
                        currentIndex: bottomNavIndex,
                        onTap: _handleBottomNavTap,
                      ),
                body: ExperienceNavigationScope(
                  onNavigate: _handleBottomNavTap,
                  onBack: _handleSystemBack,
                  child: isLandscape
                      ? Row(
                          children: [
                            HomeBottomNavigationBar(
                              currentIndex: bottomNavIndex,
                              onTap: _handleBottomNavTap,
                              rail: true,
                            ),
                            Expanded(child: body),
                          ],
                        )
                      : body,
                ),
              ),
            );
          },
        ),
      ),
    );
    return HomeNewsGate(active: bottomNavIndex == 0, child: content);
  }

  Widget _buildBottomNavBody(
    BuildContext context, {
    required int currentBottomNavIndex,
    required WidgetBuilder homeBody,
  }) {
    final index = switch (currentBottomNavIndex) {
      1 => 0,
      5 => 2,
      _ => currentBottomNavIndex,
    };
    _visitedDestinations.add(index);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final destination in _visitedDestinations)
          RetainedDestination(
            key: ValueKey('home-destination-$destination'),
            active: destination == index,
            builder: (context) => switch (destination) {
              0 => homeBody(context),
              2 => StoreHubScreen(
                key: const ValueKey('store-hub'),
                initialMaterials: currentBottomNavIndex == 5,
              ),
              3 => const NotificationScreen(),
              4 => const SocialProfileScreen(),
              6 => const MaterialCatalogScreen(library: true),
              7 => const SocialFeedScreen(),
              _ => homeBody(context),
            },
          ),
      ],
    );
  }
}
