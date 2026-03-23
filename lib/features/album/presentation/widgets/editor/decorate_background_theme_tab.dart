import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/cover_theme.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class DecorateBackgroundThemeTab extends StatefulWidget {
  final Color surfaceColor;
  final CoverTheme selectedTheme;
  final void Function(CoverTheme theme)? onThemeTap;

  const DecorateBackgroundThemeTab({
    super.key,
    required this.surfaceColor,
    required this.selectedTheme,
    this.onThemeTap,
  });

  @override
  State<DecorateBackgroundThemeTab> createState() =>
      _DecorateBackgroundThemeTabState();
}

class _DecorateBackgroundThemeTabState
    extends State<DecorateBackgroundThemeTab> {
  CoverTheme? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedTheme;
  }

  @override
  void didUpdateWidget(covariant DecorateBackgroundThemeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTheme != widget.selectedTheme) {
      _selected = widget.selectedTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 20.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.0,
      ),
      itemCount: CoverTheme.values.length,
      itemBuilder: (context, index) {
        final theme = CoverTheme.values[index];
        final selected = _selected == theme;
        return GestureDetector(
          onTap: () {
            setState(() => _selected = theme);
            widget.onThemeTap?.call(theme);
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.surfaceColor,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: selected
                    ? SnapFitColors.accent
                    : SnapFitColors.overlayLightOf(context),
                width: selected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(8.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.r),
                child: Container(
                  decoration: BoxDecoration(
                    image: theme.imageAsset != null
                        ? DecorationImage(
                            image: AssetImage(theme.imageAsset!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: theme.imageAsset == null ? theme.gradient : null,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
