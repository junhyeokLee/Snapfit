import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';

class EditToolbar extends StatelessWidget {
  final AlbumEditorViewModel vm;
  final LayerModel? selected;
  final VoidCallback onAddText;
  final VoidCallback onAddPhoto;
  final VoidCallback onOpenCoverSelector;

  /// 첫 번째 버튼 라벨 (커버 에디터: "커버", 페이지 에디터: "템플릿")
  final String coverLabel;

  const EditToolbar({
    super.key,
    required this.vm,
    this.selected,
    required this.onAddText,
    required this.onAddPhoto,
    required this.onOpenCoverSelector,
    this.coverLabel = '커버',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h, top: 10.h),
      child: Container(
        height: 72.h,
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context).withOpacity(0.95), // theme support
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(SnapFitColors.isDark(context) ? 0.3 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // "글쓰기"
            _toolbarButton(context, Icons.text_fields_outlined, "글쓰기", onAddText),
            // "사진"
            _toolbarButton(context, Icons.photo_outlined, "사진", onAddPhoto),
            // "커버"
            _toolbarButton(context, Icons.dashboard_outlined, "커버", onOpenCoverSelector),
          ],
        ),
      ),
    );
  }

  Widget _toolbarButton(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24.sp, color: SnapFitColors.textPrimaryOf(context)),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: SnapFitColors.textSecondaryOf(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}