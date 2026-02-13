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
import '../widgets/home/home_album_helpers.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/home_header_new.dart';
import '../widgets/home/recent_album_list.dart';
import '../widgets/home/completed_album_list.dart';
import '../widgets/home/shared_album_list.dart';
import '../widgets/home/home_album_actions.dart';
import '../widgets/home/home_error_state.dart';
import 'album_create_flow_screen.dart';
import '../../../search/presentation/views/search_screen.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../../store/presentation/views/store_screen.dart';
import 'album_category_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  int _bottomNavIndex = 0;
  bool _isEditMode = false;

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
          child: SafeArea( // SafeArea applied to the whole body
            child: albumsAsync.when(
              data: (albums) {
                final currentUserId = authAsync.asData?.value?.id.toString() ?? '';
                
                // 1. filtering (Draft 제외)
                var baseAlbums = albums.where((a) => !isDraftAlbum(a)).toList();
                

                // 2. Sorting by 'orders' (Ascending)
                // If orders are same, fallback to createdAt (Descending)
                final sorted = List<Album>.from(baseAlbums)
                  ..sort((a, b) {
                    if (a.orders != b.orders) {
                      return a.orders.compareTo(b.orders);
                    }
                    return b.createdAt.compareTo(a.createdAt);
                  });

                // 3. Category Filtering
                // Recent: Live Editing (Limit 6)
                final recentAlbums = sorted.where((a) => isLiveEditingAlbum(a)).take(6).toList();
                
                // Completed: isCompletedAlbum
                final completedAlbums = sorted.where((a) => isCompletedAlbum(a)).toList();
                
                // Shared: userId != currentUserId
                final sharedAlbums = sorted.where((a) => a.userId != currentUserId).toList();

                if (baseAlbums.isEmpty) {
                  return HomeEmptyState(
                    onCreate: handleCreateAlbum,
                  );
                }

                return CustomScrollView(
                  slivers: [
                     // 1. Header
                     SliverToBoxAdapter(
                       child: Padding(
                         padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
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
                     // 2. Recent Albums
                     SliverToBoxAdapter(
                       child: RecentAlbumList(
                         albums: recentAlbums,
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
                                 initialAlbums: recentAlbums,
                                 currentUserId: currentUserId,
                               ),
                             ),
                           );
                         },
                       ),
                     ),
                     // 3. Completed Albums
                     if (completedAlbums.isNotEmpty)
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
                            child: CompletedAlbumList(
                              albums: completedAlbums,
                              currentUserId: currentUserId,
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
                       ),
                     // 4. Shared Albums
                     if (sharedAlbums.isNotEmpty)
                       SliverToBoxAdapter(
                         child: Padding(
                           padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.w),
                            child: SharedAlbumList(
                              albums: sharedAlbums,
                              currentUserId: currentUserId,
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
                            ),
                         ),
                       ),
                     // Bottom Padding for FAB
                     SliverToBoxAdapter(
                       child: SizedBox(height: 80.w),
                     ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: SnapFitColors.accentLight),
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
}



