import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';

/// 레이어 순서 리스트 위젯
class LayerOrderList extends StatelessWidget {
  final List<LayerModel> layers;
  final String? selectedLayerId;
  final ValueChanged<String> onLayerSelected;
  final ValueChanged<int>? onLayerReordered;
  final ValueChanged<String>? onLayerVisibilityToggled;

  const LayerOrderList({
    super.key,
    required this.layers,
    this.selectedLayerId,
    required this.onLayerSelected,
    this.onLayerReordered,
    this.onLayerVisibilityToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withOpacity(0.95),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 헤더
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: SnapFitColors.overlayLightOf(context),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '레이어 순서',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: SnapFitColors.textMutedOf(context),
                ),
              ],
            ),
          ),
          // 레이어 리스트
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              itemCount: layers.length,
              itemBuilder: (context, index) {
                final layer = layers[index];
                final isSelected = layer.id == selectedLayerId;
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: SnapFitColors.accent.withOpacity(0.1),
                  leading: Icon(
                    layer.type == LayerType.text ? Icons.text_fields : Icons.image,
                    color: isSelected
                        ? SnapFitColors.accent
                        : SnapFitColors.textMutedOf(context),
                  ),
                  title: Text(
                    layer.type == LayerType.text
                        ? (layer.text?.isEmpty == false ? layer.text! : '텍스트 레이어')
                        : '이미지 레이어',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? SnapFitColors.textPrimaryOf(context)
                          : SnapFitColors.textMutedOf(context),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onLayerVisibilityToggled != null)
                        IconButton(
                          icon: Icon(
                            Icons.visibility_outlined,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                          onPressed: () => onLayerVisibilityToggled!(layer.id),
                        ),
                    ],
                  ),
                  onTap: () => onLayerSelected(layer.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
