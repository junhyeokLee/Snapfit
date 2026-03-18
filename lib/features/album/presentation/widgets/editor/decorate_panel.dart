import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../domain/entities/layer.dart'; // Just in case
import '../../../../../core/constants/cover_size.dart';

import './decorate_sticker_tab.dart';
import './decorate_color_tab.dart';

class DecoratePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;

  const DecoratePanel({super.key, this.onClose});

  @override
  ConsumerState<DecoratePanel> createState() => _DecoratePanelState();
}

class _DecoratePanelState extends ConsumerState<DecoratePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _closeSheet() {
    widget.onClose?.call();
    if (widget.onClose == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  Size _effectiveLogicalCanvasSize({
    required AlbumEditorViewModel editorVm,
    required AlbumEditorState? stateVal,
  }) {
    final currentPage = editorVm.currentPage;
    final isCover = currentPage?.isCover ?? false;

    final physical = isCover
        ? stateVal?.coverCanvasSize
        : stateVal?.innerCanvasSize;
    final double physicalAspect =
        (physical != null &&
            physical != Size.zero &&
            physical.height > 0 &&
            physical.width > 0)
        ? (physical.width / physical.height)
        : (editorVm.selectedCover.ratio);

    final double logicalW = isCover ? kCoverReferenceWidth : 300.0;
    final double logicalH = logicalW / physicalAspect;
    return Size(logicalW, logicalH);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = SnapFitColors.surfaceOf(context);

    return Container(
      height: 460.h,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: Column(
        children: [
          // Handle
          SizedBox(height: 12.h),
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: SnapFitColors.textPrimaryOf(
                context,
              ).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),

          // TabBar
          SizedBox(height: 12.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              // 추천 스티커 / 배경 색상 탭 텍스트는
              // 라이트 모드: 진한 검정, 다크 모드: 흰색으로 표시
              labelColor: SnapFitColors.isDark(context)
                  ? Colors.white
                  : Colors.black87,
              unselectedLabelColor: SnapFitColors.isDark(context)
                  ? Colors.white70
                  : Colors.black54,
              indicatorColor: SnapFitColors.accent,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: "추천스티커"),
                Tab(text: "배경 색상"),
              ],
            ),
          ),

          const Divider(color: Colors.black12, height: 1),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                DecorateStickerTab(
                  surfaceColor: surfaceColor,
                  onStickerTap: (sticker) {
                    final editorVm = ref.read(
                      albumEditorViewModelProvider.notifier,
                    );
                    final stateVal = ref
                        .read(albumEditorViewModelProvider)
                        .value;
                    final canvasSize = _effectiveLogicalCanvasSize(
                      editorVm: editorVm,
                      stateVal: stateVal,
                    );
                    if (sticker.startsWith('deco:')) {
                      final payload = sticker.replaceFirst('deco:', '');
                      final parts = payload.split('@');
                      final style = parts.first;
                      final scale = parts.length > 1
                          ? (double.tryParse(parts[1]) ?? 1.0)
                          : 1.0;
                      editorVm.addDecorationSticker(
                        style,
                        canvasSize,
                        scale: scale,
                      );
                    } else if (sticker.startsWith('asset:')) {
                      final assetPath = sticker.replaceFirst('asset:', '');
                      editorVm.addAssetSticker(assetPath, canvasSize);
                    } else {
                      editorVm.addTextLayer(
                        sticker,
                        style: TextStyle(fontSize: 60.sp),
                        mode: TextStyleType.none,
                        canvasSize: canvasSize,
                      );
                    }
                    _closeSheet();
                  },
                ),
                DecorateColorTab(
                  surfaceColor: surfaceColor,
                  onColorTap: (colorValue) {
                    ref
                        .read(albumEditorViewModelProvider.notifier)
                        .updatePageBackgroundColor(colorValue);
                    _closeSheet();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
