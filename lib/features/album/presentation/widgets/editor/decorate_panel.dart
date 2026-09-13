import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/album_editor_view_model.dart';

import './decorate_sticker_tab.dart';
import './decorate_color_tab.dart';

enum DecorateSheetMode { sticker, backgroundColor }

class DecoratePanel extends ConsumerStatefulWidget {
  final VoidCallback? onClose;
  final DecorateSheetMode mode;

  const DecoratePanel({super.key, this.onClose, required this.mode});

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

  @override
  Widget build(BuildContext context) {
    final surfaceColor = SnapFitColors.surfaceOf(context);
    final media = MediaQuery.of(context);
    final isLandscape = media.size.width > media.size.height;
    final preferredHeight = (media.size.height * (isLandscape ? 0.90 : 0.90))
        .clamp(isLandscape ? 300.0 : 520.0, isLandscape ? 600.0 : 900.0);
    final panelHeight = preferredHeight.clamp(
      0.0,
      media.size.height - media.padding.top - media.viewInsets.bottom,
    );
    final content = widget.mode == DecorateSheetMode.sticker
        ? DecorateStickerTab(
            surfaceColor: surfaceColor,
            onStickerTap: (sticker) {
              final editorVm = ref.read(albumEditorViewModelProvider.notifier);
              if (!editorVm.insertMaterial(sticker, emojiFontSize: 60.sp))
                return;
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
      height: panelHeight,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle
            SizedBox(height: isLandscape ? 8 : 12.h),
            Container(
              width: isLandscape ? 36 : 40.w,
              height: isLandscape ? 3.5 : 4.h,
              decoration: BoxDecoration(
                color: SnapFitColors.textPrimaryOf(
                  context,
                ).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 10.h),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
