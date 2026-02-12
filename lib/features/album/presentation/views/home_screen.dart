import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../domain/entities/album.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_album_list_view.dart';
import '../widgets/home/home_error_state.dart';
import '../widgets/home/home_bottom_nav_placeholder.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_album_helpers.dart';
import '../viewmodels/home_view_model.dart';
import 'album_create_flow_screen.dart';
import '../../../search/presentation/views/search_screen.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../../store/presentation/views/store_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  int _bottomNavIndex = 0;
  bool _isEditMode = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('HomeScreen', '홈 · 앨범 목록/피처드/그리드 · 앨범 생성 FAB');
  }

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    final authAsync = ref.watch(authViewModelProvider);
    Future<void> handleCreateAlbum() async {
      final created = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AlbumCreateFlowScreen(),
        ),
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
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 10.h),
                  decoration: BoxDecoration(
                    color: SnapFitColors.backgroundOf(context),
                    border: Border(
                      bottom: BorderSide(
                        color: SnapFitColors.overlayLightOf(context),
                      ),
                    ),
                  ),
                  child: HomeHeader(
                    hasAlbums: albumsAsync.value?.any((album) => !isDraftAlbum(album)) ?? false,
                    isSearching: _isSearching,
                    searchQuery: _searchQuery,
                    onSearch: () {
                      setState(() {
                        _isSearching = true;
                        _searchQuery = '';
                      });
                    },
                    onSearchChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                    onSearchClose: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                      });
                    },
                    onNotification: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                    isEditMode: _isEditMode,
                    onEditToggle: () {
                      setState(() {
                        _isEditMode = !_isEditMode;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: albumsAsync.when(
                    data: (albums) {
                      // 검색 필터링
                      var filteredAlbums = albums;
                      if (_isSearching && _searchQuery.isNotEmpty) {
                        final query = _searchQuery.toLowerCase();
                        filteredAlbums = albums.where((album) {
                          // 커버 테마로 검색
                          final theme = album.coverTheme?.toLowerCase() ?? '';
                          if (theme.contains(query)) return true;
                          
                          // ID로 검색 (앨범 번호)
                          if (album.id.toString().contains(query)) return true;
                          
                          // 생성일로 검색
                          if (album.createdAt.contains(query)) return true;
                          
                          return false;
                        }).toList();
                      }

                      // 순서(orders) 오름차순 -> 생성일(createdAt) 내림차순 정렬
                      final sorted = List<Album>.from(filteredAlbums)
                        ..sort((a, b) {
                          final orderDiff = a.orders.compareTo(b.orders);
                          if (orderDiff != 0) return orderDiff;
                          return b.createdAt.compareTo(a.createdAt);
                        });
                      
                      return HomeAlbumListView(
                        albums: sorted,
                        selectedIndex: _selectedIndex,
                        userInfo: authAsync.value,
                        emptyState: const HomeEmptyState(),
                        isEditMode: _isEditMode,
                        onSelect: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onOpen: (album, index) async {
                          if (_isEditMode) return; // 편집 모드일 때는 이동 막기
                          setState(() => _selectedIndex = index);
                          await HomeAlbumActions.openAlbum(context, ref, album);
                        },
                        onReorder: (oldIndex, newIndex) async {
                          await ref
                              .read(homeViewModelProvider.notifier)
                              .reorder(oldIndex, newIndex);
                        },
                        onDelete: (album) async {
                          await HomeAlbumActions.onDeleteSelected(
                              context, ref, album);
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: SnapFitColors.accentLight),
                    ),
                    error: (err, stack) => HomeErrorState(error: err),
                  ),
                ),
              ],
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
}



