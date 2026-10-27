import 'package:flutter/material.dart';

/// Paper처럼 부채꼴 펼침에서 각 페이지 카드 (그림자 + 클립)
class FannedPageCard extends StatelessWidget {
  final double width;
  final double height;
  final int depth;
  final Widget content;

  const FannedPageCard({
    super.key,
    required this.width,
    required this.height,
    required this.depth,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12 + depth * 0.05),
            blurRadius: 6 + depth * 6,
            offset: Offset(2 + depth * 1.5, 4 + depth * 3),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: content),
    );
  }
}
