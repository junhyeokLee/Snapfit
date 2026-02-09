import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_status_chip.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_helpers.dart';

/// 그리드 앨범 카드
class HomeGridAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const HomeGridAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final coverUrl =
        album.coverThumbnailUrl ?? album.coverPreviewUrl ?? album.coverImageUrl;
    final hasCoverUrl = coverUrl?.isNotEmpty == true;
    final hasLayers = album.coverLayersJson.isNotEmpty;
    final hasTheme = album.coverTheme?.isNotEmpty == true;
    final showDraft = !(hasCoverUrl || hasLayers || hasTheme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color:
              isDark ? SnapFitColors.surfaceOf(context) : SnapFitColors.pureWhite,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDraft) ...[
              HomeStatusChip(
                label: 'DRAFT',
                background: isDark
                    ? SnapFitColors.overlayLightOf(context)
                    : const Color(0xFFF2F2F2),
                foreground: isDark
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.deepCharcoal,
              ),
              SizedBox(height: 10.h),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = parseCoverRatio(album.ratio);
                  final maxHeight = constraints.maxHeight;
                  final height = ratio > 1
                      ? maxHeight * 0.82
                      : maxHeight * 0.7;
                  return Align(
                    alignment: Alignment.center,
                    child: HomeAlbumCoverThumbnail(
                      album: album,
                      height: height,
                      maxWidth: constraints.maxWidth,
                    ),
                  );
                },
              ),
            ),
            Text(
              album.coverTheme?.isNotEmpty == true ? album.coverTheme! : '앨범',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? SnapFitColors.textPrimaryOf(context)
                    : SnapFitColors.deepCharcoal,
              ),
            ),
            SizedBox(height: 2.h),
            Row(
              children: [
                Icon(
                  Icons.groups_2_outlined,
                  size: 14.sp,
                  color: SnapFitColors.textMutedOf(context),
                ),
                SizedBox(width: 4.w),
                Text(
                  '공동작업자 12명',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
