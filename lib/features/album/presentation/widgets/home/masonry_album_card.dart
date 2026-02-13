import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_helpers.dart';

class MasonryAlbumCard extends StatelessWidget {
  final Album album;
  final String currentUserId;
  final VoidCallback onTap;
  final int index;

  const MasonryAlbumCard({
    super.key,
    required this.album,
    required this.currentUserId,
    required this.onTap,
    this.index = 0,
  });

  /// 배경 자체를 더 크게 만들기 위해 AspectRatio를 더 길게 조정
  double get _cardAspectRatio {
    // 세로형은 더 길게(0.6), 가로형은 더 넓게(1.4) 하여 공간 확보
    // final List<double> ratios = [0.65, 1.4, 0.6, 1.2];
    final List<double> ratios = [0.5, 0.45, 0.55, 0.6];
    return ratios[index % ratios.length];
  }

  @override
  Widget build(BuildContext context) {
    // 전체적인 카드 너비를 확보 (좌우 여백을 미세하게 줄여 카드를 키움)
    final double columnWidth = (1.sw - 60.w) / 2;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 커버 이미지 컨테이너 (배경 캔버스)
          AspectRatio(
            aspectRatio: _cardAspectRatio,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8E2D0), // 샌드톤 배경
                borderRadius: BorderRadius.circular(16.r), // 배경이 커진 만큼 더 둥글게
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // [핵심] 배경을 키우고 커버 이미지도 비례해서 키움
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.all(12.w), // 여백을 줄여서 커버 이미지를 최대한 키움
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain, // 잘림 방지 유지
                          child: HomeAlbumCoverThumbnail(
                            album: album,
                            height: 250.h, // 기준 높이를 높여 고해상도 대응
                            maxWidth: columnWidth,
                            showShadow: true, // 커버 자체의 그림자를 활성화해 입체감 강조
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 상태 칩
                  Positioned(
                    top: 18.h,
                    left: 18.w,
                    child: _buildStatusChip(context),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 18.h),

          // 2. 제목 및 정보 섹션
          _buildTitleText(context),
          SizedBox(height: 12.h),
          _buildInfoRow(context),
        ],
      ),
    );
  }

  // --- 이하 빌더 메서드는 동일 (생략 가능하나 유지보수를 위해 구조 유지) ---
  Widget _buildTitleText(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Text(
        album.title.isEmpty ? '제목 없음' : album.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 18.sp, // 배경이 커진 만큼 폰트도 키움
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1A1A1A),
          letterSpacing: -0.8,
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildAvatarGroup(context),
          Text(
            '${formatAlbumDate(album.updatedAt.isEmpty ? album.createdAt : album.updatedAt)} 전',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black.withOpacity(0.4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final info = getAlbumStatusInfo(album, currentUserId);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: info.backgroundColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
          color: info.foregroundColor,
        ),
      ),
    );
  }

  Widget _buildAvatarGroup(BuildContext context) {
    return SizedBox(
      width: 56.w,
      height: 26.w,
      child: Stack(
        children: [
          _avatar(0, const Color(0xFFD9D4C7)),
          _avatar(18.w, const Color(0xFFC9C4B7)),
          Positioned(
            left: 36.w,
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF9F8F4), width: 2),
              ),
              alignment: Alignment.center,
              child: Text('+2', style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 26.w,
        height: 26.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF9F8F4), width: 2),
        ),
        child: Icon(Icons.person, size: 16.sp, color: Colors.white),
      ),
    );
  }
}