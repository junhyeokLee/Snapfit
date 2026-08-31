import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:ui';
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
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  const EditorBottomMenu({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.onAddPhoto,
    this.isCover = false,
    this.onCover,
    this.showCoverMenuItem = true,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final items = isCover
        ? [
            _EditorMenuItem('글', Icons.text_fields_outlined, EditorMode.text),
            _EditorMenuItem(
              '사진',
              Icons.add_photo_alternate_outlined,
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
            _EditorMenuItem(
              '레이아웃',
              Icons.dashboard_customize_outlined,
              EditorMode.layout,
            ),
            _EditorMenuItem(
              '템플릿',
              Icons.auto_awesome_mosaic_outlined,
              EditorMode.template,
            ),
            _EditorMenuItem('레이어', Icons.layers_rounded, EditorMode.layer),
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
              Icons.add_photo_alternate_outlined,
              EditorMode.none,
              isAction: true,
              onAction: onAddPhoto,
            ),
            _EditorMenuItem(
              '레이아웃',
              Icons.dashboard_customize_outlined,
              EditorMode.layout,
            ),
            _EditorMenuItem(
              '템플릿',
              Icons.auto_awesome_mosaic_outlined,
              EditorMode.template,
            ),
            _EditorMenuItem('레이어', Icons.layers_rounded, EditorMode.layer),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVerticalRail = constraints.maxWidth < 120;
        final isDark = SnapFitColors.isDark(context);

        return Container(
          height: isVerticalRail ? double.infinity : 90,
          width: isVerticalRail ? 62 : null,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.r),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1D2230).withOpacity(0.96),
                      const Color(0xFF101820).withOpacity(0.92),
                    ]
                  : [
                      Colors.white.withOpacity(0.95),
                      const Color(0xFFF5E8D7).withOpacity(0.92),
                      const Color(0xFFFCF7EF).withOpacity(0.96),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFDCCDBB),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF6C5740,
                ).withOpacity(isDark ? 0.34 : 0.14),
                blurRadius: 28,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: SingleChildScrollView(
                scrollDirection: isVerticalRail
                    ? Axis.vertical
                    : Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: isVerticalRail
                    ? const EdgeInsets.symmetric(horizontal: 6, vertical: 8)
                    : EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
                child: isVerticalRail
                    ? Column(
                        children: items
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: _buildMenuItem(
                                  context,
                                  item,
                                  compact: true,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : Row(
                        children: items
                            .map(
                              (item) => Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3.w),
                                child: _buildMenuItem(context, item),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    _EditorMenuItem item, {
    bool compact = false,
  }) {
    final isSelected = !item.isAction && currentMode == item.mode;
    final isDark = SnapFitColors.isDark(context);
    final baseColor = isDark
        ? Colors.white.withOpacity(0.74)
        : SnapFitColors.deepCharcoal.withOpacity(0.70);
    final isFeatured = isSelected;

    return SnapFitPressable(
      pressedScale: 0.94,
      borderRadius: BorderRadius.circular(22.r),
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
        width: compact ? 44 : 58,
        height: compact ? 38 : 66,
        padding: compact
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22.r),
          gradient: isSelected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2520), Color(0xFF6E5942)],
                )
              : null,
          color: isSelected
              ? null
              : isFeatured
              ? const Color(0xFFF1E1CB).withOpacity(isDark ? 0.16 : 0.80)
              : Colors.white.withOpacity(isDark ? 0.05 : 0.42),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.20)
                : isFeatured
                ? const Color(0xFFB98B62).withOpacity(0.26)
                : SnapFitColors.overlayLightOf(context),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6C5740).withOpacity(0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: SnapFitMotion.fast,
                  curve: SnapFitMotion.settle,
                  child: Icon(
                    item.icon,
                    color: isSelected
                        ? Colors.white
                        : isFeatured
                        ? const Color(0xFF8F6846)
                        : baseColor,
                    size: compact ? 19 : 22,
                  ),
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    (Theme.of(context).textTheme.bodySmall ?? const TextStyle())
                        .copyWith(
                          fontSize: 10,
                          height: 1.0,
                          color: isSelected
                              ? Colors.white
                              : isFeatured
                              ? const Color(0xFF8F6846)
                              : baseColor,
                          fontWeight: isSelected || isFeatured
                              ? FontWeight.w900
                              : FontWeight.w800,
                          letterSpacing: -0.12,
                        ),
              ),
            ],
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
