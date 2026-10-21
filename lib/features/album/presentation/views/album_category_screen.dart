import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../domain/entities/album.dart';
import '../../data/api/album_provider.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_album_helpers.dart';
import '../widgets/web/web_saved_album_artwork.dart';
import 'album_create_flow_screen.dart';
import '../../../profile/presentation/widgets/personal_collection_shelf.dart';

enum AlbumCategory { recent, shared }

class AlbumCategoryScreen extends ConsumerStatefulWidget {
  final AlbumCategory category;
  final List<Album> initialAlbums;
  final String currentUserId;
  final int? initialTabIndex;

  const AlbumCategoryScreen({
    super.key,
    required this.category,
    required this.initialAlbums,
    required this.currentUserId,
    this.initialTabIndex,
  });

  @override
  ConsumerState<AlbumCategoryScreen> createState() =>
      _AlbumCategoryScreenState();
}

class _AlbumCategoryScreenState extends ConsumerState<AlbumCategoryScreen> {
  static const String _favoriteKey = 'album_favorite_ids_v1';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  int _selectedTab = 0;
  Set<int> _favoriteAlbumIds = <int>{};
  late List<Album> _albums;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _albums = List<Album>.from(widget.initialAlbums);
    _selectedTab = _resolveInitialTabIndex();
    _loadFavoriteAlbumIds();
  }

  int _resolveInitialTabIndex() {
    final maxIndex = _tabs.length - 1;
    final initial = widget.initialTabIndex;
    if (initial == null) return 0;
    return initial.clamp(0, maxIndex);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteAlbumIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoriteKey) ?? const <String>[];
    final ids = raw.map(int.tryParse).whereType<int>().toSet();
    if (!mounted) return;
    setState(() => _favoriteAlbumIds = ids);
  }

  Future<void> _persistFavoriteAlbumIds() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _favoriteAlbumIds.map((e) => e.toString()).toList();
    await prefs.setStringList(_favoriteKey, encoded);
  }

  bool _isFavorite(Album album) => _favoriteAlbumIds.contains(album.id);

  Future<void> _toggleFavorite(Album album) async {
    setState(() {
      if (_favoriteAlbumIds.contains(album.id)) {
        _favoriteAlbumIds.remove(album.id);
      } else {
        _favoriteAlbumIds.add(album.id);
      }
    });
    await _persistFavoriteAlbumIds();
  }

  Future<void> _handlePullToRefresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final repository = ref.read(albumRepositoryProvider);
      final latest = await repository.fetchMyAlbums();
      if (!mounted) return;
      setState(() {
        _albums = latest;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('앨범을 새로 불러오지 못했어요. 다시 시도해주세요.')),
        );
      }
    } finally {
      _isRefreshing = false;
    }
  }

  void _removeAlbumLocally(int albumId) {
    if (!mounted) return;
    setState(() {
      _albums = _albums.where((album) => album.id != albumId).toList();
      _favoriteAlbumIds.remove(albumId);
    });
  }

  Future<void> _openAlbumAndSync(Album album) async {
    await HomeAlbumActions.openAlbum(
      context,
      ref,
      album,
      onAlbumDeleted: _removeAlbumLocally,
    );
  }

  String get _title {
    switch (widget.category) {
      case AlbumCategory.recent:
        return '나의 기록들';
      case AlbumCategory.shared:
        return '공유된 앨범';
    }
  }

  List<String> get _tabs {
    switch (widget.category) {
      case AlbumCategory.recent:
      case AlbumCategory.shared:
        return const ['진행 중', '완료', '즐겨찾기'];
    }
  }

  Color get _tabAccent {
    return SnapFitColors.accent;
  }

  bool _isSharedAlbum(Album album) {
    final current = widget.currentUserId.trim();
    final owner = album.userId.trim();
    if (current.isEmpty || owner.isEmpty) return false;
    return owner != current;
  }

  Color get _screenBackground => SnapFitColors.backgroundOf(context);

  List<Album> _applyFilter(List<Album> source) {
    final base = widget.category == AlbumCategory.shared
        ? source.where(_isSharedAlbum).toList()
        : source;
    final q = _searchQuery.trim().toLowerCase();
    final searched = base.where((album) {
      if (q.isEmpty) return true;
      final title = album.title.toLowerCase();
      final theme = (album.coverTheme ?? '').toLowerCase();
      return title.contains(q) || theme.contains(q) || album.id.toString() == q;
    }).toList();

    switch (_selectedTab) {
      case 0:
        return searched.where((a) => !isCompletedAlbum(a)).toList();
      case 1:
        return searched.where((a) => isCompletedAlbum(a)).toList();
      case 2:
        return searched.where(_isFavorite).toList();
      default:
        return searched;
    }
  }

  String _ownerLabel(Album album) {
    final owner = album.userId.trim();
    if (owner.isEmpty) return '공유 앨범';
    if (owner.length <= 4) return '소유자 $owner';
    return '소유자 ${owner.substring(0, 2)}***${owner.substring(owner.length - 2)}';
  }

  DateTime _dateOf(Album album) {
    return DateTime.tryParse(album.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final albums = _applyFilter(_albums);
    if (kIsWeb) return _buildWeb(albums);
    return Scaffold(
      backgroundColor: _screenBackground,
      appBar: ExperienceHeader(
        title: _title,
        themeAware: true,
        actions: [
          IconButton(
            tooltip: _isSearching ? '검색 닫기' : '앨범 검색',
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
            icon: Icon(_isSearching ? Icons.close : Icons.search, size: 21),
          ),
          IconButton(
            tooltip: '새 앨범 만들기',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlbumCreateFlowScreen()),
            ),
            icon: const Icon(Icons.add, size: 23),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _handlePullToRefresh,
          child: CustomScrollView(
            key: const PageStorageKey('personal-album-scroll'),
            physics: platformScrollPhysics(alwaysScrollable: true),
            cacheExtent: 260,
            slivers: [
              if (_isSearching)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: ExperienceFormStyle.text(context, 14),
                      decoration: ExperienceFormStyle.input(
                        context,
                        hint: '앨범 검색',
                      ),
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: _TopTabBar(
                  tabs: _tabs,
                  selectedIndex: _selectedTab,
                  accentColor: _tabAccent,
                  onChanged: (index) => setState(() => _selectedTab = index),
                ),
              ),
              if (albums.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? '검색 결과가 없습니다.'
                            : '표시할 앨범이 없습니다.',
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          secondary: true,
                        ),
                      ),
                    ),
                  ),
                )
              else
                _buildCollection(albums),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeb(List<Album> filtered) {
    final albums = [...filtered]..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    final shared = widget.category == AlbumCategory.shared;
    return SnapFitWebShell(
      title: shared ? '공유 앨범' : '앨범 모음',
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, size: 17),
          label: const Text('내 앨범'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WebPageHeading(
            title: shared ? '공유 앨범' : '앨범 모음',
            description: shared
                ? '참여한 앨범을 확인하고 부여된 권한으로 함께 작업하세요.'
                : '앨범의 진행 상황과 즐겨찾기를 한곳에서 관리하세요.',
            trailing: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                settings: const WebAppRouteSettings(WebAppLocation.create),
                builder: (_) => const AlbumCreateFlowScreen(),
              )),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('앨범 만들기'),
            ),
          ),
          const SizedBox(height: 26),
          LayoutBuilder(builder: (context, box) {
            final tabs = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < _tabs.length; index++)
                  ChoiceChip(
                    label: Text(_tabs[index]),
                    selected: _selectedTab == index,
                    onSelected: (_) => setState(() => _selectedTab = index),
                    showCheckmark: false,
                    selectedColor: WebPalette.of(context).softBrand,
                    backgroundColor: WebPalette.of(context).surface,
                    labelStyle: TextStyle(color: _selectedTab == index
                        ? WebPalette.of(context).brandInk : WebPalette.of(context).muted),
                    side: BorderSide(color: WebPalette.of(context).line),
                  ),
              ],
            );
            final search = TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: '앨범 이름 또는 테마 검색',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
            );
            final refresh = IconButton(
              tooltip: '목록 새로고침',
              onPressed: _isRefreshing ? null : _handlePullToRefresh,
              icon: const Icon(Icons.refresh, size: 21),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [Expanded(child: search), const SizedBox(width: 8), refresh]),
                const SizedBox(height: 16),
                tabs,
              ],
            );
          }),
          const SizedBox(height: 22),
          Text('${albums.length}개의 앨범', style: TextStyle(
            color: WebPalette.of(context).muted, fontSize: 12,
          )),
          const SizedBox(height: 14),
          Expanded(
            child: albums.isEmpty
                ? Center(child: WebSurface(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_searchQuery.isNotEmpty || _selectedTab != 0
                        ? '조건에 맞는 앨범이 없습니다.' : '표시할 앨범이 없습니다.'),
                      if (_searchQuery.isNotEmpty || _selectedTab != 0) ...[
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: () => setState(() {
                          _searchController.clear(); _searchQuery = ''; _selectedTab = 0;
                        }), child: const Text('검색·필터 초기화')),
                      ],
                    ]),
                  ))
                : LayoutBuilder(builder: (context, box) {
                    final columns = (box.maxWidth / 280).floor().clamp(1, 4);
                    return GridView.builder(
                      key: const PageStorageKey('web-album-category-grid'),
                      padding: const EdgeInsets.only(bottom: 24),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        mainAxisExtent: 348,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return Material(
                          color: WebPalette.of(context).surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: WebPalette.of(context).line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              _openAlbumAndSync(album);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: Center(child:
                                    WebSavedAlbumArtwork(album: album),
                                  )),
                                  const SizedBox(height: 18),
                                  Row(children: [
                                    Expanded(child: Text(
                                      album.title.isEmpty ? '제목 없음' : album.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15, fontWeight: FontWeight.w700,
                                        color: WebPalette.of(context).ink,
                                      ),
                                    )),
                                    _favoriteButton(album),
                                  ]),
                                  Text(_albumSubtitle(album), style: TextStyle(
                                    color: WebPalette.of(context).muted, fontSize: 12,
                                  )),
                                  const SizedBox(height: 6),
                                  Text(shared ? _ownerLabel(album)
                                      : formatAlbumDate(album.createdAt),
                                    style: TextStyle(
                                      color: WebPalette.of(context).muted, fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
          ),
        ],
      ),
    );
  }

  String _albumSubtitle(Album album) {
    final progress = calculateAlbumProgress(album);
    if (isCompletedAlbum(album)) {
      if (progress.hasTarget) {
        return '${progress.completedPages}/${progress.targetPages} 페이지 완료';
      }
      return '${progress.completedPages} 페이지 완료';
    }
    return progress.pageProgressLabel;
  }

  Widget _buildCollection(List<Album> albums) {
    final sorted = [...albums]
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));
    final shared = widget.category == AlbumCategory.shared;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      sliver: SliverLayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = (box.crossAxisExtent / (scale > 1.5 ? 220 : 162))
              .floor()
              .clamp(1, 5);
          final width = (box.crossAxisExtent - 20 * (columns - 1)) / columns;
          final wide =
              MediaQuery.orientationOf(context) == Orientation.landscape;
          final stage = wide
              ? (width * .85).clamp(142.0, 230.0)
              : (width * 1.12).clamp(180.0, 300.0);
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 20,
              mainAxisSpacing: 24,
              mainAxisExtent: stage + 28 + scale * (shared ? 112 : 94),
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final album = sorted[index];
                return InkWell(
                  key: ValueKey('personal-record-${album.id}'),
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    _openAlbumAndSync(album);
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: stage,
                        width: double.infinity,
                        child: SavedAlbumArtwork(
                          key: shared
                              ? ValueKey('shared-cover-${album.id}')
                              : null,
                          album: album,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              album.title.isEmpty ? '제목 없음' : album.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceFormStyle.text(
                                context,
                                14,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          _favoriteButton(album),
                        ],
                      ),
                      Text(
                        _albumSubtitle(album),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        shared
                            ? _ownerLabel(album)
                            : formatAlbumDate(album.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExperienceFormStyle.text(
                          context,
                          11,
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: sorted.length,
              addAutomaticKeepAlives: false,
            ),
          );
        },
      ),
    );
  }

  Widget _favoriteButton(Album album) => IconButton(
    tooltip: _isFavorite(album) ? '즐겨찾기 해제' : '즐겨찾기',
    onPressed: () => _toggleFavorite(album),
    color: _isFavorite(album)
        ? ExperienceFormStyle.selectionInk(context)
        : ExperienceFormStyle.muted(context),
    icon: Icon(
      _isFavorite(album) ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 22,
    ),
  );
}

class _TopTabBar extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final Color accentColor;
  final ValueChanged<int> onChanged;
  const _TopTabBar({
    required this.tabs,
    required this.selectedIndex,
    required this.accentColor,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
    ),
    child: Row(
      children: List.generate(tabs.length, (index) {
        final selected = selectedIndex == index;
        return Expanded(
          child: Semantics(
            selected: selected,
            child: InkWell(
              onTap: () => onChanged(index),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected
                          ? ExperienceFormStyle.selectionInk(context)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? ExperienceFormStyle.selectionInk(context)
                        : ExperienceFormStyle.muted(context),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    ),
  );
}
