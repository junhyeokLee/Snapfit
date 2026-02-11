import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_primary_gradient_background.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../domain/entities/album.dart';
import '../../domain/entities/layer.dart';
import '../../domain/entities/layer_export_mapper.dart';
import '../widgets/cover/cover.dart';
import '../widgets/home/home_bottom_navigation_bar.dart';
import '../widgets/home/home_greeting_header.dart';
import '../widgets/home/home_empty_state.dart';
import '../widgets/home/home_status_chip.dart';
import '../widgets/home/home_collaborator_widgets.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_icon_buttons.dart';
import '../widgets/home/home_avatar_dot.dart';
import '../widgets/home/home_create_album_fab.dart';
import '../widgets/home/home_album_list_view.dart';
import '../widgets/home/home_featured_album_card.dart';
import '../widgets/home/home_grid_album_card.dart';
import '../widgets/home/home_album_cover_thumbnail.dart';
import '../widgets/home/home_cover_frame.dart';
import '../widgets/home/home_focus_wrap.dart';
import '../widgets/home/home_album_helpers.dart';
import '../widgets/home/home_error_state.dart';
import '../widgets/home/home_album_slider.dart';
import '../widgets/home/home_bottom_nav_placeholder.dart';
import '../widgets/home/home_album_actions.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../viewmodels/cover_view_model.dart';
import '../viewmodels/home_view_model.dart';
import 'add_cover_screen.dart';
import 'album_reader_screen.dart';
import 'album_create_flow_screen.dart';
import 'fanned_pages_view.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  int _bottomNavIndex = 0;

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
    final albums = albumsAsync.asData?.value;
    final sortedAlbums = albums == null
        ? null
        : (List<Album>.from(albums)
          ..sort((a, b) => (b.createdAt).compareTo(a.createdAt)));
    final selectedAlbum = (sortedAlbums == null || sortedAlbums.isEmpty)
        ? null
        : sortedAlbums[_selectedIndex.clamp(0, sortedAlbums.length - 1)];

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
                    onSearch: () {},
                    onNotification: () {},
                  ),
                ),
                Expanded(
                  child: albumsAsync.when(
                    data: (albums) {
                      final sorted = List<Album>.from(albums)
                        ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
                      return HomeAlbumListView(
                        albums: sorted,
                        selectedIndex: _selectedIndex,
                        userInfo: authAsync.value,
                        emptyState: const HomeEmptyState(),
                        onSelect: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onOpen: (album, index) async {
                          setState(() => _selectedIndex = index);
                          await HomeAlbumActions.openAlbum(context, ref, album);
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
        return const HomeBottomNavPlaceholder(label: "알림");
      case 3:
        return const MyPageScreen();
      default:
        return homeBody;
    }
  }
}



