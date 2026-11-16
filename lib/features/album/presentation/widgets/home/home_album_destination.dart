import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/deferred_content.dart';
import '../../../../../shared/widgets/snapfit_shimmer.dart';
import '../../../../../core/navigation/web_app_location.dart';
import '../../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../auth/presentation/views/login_screen.dart';
import '../../../../notification/presentation/providers/notification_provider.dart';
import '../../../../onboarding/presentation/widgets/first_home_guide.dart';
import '../../../../moments/presentation/moments_navigation.dart';
import '../../../../moments/presentation/providers/moment_entry_refresh_provider.dart';
import '../../../../moments/presentation/providers/moments_providers.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/album_creation_draft.dart';
import '../../providers/home_ui_state_provider.dart';
import '../../utils/home_album_section_builder.dart';
import '../../viewmodels/home_view_model.dart';
import 'home_album_slider.dart';
import 'home_album_tab_screen.dart';
import 'home_album_header.dart';
import 'home_empty_state.dart';
import 'home_error_state.dart';
import 'home_moment_summary_card.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

/// Album responses and local preferences update this destination, not the
/// navigation shell or an unrelated store destination.
class HomeAlbumDestination extends ConsumerStatefulWidget {
  const HomeAlbumDestination({
    super.key,
    required this.showCollection,
    required this.insetLeft,
    required this.onCreateAlbum,
    required this.onResumeDraft,
    required this.onOpenAlbumTab,
    required this.onShowAlbumCovers,
    required this.coverScrollController,
    required this.collectionScrollController,
  });

  final bool showCollection;
  final bool insetLeft;
  final Future<void> Function() onCreateAlbum;
  final Future<void> Function(AlbumCreationDraft) onResumeDraft;
  final VoidCallback onOpenAlbumTab;
  final VoidCallback onShowAlbumCovers;
  final ScrollController coverScrollController, collectionScrollController;

  @override
  ConsumerState<HomeAlbumDestination> createState() =>
      _HomeAlbumDestinationState();
}

class _HomeAlbumDestinationState extends ConsumerState<HomeAlbumDestination> {
  static const _favoriteKey = 'album_favorite_ids_v1';
  Set<int> _favoriteAlbumIds = {};
  final _visitedViews = <int>{};
  List<Album>? _preparedSource;
  String? _preparedOwner;
  HomeAlbumsPreparedData? _preparedAlbums;
  Widget? _content;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoriteKey) ?? const <String>[];
    final ids = raw.map(int.tryParse).whereType<int>().toSet();
    if (mounted) setState(() => _favoriteAlbumIds = ids);
  }

  Future<void> _toggleFavorite(int albumId) async {
    final next = Set<int>.from(_favoriteAlbumIds);
    if (!next.remove(albumId)) next.add(albumId);
    setState(() => _favoriteAlbumIds = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoriteKey,
      next.map((id) => id.toString()).toList(),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(notificationUnreadCountProvider);
    ref.invalidate(momentsMonthProvider);
    ref.invalidate(momentEntryJournalProvider);
    await ref.read(homeViewModelProvider.notifier).refresh();
  }

  // Temporary bodies and the collection footer must not consume the guide.
  Widget _journalSummary({bool showFirstUseGuide = true}) =>
      HomeMomentSummaryCard(
        onRecord: () => openMomentCompose(context, ref),
        firstUseGuide: showFirstUseGuide
            ? FirstHomeGuide(
                onRecord: () => openMomentCompose(context, ref),
                onCreate: widget.onCreateAlbum,
              )
            : null,
        onOpenMonth: () => openMoments(
          context,
          initialMonth: ref
              .read(momentEntryJournalProvider)
              .asData
              ?.value
              ?.month,
        ),
        onSignIn: () => Navigator.of(context).push<void>(
          snapFitRoute<void>(page: const LoginScreen(), settings: const WebAppRouteSettings(WebAppLocation.login)),
        ),
        onOpenDate: (date) =>
            openMoments(context, initialMonth: date, initialDate: date),
      );

  HomeAlbumsPreparedData _prepare(List<Album> albums, String owner) {
    if (!identical(albums, _preparedSource) || owner != _preparedOwner) {
      _preparedSource = albums;
      _preparedOwner = owner;
      _preparedAlbums = buildHomeAlbumsData(
        albums: albums,
        currentUserId: owner,
      );
    }
    return _preparedAlbums!;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the latest provider snapshots subscribed while hidden, but postpone
    // sorting and rebuilding the album views until this destination is shown.
    final albums = ref.watch(homeViewModelProvider);
    final owner = ref.watch(
      authViewModelProvider.select((state) => state.asData?.value?.id ?? ''),
    );
    final albumTabIndex = ref.watch(
      homeUiStateProvider.select((state) => state.albumTabIndex),
    );
    final active = TickerMode.of(context);
    final activeScroll = widget.showCollection
        ? widget.collectionScrollController
        : widget.coverScrollController;
    if (!active) {
      return _content ??
          SnapFitShimmerHomeSlider(scrollController: activeScroll);
    }

    return _content = PrimaryScrollController(
      controller: activeScroll,
      automaticallyInheritForPlatforms: const {},
      child: DecoratedBox(
        key: const ValueKey('home-album-stage-background'),
        decoration: BoxDecoration(
          color: AlbumStageStyle.top(context),
          gradient: AlbumStageStyle.gradient(context),
        ),
        child: SafeArea(
          left: widget.insetLeft,
          child: Column(
            children: [
              HomeAlbumHeader(
                collection: widget.showCollection,
                onToggleView: widget.showCollection
                    ? widget.onShowAlbumCovers
                    : widget.onOpenAlbumTab,
                onCreateAlbum: widget.onCreateAlbum,
              ),
              Expanded(
                child: albums.when(
                  data: (albums) {
                    final prepared = _prepare(albums, owner);
                    final view = widget.showCollection ? 1 : 0;
                    _visitedViews.add(view);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        for (final destination in _visitedViews)
                          RetainedDestination(
                            key: ValueKey('home-album-view-$destination'),
                            active: destination == view,
                            builder: (_) => DeferredContent(
                              placeholder: destination == 0
                                  ? SnapFitShimmerHomeSlider(
                                      scrollController:
                                          widget.coverScrollController,
                                      leadingContent: _journalSummary(
                                        showFirstUseGuide: false,
                                      ),
                                    )
                                  : SingleChildScrollView(
                                      controller:
                                          widget.collectionScrollController,
                                      primary: false,
                                      child:
                                          const SnapFitShimmerTemplateTileGrid(
                                            rows: 2,
                                          ),
                                    ),
                              builder: (_) => destination == 1
                                  ? HomeAlbumTabScreen(
                                      showHeader: false,
                                      scrollController:
                                          widget.collectionScrollController,
                                      allAlbums: prepared.myRecordsAlbums,
                                      currentUserId: owner,
                                      albumTabIndex: albumTabIndex,
                                      favoriteAlbumIds: _favoriteAlbumIds,
                                      onAlbumTabChanged: ref
                                          .read(homeUiStateProvider.notifier)
                                          .setAlbumTabIndex,
                                      onToggleFavorite: _toggleFavorite,
                                      onRefresh: _refresh,
                                      footer: _journalSummary(
                                        showFirstUseGuide: false,
                                      ),
                                    )
                                  : prepared.myRecordsAlbums.isEmpty
                                  ? HomeEmptyState(
                                      scrollController:
                                          widget.coverScrollController,
                                      onCreate: widget.onCreateAlbum,
                                      leadingContent: _journalSummary(),
                                    )
                                  : HomeAlbumSlider(
                                      showHeader: false,
                                      scrollController:
                                          widget.coverScrollController,
                                      albums: prepared.myRecordsAlbums,
                                      onCreateAlbum: widget.onCreateAlbum,
                                      onOpenAlbumTab: widget.onOpenAlbumTab,
                                      // Keep daily recording first, then the
                                      // full-size album and its compact selector.
                                      leadingContent: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 24,
                                        ),
                                        child: _journalSummary(),
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => SnapFitShimmerHomeSlider(
                    scrollController: activeScroll,
                    leadingContent: _journalSummary(showFirstUseGuide: false),
                  ),
                  error: (error, _) => HomeErrorState(
                    error: error,
                    onRetry: _refresh,
                    scrollController: activeScroll,
                    leadingContent: _journalSummary(showFirstUseGuide: false),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
