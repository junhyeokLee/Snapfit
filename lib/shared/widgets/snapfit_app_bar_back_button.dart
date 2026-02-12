import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/snapfit_colors.dart';

class SnapFitAppBarBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const SnapFitAppBarBackButton({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 20.sp,
        color: color ?? SnapFitColors.textPrimaryOf(context),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
