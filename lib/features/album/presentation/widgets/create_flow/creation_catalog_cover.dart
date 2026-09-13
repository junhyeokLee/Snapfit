import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../../core/templates/data_template_engine.dart';
import '../../../../../core/templates/template_document_pages.dart';
import '../../../domain/entities/layer.dart';
import '../../../data/bundled_creation_templates.dart';
import '../../../../store/domain/entities/premium_template.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import 'creation_template_image.dart';

class CreationCatalogCover extends StatefulWidget {
  const CreationCatalogCover({super.key, required this.template});
  final PremiumTemplate template;
  @override
  State<CreationCatalogCover> createState() => _CreationCatalogCoverState();
}

class _CreationCatalogCoverState extends State<CreationCatalogCover> {
  List<LayerModel>? _layers;
  Size _canvas = const Size(500, 500);
  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(CreationCatalogCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.template.templateJson != widget.template.templateJson)
      _parse();
  }

  void _parse() {
    _layers = null;
    try {
      final data =
          jsonDecode(widget.template.templateJson!) as Map<String, dynamic>;
      final metadata = data['metadata'] as Map? ?? const {};
      _canvas = Size(
        (data['designWidth'] as num? ?? metadata['designWidth'] as num? ?? 500)
            .toDouble(),
        (data['designHeight'] as num? ??
                metadata['designHeight'] as num? ??
                500)
            .toDouble(),
      );
      if (_canvas.width <= 0 || _canvas.height <= 0) return;
      final page = templateDocumentPages(data).firstOrNull;
      if (page == null) return;
      _layers = DataTemplateEngine.buildLayersFromJson({
        'strictLayout': true,
        'designWidth': _canvas.width,
        'designHeight': _canvas.height,
        'layers': page['layers'] ?? [],
      }, _canvas);
    } catch (_) {
      _layers = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_layers == null || _layers!.isEmpty)
      return CreationTemplateImage(url: widget.template.coverImageUrl);
    return FittedBox(
      child: TemplatePageRenderer(
        layers: _layers!,
        width: _canvas.width,
        height: _canvas.height,
        designCanvasSize: _canvas,
        showCanvasChrome: true,
        preserveTypography: isBundledCreationTemplate(widget.template),
      ),
    );
  }
}
