import 'dart:math' as math;
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
    name: '정사각형',
    ratio: 8 / 8,
    realSize: Size(20, 20),
  ),
  CoverSize(
    name: '가로형',
    ratio: 8 / 6,
    realSize: Size(19.4, 14.5),
  ),
];

/// 출력 기준(실제 크기)을 화면 캔버스에 매핑하는 스케일
/// - 세로형 14.5x19.4cm 기준이 300x400px 정도가 되도록 설정
const double kCanvasPxPerCm = 20.64;
/// 페이지 화면 표시 최대 높이 비율 (화면 기준)
const double kPagePreviewMaxHeightFactor = 0.62;
/// 페이지 편집 화면은 크게 보여야 함
const double kPageEditorPreviewMaxHeightFactor = 0.70;
/// 앨범 보기 화면도 편집 화면과 동일한 스케일로 맞춤
const double kPageReaderPreviewMaxHeightFactor = 0.70;
/// 페이지 미리보기 최대 너비 비율
const double kPagePreviewMaxWidthFactor = 0.92;

/// 페이지 미리보기(편집/읽기) 공통 계산
Size calculatePagePreviewSize({
  required Size screen,
  required BoxConstraints constraints,
  required double pageRatio,
  double maxWidthFactor = kPagePreviewMaxWidthFactor,
  double maxHeightFactor = kPagePreviewMaxHeightFactor,
}) {
  final maxW = constraints.maxWidth * maxWidthFactor;
  final maxH = math.min(constraints.maxHeight, screen.height * maxHeightFactor);
  double targetW = maxW;
  double targetH = targetW / pageRatio;
  if (targetH > maxH) {
    targetH = maxH;
    targetW = targetH * pageRatio;
  }
  return Size(targetW, targetH);
}

/// 커버/내지 공용 베이스 캔버스 크기 (출력 기준 고정)
Size coverCanvasBaseSize(CoverSize cover) {
  return Size(
    cover.realSize.width * kCanvasPxPerCm,
    cover.realSize.height * kCanvasPxPerCm,
  );
}
