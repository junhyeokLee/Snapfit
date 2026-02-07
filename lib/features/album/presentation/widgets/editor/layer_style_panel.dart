import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../shared/widgets/image_frame_style_picker.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../controllers/text_editor_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';

/// 레이어 선택 시 표시되는 스타일 패널 (텍스트 스타일 / 이미지 프레임 / 삭제)
class LayerStylePanel extends StatelessWidget {
  final LayerModel selected;
  final AlbumEditorViewModel vm;
  final LayerInteractionManager interaction;
  final VoidCallback onChanged;
  final Future<void> Function(LayerModel layer)? onPickPhotoForSlot;

  const LayerStylePanel({
    super.key,
    required this.selected,
    required this.vm,
    required this.interaction,
    required this.onChanged,
    this.onPickPhotoForSlot,
  });

  static const double _panelHeight = 56;

  @override
  Widget build(BuildContext context) {
    final isText = selected.type == LayerType.text;
    return Material(
      color: const Color(0xFF7d7a97).withOpacity(0.92),
      borderRadius: BorderRadius.circular(16.r),
      elevation: 4,
      child: Container(
        height: _panelHeight,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isText) ...[
              ...['tag', 'bubble', 'note', 'calligraphy', 'sticker', 'tape'].asMap().entries.map(
                    (e) => _TextStyleButton(
                      label: _styleLabel(e.value),
                      styleKey: e.value,
                      selected: selected,
                      vm: vm,
                      onChanged: onChanged,
                    ),
                  ),
              SizedBox(width: 8.w),
              _EditTextButton(
                selected: selected,
                vm: vm,
                onChanged: onChanged,
              ),
            ],
            if (!isText) ...[
              _ImageStyleButtons(
                selected: selected,
                vm: vm,
                onChanged: onChanged,
                onPickPhotoForSlot: onPickPhotoForSlot,
              ),
            ],
            _DeleteButton(
              onTap: () {
                interaction.deleteSelected();
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _styleLabel(String key) {
    switch (key) {
      case 'tag': return '라벨';
      case 'bubble': return '말풍선';
      case 'note': return '노트';
      case 'calligraphy': return '캘리';
      case 'sticker': return '스티커';
      case 'tape': return '테이프';
      default: return key;
    }
  }
}

class _TextStyleButton extends StatelessWidget {
  final String label;
  final String styleKey;
  final LayerModel selected;
  final AlbumEditorViewModel vm;
  final VoidCallback onChanged;

  const _TextStyleButton({
    required this.label,
    required this.styleKey,
    required this.selected,
    required this.vm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (selected.textBackground ?? '') == styleKey;
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: GestureDetector(
        onTap: () {
          vm.updateTextStyle(selected.id, styleKey);
          onChanged();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditTextButton extends StatelessWidget {
  final LayerModel selected;
  final AlbumEditorViewModel vm;
  final VoidCallback onChanged;

  const _EditTextButton({
    required this.selected,
    required this.vm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final textEditor = TextEditorManager(context, vm);
        await textEditor.openForExisting(selected);
        onChanged();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          "편집",
          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _ImageStyleButtons extends StatelessWidget {
  final LayerModel selected;
  final AlbumEditorViewModel vm;
  final VoidCallback onChanged;
  final Future<void> Function(LayerModel layer)? onPickPhotoForSlot;

  const _ImageStyleButtons({
    required this.selected,
    required this.vm,
    required this.onChanged,
    this.onPickPhotoForSlot,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = selected.asset != null ||
        (selected.previewUrl ?? selected.imageUrl ?? selected.originalUrl) != null;

    if (hasImage) {
      return GestureDetector(
        onTap: () async {
          final currentKey = selected.imageBackground ?? '';
          final result = await ImageFrameStylePicker.show(context, currentKey: currentKey);
          if (result != null) {
            vm.updateImageFrame(selected.id, result);
            onChanged();
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          margin: EdgeInsets.only(right: 8.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.4), Colors.white.withOpacity(0.2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_size_select_large, size: 20.sp, color: Colors.white),
              SizedBox(width: 4.w),
              Text(
                "프레임",
                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (onPickPhotoForSlot != null) {
          await onPickPhotoForSlot!(selected);
          onChanged();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        margin: EdgeInsets.only(right: 8.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo, size: 20.sp, color: Colors.white),
            SizedBox(width: 4.w),
            Text(
              "사진 추가",
              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
