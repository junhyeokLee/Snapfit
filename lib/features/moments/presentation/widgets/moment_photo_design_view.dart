import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';

import '../../../../core/fonts/document_fonts.dart';
import '../../../album/data/gallery/browser_photo_asset.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/presentation/controllers/layer_builder.dart';
import '../../../album/presentation/controllers/layer_interaction_manager.dart';
import '../../../album/presentation/widgets/reader/album_reader_page_content.dart';
import '../../data/moment_photo_codec.dart';
import '../../domain/moment_photo_design.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// A bounded in-memory photo adapter for the existing album canvas and crop
/// tools. The selected original bytes remain owned by the moment draft.
Future<BrowserPhotoAsset> prepareMomentEditorPhoto(
  Uint8List bytes, {
  required String id,
  int maxEdge = 1600,
}) async {
  final prepared = await prepareMomentPhoto(bytes, maxEdge: maxEdge);
  return BrowserPhotoAsset.fromStored(
    ownerId: 'moment-local-preview',
    id: 'browser_moment_$id',
    name: 'moment-preview.png',
    width: prepared.width,
    height: prepared.height,
    createdAtSecond: 0,
    originalBytes: prepared.bytes,
    previewBytes: prepared.bytes,
    contentSha256: sha256.convert(prepared.bytes).toString(),
  );
}

List<LayerModel> momentDesignLayersWithPhoto(
  List<LayerModel> layers,
  String photoSource,
  BrowserPhotoAsset? asset,
) => [
  for (final layer in layers)
    if (asset != null &&
        layer.type == LayerType.image &&
        [
          layer.originalUrl,
          layer.previewUrl,
          layer.imageUrl,
        ].contains(photoSource))
      layer.copyWith(asset: asset)
    else
      layer,
];

/// The same editable layer renderer as the album reader. This view never adds
/// a feed caption to the artwork and never modifies or flattens the original.
class MomentPhotoDesignView extends StatefulWidget {
  const MomentPhotoDesignView({
    super.key,
    required this.design,
    required this.photoSource,
    this.bytes,
    this.fit = BoxFit.contain,
    this.imageDecodeWidth = 1440,
    this.placeholder,
    this.error,
  });

  final MomentPhotoDesign design;
  final String photoSource;
  final Uint8List? bytes;
  final BoxFit fit;
  final int imageDecodeWidth;
  final Widget? placeholder, error;

  @override
  State<MomentPhotoDesignView> createState() => _MomentPhotoDesignViewState();
}

class _MomentPhotoDesignViewState extends State<MomentPhotoDesignView> {
  // Weak keys keep a draft's bounded preview reusable across its tiles without
  // retaining the selected original after that draft has been released.
  static final _localPreviews = Expando<Map<int, Future<BrowserPhotoAsset>>>(
    'moment-photo-previews',
  );
  late Future<BrowserPhotoAsset?> _ready;
  late final LayerInteractionManager _interaction;
  List<LayerModel>? _layers;
  BrowserPhotoAsset? _layerAsset;
  late LayerBuilder _builder;

  int get _decodeWidth => widget.imageDecodeWidth.clamp(64, 1600).toInt();

  @override
  void initState() {
    super.initState();
    _interaction = LayerInteractionManager.printPreview(
      () => widget.design.canvasSize,
    );
    _builder = _newBuilder();
    _ready = _prepare();
  }

  LayerBuilder _newBuilder() => LayerBuilder(
    _interaction,
    () => widget.design.canvasSize,
    previewImageDecodeWidth: _decodeWidth,
  );

  Future<BrowserPhotoAsset?> _prepare() {
    Future<BrowserPhotoAsset?> photo() {
      final bytes = widget.bytes;
      if (bytes == null) return SynchronousFuture(null);
      final previews = _localPreviews[bytes] ??= {};
      // Reuse a small set of resolutions as tiles move between responsive sizes.
      final edge = switch (_decodeWidth) {
        <= 256 => 256,
        <= 512 => 512,
        <= 1024 => 1024,
        _ => 1600,
      };
      final existing = previews[edge];
      if (existing != null) return existing;
      final pending = prepareMomentEditorPhoto(bytes, id: 'view', maxEdge: edge)
          .then<BrowserPhotoAsset>(
            (asset) => asset,
            onError: (Object error, StackTrace stack) {
              previews.remove(edge);
              Error.throwWithStackTrace(error, stack);
            },
          );
      previews[edge] = pending;
      return pending;
    }

    final families = widget.design.fontFamilies;
    if (DocumentFonts.areReady(families)) return photo();
    return DocumentFonts.ensure(families).then((_) => photo());
  }

  @override
  void didUpdateWidget(covariant MomentPhotoDesignView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.bytes, oldWidget.bytes) ||
        !identical(widget.design, oldWidget.design) ||
        widget.imageDecodeWidth != oldWidget.imageDecodeWidth) {
      _ready = _prepare();
    }
    if (!identical(widget.design, oldWidget.design) ||
        widget.photoSource != oldWidget.photoSource ||
        !identical(widget.bytes, oldWidget.bytes)) {
      _layers = null;
    }
    if (widget.imageDecodeWidth != oldWidget.imageDecodeWidth) {
      _builder = _newBuilder();
    }
  }

  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.design.aspectRatio,
    child: FutureBuilder<BrowserPhotoAsset?>(
      future: _ready,
      builder: (context, result) {
        if (result.connectionState != ConnectionState.done) {
          return widget.placeholder ??
              const Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        }
        if (result.hasError) {
          return widget.error ??
              Semantics(
                label: '꾸민 사진을 불러오지 못했어요.',
                child: Center(
                  child: IconButton(
                    tooltip: '꾸민 사진 다시 불러오기',
                    onPressed: () => setState(() => _ready = _prepare()),
                    icon: const ExperienceIcon('RefreshCw'),
                  ),
                ),
              );
        }
        if (_layers == null || !identical(_layerAsset, result.data)) {
          _layerAsset = result.data;
          _layers = momentDesignLayersWithPhoto(
            widget.design.layersForPhoto(widget.photoSource),
            widget.photoSource,
            result.data,
          );
        }
        return LayoutBuilder(
          builder: (context, bounds) => ClipRect(
            child: FittedBox(
              fit: widget.fit,
              // The slot can have another aspect (calendar/home). Clip at the
              // saved artboard too, so hidden overflow never enters its margins.
              child: ClipRect(
                child: AlbumReaderPageContent(
                  layers: _layers!,
                  targetW: widget.design.canvasSize.width,
                  targetH: widget.design.canvasSize.height,
                  previewBuilder: _builder,
                  baseCanvasSize: widget.design.canvasSize,
                  backgroundColor: widget.design.backgroundColor,
                  flatPresentation: true,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
