import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'completed_album_card.dart';
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
    // Dummy Data for UI completion
    final List<({Album album, String description})> dummyData = [
      (
        album: Album(
          id: 1, // int type
          title: '동기들과의 홈파티',
          coverLayersJson: '',
          userId: '',
          createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          updatedAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          ratio: '1.0', // String type based on entity definition? Wait, definition said @Default('') String ratio.
        ),
        description: '함께해서 더 즐거웠던 우리의 밤',
      ),
      (
        album: Album(
          id: 2,
          title: '한강 불꽃축제 2023',
          coverLayersJson: '',
          userId: '',
          createdAt: DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
          updatedAt: DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
          ratio: '0.8',
        ),
        description: '밤하늘을 수놓은 아름다운 빛',
      ),
    ];

    return Container(
      color: Colors.white, // Section background
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 30.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '완료된 앨범',
            subtitle: '추억으로 남겨진 완벽한 기록들',
            onViewAll: onViewAll,
          ),
          SizedBox(height: 20.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dummyData.length, // Use dummy data
            separatorBuilder: (context, index) => SizedBox(height: 16.h),
            itemBuilder: (context, index) {
              final item = dummyData[index];
              return CompletedAlbumCard(
                album: item.album,
                description: item.description,
                onTap: () {},
              );
            },
          ),
        ],
      ),
    );
  }
}
