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

  const TemplateSelectionPanel({
    super.key,
    this.title = '레이아웃',
  });

  @override
  ConsumerState<TemplateSelectionPanel> createState() => _TemplateSelectionPanelState();
}

class _TemplateSelectionPanelState extends ConsumerState<TemplateSelectionPanel> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final currentPage = vm.currentPage;
    final isCover = currentPage?.isCover ?? false;
    final aspect = vm.selectedCover.ratio > 0 ? vm.selectedCover.ratio : (3 / 4);

    final double baseW = isCover ? kCoverReferenceWidth : 300.0;
    final Size canvasSize = Size(baseW, baseW / aspect);

    final templates = pageTemplates;

    return Container(
      height: 620.h,
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
                  color: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.2),
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
                    childAspectRatio: 1 / 1.18,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected ? SnapFitColors.accent : SnapFitColors.overlayLightOf(context),
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
                      AspectRatio(
                        aspectRatio: pageRatio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: SnapFitColors.backgroundOf(context),
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
          SizedBox(height: 6.h),
          Text(
            template.name,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: isSelected ? SnapFitColors.accent : SnapFitColors.textMutedOf(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
    final previewInteraction = LayerInteractionManager.preview(ref, () => logicalCanvasSize);
    final layerBuilder = LayerBuilder(previewInteraction, () => logicalCanvasSize);

    final layers = <LayerModel>[];
    for (final slot in template.slots) {
      final slotW = slot.width * logicalCanvasSize.width;
      final slotH = slot.height * logicalCanvasSize.height;
      final pos = Offset(slot.left * logicalCanvasSize.width, slot.top * logicalCanvasSize.height);

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
            // 배경은 카드 컨테이너의 backgroundOf(context)가 보이게 투명 처리
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

class _ImageFramePreview extends StatelessWidget {
  final String frameKey;
  final Color fallbackColor;

  const _ImageFramePreview({
    required this.frameKey,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 내지 템플릿 논리 캔버스(300w) 기준으로 스케일링 → 실제 적용 시 체감 여백과 최대한 동일
        final base = constraints.biggest.shortestSide;
        final s = (base / 300.0).clamp(0.18, 1.0);

        // 실제 적용에서는 이미지가 BoxFit.cover로 들어가므로, 미리보기에서도 cover 동작을 동일하게 맞춘다.
        final photoCore = Container(
          decoration: const BoxDecoration(
            color: Color(0xFFE6E9F0),
            borderRadius: BorderRadius.zero,
          ),
        );
        final photo = FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 220 * s,
            height: 220 * s,
            child: photoCore,
          ),
        );

        switch (frameKey) {
          case 'circle':
            return ClipOval(child: photo);
          case 'round':
            return ClipRRect(
              borderRadius: BorderRadius.circular(18 * s),
              child: photo,
            );
          case 'polaroid':
          case 'polaroidClassic':
          case 'polaroidFilm':
            final bg = frameKey == 'polaroidClassic'
                ? const Color(0xFFFFFEF5)
                : (frameKey == 'polaroidFilm' ? Colors.black : Colors.white);
            final border = frameKey == 'polaroidClassic'
                ? const Color(0xFFE8E4D8)
                : (frameKey == 'polaroidFilm' ? Colors.white.withOpacity(0.3) : const Color(0xFFE0E3EC));
            final borderWidth = frameKey == 'polaroidClassic' ? 1.1 : 1.0;
            final radius = frameKey == 'polaroidClassic' ? 12.0 : 10.0;
            return Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20 * s, 40 * s, 20 * s, 80 * s),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(radius * s),
                    border: Border.all(color: border, width: borderWidth * s),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(frameKey == 'polaroidClassic' ? 0.1 : 0.08),
                        blurRadius: 6 * s,
                        offset: Offset(0, 3 * s),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6 * s),
                    child: SizedBox.expand(child: photo),
                  ),
                ),
              ),
            );
          case 'polaroidWide':
            return Container(
              padding: EdgeInsets.fromLTRB(2 * s, 6 * s, 2 * s, 14 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6 * s),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 6 * s,
                    offset: Offset(0, 2 * s),
                  ),
                ],
                border: Border.all(color: Colors.grey.withOpacity(0.35), width: 0.8 * s),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3 * s),
                child: photo,
              ),
            );
          case 'film':
            return AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF151B2C),
                  borderRadius: BorderRadius.circular(10 * s),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 8 * s,
                      offset: Offset(0, 3 * s),
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(horizontal: 5 * s, vertical: 8 * s),
                child: Row(
                  children: [
                    _filmHoles(s),
                    SizedBox(width: 4 * s),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2433),
                          borderRadius: BorderRadius.circular(6 * s),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6 * s),
                          child: photo,
                        ),
                      ),
                    ),
                    SizedBox(width: 4 * s),
                    _filmHoles(s),
                  ],
                ),
              ),
            );
          case 'win95':
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFC0C0C0),
                border: Border.all(color: const Color(0xFF808080), width: 1 * s),
              ),
              child: Column(
                children: [
                  Container(
                    height: 22 * s,
                    color: const Color(0xFF000080),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      padding: EdgeInsets.all(4 * s),
                      child: photo,
                    ),
                  ),
                ],
              ),
            );
          case 'pixel8':
            return Container(
              padding: EdgeInsets.all(2 * s),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: Colors.black, width: 2 * s),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1 * s),
                ),
                child: Center(
                  child: Container(
                    margin: EdgeInsets.all(4 * s),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54, width: 1 * s),
                    ),
                    child: photo,
                  ),
                ),
              ),
            );
          case 'neon':
            return Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4 * s),
                border: Border.all(color: const Color(0xFF00FFFF), width: 2 * s),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FFFF).withOpacity(0.6), blurRadius: 8 * s),
                ],
              ),
              padding: EdgeInsets.all(3 * s),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2 * s),
                child: photo,
              ),
            );
          case 'tornNotebook':
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF0),
                boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.1), blurRadius: 6 * s, offset: Offset(0, 2 * s))],
              ),
              padding: EdgeInsets.fromLTRB(10 * s, 10 * s, 8 * s, 12 * s),
              child: Padding(
                padding: EdgeInsets.all(12 * s),
                child: ClipRect(child: photo),
              ),
            );
          case 'oldNewspaper':
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F0E6),
                borderRadius: BorderRadius.circular(4 * s),
                border: Border.all(color: const Color(0xFFE0D8C8), width: 1 * s),
              ),
              child: Column(
                children: [
                  Container(height: 12 * s, color: const Color(0xFFE8E0D4)),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 2 * s),
                      color: const Color(0xFFF8F4EC),
                      child: photo,
                    ),
                  ),
                ],
              ),
            );
          case 'postalStamp':
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2 * s),
                border: Border.all(color: const Color(0xFFC0C0C0), width: 1 * s),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4 * s, offset: Offset(0, 2 * s))],
              ),
              padding: EdgeInsets.all(8 * s),
              child: ClipRect(child: photo),
            );
          case 'kraftPaper':
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFFB8956E),
                borderRadius: BorderRadius.circular(4 * s),
                boxShadow: [BoxShadow(color: Colors.brown.withOpacity(0.2), blurRadius: 6 * s, offset: Offset(0, 2 * s))],
              ),
              padding: EdgeInsets.all(6 * s),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFC9A86C),
                  borderRadius: BorderRadius.circular(2 * s),
                  border: Border.all(color: const Color(0xFFA08050), width: 1.5 * s),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1 * s),
                  child: photo,
                ),
              ),
            );
          case 'softGlow':
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFF5FB), Color(0xFFE9F4FF)],
                ),
                borderRadius: BorderRadius.circular(24 * s),
              ),
              padding: EdgeInsets.all(10 * s),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20 * s),
                child: photo,
              ),
            );
          case 'sketch':
            return CustomPaint(
              painter: _MiniSketchPainter(strokeWidth: 1.5 * s),
              child: Padding(
                padding: EdgeInsets.all(4 * s),
                child: photo,
              ),
            );
          case 'sticker':
            return Container(
              padding: EdgeInsets.all(4 * s),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10 * s),
                border: Border.all(color: Colors.black, width: 2 * s),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6 * s),
                child: photo,
              ),
            );
          default:
            return DecoratedBox(
              decoration: BoxDecoration(color: fallbackColor, borderRadius: BorderRadius.zero),
              child: ClipRect(child: photo),
            );
        }
      },
    );
  }

  Widget _filmHoles(double s) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (_) {
        return Container(
          width: 5 * s,
          height: 5 * s,
          margin: EdgeInsets.symmetric(vertical: 2 * s),
          decoration: BoxDecoration(
            color: const Color(0xFF3D4556),
            borderRadius: BorderRadius.circular(1 * s),
          ),
        );
      }),
    );
  }
}

class _MiniSketchPainter extends CustomPainter {
  final double strokeWidth;

  _MiniSketchPainter({required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniSketchPainter oldDelegate) => oldDelegate.strokeWidth != strokeWidth;
}

class _TextBgPreview extends StatelessWidget {
  final String bgKey;
  final Color fallbackColor;

  const _TextBgPreview({
    required this.bgKey,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 텍스트 배경도 내지 논리 캔버스(300w) 기준으로 스케일링
        final base = constraints.biggest.shortestSide;
        final s = (base / 300.0).clamp(0.18, 1.0);

        // 실제 텍스트는 들어가지 않아도 “패딩/여백”이 동일하게 보이도록 내부 콘텐츠 영역만 표현
        final content = Container(color: fallbackColor);

        switch (bgKey) {
          case 'tag':
            return Container(
              color: SnapFitColors.accent.withOpacity(0.14),
              padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 8 * s),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44 * s,
                  height: 10 * s,
                  color: SnapFitColors.accent.withOpacity(0.45),
                ),
              ),
            );
          case 'tape':
            return Container(
              color: const Color(0xFFFFF3C4),
              padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
              child: content,
            );
          case 'bubble':
            return Container(
              color: Colors.white,
              padding: EdgeInsets.all(10 * s),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8 * s),
                child: content,
              ),
            );
          case 'note':
          default:
            return Container(
              color: const Color(0xFFFFFBF0),
              padding: EdgeInsets.all(12 * s),
              child: content,
            );
        }
      },
    );
  }
}
