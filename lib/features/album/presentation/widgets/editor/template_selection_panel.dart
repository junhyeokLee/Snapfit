import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class TemplateSelectionPanel extends StatelessWidget {
  const TemplateSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300.h,
      color: SnapFitColors.backgroundOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Text(
                  "템플릿 선택",
                  style: TextStyle(
                    color: SnapFitColors.textPrimaryOf(context),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {},
                  child: Text("인기", style: TextStyle(color: SnapFitColors.accent)),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text("심플", style: TextStyle(color: SnapFitColors.textSecondaryOf(context))),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text("가족", style: TextStyle(color: SnapFitColors.textSecondaryOf(context))),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                 crossAxisCount: 3,
                 crossAxisSpacing: 12,
                 mainAxisSpacing: 12,
                 childAspectRatio: 0.7,
              ),
              itemCount: 9, // DUMMY
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: SnapFitColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(8.r),
                    border: index == 0 ? Border.all(color: SnapFitColors.accent, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(
                      "Layout ${index + 1}",
                      style: TextStyle(color: SnapFitColors.textPrimaryOf(context), fontSize: 12.sp),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
