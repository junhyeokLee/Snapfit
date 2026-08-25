import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

enum EditorMode {
  none,
  layout, // 슬롯 기반 레이아웃(페이지 템플릿)
  template, // 전체 디자인 템플릿 (확장용)
  sticker,
  backgroundColor,
  layer,
  text, // For text editing, though usually handled by dialog/overlay
}

class EditorBottomMenu extends StatelessWidget {
  final EditorMode currentMode;
  final Function(EditorMode) onModeChanged;
  final VoidCallback? onAddPhoto;
  final bool isCover;
  final VoidCallback? onCover;
  final bool showCoverMenuItem;

  const EditorBottomMenu({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.onAddPhoto,
    this.isCover = false,
    this.onCover,
    this.showCoverMenuItem = true,
  });

  @override
  Widget build(BuildContext context) {
    final items = isCover
        ? [
            _EditorMenuItem('글', Icons.text_fields_outlined, EditorMode.text),
            _EditorMenuItem(
              '사진',
              Icons.photo_outlined,
              EditorMode.none,
              isAction: true,
              onAction: onAddPhoto,
            ),
            if (showCoverMenuItem)
              _EditorMenuItem(
                '커버',
                Icons.photo_album_outlined,
                EditorMode.none,
                isAction: true,
                onAction: onCover,
              ),
            _EditorMenuItem('페이지', Icons.dashboard_outlined, EditorMode.layout),
            _EditorMenuItem(
              '스티커',
              Icons.emoji_emotions_outlined,
              EditorMode.sticker,
            ),
            _EditorMenuItem(
              '배경',
              Icons.palette_outlined,
              EditorMode.backgroundColor,
            ),
          ]
        : [
            _EditorMenuItem('글', Icons.text_fields_outlined, EditorMode.text),
            _EditorMenuItem(
              '사진',
              Icons.photo_outlined,
              EditorMode.none,
              isAction: true,
              onAction: onAddPhoto,
            ),
            _EditorMenuItem('페이지', Icons.dashboard_outlined, EditorMode.layout),
            _EditorMenuItem(
              '스티커',
              Icons.emoji_emotions_outlined,
              EditorMode.sticker,
            ),
            _EditorMenuItem(
              '배경',
              Icons.palette_outlined,
              EditorMode.backgroundColor,
            ),
          ];

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
      child: Container(
        height: 72.h,
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context).withOpacity(0.94),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          border: Border(
            top: BorderSide(
              color: SnapFitColors.overlayLightOf(context),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.28 : 0.08,
              ),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              SizedBox(width: 8.w),
              ...items.map(
                (item) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.w),
                  child: _buildMenuItem(context, item),
                ),
              ),
              SizedBox(width: 8.w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _EditorMenuItem item) {
    final isSelected = !item.isAction && currentMode == item.mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withOpacity(0.72)
        : SnapFitColors.deepCharcoal.withOpacity(0.66);

    return SnapFitPressable(
      pressedScale: 0.95,
      borderRadius: BorderRadius.circular(16.r),
      onTap: () {
        if (item.isAction) {
          item.onAction?.call();
        } else {
          onModeChanged(isSelected ? EditorMode.none : item.mode);
        }
      },
      child: AnimatedContainer(
        duration: SnapFitMotion.fast,
        curve: SnapFitMotion.settle,
        width: 62.w,
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isSelected
              ? SnapFitColors.accent.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16.r),
          border: isSelected
              ? Border.all(color: SnapFitColors.accent.withOpacity(0.18))
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.06 : 1.0,
              duration: SnapFitMotion.fast,
              curve: SnapFitMotion.settle,
              child: Icon(
                item.icon,
                color: isSelected ? SnapFitColors.accent : color,
                size: 20.sp,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                      .copyWith(
                        fontSize: 10.sp,
                        height: 1.0,
                        color: isSelected ? SnapFitColors.accent : color,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        letterSpacing: -0.05,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorMenuItem {
  const _EditorMenuItem(
    this.label,
    this.icon,
    this.mode, {
    this.isAction = false,
    this.onAction,
  });

  final String label;
  final IconData icon;
  final EditorMode mode;
  final bool isAction;
  final VoidCallback? onAction;
}
