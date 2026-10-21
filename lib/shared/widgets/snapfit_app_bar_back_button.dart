import 'package:flutter/material.dart';
import '../../core/constants/snapfit_colors.dart';
import '../../core/theme/snapfit_design_tokens.dart';

class SnapFitAppBarBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const SnapFitAppBarBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: '뒤로가기',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 20,
        color: color ?? SnapFitColors.textPrimaryOf(context),
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.standard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.md),
        ),
      ),
    );
  }
}
