// Widgets/edit_cover_selector.dart
import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';

/// 상단 커버 사이즈 선택 UI 전담
class CoverSelectorWidget extends StatelessWidget {
  final List<CoverSize> sizes;
  final CoverSize selected;
  final ValueChanged<CoverSize> onSelect;
  final IconData Function(CoverSize) iconForCover;
  final double height;

  const CoverSelectorWidget({
    super.key,
    required this.sizes,
    required this.selected,
    required this.onSelect,
    required this.iconForCover,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: sizes.map((s) {
            final isSelected = s.name == selected.name;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => onSelect(s),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? Colors.blueAccent
                        : const Color(0xFF5c5d8d).withOpacity(0.5),
                  ),
                  child: Icon(
                    iconForCover(s),
                    color: isSelected ? Colors.white : Colors.black54,
                    size: 24,
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