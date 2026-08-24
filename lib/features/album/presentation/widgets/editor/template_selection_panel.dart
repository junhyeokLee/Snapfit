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

    final maxSheetHeight = (MediaQuery.sizeOf(context).height * 0.78).clamp(
      420.0,
      620.0,
    );

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
                    return RepaintBoundary(
                      child: _buildTemplateCard(
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
                      ),
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
class _TemplatePreview extends StatefulWidget {
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
  State<_TemplatePreview> createState() => _TemplatePreviewState();
}

class _TemplatePreviewState extends State<_TemplatePreview> {
  late final LayerBuilder _layerBuilder;
  late final List<LayerModel> _layers;

  @override
  void initState() {
    super.initState();
    // 스크롤 중 매 프레임 재생성을 막기 위해 initState에서 한 번만 빌드한다.
    final previewInteraction = LayerInteractionManager.preview(
      widget.ref,
      () => widget.logicalCanvasSize,
    );
    _layerBuilder = LayerBuilder(
      previewInteraction,
      () => widget.logicalCanvasSize,
    );
    _layers = _buildLayers();
  }

  List<LayerModel> _buildLayers() {
    final canvas = widget.logicalCanvasSize;
    final layers = <LayerModel>[];
    for (final slot in widget.template.slots) {
      final slotW = slot.width * canvas.width;
      final slotH = slot.height * canvas.height;
      final pos = Offset(slot.left * canvas.width, slot.top * canvas.height);

      if (slot.type == 'text') {
        final fontSize = (slotH * 0.18).clamp(14.0, 22.0);
        final approxLineH = fontSize * 1.25;
        final lines = ((slotH * 0.42) / approxLineH).clamp(1.0, 3.0).round();
        final chars = ((slotW * 0.62) / (fontSize * 0.55)).clamp(4.0, 12.0).round();
        final line = List.filled(chars, '텍').join();
        final previewText = List.filled(lines, line).join('\n');
        layers.add(LayerModel(
          id: '${widget.template.id}_text_${slot.left}_${slot.top}',
          type: LayerType.text,
          position: pos,
          width: slotW,
          height: slotH,
          rotation: slot.rotation,
          text: previewText,
          textBackground: slot.textBackground,
          textStyle: TextStyle(
            fontSize: fontSize,
            color: Colors.transparent,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
          textStyleType: TextStyleType.none,
          opacity: 1.0,
        ));
      } else {
        layers.add(LayerModel(
          id: '${widget.template.id}_image_${slot.left}_${slot.top}',
          type: LayerType.image,
          position: pos,
          width: slotW,
          height: slotH,
          rotation: slot.rotation,
          imageBackground: slot.imageBackground,
          imageTemplate: slot.imageTemplate ?? 'free',
          opacity: 1.0,
        ));
      }
    }
    return layers;
  }

  @override
  Widget build(BuildContext context) {
    final canvas = widget.logicalCanvasSize;
    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      child: SizedBox(
        width: canvas.width,
        height: canvas.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.template.backgroundColor,
                ),
              ),
            ),
            for (final layer in _layers)
              layer.type == LayerType.text
                  ? _layerBuilder.buildText(layer)
                  : _layerBuilder.buildImage(layer),
          ],
        ),
      ),
    );
  }
}
