import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../auth/data/dto/auth_response.dart';
import '../../../domain/entities/album.dart';
import 'home_greeting_header.dart';
import 'home_empty_state.dart';
import 'home_featured_album_card.dart';
import 'home_grid_album_card.dart';
import 'home_album_helpers.dart';

/// 앨범 리스트 뷰
class HomeAlbumListView extends StatelessWidget {
  final List<Album> albums;
  final int selectedIndex;
  final UserInfo? userInfo;
  final Widget emptyState;
  final ValueChanged<int> onSelect;
  final Future<void> Function(Album album, int index) onOpen;

  const HomeAlbumListView({
    super.key,
    required this.albums,
    required this.selectedIndex,
    required this.userInfo,
    required this.emptyState,
    required this.onSelect,
    required this.onOpen,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeAlbumListView', '홈 앨범 리스트 · 피처드/그리드 카드');
    }
    // Draft는 홈 리스트에서 제외
    final visibleAlbums = albums.where((a) => !isDraftAlbum(a)).toList();

    final liveEditingAlbums =
        visibleAlbums.where((a) => isLiveEditingAlbum(a)).toList();
    final completedAlbums =
        visibleAlbums.where((a) => isCompletedAlbum(a)).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 160.h),
      clipBehavior: Clip.hardEdge,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: HomeGreetingHeader(userInfo: userInfo),
        ),
        if (visibleAlbums.isEmpty) ...[
          SizedBox(height: 12.h),
          emptyState,
        ],
        // LIVE EDITING 카드 모드
        if (liveEditingAlbums.isNotEmpty) ...[
          ...liveEditingAlbums.map((album) {
            return Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: HomeFeaturedAlbumCard(
                album: album,
                onTap: () async {
                  final index = albums.indexOf(album);
                  onSelect(index);
                  await onOpen(album, index);
                },
              ),
            );
          }),
          if (completedAlbums.isNotEmpty) SizedBox(height: 4.h),
        ],
        // 완료된 앨범: 그리드 모드
        if (completedAlbums.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completedAlbums.length,
            clipBehavior: Clip.none,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 14.w,
              childAspectRatio: 0.6,
            ),
            itemBuilder: (context, i) {
              final album = completedAlbums[i];
              final index = albums.indexOf(album);
              return HomeGridAlbumCard(
                album: album,
                onTap: () async {
                  onSelect(index);
                  await onOpen(album, index);
                },
              );
            },
          ),
      ],
    );
  }
}
