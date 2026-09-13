import 'package:flutter/widgets.dart';
import '../../../../core/constants/cover_size.dart';

/// The saved physical product is independent of the editor's logical canvas.
class PrintProduct {
  const PrintProduct._(this.id, this.trimWidthMm, this.trimHeightMm);
  final String id;
  final double trimWidthMm, trimHeightMm;
  double get aspectRatio => trimWidthMm / trimHeightMm;
  String get sizeLabel => '${_mm(trimWidthMm)}×${_mm(trimHeightMm)}mm';
  bool get isHardcover => id.endsWith('_HARD');
  String get coverType => isHardcover ? 'HARD' : 'SOFT';
  String get coverLabel => isHardcover ? '하드커버' : '소프트커버';
  String get label => '$sizeLabel $coverLabel';
  Map<String, dynamic> toJson() => {
    'id': id,
    'trimWidthMm': trimWidthMm,
    'trimHeightMm': trimHeightMm,
  };

  static PrintProduct? forId(String? id) {
    final size = coverSizeForProduct(id);
    return size == null
        ? null
        : PrintProduct._(
            size.productId!,
            size.realSize.width * 10,
            size.realSize.height * 10,
          );
  }

  factory PrintProduct.fromJson(Map value) {
    final product = forId(value['id'] is String ? value['id'] as String : null);
    if (product == null ||
        value['trimWidthMm'] != product.trimWidthMm ||
        value['trimHeightMm'] != product.trimHeightMm) {
      throw const FormatException('invalid_print_product');
    }
    return product;
  }

  static PrintProduct forLegacyRatio(double ratio) {
    if ((ratio - 1).abs() <= .01) return forId('REDP_200_SOFT')!;
    if ((ratio - 4 / 3).abs() <= .01) return forId('REDP_200X150_SOFT')!;
    throw const FormatException('unsupported_print_product');
  }
}

String _mm(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

/// All measurements are millimetres; rectangles use a top-left origin.
/// A spec is supplied by the server for the exact paid page count.
class PrintVendorSpec {
  PrintVendorSpec.fromJson(Map<String, dynamic> json)
    : data = Map.unmodifiable(json) {
    if (isHardcover &&
        (_cover['construction'] != 'casewrap' ||
            _cover['trim'] is! Map ||
            _cover['bleedMm'] is! num ||
            (data['geometrySource']?.toString().trim().isEmpty ?? true))) {
      throw const FormatException('hardcover_template_required');
    }
    if (id.isEmpty ||
        specVersion.isEmpty ||
        dpi != 300 ||
        pageCount <= 0 ||
        pageCount < minInteriorPages ||
        pageCount > maxInteriorPages ||
        pageMultiple <= 0 ||
        pageCount % pageMultiple != 0 ||
        minimumPhotoPpi <= 0 ||
        colorSpace != 'sRGB') {
      throw const FormatException('print_spec_invalid');
    }
    for (final value in [
      trimWidthMm,
      trimHeightMm,
      coverSize.width,
      coverSize.height,
      front.width,
      front.height,
      back.width,
      back.height,
      coverTrim.width,
      coverTrim.height,
    ]) {
      if (!value.isFinite || value <= 0 || value > 1000) {
        throw const FormatException('print_spec_geometry_invalid');
      }
    }
    if (!coverBleedMm.isFinite ||
        coverBleedMm < 0 ||
        coverBleedMm > 50 ||
        !bleedMm.isFinite ||
        bleedMm < 0 ||
        bleedMm > 50 ||
        !Rect.fromLTWH(
          0,
          0,
          coverSize.width,
          coverSize.height,
        ).contains(front.topLeft) ||
        front.right > coverSize.width ||
        front.bottom > coverSize.height ||
        back.left < 0 ||
        back.top < 0 ||
        back.right > coverSize.width ||
        back.bottom > coverSize.height ||
        front.overlaps(back) ||
        (isHardcover && back.right >= front.left) ||
        !_within(coverTrim, Offset.zero & coverSize) ||
        !_within(front, coverTrim) ||
        !_within(back, coverTrim)) {
      throw const FormatException('print_spec_cover_geometry_invalid');
    }
    final product = PrintProduct.forId(id);
    if ((!isHardcover &&
            ((front.width - trimWidthMm).abs() > .001 ||
                (back.width - trimWidthMm).abs() > .001 ||
                (front.height - trimHeightMm).abs() > .001 ||
                (back.height - trimHeightMm).abs() > .001)) ||
        (product != null &&
            (trimWidthMm != product.trimWidthMm ||
                trimHeightMm != product.trimHeightMm))) {
      throw const FormatException('print_product_spec_mismatch');
    }
  }
  final Map<String, dynamic> data;
  String get id => data['id'] as String? ?? '';
  bool get isHardcover => id.endsWith('_HARD');
  String get specVersion => data['specVersion'] as String? ?? '';
  bool get hasOfficialHardcoverProfile =>
      isHardcover &&
      data['coverGeometrySource'] == 'official_default' &&
      data['templateFamily'] == 'REDP_PHBKMYB_CASEWRAP';

  /// Adjust only the official casewrap family; arbitrary vendor overrides need
  /// their full geometry reviewed instead of assuming its hinge construction.
  Map<String, dynamic> officialCoverGeometryForSpine(double spineMm) {
    if (!hasOfficialHardcoverProfile ||
        !spineMm.isFinite ||
        spineMm < .1 ||
        spineMm > 40) {
      throw const FormatException('hardcover_template_adjustment_invalid');
    }
    final delta = spineMm - (front.left - back.right);
    final cover = Map<String, dynamic>.from(_cover);
    cover['widthMm'] = coverSize.width + delta;
    cover['front'] = {
      ...Map<String, dynamic>.from(_cover['front'] as Map),
      'xMm': front.left + delta,
    };
    cover['trim'] = {
      ...Map<String, dynamic>.from(_cover['trim'] as Map),
      'widthMm': coverTrim.width + delta,
    };
    PrintVendorSpec.fromJson({...data, 'spineMm': spineMm, 'cover': cover});
    return cover;
  }

  bool get isLegacySquareContract =>
      id == 'REDP_200_SOFT' &&
      specVersion.startsWith('REDP_200_SOFT_REVIEW_V1_');
  double get aspectRatio => trimWidthMm / trimHeightMm;
  String get sizeLabel => '${_mm(trimWidthMm)}×${_mm(trimHeightMm)}mm';
  String get productLabel => '$sizeLabel ${isHardcover ? '하드커버' : '소프트커버'}';
  bool get verified => data['verified'] == true;
  int get dpi => (data['dpi'] as num?)?.toInt() ?? 300;
  int get pageCount => (data['pageCount'] as num).toInt();
  int get minInteriorPages => (data['minInteriorPages'] as num?)?.toInt() ?? 20;
  int get maxInteriorPages => (data['maxInteriorPages'] as num?)?.toInt() ?? 80;
  int get pageMultiple => (data['pageMultiple'] as num?)?.toInt() ?? 2;
  double get minimumPhotoPpi =>
      (data['minimumPhotoPpi'] as num?)?.toDouble() ?? 150;
  String get colorSpace => data['colorSpace'] as String? ?? 'sRGB';
  Map get _interior => data['interior'] as Map;
  Map get _cover => data['cover'] as Map;
  double get trimWidthMm => (_interior['trimWidthMm'] as num).toDouble();
  double get trimHeightMm => (_interior['trimHeightMm'] as num).toDouble();
  double get bleedMm => (_interior['bleedMm'] as num).toDouble();
  double get coverBleedMm => (_cover['bleedMm'] as num?)?.toDouble() ?? bleedMm;
  Size get interiorSize =>
      Size(trimWidthMm + 2 * bleedMm, trimHeightMm + 2 * bleedMm);
  Rect get interiorTrim =>
      Rect.fromLTWH(bleedMm, bleedMm, trimWidthMm, trimHeightMm);
  Size get coverSize => Size(
    (_cover['widthMm'] as num).toDouble(),
    (_cover['heightMm'] as num).toDouble(),
  );
  Rect _rect(Map rect) => Rect.fromLTWH(
    (rect['xMm'] as num).toDouble(),
    (rect['yMm'] as num).toDouble(),
    (rect['widthMm'] as num).toDouble(),
    (rect['heightMm'] as num).toDouble(),
  );
  Rect get front => _rect(_cover['front'] as Map);
  Rect get back => _rect(_cover['back'] as Map);
  Rect get coverTrim => _cover['trim'] is Map
      ? _rect(_cover['trim'] as Map)
      : front.expandToInclude(back);
  static bool _within(Rect inner, Rect outer) =>
      [
        inner.left,
        inner.top,
        inner.right,
        inner.bottom,
      ].every((v) => v.isFinite) &&
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;
  Map<String, dynamic> toJson() => Map.from(data);
}
