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
    String _subtitleForKey(String key) {
      switch (key) {
        case 'free':
          return '사진 비율 그대로';
        case '1:1':
          return '정사각형 앨범컷';
        case '4:3':
          return '일반 카메라 비율';
        case '3:4':
          return '세로형 인화 비율';
        case '16:9':
          return '와이드 스냅샷';
        case '9:16':
          return '스토리/릴스 비율';
        case '3:2':
          return '필름 카메라 느낌';
        case '2:3':
          return '클래식 인화 비율';
        default:
          return '';
      }
    }

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
              '사진 크기',
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 20.h),
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
                              ? SnapFitColors.accent.withOpacity(0.08)
                              : SnapFitColors.overlayLightOf(context),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isSelected
                                ? SnapFitColors.accent
                                : SnapFitColors.overlayStrongOf(context),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 미니 비율 프리뷰 박스
                            Container(
                              width: 32.w,
                              height: 22.h,
                              decoration: BoxDecoration(
                                color: SnapFitColors.overlayMediumOf(context),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // 원본(free)은 가로/세로 모두 가능하다는 느낌을 주기 위해
                                  // 가로(16:9) + 세로(9:16) 미니 박스를 동시에 보여준다.
                                  if (t.aspect == null) {
                                    return Padding(
                                      padding: EdgeInsets.all(3.w),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      SnapFitColors.accent.withOpacity(0.55),
                                                      SnapFitColors.accent.withOpacity(0.15),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(3.r),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 3.w),
                                          Expanded(
                                            child: AspectRatio(
                                              aspectRatio: 9 / 16,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      SnapFitColors.accent.withOpacity(0.35),
                                                      SnapFitColors.accent.withOpacity(0.10),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(3.r),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final baseAspect = t.aspect!;
                                  return Center(
                                    child: AspectRatio(
                                      aspectRatio: baseAspect,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              SnapFitColors.accent.withOpacity(0.55),
                                              SnapFitColors.accent.withOpacity(0.15),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.label,
                                  style: TextStyle(
                                    color: SnapFitColors.textPrimaryOf(context),
                                    fontSize: 14.sp,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  _subtitleForKey(t.key),
                                  style: TextStyle(
                                    color: SnapFitColors.textSecondaryOf(context),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
