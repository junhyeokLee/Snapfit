import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';

class LayerManagerPanel extends ConsumerWidget {
  final List<LayerModel> layers;

  const LayerManagerPanel({super.key, required this.layers});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (layers.isEmpty) {
      return Center(
        child: Text(
          "레이어가 없습니다.",
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
      );
    }

    return Container(
      height: 300.h,
      color: SnapFitColors.backgroundOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              "레이어 순서",
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              itemCount: layers.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                ref.read(albumEditorViewModelProvider.notifier).reorderLayer(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                // Reverse index because Stack renders bottom-up, but list usually shows top-down
                // Actually, let's keep it simple: index 0 is bottom-most in Stack.
                // But in UI, users usually expect top item to be "on top".
                // So we might want to display in reverse order or handle it.
                // For now, let's just show them as is.
                final layer = layers[index];
                return _buildLayerItem(context, layer, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerItem(BuildContext context, LayerModel layer, int index) {
    final surfaceColor = SnapFitColors.surfaceOf(context);
    final isSelected = false; // TODO: 링크된 선택 상태 반영

    return Container(
      key: ValueKey(layer.id),
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16.r),
        border: isSelected 
          ? Border.all(color: SnapFitColors.accent, width: 2)
          : Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, color: SnapFitColors.textPrimaryOf(context).withOpacity(0.3), size: 20.sp),
          SizedBox(width: 16.w),
          _buildLayerPreview(context, layer),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  layer.type == LayerType.text ? "텍스트 1" : "스티커 2",
                  style: TextStyle(
                    color: SnapFitColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isSelected ? "선택됨" : (layer.type == LayerType.text ? "우리의 여름" : "Sun Emoji"),
                  style: TextStyle(
                    color: isSelected ? SnapFitColors.accent : SnapFitColors.textSecondaryOf(context),
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.visibility,
            color: SnapFitColors.accent,
            size: 24.sp,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerPreview(BuildContext context, LayerModel layer) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: SnapFitColors.textPrimaryOf(context).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8.r),
      ),
      padding: EdgeInsets.all(6.w),
      child: Center(
        child: layer.type == LayerType.image
            ? Icon(Icons.wb_sunny, color: Colors.orange, size: 24.sp) // 임시 스티커 아이콘
            : Icon(Icons.text_fields, color: SnapFitColors.textSecondaryOf(context), size: 20.sp),
      ),
    );
  }
}
