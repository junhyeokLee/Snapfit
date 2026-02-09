import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/constants/image_templates.dart';
import '../../core/constants/snapfit_colors.dart';

/// 이미지 슬롯 템플릿 선택 바텀시트 (정사각형, 4:3 등 - 사진이 짤리지 않게 contain)
class ImageTemplatePicker extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelect;

  const ImageTemplatePicker({
    super.key,
    required this.selectedKey,
    required this.onSelect,
  });

  static Future<String?> show(
    BuildContext context, {
    required String? currentKey,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ImageTemplatePicker(
        selectedKey: currentKey,
        onSelect: (key) => Navigator.pop(ctx, key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
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
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              '사진 크기(템플릿)',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 8.h, bottom: 24.h),
              child: Text(
                '선택한 비율로 슬롯이 만들어지고, 사진이 그 안에 꽉 차게 들어갑니다.',
                style: TextStyle(
                  color: SnapFitColors.textSecondaryOf(context),
                  fontSize: 13.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 24.h),
              child: Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: imageTemplates.map((t) {
                  final isSelected = (selectedKey ?? 'free') == t.key;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onSelect(t.key),
                      borderRadius: BorderRadius.circular(12.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? SnapFitColors.surfaceOf(context).withOpacity(0.95)
                              : SnapFitColors.overlayLightOf(context),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected
                                ? SnapFitColors.textPrimaryOf(context)
                                : SnapFitColors.overlayStrongOf(context),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Text(
                          t.label,
                          style: TextStyle(
                            color: isSelected
                                ? SnapFitColors.textPrimaryOf(context)
                                : SnapFitColors.textSecondaryOf(context),
                            fontSize: 14.sp,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
