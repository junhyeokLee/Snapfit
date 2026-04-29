import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../core/constants/cover_size.dart';

import './decorate_sticker_tab.dart';
import './decorate_color_tab.dart';

enum DecorateSheetMode { sticker, backgroundColor }

class DecoratePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final DecorateSheetMode mode;

  const DecoratePanel({
    super.key,
    this.onClose,
    required this.mode,
  });

  @override
  ConsumerState<DecoratePanel> createState() => _DecoratePanelState();
}

class _DecoratePanelState extends ConsumerState<DecoratePanel> {
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
    final double physicalAspect = editorVm.selectedCover.ratio > 0
        ? editorVm.selectedCover.ratio
        : (3 / 4);
    final double logicalW = kCoverReferenceWidth;
    final double logicalH = logicalW / physicalAspect;
    return Size(logicalW, logicalH);
  }

  @override
  Widget build(BuildContext context) {
    final surfaceColor = SnapFitColors.surfaceOf(context);
    final content = widget.mode == DecorateSheetMode.sticker
        ? DecorateStickerTab(
            surfaceColor: surfaceColor,
            onStickerTap: (sticker) {
              final editorVm = ref.read(albumEditorViewModelProvider.notifier);
              final stateVal = ref.read(albumEditorViewModelProvider).value;
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
                editorVm.addDecorationSticker(style, canvasSize, scale: scale);
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
          )
        : DecorateColorTab(
            surfaceColor: surfaceColor,
            onColorTap: (colorValue) {
              final editorVm = ref.read(albumEditorViewModelProvider.notifier);
              if (colorValue == -1) {
                editorVm.clearPageBackgroundColor();
              } else {
                editorVm.updatePageBackgroundColor(colorValue);
              }
              _closeSheet();
            },
          );

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
          SizedBox(height: 10.h),
          Expanded(child: content),
        ],
      ),
    );
  }
}
