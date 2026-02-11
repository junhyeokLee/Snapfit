import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../controllers/text_editor_manager.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../editor/edit_toolbar.dart';
import 'album_reader_toolbar_button.dart';

/// 앨범 리더 편집 툴바
class AlbumReaderToolbar extends StatelessWidget {
  final AlbumEditorViewModel vm;
  final LayerModel? selectedLayer;
  final List<LayerModel> layers;
  final LayerInteractionManager interaction;
  final Size baseCanvasSize;
  final bool showLayerOrderList;
  final ValueChanged<bool> onLayerOrderListToggled;
  final VoidCallback onStateChanged;

  const AlbumReaderToolbar({
    super.key,
    required this.vm,
    required this.selectedLayer,
    required this.layers,
    required this.interaction,
    required this.baseCanvasSize,
    required this.showLayerOrderList,
    required this.onLayerOrderListToggled,
    required this.onStateChanged,
  });

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('AlbumReaderToolbar', '앨범 리더 툴바 · 텍스트/사진/레이어 순서');
    }
    return Container(
      height: 56.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (selectedLayer != null) ...[
            // 스타일 버튼 (텍스트일 때만)
            if (selectedLayer!.type == LayerType.text)
              AlbumReaderToolbarButton(
                icon: Icons.format_paint,
                label: '스타일',
                onTap: () {
                  // 스타일 선택 모달 표시
                },
              ),
            // 폰트 버튼 (텍스트일 때만)
            if (selectedLayer!.type == LayerType.text)
              AlbumReaderToolbarButton(
                icon: Icons.text_fields,
                label: '폰트',
                onTap: () {
                  final textEditor = TextEditorManager(context, vm);
                  textEditor.openForExisting(selectedLayer!);
                  onStateChanged();
                },
              ),
            // 색상 버튼 (이미지에서 파란색으로 강조됨)
            AlbumReaderToolbarButton(
              icon: Icons.palette,
              label: '색상',
              onTap: () {
                // 색상 선택 모달 표시
              },
              isActive: true,
            ),
            // 불투명도 버튼
            AlbumReaderToolbarButton(
              icon: Icons.opacity,
              label: '불투명도',
              onTap: () {
                // 불투명도 조절 모달 표시
              },
            ),
            // 삭제 버튼 (빨간색 원형)
            GestureDetector(
              onTap: () {
                interaction.deleteSelected();
                onStateChanged();
              },
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 20.sp,
                ),
              ),
            ),
            // 순서 버튼 (레이어 순서 리스트 토글)
            AlbumReaderToolbarButton(
              icon: Icons.layers,
              label: '순서',
              onTap: () {
                onLayerOrderListToggled(!showLayerOrderList);
              },
              isActive: showLayerOrderList,
            ),
          ] else ...[
            // 레이어가 선택되지 않았을 때는 기본 툴바
            Expanded(
              child: EditToolbar(
                vm: vm,
                selected: null,
                coverLabel: '템플릿',
                onAddText: () {
                  final textEditor = TextEditorManager(context, vm);
                  textEditor.openAndCreateNew(baseCanvasSize);
                  onStateChanged();
                },
                onAddPhoto: () {
                  // TODO: 갤러리 열기
                },
                onOpenCoverSelector: () {
                  // TODO: 템플릿 선택기 표시
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
