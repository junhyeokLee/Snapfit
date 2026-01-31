import 'package:flutter/material.dart';

/// 커버 기본 비율 (세로형, 가로형, 정사각형 등)
class CoverSize {
  final String name;           // 커버 이름 (세로형, 가로형 등)
  final double ratio;          // 화면 비율
  final Size realSize;         // 실제 mm 크기

  const CoverSize({
    required this.name,
    required this.ratio,
    required this.realSize,
  });
}
const List<CoverSize> coverSizes = [
  CoverSize(
    name: '세로형',
    ratio: 6 / 8,
    realSize: Size(14.5, 19.4),
  ),
  CoverSize(
    name: '가로형',
    ratio: 8 / 6,
    realSize: Size(19.4, 14.5),
  ),
  CoverSize(
    name: '정사각형',
    ratio: 8 / 8,
    realSize: Size(20, 20),
  ),
];
