import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_primary_gradient_background.dart';
import '../../../domain/entities/album.dart';
import 'home_status_chip.dart';
import 'home_collaborator_widgets.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_helpers.dart';

/// 피처드 앨범 카드
class HomeFeaturedAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const HomeFeaturedAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeFeaturedAlbumCard', '피처드 앨범 카드 · 진행률/협업자');
    }
    final created = formatAlbumDate(album.createdAt);
    final hasTarget = album.targetPages > 0;
    final progressText = hasTarget
        ? '${album.totalPages}/${album.targetPages} 페이지 진행 중'
        : '${album.totalPages} 페이지 진행 중';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: SnapFitColors.isDark(context)
              ? SnapFitColors.surfaceOf(context)
              : SnapFitColors.pureWhite,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20.r,
              offset: Offset(0, 10.h),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LIVE EDITING 배지 - 그라데이션 컬러 적용
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: SnapFitColors.primaryGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'LIVE EDITING',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: SnapFitColors.pureWhite,
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    album.coverTheme?.isNotEmpty == true
                        ? album.coverTheme!
                        : '앨범',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '$created 업데이트',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(height: 12.h),
                  // 하단: 왼쪽 정렬, 텍스트 길이만큼만 차지하는 편집 계속하기 버튼
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        // OutlinedButton 기본 보더 제거
                        side: BorderSide.none,
                        minimumSize: Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        backgroundColor: SnapFitColors.accentLight,
                      ),
                      onPressed: onTap,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '편집 계속하기',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: SnapFitColors.accent,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.arrow_forward,
                            size: 16.sp,
                            color: SnapFitColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            // 커버 이미지를 카드의 위아래를 거의 꽉 채우도록 배치
            LayoutBuilder(
              builder: (context, constraints) {
                final coverHeight = constraints.maxHeight - 8.h; // 위아래 살짝 패딩
                return Padding(
                  padding: EdgeInsets.only(
                    top: 4.h,
                    bottom: 4.h,
                    right: 4.w,
                  ),
                  child: HomeAlbumCoverThumbnail(
                    album: album,
                    height: coverHeight.clamp(88.h, 140.h),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
