import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';

/// 텍스트 스타일 버튼
class PageEditorTextStyleButton extends StatelessWidget {
  final AlbumEditorViewModel vm;
  final LayerModel selected;
  final String label;
  final String styleKey;
  final VoidCallback onStateChanged;

  const PageEditorTextStyleButton({
    super.key,
    required this.vm,
    required this.selected,
    required this.label,
    required this.styleKey,
    required this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = (selected.textBackground ?? '') == styleKey;
    return Padding(
      padding: EdgeInsets.only(right: 6.w),
      child: GestureDetector(
        onTap: () {
          vm.updateTextStyle(selected.id, styleKey);
          onStateChanged();
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isSelected
                ? SnapFitColors.overlayStrongOf(context)
                : SnapFitColors.overlayLightOf(context),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 11.sp,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
