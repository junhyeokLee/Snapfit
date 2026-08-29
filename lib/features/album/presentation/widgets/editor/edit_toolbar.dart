import 'package:flutter/material.dart';
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
      padding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 14.h, top: 8.h),
      child: Container(
        height: 64.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: SnapFitColors.isDark(context)
                ? [
                    SnapFitColors.surfaceOf(context).withOpacity(0.94),
                    SnapFitColors.surfaceOf(context).withOpacity(0.82),
                  ]
                : [
                    Colors.white.withOpacity(0.94),
                    const Color(0xFFFFF8F1).withOpacity(0.88),
                  ],
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.3 : 0.1,
              ),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // "글쓰기"
            _toolbarButton(
              context,
              Icons.text_fields_outlined,
              "글쓰기",
              onAddText,
            ),
            // "사진"
            _toolbarButton(context, Icons.photo_outlined, "사진", onAddPhoto),
            // "커버"
            _toolbarButton(
              context,
              Icons.dashboard_outlined,
              "커버",
              onOpenCoverSelector,
            ),
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
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22.sp, color: SnapFitColors.deepCharcoal),
            SizedBox(height: 4.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: SnapFitColors.textSecondaryOf(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
