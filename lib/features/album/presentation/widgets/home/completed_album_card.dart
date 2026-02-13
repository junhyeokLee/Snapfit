import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/album.dart';
import 'home_album_cover_thumbnail.dart';

class CompletedAlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;
  final String? description;

  const CompletedAlbumCard({
    super.key,
    required this.album,
    required this.onTap,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // 배경 제거 및 패딩 조정
        padding: EdgeInsets.symmetric(vertical: 12.h),
        color: Colors.transparent, 
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Album Cover (Self-sized)
            _buildCoverImage(),
            SizedBox(width: 16.w),
            // Right: Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Text(
                        '2일 전', // Dummy relative time
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFFAAAAAA),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    description ?? '함께해서 더 즐거웠던 우리의 밤',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF888888),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _buildBottomRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    // "앨범으로 꽉 채워줘 각 커버 사이즈에 맞게"
    // -> Remove book styling, just show the thumbnail with shadow
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: HomeAlbumCoverThumbnail(
        album: album,
        height: 100.h, // Fixed height, width will adjust by ratio
        showShadow: false, // External shadow used
      ),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildAvatarGroup(),
        Icon(
          Icons.more_horiz,
          size: 20.sp,
          color: const Color(0xFFDDDDDD),
        ),
      ],
    );
  }

  Widget _buildAvatarGroup() {
    // Dummy avatars
    return SizedBox(
      width: 60.w,
      height: 24.w,
      child: Stack(
        children: [
           _avatar(0, const Color(0xFFE0E0E0)),
           _avatar(16.w, const Color(0xFFD0D0D0)),
           Positioned(
            left: 32.w,
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '+2',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF888888),
                  ),
                ),
              ),
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
        width: 24.w,
        height: 24.w,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Icon(Icons.person, size: 14.sp, color: Colors.white),
      ),
    );
  }
}
