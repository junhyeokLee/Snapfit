import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 커버 좌측 책심(Spine)의 고정 너비 (px)
const double kCoverSpineWidth = 14.0;

/// 커버 레이아웃의 논리적 기준 너비 (모든 화면에서 일관된 비례 유지를 위해 사용)
const double kCoverReferenceWidth = 500.0;

enum PrintCoverType {
  soft,
  hard;

  String get label => switch (this) {
    soft => '소프트커버',
    hard => '하드커버',
  };
}

/// 커버의 화면 비율과 실제 인쇄 규격.
class CoverSize {
  final String name; // 커버 이름 (세로형, 가로형 등)
  final double ratio; // 화면 비율
  final Size realSize; // 실제 cm 크기
  final String? productId; // 기존 앨범은 인쇄 상품 정보가 없을 수 있다.

  const CoverSize({
    required this.name,
    required this.ratio,
    required this.realSize,
    this.productId,
  });

  String get displayName =>
      '$name ${_dimension(realSize.width)} × ${_dimension(realSize.height)}cm';

  PrintCoverType get coverType => productId?.endsWith('_HARD') == true
      ? PrintCoverType.hard
      : PrintCoverType.soft;

  /// 표지 종류가 달라도 내지 레이아웃에 사용하는 크기 키는 같다.
  String? get sizeProductId =>
      productId?.replaceFirst(RegExp(r'_HARD$'), '_SOFT');

  CoverSize withCoverType(PrintCoverType type) {
    final source = coverSizeForProduct(productId) ?? newAlbumCoverSize(this);
    final id = source.sizeProductId!;
    return coverSizeForProduct(
      type == PrintCoverType.hard
          ? id.replaceFirst(RegExp(r'_SOFT$'), '_HARD')
          : id,
    )!;
  }

  Map<String, dynamic>? get printProduct => productId == null
      ? null
      : {
          'id': productId,
          'trimWidthMm': (realSize.width * 10).round(),
          'trimHeightMm': (realSize.height * 10).round(),
        };

  static String _dimension(double value) =>
      value == value.roundToDouble() ? '${value.toInt()}' : '$value';
}

const defaultCoverSize = CoverSize(
  name: '정사각형',
  ratio: 1,
  realSize: Size(20, 20),
  productId: 'REDP_200_SOFT',
);

/// 새 앨범에서 선택 가능한 공식 PHBKMYB 재단 규격.
const List<CoverSize> coverSizes = [
  defaultCoverSize,
  CoverSize(
    name: '가로형',
    ratio: 4 / 3,
    realSize: Size(20, 15),
    productId: 'REDP_200X150_SOFT',
  ),
  CoverSize(
    name: '가로형',
    ratio: 5 / 4,
    realSize: Size(25, 20),
    productId: 'REDP_250X200_SOFT',
  ),
  CoverSize(
    name: '정사각형',
    ratio: 1,
    realSize: Size(25, 25),
    productId: 'REDP_250_SOFT',
  ),
  CoverSize(
    name: '정사각형',
    ratio: 1,
    realSize: Size(30, 30),
    productId: 'REDP_300_SOFT',
  ),
];

/// 저장된 앨범을 복원할 때만 사용하는 기존 캔버스 크기.
const List<CoverSize> legacyCoverSizes = [
  CoverSize(name: '세로형', ratio: 3 / 4, realSize: Size(14.5, 19.4)),
  CoverSize(name: '정사각형', ratio: 1, realSize: Size(20, 20)),
  CoverSize(name: '가로형', ratio: 4 / 3, realSize: Size(19.4, 14.5)),
];

CoverSize? coverSizeForProduct(String? productId) {
  for (final cover in coverSizes) {
    if (cover.productId == productId) return cover;
    if (productId ==
        cover.productId!.replaceFirst(RegExp(r'_SOFT$'), '_HARD')) {
      return CoverSize(
        name: cover.name,
        ratio: cover.ratio,
        realSize: cover.realSize,
        productId: productId,
      );
    }
  }
  return null;
}

/// 인쇄 상품 정보가 없는 기존 앨범을 새 상품 크기로 바꾸지 않는다.
CoverSize resolveCoverSize({
  required double ratio,
  Map<String, dynamic>? printProduct,
}) {
  final id = printProduct?['id'];
  final product = coverSizeForProduct(id is String ? id : null);
  final width = printProduct?['trimWidthMm'];
  final height = printProduct?['trimHeightMm'];
  if (product != null &&
      width is num &&
      height is num &&
      (width - product.realSize.width * 10).abs() < .0001 &&
      (height - product.realSize.height * 10).abs() < .0001 &&
      (ratio - product.ratio).abs() <= .01)
    return product;
  for (final legacy in legacyCoverSizes) {
    if ((legacy.ratio - ratio).abs() < .0001) return legacy;
  }
  if (!ratio.isFinite || ratio <= 0) return defaultCoverSize;
  return CoverSize(
    name: ratio > 1 ? '가로형' : '세로형',
    ratio: ratio,
    realSize: Size(20, 20 / ratio),
  );
}

/// 새 제작에서는 오래된 세로형/비규격 크기를 그대로 선택하지 않는다.
CoverSize newAlbumCoverSize(CoverSize? source) {
  final product = coverSizeForProduct(source?.productId);
  if (product != null) return product;
  final ratio = source?.ratio ?? 1;
  if ((ratio - 1.25).abs() < .0001) return coverSizes[2];
  if (ratio > 1) return coverSizes[1];
  return defaultCoverSize;
}

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
