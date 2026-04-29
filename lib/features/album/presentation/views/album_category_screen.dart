import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../shared/snapfit_image.dart';
import '../../domain/entities/album.dart';
import '../../data/api/album_provider.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_album_cover_thumbnail.dart';
import '../widgets/home/home_album_helpers.dart';
import 'album_create_flow_screen.dart';

enum AlbumCategory { recent, completed, shared }

class AlbumCategoryScreen extends ConsumerStatefulWidget {
  final AlbumCategory category;
  final List<Album> initialAlbums;
  final String currentUserId;

  const AlbumCategoryScreen({
    super.key,
    required this.category,
    required this.initialAlbums,
    required this.currentUserId,
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
    _loadFavoriteAlbumIds();
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
      case AlbumCategory.completed:
        return '완료된 앨범';
    }
  }

  List<String> get _tabs {
    switch (widget.category) {
      case AlbumCategory.completed:
        return const ['전체', '인쇄됨', '주문됨'];
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

  Color get _screenBackground {
    if (SnapFitColors.isDark(context)) {
      return SnapFitColors.backgroundOf(context);
    }
    if (widget.category == AlbumCategory.shared) {
      return SnapFitColors.backgroundOf(context);
    }
    if (widget.category == AlbumCategory.recent) {
      return const Color(0xFFF3F6FA);
    }
    return SnapFitColors.backgroundOf(context);
  }

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

    if (widget.category == AlbumCategory.completed) {
      switch (_selectedTab) {
        case 1:
          return searched.where((a) => a.id.isEven).toList();
        case 2:
          return searched.where((a) => a.id.isOdd).toList();
        default:
          return searched;
      }
    }

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

  String _relativeTime(Album album) {
    final raw = album.createdAt;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    if (diff.inDays < 8) return '${diff.inDays}일 전';
    return formatAlbumDate(raw);
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

  Widget _coverImage(Album album, {double? width, double? height}) {
    final url =
        album.coverThumbnailUrl ?? album.coverPreviewUrl ?? album.coverImageUrl;
    final bg = SnapFitColors.surfaceOf(context);
    if (url == null || url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: bg,
        alignment: Alignment.center,
        child: Icon(
          Icons.photo_outlined,
          color: SnapFitColors.textMutedOf(context),
          size: 22.sp,
        ),
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: SnapfitImage(urlOrGs: url, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themedBg = _screenBackground;
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final all = _applyFilter(_albums);

    return Scaffold(
      backgroundColor: themedBg,
      appBar: AppBar(
        backgroundColor: themedBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: widget.category != AlbumCategory.shared,
        leading: IconButton(
          icon: Icon(platformBackIcon(), color: textPrimary, size: 20.w),
          onPressed: () => Navigator.pop(context),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: textPrimary, fontSize: 16.sp),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '앨범 검색',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 15.sp),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : Text(
                _title,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: textPrimary,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
          ),
          if (widget.category == AlbumCategory.shared)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AlbumCreateFlowScreen(),
                  ),
                ),
                child: Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: SnapFitColors.accent.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _TopTabBar(
            tabs: _tabs,
            selectedIndex: _selectedTab,
            accentColor: _tabAccent,
            onChanged: (index) => setState(() => _selectedTab = index),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handlePullToRefresh,
              child: all.isEmpty
                  ? ListView(
                      physics: platformScrollPhysics(alwaysScrollable: true),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.42,
                          child: Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? '검색 결과가 없습니다.'
                                  : '표시할 앨범이 없습니다.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Builder(
                      builder: (context) {
                        switch (widget.category) {
                          case AlbumCategory.recent:
                            return _buildRecentTimeline(all);
                          case AlbumCategory.shared:
                            return _buildSharedGrid(all);
                          case AlbumCategory.completed:
                            return _buildCompletedShowcase(all);
                        }
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.category == AlbumCategory.recent
          ? FloatingActionButton(
              backgroundColor: _tabAccent,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AlbumCreateFlowScreen(),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            )
          : null,
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

  Widget _buildRecentTimeline(List<Album> albums) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final sorted = [...albums]
      ..sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 26.h),
      children: [
        for (int index = 0; index < sorted.length; index++) ...[
          if (index == 0 ||
              !_isSameDay(_dateOf(sorted[index - 1]), _dateOf(sorted[index])))
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 2.h, 8.w, 8.h),
              child: _buildRecentDateHeader(
                _dateOf(sorted[index]),
                textSecondary,
              ),
            ),
          Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: _buildRecentCard(sorted[index], textPrimary, textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentDateHeader(DateTime dt, Color textSecondary) {
    final month = _monthAbbr(dt.month);
    final dateLabel = dt.day.toString().padLeft(2, '0');
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
        children: [
          TextSpan(text: '${dt.year}'),
          const TextSpan(text: '  /  '),
          TextSpan(text: month),
          TextSpan(
            text: '  $dateLabel',
            style: TextStyle(
              color: SnapFitColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCard(Album album, Color textPrimary, Color textSecondary) {
    return GestureDetector(
      onTap: () => _openAlbumAndSync(album),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.18 : 0.04,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 92.w,
              height: 92.w,
              child: Center(
                child: HomeAlbumCoverThumbnail(
                  album: album,
                  height: 92.w,
                  maxWidth: 92.w,
                  showShadow: true,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title.isEmpty ? '제목 없음' : album.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _albumSubtitle(album),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleFavorite(album),
              child: SizedBox(
                width: 28.w,
                height: 28.w,
                child: Icon(
                  _isFavorite(album)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _isFavorite(album)
                      ? const Color(0xFFFF4F7B)
                      : SnapFitColors.overlayStrongOf(context),
                  size: 23.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildSharedGrid(List<Album> albums) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 26.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 18.h,
        childAspectRatio: 0.6,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final progress = calculateAlbumProgress(album);
        final isEditing = progress.ratio < 1.0;
        final isFavorite = _isFavorite(album);

        return GestureDetector(
          onTap: () => _openAlbumAndSync(album),
          child: Container(
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    SnapFitColors.isDark(context) ? 0.14 : 0.03,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18.r),
                          ),
                          child: _coverImage(album),
                        ),
                      ),
                      if (isEditing)
                        Positioned(
                          top: 9.h,
                          right: 9.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: SnapFitColors.accent,
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              '진행중',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 9.w,
                        bottom: 9.h,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _toggleFavorite(album),
                          child: Container(
                            width: 30.w,
                            height: 30.w,
                            decoration: BoxDecoration(
                              color: SnapFitColors.surfaceOf(
                                context,
                              ).withOpacity(0.92),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: SnapFitColors.overlayLightOf(context),
                              ),
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: isFavorite
                                  ? SnapFitColors.accent
                                  : SnapFitColors.textSecondaryOf(context),
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title.isEmpty ? '제목 없음' : album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        _relativeTime(album),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _ownerLabel(album),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: textSecondary.withOpacity(0.95),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 9.h),
                      Row(
                        children: [
                          Container(
                            margin: EdgeInsets.only(left: 0.w),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: SnapFitColors.accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                            child: Text(
                              '공유중',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: SnapFitColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
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
        );
      },
    );
  }

  Widget _buildCompletedShowcase(List<Album> albums) {
    final firstLarge = albums.take(2).toList();
    final rest = albums.skip(2).toList();
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 26.h),
      children: [
        for (int i = 0; i < firstLarge.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: 20.h),
            child: _completedLargeCard(
              album: firstLarge[i],
              label: i.isEven ? 'PRINTED' : 'ORDERED',
              accent: i.isEven
                  ? const Color(0xFFFF7A2F)
                  : const Color(0xFF18B6D7),
            ),
          ),
        if (rest.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14.w,
              mainAxisSpacing: 14.h,
              childAspectRatio: 0.74,
            ),
            itemCount: rest.length,
            itemBuilder: (context, index) {
              final album = rest[index];
              return GestureDetector(
                onTap: () => _openAlbumAndSync(album),
                child: Container(
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(
                          SnapFitColors.isDark(context) ? 0.2 : 0.04,
                        ),
                        blurRadius: 10,
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18.r),
                                ),
                                child: _coverImage(album),
                              ),
                            ),
                            Positioned(
                              top: 8.h,
                              left: 8.w,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF7A2F),
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  'PRINTED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.title.isEmpty ? '제목 없음' : album.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w800,
                                color: textPrimary,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              formatAlbumDate(album.createdAt),
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _completedLargeCard({
    required Album album,
    required String label,
    required Color accent,
  }) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final statusText = label == 'PRINTED' ? '완료됨' : '배송중';

    return GestureDetector(
      onTap: () => _openAlbumAndSync(album),
      child: Container(
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.24 : 0.05,
              ),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 220.h,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24.r),
                      ),
                      child: _coverImage(album),
                    ),
                  ),
                  Positioned(
                    top: 14.h,
                    left: 14.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          album.title.isEmpty ? '제목 없음' : album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                          ),
                        ),
                      ),
                      _tinyAvatar(Colors.orange[200]!),
                      _tinyAvatar(Colors.brown[200]!),
                      Container(
                        margin: EdgeInsets.only(left: 2.w),
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: SnapFitColors.overlayLightOf(context),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          '+${(album.id % 5) + 1}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '${formatAlbumDate(album.createdAt)}  ·  $statusText',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _openAlbumAndSync(album),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7A2F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                      child: Text(
                        '상세보기',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tinyAvatar(Color color) {
    return Container(
      margin: EdgeInsets.only(left: 4.w),
      width: 24.w,
      height: 24.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: SnapFitColors.backgroundOf(context),
          width: 1.5,
        ),
      ),
      child: Icon(Icons.person, size: 14.sp, color: Colors.white),
    );
  }

  String _monthAbbr(int month) {
    const m = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return m[(month - 1).clamp(0, 11)];
  }
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
  Widget build(BuildContext context) {
    final secondary = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: SnapFitColors.overlayLightOf(context)),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.only(top: 8.h, bottom: 10.h),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? accentColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    tabs[index],
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: selected ? accentColor : secondary,
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
}
