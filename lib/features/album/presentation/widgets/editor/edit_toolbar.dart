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
      height: 80.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolbarButton(Icons.menu_book_outlined, coverLabel, onOpenCoverSelector),
          _toolbarButton(Icons.text_fields, "텍스트", onAddText),
          _toolbarButton(Icons.photo, "오버레이", onAddPhoto),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26.sp, color: SnapFitColors.accent),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.sp,
                color: SnapFitColors.textPrimary.withOpacity(0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}