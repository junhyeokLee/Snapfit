// Widgets/edit_cover_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 상단 커버 사이즈 선택 UI 전담
class CoverSelectorWidget extends StatelessWidget {
  final List<CoverSize> sizes;
  final CoverSize selected;
  final ValueChanged<CoverSize> onSelect;
  final IconData Function(CoverSize) iconForCover;
  final double height;

  const CoverSelectorWidget({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onSelect,
    required this.iconForCover,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: sizes.map((s) {
          final isSelected = s.name == selected.name;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: GestureDetector(
              onTap: () => onSelect(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayMediumOf(context),
                ),
                child: Icon(
                  iconForCover(s),
                  color: isSelected
                      ? SnapFitColors.pureWhite
                      : SnapFitColors.textPrimaryOf(context).withOpacity(0.7),
                  size: 22.sp,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}