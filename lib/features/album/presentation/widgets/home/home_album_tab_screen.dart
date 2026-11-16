import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/context_extensions.dart';
import '../../../../../core/utils/platform_ui.dart';
import '../../../../../shared/widgets/album_stage_style.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../../shared/widgets/viewport_sliver_layout_builder.dart';
import '../../../domain/entities/album.dart';
import '../../utils/home_album_section_builder.dart';
import '../../views/album_category_screen.dart';
import 'home_album_actions.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_header.dart';
import 'home_album_progress_builder.dart';
import '../../utils/album_progress.dart'
    show
        AlbumProgressLoader,
        AlbumProgressRequest,
        cachedAlbumProgress,
        albumCompletionCriteria;
import 'home_album_helpers.dart';

enum _AlbumFilter { all, working, completed }

class HomeAlbumTabScreen extends ConsumerStatefulWidget {
  const HomeAlbumTabScreen({
    super.key,
    required this.allAlbums,
    required this.currentUserId,
    required this.albumTabIndex,
    required this.favoriteAlbumIds,
    required this.onAlbumTabChanged,
    required this.onToggleFavorite,
    required this.onRefresh,
    this.showHeader = true,
    this.scrollController,
    this.onShowCovers,
    this.onCreateAlbum,
    this.onResumeDraft,
    this.footer,
  });
  final List<Album> allAlbums;
  final String currentUserId;
  final int albumTabIndex;
  final Set<int> favoriteAlbumIds;
  final ValueChanged<int> onAlbumTabChanged, onToggleFavorite;
  final Future<void> Function() onRefresh;
  final bool showHeader;
  final ScrollController? scrollController;
  final VoidCallback? onShowCovers, onCreateAlbum, onResumeDraft;
  final Widget? footer;

  @override
  ConsumerState<HomeAlbumTabScreen> createState() => _HomeAlbumTabScreenState();
}

class _HomeAlbumTabScreenState extends ConsumerState<HomeAlbumTabScreen>
    with WidgetsBindingObserver {
  ScrollController? _localScroll;
  ScrollController get _scroll =>
      widget.scrollController ?? (_localScroll ??= ScrollController());
  AlbumProgressRequest? _filterRequest;
  late HomeAlbumTabPreparedData _data;
  List<Album> _preparedAlbums = const [];
  late Set<int> _preparedFavorites;
  List<Album> _visibleAlbums = const [];
  _AlbumFilter _filter = _AlbumFilter.all;
  bool _listView = false;
  bool _filtering = false;
  bool _viewActive = false;
  bool _foreground = true;
  bool get _active => _viewActive && _foreground;
  int _filterVersion = 0;
  int? _filterFrame;
  int _filterIndex = 0;
  List<Album> _filterMatches = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _prepareData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_viewActive == active) return;
    _viewActive = active;
    if (!_active) {
      _cancelFilterBatch();
    } else if (_filtering) {
      _queueFilter();
    }
  }

  @override
  void didUpdateWidget(covariant HomeAlbumTabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!sameHomeAlbumSequence(_preparedAlbums, widget.allAlbums) ||
        oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.albumTabIndex != widget.albumTabIndex ||
        !setEquals(_preparedFavorites, widget.favoriteAlbumIds)) {
      _prepareData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelFilterBatch();
    _localScroll?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_active) {
      _cancelFilterBatch();
    } else if (_filtering) {
      _queueFilter();
    }
  }

  void _prepareData() {
    if (!sameHomeAlbumSequence(_preparedAlbums, widget.allAlbums)) {
      _preparedAlbums = List.of(widget.allAlbums);
    }
    _preparedFavorites = Set.of(widget.favoriteAlbumIds);
    _data = buildHomeAlbumTabData(
      allAlbums: _preparedAlbums,
      currentUserId: widget.currentUserId,
      favoriteAlbumIds: _preparedFavorites,
      albumTabIndex: widget.albumTabIndex,
    );
    _updateFilter();
  }

  void _updateFilter() {
    _cancelFilterBatch();
    // Initial entry reuses the prepared order without scanning every document
    // for completeness. Classify only if the user requests a status filter.
    _visibleAlbums = _filter == _AlbumFilter.all ? _data.tabAlbums : const [];
    _filtering = _filter != _AlbumFilter.all;
    if (_filtering && _active) _queueFilter();
  }

  void _cancelFilterBatch() {
    _filterVersion++;
    _filterRequest?.cancel();
    _filterRequest = null;
    final frame = _filterFrame;
    if (frame != null) WidgetsBinding.instance.cancelFrameCallbackWithId(frame);
    _filterFrame = null;
    _filterIndex = 0;
    _filterMatches = [];
  }

  void _queueFilter() {
    if (!_active ||
        !_filtering ||
        _filterFrame != null ||
        _filterRequest != null)
      return;
    final version = _filterVersion;
    _filterFrame = WidgetsBinding.instance.scheduleFrameCallback((_) {
      _filterFrame = null;
      if (!mounted || !_active || version != _filterVersion) return;
      final source = _data.tabAlbums;
      final budget = Stopwatch()..start();
      var batchSize = 0;
      while (_filterIndex < source.length) {
        final album = source[_filterIndex];
        // Unknown progress is loaded serially off the frame path, shared with
        // visible captions. Metadata-only cases don't decode any document.
        // A legacy album may omit targetPages while its document contains every
        // interior. Resolve its target from the same metadata as cover captions.
        final known = isDraftAlbum(album);
        final progress = known ? null : cachedAlbumProgress(album);
        if (!known && progress == null) {
          final request = AlbumProgressLoader.request(album);
          _filterRequest = request;
          request.result.then((result) {
            if (!mounted || !_active || version != _filterVersion) return;
            _filterRequest = null;
            if (result != null) {
              if ((_filter == _AlbumFilter.completed) == result.isCompleted) {
                _filterMatches.add(album);
              }
              _filterIndex++;
            }
            _queueFilter();
          });
          return;
        }
        final completed = progress?.isCompleted ?? false;
        if ((_filter == _AlbumFilter.completed) == completed)
          _filterMatches.add(album);
        _filterIndex++;
        // Cached/metadata-only decisions stay bounded to a small frame batch.
        if (++batchSize >= 64 || budget.elapsedMilliseconds >= 2) break;
      }
      if (_filterIndex < source.length) {
        _queueFilter();
      } else {
        setState(() {
          _visibleAlbums = _filterMatches;
          _filterMatches = [];
          _filtering = false;
        });
      }
    });
  }

  void _selectFilter(_AlbumFilter next) {
    if (_filter == next) return;
    HapticFeedback.selectionClick();
    setState(() {
      _filter = next;
      _updateFilter();
    });
  }

  void _setListView(bool value) {
    if (_listView == value) return;
    HapticFeedback.selectionClick();
    setState(() => _listView = value);
  }

  void _openSearch() => Navigator.push<void>(
    context,
    snapFitRoute(
      page: AlbumCategoryScreen(
        category: AlbumCategory.recent,
        initialAlbums: _data.allAlbums,
        currentUserId: widget.currentUserId,
        initialTabIndex: 0,
      ),
    ),
  );

  Future<void> _openAlbum(Album album) async {
    try {
      await HomeAlbumActions.openAlbum(
        context,
        ref,
        album,
        canContinue: () =>
            mounted &&
            _active &&
            widget.allAlbums.any((current) => current.id == album.id),
      );
    } catch (_) {
      if (mounted) context.showErrorSnack('앨범을 열 수 없습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) => PrimaryScrollController(
    controller: _scroll,
    automaticallyInheritForPlatforms: const {},
    child: Column(
      children: [
        if (widget.showHeader)
          HomeAlbumHeader(
            collection: true,
            onToggleView: widget.onShowCovers,
            onCreateAlbum: widget.onCreateAlbum,
            onResumeDraft: widget.onResumeDraft,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: CustomScrollView(
              controller: _scroll,
              primary: false,
              key: PageStorageKey(
                'home-album-collection-${_listView ? 'list' : 'grid'}-${_filter.name}',
              ),
              // Keep the same one-row prebuild budget as the original collection.
              cacheExtent: 280,
              physics: platformScrollPhysics(alwaysScrollable: true),
              slivers: [
                SliverToBoxAdapter(child: _buildCollectionTools(context)),
                if (_filtering)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        color: ExperienceFormStyle.selectionInk(context),
                        backgroundColor: ExperienceFormStyle.line(context),
                        semanticsLabel: '앨범 상태를 확인하고 있어요',
                      ),
                    ),
                  ),
                if (_visibleAlbums.isEmpty && widget.footer == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          _filtering
                              ? '앨범 상태를 확인하고 있어요.'
                              : _filter == _AlbumFilter.all
                              ? '아직 이곳에 모인 앨범이 없어요.'
                              : '이 상태의 앨범이 아직 없어요.',
                          textAlign: TextAlign.center,
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            secondary: true,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_visibleAlbums.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(
                        _filtering
                            ? '앨범 상태를 확인하고 있어요.'
                            : _filter == _AlbumFilter.all
                            ? '아직 이곳에 모인 앨범이 없어요.'
                            : '이 상태의 앨범이 아직 없어요.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          secondary: true,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                    sliver: ViewportSliverLayoutBuilder(
                      builder: (context, box) {
                        final textScaler = MediaQuery.textScalerOf(context);
                        final scale = textScaler.scale(14) / 14;
                        final metadataHeight =
                            math.max(48.0, textScaler.scale(14) * 1.4 * 2) +
                            textScaler.scale(12) * 1.5 +
                            textScaler.scale(11) * 1.5 +
                            10;
                        if (_listView) {
                          final extent = math.max(112.0, metadataHeight + 25);
                          return SliverFixedExtentList(
                            itemExtent: extent,
                            delegate: _albumDelegate(
                              (album) => _AlbumCollectionTile(
                                album: album,
                                list: true,
                                stageHeight: 88,
                                stageWidth: 76,
                                favorite: widget.favoriteAlbumIds.contains(
                                  album.id,
                                ),
                                onOpen: () => _openAlbum(album),
                                onToggleFavorite: () =>
                                    widget.onToggleFavorite(album.id),
                              ),
                            ),
                          );
                        }
                        final columns =
                            ((box.crossAxisExtent + 20) /
                                    (scale > 1.5 ? 250 : 146))
                                .floor()
                                .clamp(1, 5)
                                .toInt();
                        final width =
                            (box.crossAxisExtent - 20 * (columns - 1)) /
                            columns;
                        final stage = (width * 1.2)
                            .clamp(140.0, 250.0)
                            .toDouble();
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 22,
                                mainAxisExtent: stage + 12 + metadataHeight,
                              ),
                          delegate: _albumDelegate(
                            (album) => _AlbumCollectionTile(
                              album: album,
                              list: false,
                              stageHeight: stage,
                              stageWidth: width,
                              favorite: widget.favoriteAlbumIds.contains(
                                album.id,
                              ),
                              onOpen: () => _openAlbum(album),
                              onToggleFavorite: () =>
                                  widget.onToggleFavorite(album.id),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (widget.footer != null)
                  SliverToBoxAdapter(child: widget.footer),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  SliverChildBuilderDelegate _albumDelegate(
    Widget Function(Album album) buildTile,
  ) {
    final albums = _visibleAlbums;
    return SliverChildBuilderDelegate(
      (context, index) {
        final album = albums[index];
        return RepaintBoundary(
          key: ValueKey('home-collection-item-${album.id}'),
          child: buildTile(album),
        );
      },
      childCount: albums.length,
      addAutomaticKeepAlives: false,
      // Each tile already owns its boundary; don't allocate a second layer.
      addRepaintBoundaries: false,
    );
  }

  Widget _buildCollectionTools(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _filtering ? '앨범 확인 중' : '앨범 ${_visibleAlbums.length}권',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(context, 13, secondary: true),
                ),
              ),
            ),
            IconButton(
              tooltip: '앨범 검색 및 관리',
              onPressed: _openSearch,
              icon: const ExperienceIcon('Search', size: 20),
            ),
            const SizedBox(width: 4),
            Material(
              color: AlbumStageStyle.controlFill(context),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CollectionViewButton(
                      key: const ValueKey('home-collection-view-grid'),
                      selected: !_listView,
                      label: '표지 격자로 보기',
                      icon: const ExperienceIcon('LayoutGrid', size: 18),
                      onTap: () => _setListView(false),
                    ),
                    _CollectionViewButton(
                      key: const ValueKey('home-collection-view-list'),
                      selected: _listView,
                      label: '목록으로 보기',
                      icon: const ExperienceIcon('List', size: 21),
                      onTap: () => _setListView(true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ExperienceFormStyle.line(context)),
              ),
            ),
            child: Wrap(
              spacing: 16,
              children: [
                for (final filter in _AlbumFilter.values)
                  _CollectionFilterButton(
                    selected: _filter == filter,
                    label: switch (filter) {
                      _AlbumFilter.all => '전체',
                      _AlbumFilter.working => '만드는 중',
                      _AlbumFilter.completed => '완성',
                    },
                    onTap: () => _selectFilter(filter),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CollectionViewButton extends StatelessWidget {
  const _CollectionViewButton({
    super.key,
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.surface
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      icon: icon,
    ),
  );
}

class _CollectionFilterButton extends StatelessWidget {
  const _CollectionFilterButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            width: 2,
            color: selected
                ? ExperienceFormStyle.selectionInk(context)
                : Colors.transparent,
          ),
        ),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          foregroundColor: selected
              ? ExperienceFormStyle.ink(context)
              : ExperienceFormStyle.muted(context),
          textStyle: ExperienceFormStyle.text(
            context,
            13,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        child: Text(label),
      ),
    ),
  );
}

class _AlbumCollectionTile extends StatelessWidget {
  const _AlbumCollectionTile({
    required this.album,
    required this.list,
    required this.stageHeight,
    required this.stageWidth,
    required this.favorite,
    required this.onOpen,
    required this.onToggleFavorite,
  });
  final Album album;
  final bool list, favorite;
  final double stageHeight, stageWidth;
  final VoidCallback onOpen, onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final title = album.title.trim().isEmpty ? '제목 없는 앨범' : album.title;
    final artwork = SizedBox(
      height: stageHeight,
      width: stageWidth,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Center(
          child: HomeAlbumCoverThumbnail(
            album: album,
            height: math.max(1.0, stageHeight - 16),
            maxWidth: math.max(1.0, stageWidth - 16),
            showBookDepth: true,
            shadowScaleMultiplier: .6,
          ),
        ),
      ),
    );
    final metadata = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Tooltip(
                message: title,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.4, letterSpacing: -.3),
                ),
              ),
            ),
            IconButton(
              tooltip: favorite ? '즐겨찾기 해제' : '즐겨찾기',
              onPressed: onToggleFavorite,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.all(10),
              icon: Icon(
                favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
                color: favorite
                    ? ExperienceFormStyle.selectionInk(context)
                    : ExperienceFormStyle.muted(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        HomeAlbumProgressBuilder(
          album: album,
          builder: (context, progress) {
            final status = !album.allowsEditing
                ? '보기 전용'
                : progress == null
                ? '상태 확인 중'
                : !isDraftAlbum(album) && progress.isCompleted
                ? '완성'
                : '만드는 중';
            return Tooltip(
              message: albumCompletionCriteria,
              child: Text(
                progress == null
                    ? '$status${!album.allowsEditing ? ' · 상태 확인 중' : ''}'
                    : '$status · ${progress.completedPages}쪽',
                semanticsLabel: progress == null
                    ? '앨범 상태 확인 중'
                    : '$status, ${progress.pageProgressLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExperienceFormStyle.text(
                  context,
                  12,
                  color: ExperienceFormStyle.selectionInk(context),
                ).copyWith(height: 1.5),
              ),
            );
          },
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
          ).copyWith(height: 1.5),
        ),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('home-collection-album-${album.id}'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: list
            ? DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ExperienceFormStyle.line(context),
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      artwork,
                      const SizedBox(width: 16),
                      Expanded(child: metadata),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [artwork, const SizedBox(height: 12), metadata],
              ),
      ),
    );
  }
}
