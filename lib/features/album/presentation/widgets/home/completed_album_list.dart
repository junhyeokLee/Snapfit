import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'completed_album_card.dart';
import 'section_header.dart';

class CompletedAlbumList extends StatelessWidget {
  final List<Album> albums;
  final String currentUserId;
  final Function(Album) onTap;
  final VoidCallback onViewAll;

  const CompletedAlbumList({
    super.key,
    required this.albums,
    required this.currentUserId,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return Container(
      color: SnapFitColors.backgroundOf(context),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '완료된 앨범',
            subtitle: '추억으로 남겨진 완벽한 기록들',
            onViewAll: onViewAll,
          ),
          SizedBox(height: 14.h),
          for (int index = 0; index < albums.length; index++) ...[
            if (index > 0) SizedBox(height: 12.h),
            CompletedAlbumCard(
              album: albums[index],
              onTap: () => onTap(albums[index]),
            ),
          ],
        ],
      ),
    );
  }
}
