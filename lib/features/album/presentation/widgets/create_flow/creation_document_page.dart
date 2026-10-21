import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../data/gallery/browser_photo_asset.dart';
import '../../../domain/entities/layer.dart';

/// Resolves only the visible page's local originals, without changing its layers.
class CreationDocumentPage extends StatefulWidget {
  const CreationDocumentPage({
    super.key,
    required this.layers,
    required this.canvas,
    required this.width,
    required this.height,
    this.preserveTypography = true,
    this.wrapSpine = false,
    this.decodeWidth,
  });

  final List<LayerModel> layers;
  final Size canvas;
  final double width, height;
  final bool preserveTypography, wrapSpine;
  final int? decodeWidth;

  @override
  State<CreationDocumentPage> createState() => _CreationDocumentPageState();
}

class _CreationDocumentPageState extends State<CreationDocumentPage> {
  final Map<String, File> _files = {};
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CreationDocumentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layers, widget.layers)) {
      _files.clear();
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final files = <String, File>{};
    for (final layer in widget.layers) {
      if (layer.asset == null || layer.asset is BrowserPhotoAsset) continue;
      try {
        final file = await layer.asset!.file;
        if (!mounted || generation != _generation) return;
        if (file != null) files[layer.id] = file;
      } catch (_) {
        // An unavailable original stays an empty slot, never a sample photo.
      }
    }
    if (mounted && generation == _generation && files.isNotEmpty) {
      setState(() => _files.addAll(files));
    }
  }

  @override
  Widget build(BuildContext context) => TemplatePageRenderer(
    layers: widget.layers,
    width: widget.width,
    height: widget.height,
    designCanvasSize: widget.canvas,
    localFiles: _files,
    imageDecodeWidth:
        widget.decodeWidth ??
        (math.max(widget.width, widget.height) *
                MediaQuery.devicePixelRatioOf(context) *
                1.5)
            .ceil()
            .clamp(320, 1200),
    showCanvasChrome: false,
    wrapSpineArtwork: widget.wrapSpine,
    cacheNetworkImages: true,
    preserveTypography: widget.preserveTypography,
  );
}
