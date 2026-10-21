import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/constants/album_page_policy.dart';
import '../../domain/entities/layer.dart';
import 'ai_template_art_direction.dart';
import 'ai_template_composition.g.dart';
import 'ai_template_safe_options.dart';

export 'ai_template_safe_options.dart';

part 'ai_template_composition.dart';

enum AiTemplateAspect { portrait, square, landscape }

class AiTemplateBrief {
  const AiTemplateBrief({
    required this.prompt,
    this.pageCount = 8,
    this.aspect = AiTemplateAspect.square,
    this.printProductId,
    this.designVersion = 3,
    this.expectedPointCost,
    this.safeOptions = const AiTemplateSafeOptions(),
  });

  /// Private device memo. Network requests serialize only [toSafeDesignJson].
  final String prompt;
  final int pageCount;
  final AiTemplateAspect aspect;
  final String? printProductId;
  final int designVersion;
  final int? expectedPointCost;
  final AiTemplateSafeOptions safeOptions;
  AiTemplateBrief withExpectedPointCost(int cost) => AiTemplateBrief(
    prompt: prompt,
    pageCount: pageCount,
    aspect: aspect,
    printProductId: printProductId,
    designVersion: designVersion,
    expectedPointCost: cost,
    safeOptions: safeOptions,
  );
  CoverSize get coverSize =>
      coverSizeForProduct(printProductId) ??
      newAlbumCoverSize(legacyCoverSizes[aspect.index]);

  Map<String, Object?> toJson() => {
    'prompt': prompt.trim(),
    'pageCount': pageCount,
    'aspect': aspect.name,
    'designVersion': designVersion,
    if (printProductId != null) 'printProduct': coverSize.printProduct,
  };

  Map<String, Object?> toSafeDesignJson() {
    if (!AlbumPagePolicy.isValid(pageCount) || pageCount < 20) {
      throw const FormatException('Invalid safe design page count');
    }
    if (printProductId != null) {
      final product = coverSizeForProduct(printProductId);
      if (product == null ||
          (product.ratio > 1
                  ? AiTemplateAspect.landscape
                  : AiTemplateAspect.square) !=
              aspect) {
        throw const FormatException('Invalid print product');
      }
    }
    return {
      ...safeOptions.toJson(),
      'pageCount': pageCount,
      'aspect': aspect.name,
      if (printProductId != null) 'printProduct': coverSize.printProduct,
    };
  }

  AiTemplateBrief get publicBrief => AiTemplateBrief(
    prompt: safeOptions.publicDescription,
    pageCount: pageCount,
    aspect: aspect,
    printProductId: printProductId,
    designVersion: 3,
    expectedPointCost: expectedPointCost,
    safeOptions: safeOptions,
  );

  factory AiTemplateBrief.fromSafeDesign(Map value, {String localMemo = ''}) {
    final count = value['pageCount'];
    if (count is! int || !AlbumPagePolicy.isValid(count) || count < 20) {
      throw const FormatException('Invalid safe design page count');
    }
    final aspect = AiTemplateAspect.values.byName(value['aspect'] as String);
    final rawProduct = value['printProduct'];
    String? productId;
    if (rawProduct != null) {
      if (rawProduct is! Map)
        throw const FormatException('Invalid print product');
      final cover = coverSizeForProduct(rawProduct['id'] as String?);
      if (cover == null ||
          rawProduct['trimWidthMm'] != cover.printProduct!['trimWidthMm'] ||
          rawProduct['trimHeightMm'] != cover.printProduct!['trimHeightMm'] ||
          (cover.ratio > 1
                  ? AiTemplateAspect.landscape
                  : AiTemplateAspect.square) !=
              aspect) {
        throw const FormatException('Invalid print product');
      }
      productId = cover.productId;
    }
    return AiTemplateBrief(
      prompt: localMemo,
      pageCount: count,
      aspect: aspect,
      printProductId: productId,
      safeOptions: AiTemplateSafeOptions.fromJson(value),
    );
  }
}

/// Records bounded AI generation separately from the final printed page count.
class AiTemplateLayoutExpansion {
  const AiTemplateLayoutExpansion({
    required this.sourcePageCount,
    required this.finalPageCount,
  });
  final int sourcePageCount;
  final int finalPageCount;

  factory AiTemplateLayoutExpansion.fromJson(Object? raw, int pageCount) {
    if (raw is! Map ||
        raw['strategy'] != 'repeat_inner_layouts_v1' ||
        raw['sourcePageCount'] is! int ||
        raw['sourcePageCount'] < 4 ||
        raw['sourcePageCount'] > 16 ||
        (raw['sourcePageCount'] as int).isOdd ||
        raw['finalPageCount'] != pageCount ||
        !AlbumPagePolicy.isValid(pageCount)) {
      throw const FormatException('Invalid template page expansion');
    }
    return AiTemplateLayoutExpansion(
      sourcePageCount: raw['sourcePageCount'] as int,
      finalPageCount: pageCount,
    );
  }
}

class AiTemplateDesign {
  const AiTemplateDesign({
    required this.concept,
    required this.rationale,
    required this.aspect,
    required this.pages,
    this.artDirection,
    this.printProduct,
    this.layoutExpansion,
    this.version = 1,
    this.compositionPlan,
  });

  final String concept;
  final String rationale;
  final AiTemplateAspect aspect;
  final List<AiTemplateDesignPage> pages;
  final AiTemplateArtDirection? artDirection;
  final Map<String, dynamic>? printProduct;
  final AiTemplateLayoutExpansion? layoutExpansion;
  final int version;
  final AiTemplateCompositionPlan? compositionPlan;

  CoverSize get coverSize =>
      coverSizeForProduct(printProduct?['id'] as String?) ??
      legacyCoverSizes[switch (aspect) {
        AiTemplateAspect.portrait => 0,
        AiTemplateAspect.square => 1,
        AiTemplateAspect.landscape => 2,
      }];

  Size get canvasSize =>
      Size(500, 500 * coverSize.realSize.height / coverSize.realSize.width);

  factory AiTemplateDesign.fromJson(Map<String, Object?> json, int pageCount) {
    final rawPages = json['pages'];
    final aspect = AiTemplateAspect.values
        .where((v) => v.name == json['aspect'])
        .firstOrNull;
    final original = json['version'] == 3;
    final directed = original || json['version'] == 2;
    Map<String, dynamic>? printProduct;
    if (json['printProduct'] != null) {
      final raw = json['printProduct'];
      if (raw is! Map || raw['id'] is! String) {
        throw const FormatException('Invalid template print product');
      }
      final cover = coverSizeForProduct(raw['id'] as String);
      if (cover == null ||
          raw['trimWidthMm'] != cover.printProduct!['trimWidthMm'] ||
          raw['trimHeightMm'] != cover.printProduct!['trimHeightMm'] ||
          aspect !=
              (cover.ratio > 1
                  ? AiTemplateAspect.landscape
                  : AiTemplateAspect.square)) {
        throw const FormatException('Invalid template print product');
      }
      printProduct = cover.printProduct;
    }
    if ((!directed && json['version'] != 1) ||
        aspect == null ||
        rawPages is! List ||
        rawPages.length != pageCount + 1 ||
        rawPages.length > AlbumPagePolicy.maxInnerPages + 1 ||
        (pageCount > 16 && !AlbumPagePolicy.isValid(pageCount))) {
      throw const FormatException('Invalid template design');
    }
    final expansion = json['layoutExpansion'] != null
        ? AiTemplateLayoutExpansion.fromJson(json['layoutExpansion'], pageCount)
        : null;
    if (pageCount > 16 && expansion == null && !original) {
      throw const FormatException('Missing template page expansion');
    }
    final direction = directed
        ? AiTemplateArtDirection.fromJson(json['artDirection'], pageCount)
        : null;
    final compositionPlan = original
        ? AiTemplateCompositionPlan.fromJson(json, pageCount)
        : null;
    if (direction != null &&
        (json['concept'] != direction.concept ||
            json['rationale'] != direction.rationale)) {
      throw const FormatException('Art direction changed');
    }
    final ids = <String>{};
    final pages = rawPages.indexed
        .map((entry) {
          final (index, raw) = entry;
          final page = Map<String, Object?>.from(raw as Map);
          final background = _color(page['background']);
          final elements = page['elements'];
          if (elements is! List ||
              elements.isEmpty ||
              elements.length >
                  (original
                      ? 24
                      : directed
                      ? 16
                      : 12))
            throw const FormatException('Invalid design elements');
          if (direction != null &&
              (!direction.palette.contains(_hex(background).toUpperCase()) ||
                  page['role'] != direction.pages[index].role ||
                  page['purpose'] != direction.pages[index].intent)) {
            throw const FormatException('Planned page changed');
          }
          return AiTemplateDesignPage(
            background: background,
            purpose: _text(page['purpose'], directed ? 120 : 80),
            elements: elements
                .map((raw) {
                  final e = Map<String, Object?>.from(raw as Map);
                  final id = _text(e['id'], 64);
                  final kind = e['kind'];
                  if (!ids.add(id) ||
                      (directed && id.startsWith('ai_paper_')) ||
                      !(original
                              ? ['photo', 'text', 'paper']
                              : ['photo', 'text', 'shape'])
                          .contains(kind) ||
                      (original && !id.startsWith('p${index}_')))
                    throw const FormatException('Invalid design element');
                  final rect = Rect.fromLTWH(
                    _number(e['x'], 0, 1),
                    _number(e['y'], 0, 1),
                    _number(e['width'], directed ? .001 : .01, 1),
                    _number(e['height'], directed ? .001 : .005, 1),
                  );
                  if (rect.right > 1.0001 || rect.bottom > 1.0001)
                    throw const FormatException('Design element outside page');
                  AiTemplateTypeStyle? type;
                  final color = _color(e['color']);
                  if (direction != null) {
                    final allowed = {
                      'id',
                      'kind',
                      'x',
                      'y',
                      'width',
                      'height',
                      'color',
                      if (kind == 'text' || original) ...[
                        'text',
                        'typography',
                        'align',
                      ],
                      if (original) ...['style', 'rotation', 'zIndex'],
                    };
                    if (e.keys.any((key) => !allowed.contains(key)))
                      throw const FormatException('Unsupported design field');
                    if (kind != 'photo' &&
                        !direction.palette.contains(_hex(color).toUpperCase()))
                      throw const FormatException('Plan palette changed');
                    if (kind == 'photo' &&
                        (rect.width < .18 || rect.height < .14))
                      throw const FormatException('Photo frame too small');
                    if (kind == 'text') {
                      type = direction.typography[e['typography']];
                      if (type == null ||
                          !['left', 'center', 'right'].contains(e['align']))
                        throw const FormatException('Invalid typography role');
                      if (rect.left < .04 ||
                          rect.top < .04 ||
                          rect.right > .96 ||
                          rect.bottom > .96)
                        throw const FormatException('Text outside safe area');
                      final content = _text(e['text'], 160);
                      if (!type.supportsHangul &&
                          RegExp(
                            r'[\u1100-\u11ff\u3130-\u318f\uac00-\ud7a3]',
                          ).hasMatch(content))
                        throw const FormatException('Unsupported font script');
                    }
                  }
                  final materialStyle = original
                      ? _text(e['style'], 40)
                      : 'plain';
                  if (compositionPlan != null) {
                    if ((kind == 'photo' &&
                            !compositionPlan.frames.contains(materialStyle)) ||
                        (kind == 'paper' &&
                            !compositionPlan.papers.contains(materialStyle)) ||
                        (kind == 'text' &&
                            !['plain', 'outline'].contains(materialStyle))) {
                      throw const FormatException('Unlicensed AI material');
                    }
                    if (kind != 'text' &&
                        (e['text'] != null ||
                            e['typography'] != null ||
                            e['align'] != null)) {
                      throw const FormatException('Unexpected nontext content');
                    }
                  }
                  final rotation = original
                      ? _number(e['rotation'], -.12, .12)
                      : 0.0;
                  final z = original ? _number(e['zIndex'], 1, 99) : null;
                  if (original &&
                      (z != z!.roundToDouble() ||
                          (kind == 'text' && rotation != 0))) {
                    throw const FormatException(
                      'Invalid AI stacking or text rotation',
                    );
                  }
                  return AiTemplateDesignElement(
                    id: id,
                    kind: kind! as String,
                    rect: rect,
                    color: color,
                    style: materialStyle,
                    rotation: rotation,
                    zIndex: z?.toInt(),
                    text: kind == 'text' ? _text(e['text'], 160) : null,
                    fontFamily: type?.fontFamily,
                    lineHeight: type?.lineHeight ?? 1.3,
                    typographyRole: kind == 'text' && directed
                        ? e['typography'] as String
                        : null,
                    fontSize:
                        type?.fontSize ??
                        (kind == 'text' ? _number(e['fontSize'], 12, 56) : 14),
                    weight:
                        type?.weight ??
                        (kind == 'text'
                            ? _number(e['weight'], 400, 800).round()
                            : 400),
                    align: switch (e['align']) {
                      'center' => TextAlign.center,
                      'right' => TextAlign.right,
                      _ => TextAlign.left,
                    },
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
    if (!directed &&
        pages.any((p) => !p.elements.any((e) => e.kind == 'photo')))
      throw const FormatException('Missing photo frame');
    if (direction != null) {
      for (final (index, page) in pages.indexed) {
        final photos = page.elements.where((e) => e.kind == 'photo').length;
        if (photos != direction.pages[index].photoCount ||
            (photos == 0 && !page.elements.any((e) => e.kind == 'text')))
          throw const FormatException('Photo plan changed');
      }
    }
    final design = AiTemplateDesign(
      concept: _text(json['concept'], 80),
      rationale: _text(json['rationale'], 300),
      aspect: aspect,
      pages: pages,
      artDirection: direction,
      printProduct: printProduct,
      layoutExpansion: expansion,
      version: json['version']! as int,
      compositionPlan: compositionPlan,
    );
    if (original) _validateOriginalComposition(design);
    return design;
  }

  List<List<LayerModel>> buildLayers({Size? targetSize}) {
    final size = targetSize ?? canvasSize;
    return pages.indexed
        .map((entry) {
          final (index, page) = entry;
          return <LayerModel>[
            LayerModel(
              id: 'ai_paper_$index',
              type: LayerType.decoration,
              position: Offset.zero,
              width: size.width,
              height: size.height,
              text: 'rect',
              decorationFillColor: _hex(page.background),
              decorationCornerRadius: 0,
              zIndex: 0,
            ),
            ...page.elements.indexed.map((entry) {
              final (order, e) = entry;
              return LayerModel(
                id: e.id,
                type: switch (e.kind) {
                  'photo' => LayerType.image,
                  'text' => LayerType.text,
                  _ => LayerType.decoration,
                },
                position: Offset(
                  e.rect.left * size.width,
                  e.rect.top * size.height,
                ),
                width: e.rect.width * size.width,
                height: e.rect.height * size.height,
                text: e.kind == 'shape' || e.kind == 'paper' ? 'rect' : e.text,
                imageTemplate: e.kind == 'photo' ? 'free' : null,
                imageBackground: version == 3 && e.kind != 'text'
                    ? e.style
                    : e.kind == 'photo'
                    ? 'none'
                    : null,
                rotation: e.rotation,
                textFillMode: version == 3 && e.kind == 'text'
                    ? (e.style == 'outline' ? 'outline' : 'solid')
                    : null,
                decorationFillColor: _hex(e.color),
                decorationCornerRadius: 0,
                textStyleType: TextStyleType.none,
                textAlign: e.align,
                textStyle: e.kind == 'text'
                    ? TextStyle(
                        fontSize: e.fontSize * size.width / 500,
                        fontFamily: e.fontFamily,
                        letterSpacing: artDirection == null ? null : 0,
                        height: e.lineHeight,
                        color: e.color,
                        fontWeight: FontWeight
                            .values[(e.weight ~/ 100 - 1).clamp(0, 8)],
                      )
                    : null,
                zIndex: e.zIndex ?? (e.kind == 'shape' ? 1 : 20) + order,
              );
            }),
          ];
        })
        .toList(growable: false);
  }
}

class AiTemplateDesignPage {
  const AiTemplateDesignPage({
    required this.background,
    required this.purpose,
    required this.elements,
  });
  final Color background;
  final String purpose;
  final List<AiTemplateDesignElement> elements;
}

class AiTemplateDesignElement {
  const AiTemplateDesignElement({
    required this.id,
    required this.kind,
    required this.rect,
    required this.color,
    this.text,
    this.fontSize = 14,
    this.weight = 400,
    this.align = TextAlign.left,
    this.fontFamily,
    this.lineHeight = 1.3,
    this.typographyRole,
    this.style = 'plain',
    this.rotation = 0,
    this.zIndex,
  });
  final String id;
  final String kind;
  final Rect rect;
  final Color color;
  final String? text;
  final double fontSize;
  final int weight;
  final TextAlign align;
  final String? fontFamily;
  final double lineHeight;
  final String? typographyRole;
  final String style;
  final double rotation;
  final int? zIndex;
}

String _text(Object? value, int max) {
  if (value is! String || value.trim().isEmpty || value.length > max)
    throw const FormatException('Invalid design text');
  return value.trim();
}

double _number(Object? value, double min, double max) {
  if (value is! num || !value.isFinite || value < min || value > max)
    throw const FormatException('Invalid design number');
  return value.toDouble();
}

Color _color(Object? value) {
  if (value is! String || !RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value))
    throw const FormatException('Invalid design color');
  return Color(int.parse('FF${value.substring(1)}', radix: 16));
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2)}';
