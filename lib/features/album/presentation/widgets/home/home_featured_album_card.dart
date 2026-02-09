import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final created = formatAlbumDate(album.createdAt);
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
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeStatusChip(
                    label: 'LIVE EDITING',
                    background: SnapFitColors.accent.withOpacity(0.16),
                    foreground: SnapFitColors.accentLight,
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
                  SizedBox(height: 10.h),
                  HomeCollaboratorSummary(
                    count: 12,
                    textColor: SnapFitColors.textMutedOf(context),
                  ),
                  SizedBox(height: 12.h),
                  SnapFitPrimaryGradientBackground(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '편집 계속하기',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: SnapFitColors.pureWhite,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Icon(
                            Icons.arrow_forward,
                            size: 14.sp,
                            color: SnapFitColors.pureWhite,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: HomeAlbumCoverThumbnail(
                album: album,
                height: 96.h,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
