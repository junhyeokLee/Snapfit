import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../auth/data/dto/auth_response.dart';
import '../../../domain/entities/album.dart';
import 'home_greeting_header.dart';
import 'home_empty_state.dart';
import 'home_featured_album_card.dart';
import 'home_grid_album_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final featured = albums.isNotEmpty ? albums.first : null;
    final rest = albums.length > 1 ? albums.sublist(1) : const <Album>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 160.h),
      clipBehavior: Clip.hardEdge,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 8.h),
          child: HomeGreetingHeader(userInfo: userInfo),
        ),
        if (albums.isEmpty) ...[
          SizedBox(height: 12.h),
          emptyState,
        ],
        if (featured != null) ...[
          HomeFeaturedAlbumCard(
            album: featured,
            onTap: () async {
              final index = albums.indexOf(featured);
              onSelect(index);
              await onOpen(featured, index);
            },
          ),
          SizedBox(height: 16.h),
        ],
        if (rest.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rest.length,
            clipBehavior: Clip.none,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16.h,
              crossAxisSpacing: 14.w,
              childAspectRatio: 0.6,
            ),
            itemBuilder: (context, i) {
              final album = rest[i];
              final index = i + 1;
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
