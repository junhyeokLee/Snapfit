import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/cover_theme.dart';
import '../../album/domain/entities/layer.dart';
import '../../album/domain/entities/layer_export_mapper.dart';
import 'print_vendor_spec.dart';

/// Frozen print content, never reconstructed from the current editable album.
class PrintAlbumDocument {
  PrintAlbumDocument(
    this.pages, {
    required this.ratio,
    this.savedProduct,
    this.frozenProduct,
  });
  final List<PrintAlbumPage> pages;
  final double ratio;
  final Map? savedProduct, frozenProduct;
  PrintAlbumPage get cover => pages.singleWhere((page) => page.isCover);
  List<PrintAlbumPage> get interiors => pages.where((p) => !p.isCover).toList();

  PrintProduct get productForNewPreview {
    final product = savedProduct == null
        ? PrintProduct.forLegacyRatio(ratio)
        : PrintProduct.fromJson(savedProduct!);
    if ((ratio - product.aspectRatio).abs() > .01) {
      throw const FormatException('print_product_ratio_mismatch');
    }
    if (frozenProduct != null &&
        PrintProduct.fromJson(frozenProduct!).id != product.id) {
      throw const FormatException('print_product_snapshot_mismatch');
    }
    return product;
  }

  void validateSpec(PrintVendorSpec spec, {bool newPreview = false}) {
    // Existing purchased square books retain their original manufacturing size.
    if (!newPreview && spec.isLegacySquareContract) return;
    if (newPreview ||
        savedProduct != null ||
        frozenProduct != null ||
        RegExp(r'_REVIEW_V[23]_').hasMatch(spec.specVersion)) {
      final product = productForNewPreview;
      if (product.id != spec.id ||
          product.trimWidthMm != spec.trimWidthMm ||
          product.trimHeightMm != spec.trimHeightMm) {
        throw const FormatException('print_product_spec_mismatch');
      }
    }
  }

  factory PrintAlbumDocument.fromSnapshot(Map<String, dynamic> snapshot) {
    final album = Map<String, dynamic>.from(snapshot['album'] as Map);
    final ratioText = '${album['ratio']}'.trim();
    final parts = RegExp(
      r'^(\d+(?:\.\d+)?)\s*[:/]\s*(\d+(?:\.\d+)?)$',
    ).firstMatch(ratioText);
    final ratio = parts == null
        ? double.tryParse(ratioText)
        : double.parse(parts[1]!) / double.parse(parts[2]!);
    if (ratio == null || !ratio.isFinite || ratio <= 0 || ratio > 5) {
      throw const FormatException('print_album_ratio_invalid');
    }
    dynamic decode(dynamic value) =>
        value is String ? jsonDecode(value) : value;
    final full = decode(album['cover_layers_json']);
    final savedProduct = full is Map ? full['printProduct'] : null;
    final frozenProduct = snapshot['printProduct'];
    if ((savedProduct != null && savedProduct is! Map) ||
        (frozenProduct != null && frozenProduct is! Map)) {
      throw const FormatException('invalid_print_product');
    }
    final List<dynamic> rawPages;
    if (full is Map && full['pages'] is List) {
      rawPages = full['pages'] as List;
    } else {
      // Older albums store the cover separately from album_pages.
      if (full is! Map || full['layers'] is! List) {
        throw const FormatException('print_album_layers_missing');
      }
      final legacyRows =
          (snapshot['pages'] as List? ?? const []).map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final index = row['page_number'] ?? row['page_index'];
            if (index is! num ||
                !index.isFinite ||
                index < 0 ||
                index != index.toInt()) {
              throw const FormatException('print_page_index_invalid');
            }
            return row;
          }).toList()..sort(
            (a, b) => ((a['page_number'] ?? a['page_index']) as num).compareTo(
              (b['page_number'] ?? b['page_index']) as num,
            ),
          );
      if (legacyRows
              .map((row) => row['page_number'] ?? row['page_index'])
              .toSet()
              .length !=
          legacyRows.length)
        throw const FormatException('print_page_index_invalid');
      rawPages = [
        {...full, 'index': 0, 'isCover': true},
        for (final entry in legacyRows.indexed)
          {
            ...(decode(entry.$2['layers_json']) as Map),
            // Legacy table indices can start at zero; cover is always separate.
            'index': entry.$1 + 1,
            'isCover': false,
          },
      ];
    }
    final pages = <PrintAlbumPage>[];
    final seen = <int>{};
    for (final value in rawPages) {
      final page = Map<String, dynamic>.from(value as Map);
      final rawIndex = page['index'];
      if (rawIndex is! num ||
          !rawIndex.isFinite ||
          rawIndex < 0 ||
          rawIndex != rawIndex.toInt() ||
          !seen.add(rawIndex.toInt())) {
        throw const FormatException('print_page_index_invalid');
      }
      final index = rawIndex.toInt();
      final isCover = page['isCover'] == true;
      final editorSize = Size(
        kCoverReferenceWidth,
        kCoverReferenceWidth / ratio,
      );
      // The 14 logical-pixel spine is editor chrome, never physical book spine.
      final designSize = Size(
        isCover ? editorSize.width - kCoverSpineWidth : editorSize.width,
        editorSize.height,
      );
      final rawLayers = page['layers'];
      if (rawLayers is! List)
        throw const FormatException('print_page_layers_missing');
      final layers = rawLayers.map((raw) {
        final json = Map<String, dynamic>.from(raw as Map);
        for (final key in [
          'x',
          'y',
          'width',
          'height',
          'scale',
          'rotation',
          'opacity',
        ]) {
          final value = json[key];
          if (value != null && (value is! num || !value.isFinite)) {
            throw FormatException('print_layer_geometry_invalid:$key');
          }
        }
        json.putIfAbsent('rotation', () => 0);
        final layer = LayerExportMapper.fromJson(
          json,
          canvasSize: editorSize,
          isCover: isCover,
        );
        if (layer.width <= 0 ||
            layer.height <= 0 ||
            layer.scale <= 0 ||
            layer.opacity < 0 ||
            layer.opacity > 1) {
          throw FormatException('print_layer_geometry_invalid:${layer.id}');
        }
        return isCover
            ? layer.copyWith(
                position: layer.position - const Offset(kCoverSpineWidth, 0),
              )
            : layer;
      }).toList()..sort((a, b) => a.zIndex.compareTo(b.zIndex));
      final background = page['backgroundColor'];
      if (background != null && background is! int) {
        throw const FormatException('print_background_invalid');
      }
      final themeName = (album['cover_theme'] ?? 'classic').toString();
      final theme = CoverTheme.values
          .where((value) => value.name == themeName)
          .firstOrNull;
      if (isCover && background == null && theme == null) {
        throw FormatException('print_cover_theme_unknown:$themeName');
      }
      final coverTheme = isCover && background == null ? theme : null;
      if (coverTheme?.imageAsset case final String path) {
        // The editor paints its theme over the full 500px cover including spine.
        // Keep the same crop then omit the decorative spine area from the print.
        layers.insert(
          0,
          LayerModel(
            id: '__print_cover_theme',
            type: LayerType.image,
            position: const Offset(-kCoverSpineWidth, 0),
            width: editorSize.width,
            height: editorSize.height,
            originalUrl: 'asset:$path',
            zIndex: -2147483648,
          ),
        );
      }
      pages.add(
        PrintAlbumPage(
          index: index,
          isCover: isCover,
          canvasSize: designSize,
          layers: List.unmodifiable(layers),
          backgroundColor: Color(
            background as int? ??
                coverTheme?.gradient.colors.first.toARGB32() ??
                0xffffffff,
          ).withAlpha(255),
          backgroundGradient:
              coverTheme != null && coverTheme.imageAsset == null
              ? coverTheme.gradient
              : null,
        ),
      );
    }
    pages.sort((a, b) => a.index.compareTo(b.index));
    if (pages.where((p) => p.isCover).length != 1 || !pages.first.isCover) {
      throw const FormatException('print_cover_missing_or_ambiguous');
    }
    return PrintAlbumDocument(
      List.unmodifiable(pages),
      ratio: ratio,
      savedProduct: savedProduct as Map?,
      frozenProduct: frozenProduct as Map?,
    );
  }
}

class PrintAlbumPage {
  const PrintAlbumPage({
    required this.index,
    required this.isCover,
    required this.canvasSize,
    required this.layers,
    required this.backgroundColor,
    this.backgroundGradient,
  });
  final int index;
  final bool isCover;
  final Size canvasSize;
  final List<LayerModel> layers;
  final Color backgroundColor;
  final Gradient? backgroundGradient;
}
