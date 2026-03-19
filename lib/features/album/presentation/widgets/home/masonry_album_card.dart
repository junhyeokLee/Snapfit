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
    final List<double> ratios = [0.62, 0.58, 0.66, 0.7];
    return ratios[index % ratios.length];
  }

  @override
  Widget build(BuildContext context) {
    // 전체적인 카드 너비를 확보 (좌우 여백을 미세하게 줄여 카드를 키움)
    final double columnWidth = (1.sw - 60.w) / 2;
    final coverTone = sharedAlbumCoverToneColor(album);

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
                color: coverTone, // 커버 톤과 유사한 배경색 자동 매칭
                borderRadius: BorderRadius.circular(14.r),
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
                      padding: EdgeInsets.all(9.w),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain, // 잘림 방지 유지
                          child: HomeAlbumCoverThumbnail(
                            album: album,
                            height: 210.h,
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
                    left: 12.w,
                    child: _buildStatusChip(context),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),

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
          fontSize: 14.sp,
          fontWeight: FontWeight.w900,
          color: SnapFitColors.textPrimaryOf(context),
          letterSpacing: -0.3,
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
              fontSize: 10.5.sp,
              color: SnapFitColors.textMutedOf(context),
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: info.backgroundColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          fontSize: 9.5.sp,
          fontWeight: FontWeight.w900,
          color: info.foregroundColor,
        ),
      ),
    );
  }

  Widget _buildAvatarGroup(BuildContext context) {
    return SizedBox(
      width: 50.w,
      height: 22.w,
      child: Stack(
        children: [
          _avatar(context, 0, const Color(0xFFD9D4C7)),
          _avatar(context, 16.w, const Color(0xFFC9C4B7)),
          Positioned(
            left: 30.w,
            child: Container(
              width: 22.w,
              height: 22.w,
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: SnapFitColors.backgroundOf(context),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+2',
                style: TextStyle(
                  fontSize: 8.5.sp,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(BuildContext context, double left, Color color) {
    return Positioned(
      left: left,
      child: Container(
        width: 22.w,
        height: 22.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: SnapFitColors.backgroundOf(context),
            width: 2,
          ),
        ),
        child: Icon(Icons.person, size: 13.sp, color: Colors.white),
      ),
    );
  }
}
