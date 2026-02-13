import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'list_album_card.dart';
import 'section_header.dart';

class CompletedAlbumList extends StatelessWidget {
  final List<Album> albums;
  final String currentUserId;
  final VoidCallback onViewAll;

  const CompletedAlbumList({
    super.key,
    required this.albums,
    required this.currentUserId,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '완료된 앨범',
          onViewAll: onViewAll,
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: albums.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.w),
          itemBuilder: (context, index) {
            return ListAlbumCard(
              album: albums[index],
              currentUserId: currentUserId,
              onTap: () {},
            );
          },
        ),
      ],
    );
  }
}
