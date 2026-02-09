import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 홈 화면 우측 하단 새 앨범 버튼
class HomeCreateAlbumFab extends StatelessWidget {
  final VoidCallback onPressed;

  const HomeCreateAlbumFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'create_album_fab',
          onPressed: onPressed,
          backgroundColor: SnapFitColors.accent,
          elevation: 6,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        SizedBox(height: 6.h),
        Text(
          '앨범 만들기',
          style: TextStyle(
            fontSize: 11.sp,
            color: SnapFitColors.accentLight,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
