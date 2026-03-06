import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

enum EditorMode {
  none,
  template,
  decorate,
  layer,
  text, // For text editing, though usually handled by dialog/overlay
}

class EditorBottomMenu extends StatelessWidget {
  final EditorMode currentMode;
  final Function(EditorMode) onModeChanged;
  final VoidCallback? onAddPhoto;
  final bool isCover;
  final VoidCallback? onCover;

  const EditorBottomMenu({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.onAddPhoto,
    this.isCover = false,
    this.onCover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80.h,
      padding: EdgeInsets.only(bottom: 20.h), // 하단 여백 확보
      decoration: BoxDecoration(
        color: Colors.transparent, // 상위 그라데이션 배경 그대로 사용
        border: Border(
          top: BorderSide(color: SnapFitColors.overlayLightOf(context), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMenuItem(context, '글쓰기', Icons.text_fields_outlined, EditorMode.text),
          _buildMenuItem(context, '사진', Icons.photo_outlined, EditorMode.none, isAction: true, onAction: onAddPhoto),
          isCover 
            ? _buildMenuItem(context, '커버', Icons.dashboard_outlined, EditorMode.none, isAction: true, onAction: onCover)
            : _buildMenuItem(context, '템플릿', Icons.dashboard_outlined, EditorMode.template),
          _buildMenuItem(context, '꾸미기', Icons.palette_outlined, EditorMode.decorate),
          _buildMenuItem(context, '레이어', Icons.layers_outlined, EditorMode.layer),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String label, IconData icon, EditorMode mode, {bool isAction = false, VoidCallback? onAction}) {
    final isSelected = !isAction && currentMode == mode;
    final color = isSelected ? SnapFitColors.accent : SnapFitColors.textSecondaryOf(context);

    return InkWell(
      onTap: () {
        if (isAction) {
          onAction?.call();
        } else {
          onModeChanged(isSelected ? EditorMode.none : mode);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
