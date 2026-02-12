import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../domain/entities/album.dart';
import 'home_status_chip.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_helpers.dart';

/// 그리드 앨범 카드
class HomeGridAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isEditMode;
  final VoidCallback? onDelete;

  const HomeGridAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.onLongPress,
    this.isEditMode = false,
    this.onDelete,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeGridAlbumCard', '그리드 앨범 카드 · 커버/제목/상태');
    }
    final isDark = SnapFitColors.isDark(context);
    final coverUrl =
        album.coverThumbnailUrl ?? album.coverPreviewUrl ?? album.coverImageUrl;
    final hasCoverUrl = coverUrl?.isNotEmpty == true;
    final hasLayers = album.coverLayersJson.isNotEmpty;
    final hasTheme = album.coverTheme?.isNotEmpty == true;
    final showDraft = !(hasCoverUrl || hasLayers || hasTheme);

    final cardContent = InkWell(
      onTap: isEditMode ? null : onTap, // 편집 모드일 때 클릭 방지
      onLongPress: onLongPress,
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
              album.title.isNotEmpty ? album.title : '앨범',
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
          ],
        ),
      ),
    );

    if (!isEditMode) return cardContent;

    // 편집 모드: 겹쳐서 X 버튼 표시
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: 0.9, // 살짝 흐리게
          child: cardContent,
        ),
        Positioned(
          top: -6.h,
          right: -6.w,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935), // Red
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.w),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4.r,
                    offset: Offset(0, 2.h),
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                size: 16.sp,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
