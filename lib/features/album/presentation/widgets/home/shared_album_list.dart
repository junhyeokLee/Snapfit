import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_actions.dart';
import 'list_album_card.dart';
import 'section_header.dart';

class SharedAlbumList extends ConsumerWidget {
  final List<Album> albums;
  final String currentUserId;
  final VoidCallback onViewAll;

  const SharedAlbumList({
    super.key,
    required this.albums,
    required this.currentUserId,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '공유된 앨범',
          onViewAll: onViewAll,
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: albums.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.w),
          itemBuilder: (context, index) {
            final album = albums[index];
            return ListAlbumCard(
              album: album,
              currentUserId: currentUserId,
              onTap: () => HomeAlbumActions.openAlbum(context, ref, album),
            );
          },
        ),
      ],
    );
  }
}
