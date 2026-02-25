import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../controllers/text_editor_manager.dart';

enum EditPanelMode { none, decorate, opacity }

class LayerActionPanel extends ConsumerStatefulWidget {
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final TextEditorManager textEditor;
  final VoidCallback onRefresh;
  final Future<void> Function(LayerModel)? onOpenGallery;

  const LayerActionPanel({
    super.key,
    required this.layers,
    required this.interaction,
    required this.textEditor,
    required this.onRefresh,
    this.onOpenGallery,
  });

  @override
  ConsumerState<LayerActionPanel> createState() => _LayerActionPanelState();
}

class _LayerActionPanelState extends ConsumerState<LayerActionPanel> {
  EditPanelMode _panelMode = EditPanelMode.none;

  @override
  Widget build(BuildContext context) {
    final selectedId = widget.interaction.selectedLayerId;
    if (selectedId == null) return const SizedBox.shrink();

    // 레이어가 하나도 없거나(빈 페이지), 해당 ID의 레이어를 찾지 못한 경우 안전하게 처리
    final layerIndex = widget.layers.indexWhere((l) => l.id == selectedId);
    if (layerIndex == -1) return const SizedBox.shrink();
    
    final layer = widget.layers[layerIndex];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(SnapFitColors.isDark(context) ? 0.3 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_panelMode == EditPanelMode.opacity)
            _buildOpacitySlider(layer),
          if (_panelMode == EditPanelMode.decorate)
            _buildDecorateSubmenu(layer),
          if (_panelMode == EditPanelMode.none)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (layer.type == LayerType.text)
                  _buildActionButton(Icons.font_download_outlined, "폰트", () => widget.textEditor.openForExisting(layer)),
                if (layer.type == LayerType.image)
                  _buildActionButton(Icons.image_outlined, "사진변경", () => widget.onOpenGallery?.call(layer)),
                
                _buildActionButton(Icons.opacity, "불투명도", () => setState(() => _panelMode = EditPanelMode.opacity)),
                _buildActionButton(Icons.auto_awesome_outlined, "꾸미기", () => setState(() => _panelMode = EditPanelMode.decorate)),
                
                _buildActionButton(Icons.delete_outline, "삭제", () {
                  widget.interaction.deleteSelected();
                  widget.onRefresh();
                }, color: Colors.red),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Icon(icon, size: 24.sp, color: color ?? SnapFitColors.textPrimaryOf(context).withOpacity(0.9)),
      ),
    );
  }

  Widget _buildOpacitySlider(LayerModel layer) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios, color: SnapFitColors.textPrimaryOf(context), size: 16),
          onPressed: () => setState(() => _panelMode = EditPanelMode.none),
        ),
        Expanded(
          child: Slider(
            value: layer.opacity,
            min: 0.0,
            max: 1.0,
            activeColor: SnapFitColors.accent,
            onChanged: (val) {
              ref.read(albumEditorViewModelProvider.notifier).updateLayer(
                layer.copyWith(opacity: val),
              );
              widget.onRefresh();
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.only(right: 16.w),
          child: Text(
            "${(layer.opacity * 100).toInt()}%",
            style: TextStyle(color: SnapFitColors.textPrimaryOf(context), fontSize: 13.sp),
          ),
        ),
      ],
    );
  }

  Widget _buildDecorateSubmenu(LayerModel layer) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: SnapFitColors.textPrimaryOf(context), size: 16),
            onPressed: () => setState(() => _panelMode = EditPanelMode.none),
          ),
          if (layer.type == LayerType.text) ...[
            _buildTextStyleButton("라벨", "tag"),
            _buildTextStyleButton("말풍선", "bubble"),
            _buildTextStyleButton("노트", "note"),
            _buildTextStyleButton("캘리", "calligraphy"),
            _buildTextStyleButton("스티커", "sticker"),
            _buildTextStyleButton("테이프", "tape"),
            _buildTextStyleButton("없음", ""),
          ],
          if (layer.type == LayerType.image) ...[
            _buildImageStyleItem("라운드", "round"),
            _buildImageStyleItem("폴라로이드", "polaroid"),
            _buildImageStyleItem("클래식", "polaroidClassic"),
            _buildImageStyleItem("와이드", "polaroidWide"),
            _buildImageStyleItem("글로우", "softGlow"),
            _buildImageStyleItem("스티커", "sticker"),
            _buildImageStyleItem("스케치", "sketch"),
            _buildImageStyleItem("필름", "film"),
            _buildImageStyleItem("없음", ""),
          ],
        ],
      ),
    );
  }

  Widget _buildImageStyleItem(String label, String key) {
    return GestureDetector(
      onTap: () {
        final id = widget.interaction.selectedLayerId;
        if (id == null) return;
        ref.read(albumEditorViewModelProvider.notifier).updateImageFrame(id, key);
        widget.onRefresh();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        margin: EdgeInsets.only(right: 8.w),
        decoration: BoxDecoration(
          color: SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(color: SnapFitColors.textPrimaryOf(context), fontSize: 12.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTextStyleButton(String label, String key) {
    return GestureDetector(
      onTap: () {
        final id = widget.interaction.selectedLayerId;
        if (id == null) return;
        ref.read(albumEditorViewModelProvider.notifier).updateTextStyle(id, key);
        widget.onRefresh();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
