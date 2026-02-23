import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class LayerSelectionToolbar extends StatelessWidget {
  final VoidCallback? onStyle;
  final VoidCallback? onFont;
  final VoidCallback? onColor;
  final VoidCallback? onOpacity;
  final VoidCallback? onDelete;
  final VoidCallback? onOrder;
  final bool isText;

  const LayerSelectionToolbar({
    super.key,
    this.onStyle,
    this.onFont,
    this.onColor,
    this.onOpacity,
    this.onDelete,
    this.onOrder,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64.h,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withOpacity(0.95), // Semi-transparent based on theme
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolItem(context, Icons.style_outlined, "스타일", onStyle),
          if (isText) _buildToolItem(context, Icons.text_fields_outlined, "폰트", onFont),
          _buildToolItem(context, Icons.palette_outlined, "색상", onColor, isActive: true),
          _buildToolItem(context, Icons.opacity_outlined, "불투명도", onOpacity),
          _buildDeleteButton(context),
          _buildToolItem(context, Icons.layers_outlined, "순서", onOrder),
        ],
      ),
    );
  }

  Widget _buildToolItem(BuildContext context, IconData icon, String label, VoidCallback? onTap, {bool isActive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        decoration: isActive ? BoxDecoration(
          color: SnapFitColors.isDark(context) ? const Color(0xFF162A2E) : SnapFitColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: SnapFitColors.accent.withOpacity(0.3)),
        ) : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isActive ? SnapFitColors.accent : SnapFitColors.textSecondaryOf(context), 
              size: 20.sp
            ),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                color: isActive ? SnapFitColors.accent : SnapFitColors.textMutedOf(context),
                fontSize: 10.sp,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return InkWell(
      onTap: onDelete,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: const BoxDecoration(
                color: Color(0xFFFF4848), // Red delete button
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: Colors.white, size: 16.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              "삭제",
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
