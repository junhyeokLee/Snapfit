import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../domain/entities/layer.dart';
import 'ai_template_art_direction.dart';

enum AiTemplateAspect { portrait, square, landscape }

class AiTemplateBrief {
  const AiTemplateBrief({
    required this.prompt,
    this.pageCount = 8,
    this.aspect = AiTemplateAspect.square,
    this.printProductId,
  });

  final String prompt;
  final int pageCount;
  final AiTemplateAspect aspect;
  final String? printProductId;
  CoverSize get coverSize =>
      coverSizeForProduct(printProductId) ??
      newAlbumCoverSize(legacyCoverSizes[aspect.index]);

  Map<String, Object?> toJson() => {
    'prompt': prompt.trim(),
    'pageCount': pageCount,
    'aspect': aspect.name,
    'designVersion': 2,
    if (printProductId != null) 'printProduct': coverSize.printProduct,
  };
}

class AiTemplateDesign {
  const AiTemplateDesign({
    required this.concept,
    required this.rationale,
    required this.aspect,
    required this.pages,
    this.artDirection,
    this.printProduct,
  });

  final String concept;
  final String rationale;
  final AiTemplateAspect aspect;
  final List<AiTemplateDesignPage> pages;
  final AiTemplateArtDirection? artDirection;
  final Map<String, dynamic>? printProduct;

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
    final directed = json['version'] == 2;
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
        rawPages.length > 17) {
      throw const FormatException('Invalid template design');
    }
    final direction = directed
        ? AiTemplateArtDirection.fromJson(json['artDirection'], pageCount)
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
              elements.length > (directed ? 16 : 12))
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
                      !['photo', 'text', 'shape'].contains(kind))
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
                      if (kind == 'text') ...['text', 'typography', 'align'],
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
                  return AiTemplateDesignElement(
                    id: id,
                    kind: kind! as String,
                    rect: rect,
                    color: color,
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
    return AiTemplateDesign(
      concept: _text(json['concept'], 80),
      rationale: _text(json['rationale'], 300),
      aspect: aspect,
      pages: pages,
      artDirection: direction,
      printProduct: printProduct,
    );
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
                text: e.kind == 'shape' ? 'rect' : e.text,
                imageTemplate: e.kind == 'photo' ? 'free' : null,
                imageBackground: e.kind == 'photo' ? 'none' : null,
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
                zIndex: (e.kind == 'shape' ? 1 : 20) + order,
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
