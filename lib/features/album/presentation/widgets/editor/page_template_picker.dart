import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/page_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';

/// 페이지 템플릿 선택 바텀시트 (스크랩북 스타일)
class PageTemplatePicker extends StatelessWidget {
  final ValueChanged<PageTemplate> onSelect;

  const PageTemplatePicker({
    super.key,
    required this.onSelect,
  });

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<PageTemplate> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PageTemplatePicker(
        onSelect: (t) {
          onSelect(t);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          decoration: BoxDecoration(
            color: SnapFitColors.surfaceOf(context).withOpacity(0.95),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            boxShadow: [
              BoxShadow(
                color: SnapFitColors.isDark(context)
                    ? SnapFitColors.accentLight.withOpacity(0.25)
                    : Colors.black.withOpacity(0.18),
                blurRadius: 20.r,
                offset: Offset(0, -4.h),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 12.h),
                Container(
                  width: 48.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayMediumOf(context),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Text(
                    '페이지 템플릿',
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
                    child: Wrap(
                      spacing: 12.w,
                      runSpacing: 16.h,
                      children: pageTemplates.map((template) {
                        return _TemplateCard(
                          template: template,
                          onTap: () => onSelect(template),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 실제 템플릿 레이아웃을 그대로 보여주는 미리보기 (직관적 구분용)
class TemplatePreviewCanvas extends StatelessWidget {
  final PageTemplate template;
  final double width;
  final double height;

  const TemplatePreviewCanvas({
    super.key,
    required this.template,
    this.width = 88,
    this.height = 118,
  });

  @override
  Widget build(BuildContext context) {
    if (template.slots.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: SnapFitColors.overlayStrongOf(context), width: 1),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 28.sp,
          color: SnapFitColors.textSecondaryOf(context),
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: SnapFitColors.pureWhite.withOpacity(0.95),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.r),
        child: Stack(
          clipBehavior: Clip.none,
          children: template.slots.map((slot) {
            final left = slot.left * width;
            final top = slot.top * height;
            final slotW = slot.width * width;
            final slotH = slot.height * height;
            final rot = slot.rotation * math.pi / 180;
            final isImage = slot.type == 'image';
            return Positioned(
              left: left,
              top: top,
              child: Transform.rotate(
                angle: rot,
                child: Container(
                  width: slotW,
                  height: slotH,
                  decoration: BoxDecoration(
                    color: isImage
                        ? Colors.grey.shade300
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(isImage ? 4 : 2),
                    border: Border.all(
                      color: isImage
                          ? Colors.grey.shade400
                          : Colors.amber.shade200,
                      width: 1,
                    ),
                    boxShadow: isImage
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: isImage
                      ? Center(
                          child: Icon(
                            Icons.photo_camera_outlined,
                            size: (slotW.clamp(0, 24) + slotH.clamp(0, 24)) / 3,
                            color: Colors.grey.shade500,
                          ),
                        )
                      : Center(
                          child: Text(
                            'Aa',
                            style: TextStyle(
                              fontSize: (slotW.clamp(0, 20) + slotH.clamp(0, 20)) / 4,
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final PageTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 100.w,
          padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: SnapFitColors.overlayLightOf(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: SnapFitColors.overlayStrongOf(context), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TemplatePreviewCanvas(
                template: template,
                width: 88.w,
                height: 118.h,
              ),
              SizedBox(height: 8.h),
              Text(
                template.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: SnapFitColors.textPrimaryOf(context),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
