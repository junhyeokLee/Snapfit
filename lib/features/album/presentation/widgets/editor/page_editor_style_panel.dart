import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/text_editor_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../shared/widgets/image_frame_style_picker.dart';
import 'page_editor_text_style_button.dart';
import 'page_editor_image_action_buttons.dart';

/// 페이지 편집 스타일 패널
class PageEditorStylePanel extends StatelessWidget {
  final AlbumEditorViewModel vm;
  final LayerModel selected;
  final List<LayerModel> layers;
  final VoidCallback onDelete;
  final Future<void> Function(LayerModel layer) onPickPhotoForSlot;
  final VoidCallback onStateChanged;

  const PageEditorStylePanel({
    super.key,
    required this.vm,
    required this.selected,
    required this.layers,
    required this.onDelete,
    required this.onPickPhotoForSlot,
    required this.onStateChanged,
  });

  static const double panelHeight = 56;

  @override
  Widget build(BuildContext context) {
    final isText = selected.type == LayerType.text;
    return Material(
      color: SnapFitColors.surfaceOf(context).withOpacity(0.92),
      borderRadius: BorderRadius.circular(16.r),
      elevation: 4,
      child: Container(
        height: panelHeight,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isText) ...[
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "라벨",
                styleKey: "tag",
                onStateChanged: onStateChanged,
              ),
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "말풍선",
                styleKey: "bubble",
                onStateChanged: onStateChanged,
              ),
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "노트",
                styleKey: "note",
                onStateChanged: onStateChanged,
              ),
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "캘리",
                styleKey: "calligraphy",
                onStateChanged: onStateChanged,
              ),
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "스티커",
                styleKey: "sticker",
                onStateChanged: onStateChanged,
              ),
              PageEditorTextStyleButton(
                vm: vm,
                selected: selected,
                label: "테이프",
                styleKey: "tape",
                onStateChanged: onStateChanged,
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () async {
                  final textEditor = TextEditorManager(context, vm);
                  await textEditor.openForExisting(selected);
                  onStateChanged();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    "편집",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (!isText) ...[
              PageEditorImageActionButtons(
                selected: selected,
                vm: vm,
                onPickPhotoForSlot: onPickPhotoForSlot,
                onStateChanged: onStateChanged,
              ),
            ],
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.delete, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
