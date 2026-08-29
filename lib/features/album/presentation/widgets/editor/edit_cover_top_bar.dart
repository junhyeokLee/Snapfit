import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// EditCover 전용 상단 액션 바
class EditCoverTopBar extends StatelessWidget {
  final bool isCreating;
  final bool isEditMode;
  final VoidCallback onAction;

  const EditCoverTopBar({
    super.key,
    required this.isCreating,
    required this.isEditMode,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: SnapFitColors.readerGradientOf(context),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kToolbarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1F1B16), Color(0xFF5A4634)],
                  ),
                  borderRadius: BorderRadius.circular(999.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: Size(64.w, 32.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isCreating ? null : onAction,
                  child: Text(
                    !isEditMode ? '완료' : '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
            ],
          ),
        ),
      ),
    );
  }
}
