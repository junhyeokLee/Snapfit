import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final displayAlbums = albums.take(6).toList();
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
      // 스크린샷의 배경 톤과 시원한 여백 적용
      color: const Color(0xFFF9F8F4),
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '공유된 앨범',
            subtitle: '함께 만들어가는 소중한 순간들',
            onViewAll: onViewAll,
          ),
          SizedBox(height: 24.h), // 헤더와 리스트 사이 여백 확대
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: leftCol.map((e) => _padding(e, true)).toList(),
                ),
              ),
              SizedBox(width: 20.w), // 컬럼 사이 간격 확대
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
      padding: EdgeInsets.only(bottom: 32.h),
      child: MasonryAlbumCard(
        album: entry.value,
        currentUserId: currentUserId,
        onTap: () => onTap(entry.value),
        index: entry.key,
      ),
    );
  }
}