import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

class HomeHeaderNew extends StatelessWidget {
  final VoidCallback onNotification;
  
  const HomeHeaderNew({
    super.key,
    required this.onNotification,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row: Logo + Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '스냅핏',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w800,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
            Row(
              children: [
                Stack(
                  children: [
                    IconButton(
                      onPressed: onNotification,
                      icon: Icon(
                        Icons.notifications_none_rounded,
                        color: SnapFitColors.textPrimaryOf(context),
                        size: 26.sp,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 24.w),
        // Main Title
        Text(
          '함께 만드는\n우리만의 앨범',
          style: TextStyle(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            height: 1.3,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
