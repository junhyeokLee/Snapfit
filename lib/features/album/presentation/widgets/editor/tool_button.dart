import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// 툴 버튼 (하단 버튼)
class ToolButton extends StatelessWidget {
  final dynamic label; // String or IconData
  final bool selected;
  final VoidCallback onTap;
  const ToolButton({super.key, 
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.08), // 약간 더 강조
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: label is IconData
            ? Icon(label, color: Colors.white, size: 24.sp)
            : Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
