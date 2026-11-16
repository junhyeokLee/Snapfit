import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../../domain/entities/layer_export_mapper.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../utils/album_document_worker.dart';
import '../reader/album_reader_page_content.dart';

/// Only the chosen unfinished page crosses the worker boundary. The card does
/// not retain a decoded book or generate a substitute layout for an old album.
Map<String, dynamic>? readSuggestedAlbumPage(Map<String, dynamic> request) {
  final document = jsonDecode(request['source'] as String);
  final position = request['position'] as int?;
  if (document is! Map || position == null || document['pages'] is! List)
    return null;
  final pages = document['pages'] as List;
  if (position < 0 || position >= pages.length) return null;
  final page = pages[position];
  if (page is! Map || page['layers'] is! List) return null;
  return Map<String, dynamic>.from(page);
}

class AlbumNextPagePreview extends StatefulWidget {
  const AlbumNextPagePreview({
    super.key,
    required this.album,
    required this.pagePosition,
  });
  final Album album;
  final int? pagePosition;

  @override
  State<AlbumNextPagePreview> createState() => _AlbumNextPagePreviewState();
}

class _AlbumNextPagePreviewState extends State<AlbumNextPagePreview> {
  List<LayerModel> _layers = const [];
  Color _paper = Colors.white;
  var _revision = 0;
  late final _interaction = LayerInteractionManager.printPreview(() => _canvas);
  late final _builder = LayerBuilder(
    _interaction,
    () => _canvas,
    previewImageDecodeWidth: 192,
  );

  Size get _canvas => Size(
    kCoverReferenceWidth,
    kCoverReferenceWidth / widget.album.physicalCoverSize.ratio,
  );

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(AlbumNextPagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.album, widget.album) ||
        oldWidget.pagePosition != widget.pagePosition) {
      _layers = const [];
      _paper = Colors.white;
      _prepare();
    }
  }

  Future<void> _prepare() async {
    final revision = ++_revision;
    final request = <String, dynamic>{
      'source': widget.album.coverLayersJson,
      'position': widget.pagePosition,
    };
    try {
      final page = widget.album.coverLayersJson.length <= 32 * 1024
          ? readSuggestedAlbumPage(request)
          : await AlbumDocumentWorker.run(
              () => compute(
                readSuggestedAlbumPage,
                request,
                debugLabel: 'next-album-page',
              ),
              isCurrent: () => mounted && revision == _revision,
            );
      if (!mounted || revision != _revision || page == null) return;
      final canvas = _canvas;
      final layers = [
        for (final raw in page['layers'] as List)
          if (raw is Map)
            LayerExportMapper.fromJson(
              Map<String, dynamic>.from(raw),
              canvasSize: canvas,
              isCover: false,
            ),
      ];
      setState(() {
        _layers = layers;
        _paper = Color(
          (page['backgroundColor'] as num?)?.toInt() ?? 0xFFFFFFFF,
        );
      });
    } catch (_) {
      // A malformed old page stays a blank page preview. Entry fetches the
      // latest document again; a preview failure never replaces saved content.
    }
  }

  @override
  void dispose() {
    _revision++;
    _interaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      key: const ValueKey('first-book-actual-page-preview'),
      aspectRatio: _canvas.aspectRatio,
      child: ColoredBox(
        color: _paper,
        child: FittedBox(
          child: AlbumReaderPageContent(
            layers: _layers,
            targetW: _canvas.width,
            targetH: _canvas.height,
            baseCanvasSize: _canvas,
            previewBuilder: _builder,
            backgroundColor: _paper,
            flatPresentation: true,
          ),
        ),
      ),
    ),
  );
}
