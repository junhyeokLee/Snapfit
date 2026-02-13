import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';
import 'home_album_helpers.dart';

class ListAlbumCard extends StatelessWidget {
  final Album album;
  final String currentUserId;
  final VoidCallback onTap;

  const ListAlbumCard({
    super.key,
    required this.album,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            SizedBox(
              width: 60.w,
              height: 80.w,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: HomeAlbumCoverThumbnail(
                  album: album,
                  height: 80.w,
                  maxWidth: 60.w,
                  showShadow: false,
                ),
              ),
            ),
            SizedBox(width: 16.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.title.isEmpty ? '제목 없음' : album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8.w),
                  Row(
                    children: [
                       // Mock Avatars
                       SizedBox(
                         width: 44.w,
                         height: 20.w,
                         child: Stack(
                           children: [
                             Positioned(
                               left: 0,
                               child: _buildAvatar(Colors.grey[300]!),
                             ),
                             Positioned(
                               left: 14.w,
                                child: _buildAvatar(Colors.grey[400]!),
                             ),
                              Positioned(
                               left: 28.w,
                               child: _buildAvatar(Colors.amber[200]!),
                             ),
                           ],
                         ),
                       ),
                       SizedBox(width: 8.w),
                       () {
                         final info = getAlbumStatusInfo(album, currentUserId);
                         return Text(
                           info.label,
                           style: TextStyle(
                             fontSize: 12.sp,
                             fontWeight: FontWeight.w700,
                             color: info.foregroundColor,
                           ),
                         );
                       }(),
                    ],
                  ),
                  SizedBox(height: 4.w),
                  Text(
                    '마지막 수정: ${formatAlbumDate(album.updatedAt.isEmpty ? album.createdAt : album.updatedAt)}',
                     style: TextStyle(
                       fontSize: 11.sp,
                       color: SnapFitColors.textSecondaryOf(context),
                     ),
                  ),
                ],
              ),
            ),

          ],
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
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(Icons.person, size: 12.sp, color: Colors.white),
    );
  }
}
