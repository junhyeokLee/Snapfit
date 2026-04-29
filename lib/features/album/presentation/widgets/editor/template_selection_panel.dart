import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../core/constants/page_templates.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../../domain/entities/layer.dart';

/// 페이지 템플릿 선택 바텀시트
/// - 여러 레이아웃 템플릿, 슬롯 간 여백 있음
class TemplateSelectionPanel extends ConsumerStatefulWidget {
  final String title;

  const TemplateSelectionPanel({super.key, this.title = '레이아웃'});

  @override
  ConsumerState<TemplateSelectionPanel> createState() =>
      _TemplateSelectionPanelState();
}

class _TemplateSelectionPanelState
    extends ConsumerState<TemplateSelectionPanel> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final aspect = vm.selectedCover.ratio > 0
        ? vm.selectedCover.ratio
        : (3 / 4);

    // 페이지 에디터는 커버/내지 모두 500 기준 논리 좌표계를 사용하므로
    // 템플릿 생성도 동일 기준으로 맞춰야 터치/이동 체감이 일관된다.
    final double baseW = kCoverReferenceWidth;
    final Size canvasSize = Size(baseW, baseW / aspect);

    final templates = pageTemplates;

    final maxSheetHeight =
        (MediaQuery.sizeOf(context).height * 0.78).clamp(420.0, 620.0);

    return Container(
      height: maxSheetHeight,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.h),
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: SnapFitColors.textPrimaryOf(
                    context,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                widget.title,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    // 카드가 더 커지고 미리보기가 더 꽉 차 보이도록 살짝 더 세로로
                    childAspectRatio: 1 / 1.12,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final isSelected = _selectedId == template.id;
                    return _buildTemplateCard(
                      context,
                      template: template,
                      isSelected: isSelected,
                      pageRatio: aspect,
                      logicalCanvasSize: canvasSize,
                      onTap: () {
                        setState(() => _selectedId = template.id);
                        vm.applyTemplateToCurrentPage(template, canvasSize);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required PageTemplate template,
    required bool isSelected,
    required double pageRatio,
    required Size logicalCanvasSize,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: SnapFitColors.surfaceOf(context),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: isSelected
                        ? SnapFitColors.accent
                        : SnapFitColors.overlayLightOf(context),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
                      child: Column(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: pageRatio,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: template.backgroundColor,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: _TemplatePreview(
                                  template: template,
                                  pageRatio: pageRatio,
                                  ref: ref,
                                  logicalCanvasSize: logicalCanvasSize,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 6.h,
                        left: 6.w,
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: const BoxDecoration(
                            color: SnapFitColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 12.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              template.name,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? SnapFitColors.accent
                    : SnapFitColors.textMutedOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 슬롯 비율대로 그리기 → 슬롯 사이가 비어 있어 여백으로 보임
class _TemplatePreview extends StatelessWidget {
  final PageTemplate template;
  final double pageRatio;
  final WidgetRef ref;
  final Size logicalCanvasSize;

  const _TemplatePreview({
    required this.template,
    required this.pageRatio,
    required this.ref,
    required this.logicalCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    // 미리보기에서도 실제 적용과 동일한 프레임/텍스트 스타일(패딩·정렬·비율)을 재사용하기 위해
    // LayerBuilder + LayerInteractionManager.preview로 “실제 레이어 렌더링”을 그대로 사용한다.
    final previewInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCanvasSize,
    );
    final layerBuilder = LayerBuilder(
      previewInteraction,
      () => logicalCanvasSize,
    );

    final layers = <LayerModel>[];
    for (final slot in template.slots) {
      final slotW = slot.width * logicalCanvasSize.width;
      final slotH = slot.height * logicalCanvasSize.height;
      final pos = Offset(
        slot.left * logicalCanvasSize.width,
        slot.top * logicalCanvasSize.height,
      );

      if (slot.type == 'text') {
        // 미리보기에서는 “실제 텍스트”는 노출하지 않고 프레임(배경)만 보이게 한다.
        // 단, LayerBuilder의 텍스트 프레임은 텍스트 레이아웃 크기에 영향을 받으므로
        // 슬롯 크기에 비례한 더미 텍스트를 생성해 프레임 크기를 안정화한다.
        final fontSize = (slotH * 0.18).clamp(14.0, 22.0);
        final approxLineH = fontSize * 1.25;
        final desiredH = slotH * 0.42;
        final lines = (desiredH / approxLineH).clamp(1.0, 3.0).round();
        final approxCharW = fontSize * 0.55;
        final desiredW = slotW * 0.62;
        final chars = (desiredW / approxCharW).clamp(4.0, 12.0).round();
        final line = List.filled(chars, '텍').join(); // 폭 확보용
        final previewText = List.filled(lines, line).join('\n');

        layers.add(
          LayerModel(
            id: '${template.id}_text_${slot.left}_${slot.top}_${slot.width}_${slot.height}',
            type: LayerType.text,
            position: pos,
            width: slotW,
            height: slotH,
            rotation: slot.rotation,
            text: previewText,
            textBackground: slot.textBackground,
            // 텍스트는 보이지 않게(투명). 프레임만 노출.
            textStyle: TextStyle(
              fontSize: fontSize,
              color: Colors.transparent,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
            textStyleType: TextStyleType.none,
            opacity: 1.0,
          ),
        );
      } else {
        layers.add(
          LayerModel(
            id: '${template.id}_image_${slot.left}_${slot.top}_${slot.width}_${slot.height}',
            type: LayerType.image,
            position: pos,
            width: slotW,
            height: slotH,
            rotation: slot.rotation,
            imageBackground: slot.imageBackground,
            imageTemplate: slot.imageTemplate ?? 'free',
            opacity: 1.0,
          ),
        );
      }
    }

    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      child: SizedBox(
        width: logicalCanvasSize.width,
        height: logicalCanvasSize.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: template.backgroundColor),
              ),
            ),
            for (final layer in layers)
              layer.type == LayerType.text
                  ? layerBuilder.buildText(layer)
                  : layerBuilder.buildImage(layer),
          ],
        ),
      ),
    );
  }
}
