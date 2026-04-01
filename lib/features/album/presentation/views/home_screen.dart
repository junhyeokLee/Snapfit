import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../domain/entities/album.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_album_helpers.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/home_header_new.dart';
import '../widgets/home/recent_album_list.dart';
import '../widgets/home/completed_album_list.dart';
import '../widgets/home/shared_album_list.dart';
import '../../../store/presentation/widgets/premium_template_list.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_error_state.dart';
import '../widgets/home/home_album_cover_thumbnail.dart';
import 'album_create_flow_screen.dart';
import '../../../search/presentation/views/search_screen.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../../../store/presentation/views/store_screen.dart';
import '../../data/api/album_provider.dart';
import '../providers/home_ui_state_provider.dart';
import '../utils/home_album_section_builder.dart';
import '../utils/home_shared_membership_resolver.dart';
import 'album_category_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _favoriteKey = 'album_favorite_ids_v1';
  String _sharedResolveKey = '';
  Future<List<Album>>? _sharedResolveFuture;
  final HomeSharedMembershipResolver _sharedMembershipResolver =
      HomeSharedMembershipResolver();
  Set<int> _favoriteAlbumIds = <int>{};

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('HomeScreen', '홈 · 앨범 목록/피처드/그리드 · 앨범 생성 FAB');
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

  Color _albumCardTone(Album album) {
    final bgTone = _extractCoverBackgroundTone(album.coverLayersJson);
    if (bgTone != null) return bgTone;

    const palette = <Color>[
      Color(0xFFE8D6B8),
      Color(0xFFD3D9EA),
      Color(0xFFD2E6D3),
      Color(0xFFE4D6EA),
      Color(0xFFE7DCC8),
      Color(0xFFD0E0EC),
    ];
    return palette[album.id.abs() % palette.length];
  }

  Color _readableAlbumCardTone(Color tone) {
    final luminance = tone.computeLuminance();
    final blendToWhite = luminance < 0.2
        ? 0.84
        : luminance < 0.35
        ? 0.72
        : 0.58;

    final softened = Color.lerp(tone, Colors.white, blendToWhite) ?? tone;
    final hsl = HSLColor.fromColor(softened);
    final safeSaturation = (hsl.saturation * 0.72).clamp(0.06, 0.40);
    final safeLightness = hsl.lightness.clamp(0.84, 0.94);

    return hsl
        .withSaturation(safeSaturation.toDouble())
        .withLightness(safeLightness.toDouble())
        .toColor();
  }

  Color? _extractCoverBackgroundTone(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final coverPage = _extractCoverPage(decoded);
      if (coverPage != null) {
        final pageColor = _extractColorFromMap(coverPage, const [
          'backgroundColor',
          'canvasColor',
          'bgColor',
          'color',
        ]);
        if (pageColor != null) return pageColor;
      }

      final layers = _extractCoverLayers(decoded, coverPage: coverPage);
      for (final rawLayer in layers.reversed) {
        if (rawLayer is! Map) continue;
        final layer = rawLayer.cast<String, dynamic>();
        final payload = (layer['payload'] is Map)
            ? (layer['payload'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{};

        final layerColor = _extractColorFromMap(payload, const [
          'backgroundColor',
          'canvasColor',
          'bgColor',
          'fillColor',
          'bubbleColor',
          'color',
        ]);
        if (layerColor != null) return layerColor;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _extractCoverPage(Map<String, dynamic> decoded) {
    final pages = decoded['pages'];
    if (pages is! List || pages.isEmpty) return null;
    for (final p in pages) {
      if (p is! Map) continue;
      final page = p.cast<String, dynamic>();
      final isCover = page['isCover'] == true;
      final idx = (page['index'] as num?)?.toInt();
      if (isCover || idx == 0) return page;
    }
    final first = pages.first;
    if (first is Map) return first.cast<String, dynamic>();
    return null;
  }

  List<dynamic> _extractCoverLayers(
    Map<String, dynamic> decoded, {
    Map<String, dynamic>? coverPage,
  }) {
    final fromCoverPage = coverPage?['layers'];
    if (fromCoverPage is List) return fromCoverPage;
    final fromRoot = decoded['layers'];
    if (fromRoot is List) return fromRoot;
    return const <dynamic>[];
  }

  Color? _extractColorFromMap(Map<String, dynamic> src, List<String> keys) {
    for (final key in keys) {
      final color = _parseDynamicColor(src[key]);
      if (color != null) return color;
    }
    return null;
  }

  Color? _parseDynamicColor(dynamic value) {
    if (value == null) return null;
    if (value is int) return Color(value);
    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) return null;
      if (raw.startsWith('#')) return _parseHexColor(raw);

      final noPrefix = raw.replaceAll(RegExp(r'^0x', caseSensitive: false), '');
      if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(noPrefix) ||
          RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(noPrefix)) {
        return _parseHexColor('#$noPrefix');
      }
      final numeric = int.tryParse(raw);
      if (numeric != null) return Color(numeric);
    }
    return null;
  }

  Color? _parseHexColor(String hex) {
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return null;
  }

  Future<void> _handlePullToRefresh() async {
    ref.invalidate(notificationUnreadCountProvider);
    await ref.read(homeViewModelProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final unreadCountAsync = ref.watch(notificationUnreadCountProvider);
    final authAsync = ref.watch(authViewModelProvider);
    final uiState = ref.watch(homeUiStateProvider);
    final uiStateNotifier = ref.read(homeUiStateProvider.notifier);
    Future<void> handleCreateAlbum() async {
      final created = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AlbumCreateFlowScreen()),
      );
      if (created == true && context.mounted) {
        await ref.read(homeViewModelProvider.notifier).refresh();
      }
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      bottomNavigationBar: HomeBottomNavigationBar(
        currentIndex: uiState.bottomNavIndex,
        onTap: (index) {
          uiStateNotifier.setBottomNavIndex(index);
        },
        onCreate: handleCreateAlbum,
      ),
      body: _buildBottomNavBody(
        context,
        currentBottomNavIndex: uiState.bottomNavIndex,
        homeBody: Container(
          color: SnapFitColors.backgroundOf(context),
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
                if (prepared.baseAlbums.isEmpty) {
                  return HomeEmptyState(onCreate: handleCreateAlbum);
                }

                final homeContent = RefreshIndicator(
                  onRefresh: _handlePullToRefresh,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    slivers: [
                      // 1. Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.w,
                            vertical: 12.w,
                          ),
                          child: HomeHeaderNew(
                            hasUnreadNotification:
                                (unreadCountAsync.asData?.value ?? 0) > 0,
                            onNotification: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      // 2. Premium Templates (New Section)
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const PremiumTemplateList(maxItems: 3),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                      // 3. My Records (Section 1: Masonry)
                      SliverToBoxAdapter(
                        child: RecentAlbumList(
                          albums: prepared.myRecordsAlbums,
                          currentUserId: currentUserId,
                          onTap: (album) async {
                            await HomeAlbumActions.openAlbum(
                              context,
                              ref,
                              album,
                            );
                          },
                          onViewAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlbumCategoryScreen(
                                  category: AlbumCategory.recent,
                                  initialAlbums: prepared.myRecordsAlbums,
                                  currentUserId: currentUserId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // 4. Shared Albums (Section 2: Carousel)
                      SliverToBoxAdapter(
                        child: FutureBuilder<List<Album>>(
                          future: _resolveSharedAlbums(
                            prepared.sharedOwnerCandidates,
                            currentUserId,
                          ),
                          builder: (context, snapshot) {
                            final sharedAlbums =
                                snapshot.data ?? const <Album>[];
                            return SharedAlbumList(
                              albums: sharedAlbums,
                              currentUserId: currentUserId,
                              onTap: (album) async {
                                await HomeAlbumActions.openAlbum(
                                  context,
                                  ref,
                                  album,
                                );
                              },
                              onViewAll: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlbumCategoryScreen(
                                      category: AlbumCategory.shared,
                                      initialAlbums: sharedAlbums,
                                      currentUserId: currentUserId,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // 5. Completed Albums (Section 3: List)
                      SliverToBoxAdapter(
                        child: CompletedAlbumList(
                          albums: prepared.completedPreviewAlbums,
                          currentUserId: currentUserId,
                          onTap: (album) async {
                            await HomeAlbumActions.openAlbum(
                              context,
                              ref,
                              album,
                            );
                          },
                          onViewAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlbumCategoryScreen(
                                  category: AlbumCategory.completed,
                                  initialAlbums: prepared.completedAlbums,
                                  currentUserId: currentUserId,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom Padding for FAB
                      SliverToBoxAdapter(child: SizedBox(height: 80.w)),
                    ],
                  ),
                );

                final albumTabContent = _buildAlbumTabScreen(
                  allAlbums: prepared.myRecordsAlbums,
                  currentUserId: currentUserId,
                  albumTabIndex: uiState.albumTabIndex,
                  onAlbumTabChanged: uiStateNotifier.setAlbumTabIndex,
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
        return const MyPageScreen();
      default:
        return homeBody;
    }
  }

  Widget _buildAlbumTabScreen({
    required List<Album> allAlbums,
    required String currentUserId,
    required int albumTabIndex,
    required ValueChanged<int> onAlbumTabChanged,
  }) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final tabData = buildHomeAlbumTabData(
      allAlbums: allAlbums,
      favoriteAlbumIds: _favoriteAlbumIds,
      albumTabIndex: albumTabIndex,
    );

    return RefreshIndicator(
      onRefresh: _handlePullToRefresh,
      child: CustomScrollView(
        cacheExtent: 1000,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
              child: Text(
                '내 앨범',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: SnapFitColors.overlayLightOf(context),
                  ),
                ),
              ),
              child: Row(
                children: ['진행중', '완료', '즐겨찾기'].asMap().entries.map((entry) {
                  final idx = entry.key;
                  final selected = idx == albumTabIndex;
                  return GestureDetector(
                    onTap: () => onAlbumTabChanged(idx),
                    child: Container(
                      margin: EdgeInsets.only(right: 18.w),
                      padding: EdgeInsets.only(bottom: 10.h),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: selected
                                ? SnapFitColors.accent
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: selected ? textPrimary : textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 8.h),
              child: Row(
                children: [
                  Text(
                    '앨범',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${tabData.tabAlbums.length}개',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  GestureDetector(
                    onTap: () {
                      final category = albumTabIndex == 1
                          ? AlbumCategory.completed
                          : AlbumCategory.recent;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AlbumCategoryScreen(
                            category: category,
                            initialAlbums: tabData.tabAlbums,
                            currentUserId: currentUserId,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      '더보기',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: SnapFitColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildAlbumGridSliver(
            albums: tabData.tabAlbums,
            currentUserId: currentUserId,
          ),
          SliverToBoxAdapter(child: SizedBox(height: 90.h)),
        ],
      ),
    );
  }

  Widget _buildAlbumGridSliver({
    required List<Album> albums,
    required String currentUserId,
  }) {
    if (albums.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 4.h),
          child: Container(
            height: 110.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
            child: Text(
              '표시할 앨범이 없습니다.',
              style: TextStyle(
                fontSize: 10.sp,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
        ),
      );
    }

    final List<MapEntry<int, Album>> leftCol = [];
    final List<MapEntry<int, Album>> rightCol = [];
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
                          child: _buildAlbumGridCard(entry.value),
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
                          child: _buildAlbumGridCard(entry.value),
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

  Widget _buildAlbumGridCard(Album album) {
    final progress = calculateAlbumProgress(album);
    final isFav = _favoriteAlbumIds.contains(album.id);
    final tone = _albumCardTone(album);
    final cardBg = SnapFitColors.isDark(context)
        ? SnapFitColors.surfaceOf(context)
        : _readableAlbumCardTone(tone);
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
      child: GestureDetector(
        onTap: () => HomeAlbumActions.openAlbum(context, ref, album),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(15.r),
            border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  SnapFitColors.isDark(context) ? 0.24 : 0.06,
                ),
                blurRadius: 9,
                offset: const Offset(0, 5),
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
                        onTap: () => _toggleFavorite(album.id),
                        child: CircleAvatar(
                          radius: 14.r,
                          backgroundColor: SnapFitColors.pureWhite.withOpacity(
                            0.92,
                          ),
                          child: Icon(
                            isFav
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFav
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
                padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
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
                      formatAlbumDate(
                        album.updatedAt.isEmpty
                            ? album.createdAt
                            : album.updatedAt,
                      ),
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

  Future<List<Album>> _resolveSharedAlbums(
    List<Album> candidates,
    String currentUserId,
  ) {
    final sortedIds = candidates.map((a) => a.id).toList()..sort();
    final key = '${currentUserId.trim()}|${sortedIds.join(',')}';
    if (_sharedResolveFuture != null && _sharedResolveKey == key) {
      return _sharedResolveFuture!;
    }
    _sharedResolveKey = key;
    _sharedResolveFuture = _resolveSharedAlbumsFromMembers(
      candidates,
      currentUserId,
    );
    return _sharedResolveFuture!;
  }

  Future<List<Album>> _resolveSharedAlbumsFromMembers(
    List<Album> candidates,
    String currentUserId,
  ) async {
    final memberRepo = ref.read(albumMemberRepositoryProvider);
    return _sharedMembershipResolver.resolve(
      candidates: candidates,
      currentUserId: currentUserId,
      isJoinedLoader: (albumId, normalizedUserId) async {
        final members = await memberRepo.fetchMembers(albumId);
        return members.any((m) {
          final memberId = m.userId.toString();
          final status = m.status.trim().toUpperCase();
          final isActive =
              status.isEmpty ||
              status == 'ACCEPTED' ||
              status == 'ACTIVE' ||
              status == 'JOINED';
          return memberId == normalizedUserId && isActive;
        });
      },
      fallbackOnError: (album, normalizedUserId) =>
          album.userId.trim() != normalizedUserId,
      sortBy: compareAlbumByLatestDesc,
    );
  }
}

enum _CoverType { landscape, square, portrait }
