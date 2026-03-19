import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'masonry_album_card.dart';
import 'section_header.dart';

class SharedAlbumList extends StatelessWidget {
  final List<Album> albums;
  final String currentUserId;
  final Function(Album) onTap;
  final VoidCallback onViewAll;

  const SharedAlbumList({
    super.key,
    required this.albums,
    required this.currentUserId,
    required this.onTap,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final displayAlbums = albums.take(4).toList();
    if (displayAlbums.isEmpty) return const SizedBox.shrink();

    final List<MapEntry<int, Album>> leftCol = [];
    final List<MapEntry<int, Album>> rightCol = [];

    for (int i = 0; i < displayAlbums.length; i++) {
      i % 2 == 0
          ? leftCol.add(MapEntry(i, displayAlbums[i]))
          : rightCol.add(MapEntry(i, displayAlbums[i]));
    }

    return Container(
      width: double.infinity,
      color: SnapFitColors.backgroundOf(context),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '공유된 앨범',
            subtitle: '함께 만들어가는 소중한 순간들',
            onViewAll: onViewAll,
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: leftCol.map((e) => _padding(e, true)).toList(),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  children: rightCol.map((e) => _padding(e, false)).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _padding(MapEntry<int, Album> entry, bool isLeft) {
    return Padding(
      // 아래쪽 여백을 크게 주어 비정형 느낌 강조
      padding: EdgeInsets.only(bottom: 20.h),
      child: MasonryAlbumCard(
        album: entry.value,
        currentUserId: currentUserId,
        onTap: () => onTap(entry.value),
        index: entry.key,
      ),
    );
  }
}
