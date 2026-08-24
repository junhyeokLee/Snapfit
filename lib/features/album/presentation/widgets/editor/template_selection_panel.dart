import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../core/constants/page_templates.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

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
                widget.title == '레이아웃' ? '쪽 레이아웃 고르기' : widget.title,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 6.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                '사진이 놓일 리듬을 먼저 골라보세요.',
                style: TextStyle(
                  fontSize: 12.5.sp,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 14.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1 / 1.18,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final isSelected = _selectedId == template.id;
                    return RepaintBoundary(
                      child: _TemplateCard(
                        template: template,
                        isSelected: isSelected,
                        pageRatio: aspect,
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
}

class _TemplateCard extends StatelessWidget {
  final PageTemplate template;
  final bool isSelected;
  final double pageRatio;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.pageRatio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SnapFitPressable(
      onTap: onTap,
      pressedScale: 0.98,
      borderRadius: BorderRadius.circular(22.r),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: SnapFitMotion.settle,
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(22.r),
          border: Border.all(
            color: isSelected
                ? SnapFitColors.accent
                : SnapFitColors.overlayLightOf(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                SnapFitColors.isDark(context) ? 0.22 : 0.06,
              ),
              blurRadius: isSelected ? 20 : 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: pageRatio,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14.r),
                            child: CustomPaint(
                              painter: _SlotPreviewPainter(template),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8.h,
                        right: 8.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: SnapFitColors.accent,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 13.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                template.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.textPrimaryOf(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),
              Text(
                '${template.slots.length}컷 레이아웃',
                style: TextStyle(
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 슬롯 레이아웃을 CustomPainter로 직접 그려서 위젯 트리 생성 비용을 완전히 제거.
/// LayerBuilder 없이 색 사각형으로만 표현해도 레이아웃 구분이 충분하다.
class _SlotPreviewPainter extends CustomPainter {
  final PageTemplate template;

  static const _imageFill = Color(0xFFF1E7DB);
  static const _imageBorder = Color(0xFFD8CBBB);
  static const _textFill = Color(0xFFFFF8E8);
  static const _textBorder = Color(0xFFE8D5A8);

  const _SlotPreviewPainter(this.template);

  @override
  void paint(Canvas canvas, Size size) {
    // 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = template.backgroundColor,
    );

    final fillPaints = {
      'image': Paint()..color = _imageFill,
      'text': Paint()..color = _textFill,
    };
    final borderPaints = {
      'image': Paint()
        ..color = _imageBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
      'text': Paint()
        ..color = _textBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    };
    const radius = Radius.circular(3);

    for (final slot in template.slots) {
      final l = slot.left * size.width;
      final t = slot.top * size.height;
      final w = slot.width * size.width;
      final h = slot.height * size.height;
      final fill = fillPaints[slot.type] ?? fillPaints['image']!;
      final border = borderPaints[slot.type] ?? borderPaints['image']!;

      if (slot.rotation != 0) {
        canvas.save();
        canvas.translate(l + w / 2, t + h / 2);
        canvas.rotate(slot.rotation * math.pi / 180);
        final rect = Rect.fromLTWH(-w / 2, -h / 2, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), border);
        canvas.restore();
      } else {
        final rect = Rect.fromLTWH(l, t, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), border);
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPreviewPainter old) => old.template.id != template.id;
}
