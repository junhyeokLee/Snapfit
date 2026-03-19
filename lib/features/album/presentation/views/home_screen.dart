import 'dart:async';
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
import '../../../store/presentation/views/store_screen.dart';
import '../../data/api/album_provider.dart';
import 'album_category_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const String _favoriteKey = 'album_favorite_ids_v1';
  int _bottomNavIndex = 0;
  int _albumTabIndex = 0;
  String _sharedResolveKey = '';
  Future<List<Album>>? _sharedResolveFuture;
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

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
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
            // SafeArea applied to the whole body
            child: albumsAsync.when(
              data: (albums) {
                final currentUserId =
                    authAsync.asData?.value?.id.toString() ?? '';

                // 1. filtering (Draft 제외)
                final baseAlbums = albums
                    .where((a) => !isDraftAlbum(a))
                    .toList();

                // 2. 섹션별 정렬/필터
                // 나의 기록들: 내 앨범 + 최신순(완료/진행중 모두 포함)
                final myOwnedAlbums = baseAlbums.where((a) {
                  if (currentUserId.isEmpty) return true;
                  return a.userId.trim() == currentUserId.trim();
                }).toList();
                final myRecordsSource = myOwnedAlbums.isNotEmpty
                    ? myOwnedAlbums
                    : baseAlbums;
                final myRecordsAlbums = List<Album>.from(myRecordsSource)
                  ..sort(_compareByLatestDesc);

                // 완료된 앨범: "진짜 완료"만 + 최신순
                final completedAlbums = List<Album>.from(
                  baseAlbums.where((a) => isCompletedAlbum(a)),
                )..sort(_compareByLatestDesc);
                final completedPreviewAlbums = completedAlbums.take(3).toList();

                // Shared: 실제 공유 앨범(내 소유 아님)만 노출
                final sharedOwnerCandidates =
                    currentUserId.trim().isEmpty
                          ? <Album>[]
                          : baseAlbums
                                .where(
                                  (a) =>
                                      a.userId.trim().isNotEmpty &&
                                      a.userId.trim() != currentUserId.trim(),
                                )
                                .toList()
                      ..sort(_compareByLatestDesc);

                if (baseAlbums.isEmpty) {
                  return HomeEmptyState(onCreate: handleCreateAlbum);
                }

                final homeContent = CustomScrollView(
                  slivers: [
                    // 1. Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20.w,
                          vertical: 12.w,
                        ),
                        child: HomeHeaderNew(
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
                        albums: myRecordsAlbums,
                        currentUserId: currentUserId,
                        onTap: (album) async {
                          await HomeAlbumActions.openAlbum(context, ref, album);
                        },
                        onViewAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumCategoryScreen(
                                category: AlbumCategory.recent,
                                initialAlbums: myRecordsAlbums,
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
                          sharedOwnerCandidates,
                          currentUserId,
                        ),
                        builder: (context, snapshot) {
                          final sharedAlbums = snapshot.data ?? const <Album>[];
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
                        albums: completedPreviewAlbums,
                        currentUserId: currentUserId,
                        onTap: (album) async {
                          await HomeAlbumActions.openAlbum(context, ref, album);
                        },
                        onViewAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AlbumCategoryScreen(
                                category: AlbumCategory.completed,
                                initialAlbums: completedAlbums,
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
                );

                final albumTabContent = _buildAlbumTabScreen(
                  allAlbums: myRecordsAlbums,
                  currentUserId: currentUserId,
                );

                return _bottomNavIndex == 1 ? albumTabContent : homeContent;
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

  Widget _buildBottomNavBody(BuildContext context, Widget homeBody) {
    switch (_bottomNavIndex) {
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
  }) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final inProgressAlbums = List<Album>.from(
      allAlbums.where((a) => isLiveEditingAlbum(a)),
    )..sort(_compareByLatestDesc);
    final completedAlbums = List<Album>.from(
      allAlbums.where((a) => isCompletedAlbum(a)),
    )..sort(_compareByLatestDesc);
    final favoriteAlbums = List<Album>.from(
      allAlbums.where((a) => _favoriteAlbumIds.contains(a.id)),
    )..sort(_compareByLatestDesc);

    final tabAlbums = switch (_albumTabIndex) {
      1 => completedAlbums,
      2 => favoriteAlbums,
      _ => inProgressAlbums,
    };

    final tabLabel = switch (_albumTabIndex) {
      1 => '완료',
      2 => '즐겨찾기',
      _ => '진행중',
    };

    return CustomScrollView(
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
                final selected = idx == _albumTabIndex;
                return GestureDetector(
                  onTap: () => setState(() => _albumTabIndex = idx),
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
                  '$tabLabel 앨범',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${tabAlbums.length}개',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: () {
                    final category = _albumTabIndex == 1
                        ? AlbumCategory.completed
                        : AlbumCategory.recent;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumCategoryScreen(
                          category: category,
                          initialAlbums: tabAlbums,
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
        SliverToBoxAdapter(
          child: _buildAlbumGrid(
            albums: tabAlbums,
            currentUserId: currentUserId,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: 90.h)),
      ],
    );
  }

  Widget _buildAlbumGrid({
    required List<Album> albums,
    required String currentUserId,
  }) {
    if (albums.isEmpty) {
      return Padding(
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
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: albums.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 10.h,
          childAspectRatio: 0.74,
        ),
        itemBuilder: (context, index) {
          final album = albums[index];
          final progress = calculateAlbumProgress(album);
          final isFav = _favoriteAlbumIds.contains(album.id);
          final isShared =
              currentUserId.trim().isNotEmpty &&
              album.userId.trim().isNotEmpty &&
              album.userId.trim() != currentUserId.trim();
          final chipColor = isCompletedAlbum(album)
              ? (album.id.isEven
                    ? const Color(0xFF1BB57A)
                    : const Color(0xFFF2A11A))
              : const Color(0xFF16A8E3);
          final chipText = isCompletedAlbum(album)
              ? (album.id.isEven ? '인쇄' : '주문')
              : '진행중';
          return GestureDetector(
            onTap: () => HomeAlbumActions.openAlbum(context, ref, album),
            child: Container(
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(15.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
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
                              child: HomeAlbumCoverThumbnail(
                                album: album,
                                height: 152.h,
                                maxWidth: 120.w,
                                showShadow: true,
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
                              backgroundColor: SnapFitColors.pureWhite
                                  .withOpacity(0.92),
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
                        Positioned(
                          left: 10.w,
                          bottom: 8.h,
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 9.w,
                                  vertical: 3.h,
                                ),
                                decoration: BoxDecoration(
                                  color: chipColor,
                                  borderRadius: BorderRadius.circular(999.r),
                                ),
                                child: Text(
                                  chipText,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isShared) ...[
                                SizedBox(width: 6.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 3.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6E7F96),
                                    borderRadius: BorderRadius.circular(999.r),
                                  ),
                                  child: Text(
                                    '공유',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                album.title.isEmpty ? '제목 없음' : album.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: SnapFitColors.textPrimaryOf(context),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.more_vert_rounded,
                              size: 18.sp,
                              color: SnapFitColors.textSecondaryOf(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          isCompletedAlbum(album)
                              ? formatAlbumDate(
                                  album.updatedAt.isEmpty
                                      ? album.createdAt
                                      : album.updatedAt,
                                )
                              : '수정됨',
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
                              '${progress.completedPages}개 항목',
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
          );
        },
      ),
    );
  }

  int _compareByLatestDesc(Album a, Album b) {
    final aTime = _latestTimeOf(a);
    final bTime = _latestTimeOf(b);
    return bTime.compareTo(aTime);
  }

  DateTime _latestTimeOf(Album album) {
    final updated = DateTime.tryParse(album.updatedAt);
    if (updated != null) return updated;
    return DateTime.tryParse(album.createdAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
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
    final current = currentUserId.trim();
    if (current.isEmpty || candidates.isEmpty) return <Album>[];
    final memberRepo = ref.read(albumMemberRepositoryProvider);

    final tasks = candidates.map((album) async {
      try {
        final members = await memberRepo.fetchMembers(album.id);
        final isJoined = members.any((m) {
          final memberId = m.userId.toString();
          final status = m.status.trim().toUpperCase();
          final isActive =
              status.isEmpty ||
              status == 'ACCEPTED' ||
              status == 'ACTIVE' ||
              status == 'JOINED';
          return memberId == current && isActive;
        });
        return isJoined ? album : null;
      } catch (_) {
        // 멤버 API 실패 시 owner 기반 폴백
        return album.userId.trim() != current ? album : null;
      }
    });

    final resolved = (await Future.wait(tasks)).whereType<Album>().toList()
      ..sort(_compareByLatestDesc);
    return resolved;
  }
}
