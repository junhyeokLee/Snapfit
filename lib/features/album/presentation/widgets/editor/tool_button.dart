import 'package:flutter/material.dart';

/// 툴 버튼 (하단 버튼)
class ToolButton extends StatelessWidget {
  final dynamic label; // String or IconData
  final bool selected;
  final VoidCallback onTap;
  const ToolButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.08), // 약간 더 강조
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.white : Colors.white24,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: label is IconData
            ? Icon(label, color: Colors.white, size: 22)
            : Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
