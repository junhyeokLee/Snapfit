import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 상단 바
class TopBar extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onDone;
  const TopBar({super.key, required this.onCancel, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _pillBtn('완료', onDone),
        ],
      ),
    );
  }

  Widget _pillBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
