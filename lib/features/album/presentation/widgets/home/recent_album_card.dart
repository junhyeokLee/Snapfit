import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_focus_wrap.dart';
import 'home_album_helpers.dart';

class RecentAlbumCard extends StatelessWidget {
  final Album album;
  final String currentUserId;
  final VoidCallback onTap;
  final bool isFocused;

  const RecentAlbumCard({
    super.key,
    required this.album,
    required this.currentUserId,
    required this.onTap,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final progressInfo = calculateAlbumProgress(album);
    final progress = progressInfo.ratio;
    final progressLabel = progressInfo.percentLabel;

    // Dynamic card size based on aspect ratio
    final ratio = parseCoverRatio(album.ratio);
    double width, height;

    if (ratio < 0.9) {
      // Vertical (3:4)
      width = 178.w;
      height = 238.w;
    } else if (ratio > 1.1) {
      // Horizontal (4:3)
      width = 238.w;
      height = 180.w;
    } else {
      // Square (1:1)
      width = 236.w;
      height = 236.w;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isFocused ? 1.0 : 0.7,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover Image Container
              Container(
                height:
                    238.w, // Fixed height to max possible height for alignment
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Hero(
                      tag: 'album_cover_${album.id}',
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          // Use HomeFocusWrap's shadow style
                          // scale: 0.8 matches roughly the card size relative to typical cover
                          // focus: 0.0 (unfocused) -> 1.0 (focused/lifted)
                          boxShadow: HomeFocusWrap.coverStyleShadowForScale(
                            0.8,
                            isFocused ? 1.0 : 0.0,
                          ),
                        ),
                        child: HomeAlbumCoverThumbnail(
                          album: album,
                          height:
                              height, // Actual height of the card (200, 266)
                          maxWidth: width,
                          showShadow: false,
                        ),
                      ),
                    ),
                    // Status Chip
                    Positioned(
                      top: 12.h,
                      left: 12.w,
                      child: _buildStatusChip(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.w),
              // Title
              Text(
                album.title.isEmpty ? '제목 없음' : album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textPrimaryOf(context),
                  height: 1.2,
                ),
              ),
              SizedBox(height: 6.w),
              // Info Row (Avatars + Time)
              Row(
                children: [
                  // Mock Avatars
                  SizedBox(
                    width: 38.w,
                    height: 20.w,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          child: _buildAvatar(const Color(0xFFD9D9D9)),
                        ),
                        Positioned(
                          left: 14.w,
                          child: _buildAvatar(const Color(0xFFE5E5E5)),
                        ),
                        Positioned(
                          left: 22.w,
                          child: Container(
                            width: 20.w,
                            height: 20.w,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.0,
                              ),
                            ),
                            alignment: Alignment.center,
                              child: Text(
                                '+2',
                                style: TextStyle(
                                fontSize: 8.5.sp,
                                color: Colors.black54,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      '최근 수정: ${formatAlbumDate(album.updatedAt.isEmpty ? album.createdAt : album.updatedAt)} 전',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.w),
              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00C2E0),
                        ), // Cyan Blue
                        minHeight: 5.w,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    progressLabel,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: const Color(0xFF00C2E0),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Color color) {
    return Container(
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.0),
      ),
      child: Icon(Icons.person, size: 12.sp, color: Colors.white),
    );
  }

  Widget _buildStatusChip() {
    final info = getAlbumStatusInfo(album, currentUserId);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: info.backgroundColor.withOpacity(0.78),
        borderRadius: BorderRadius.circular(7.r),
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        info.label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: info.foregroundColor,
        ),
      ),
    );
  }
}
