import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../shared/widgets/image_frame_style_picker.dart';

/// 이미지 액션 버튼들 (프레임 변경 또는 사진 추가)
class PageEditorImageActionButtons extends StatelessWidget {
  final LayerModel selected;
  final AlbumEditorViewModel vm;
  final Future<void> Function(LayerModel layer) onPickPhotoForSlot;
  final VoidCallback onStateChanged;

  const PageEditorImageActionButtons({
    super.key,
    required this.selected,
    required this.vm,
    required this.onPickPhotoForSlot,
    required this.onStateChanged,
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
            onStateChanged();
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          margin: EdgeInsets.only(right: 8.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                SnapFitColors.overlayMediumOf(context),
                SnapFitColors.overlayLightOf(context),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_size_select_large,
                size: 20.sp,
                color: SnapFitColors.textPrimaryOf(context),
              ),
              SizedBox(width: 4.w),
              Text(
                "프레임",
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return GestureDetector(
        onTap: () => onPickPhotoForSlot(selected),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          margin: EdgeInsets.only(right: 8.w),
          decoration: BoxDecoration(
            color: SnapFitColors.overlayMediumOf(context),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_a_photo,
                size: 20.sp,
                color: SnapFitColors.textPrimaryOf(context),
              ),
              SizedBox(width: 4.w),
              Text(
                "사진 추가",
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
