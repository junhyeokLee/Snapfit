import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_photo_frame_catalog.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../../core/utils/storage_url_resolver.dart';
import '../domain/entities/layer.dart';
import '../presentation/controllers/layer_builder.dart';
import '../presentation/controllers/layer_interaction_manager.dart';
import 'print_album_document.dart';
import 'print_image_header.dart';
import 'print_vendor_spec.dart';
import 'raster_print_pdf.dart';
export 'print_vendor_spec.dart';

typedef PrintAssetLoader = Future<Uint8List> Function(String source);

class PrintPreflightException implements Exception {
  const PrintPreflightException(this.code, this.details);
  final String code;
  final List<String> details;
  @override
  String toString() => '$code: ${details.join(', ')}';
}

class AlbumPrintExport {
  const AlbumPrintExport({
    required this.coverPdf,
    required this.interiorPdf,
    required this.report,
    required this.interiorPageCount,
  });
  final Uint8List coverPdf, interiorPdf;
  final Map<String, dynamic> report;
  final int interiorPageCount;
}

/// Builds actual artwork PDFs from the immutable paid order snapshot.
/// Every original and font is ready before a page is painted. No thumbnail or
/// asynchronous placeholder is allowed to enter the output.
class AlbumPrintExporter {
  AlbumPrintExporter({
    PrintAssetLoader? assetLoader,
    this.fontFamilyPrefix = '',
    this.loadOnlyUsedFonts = false,
  }) : _load = assetLoader ?? _loadSource;
  final PrintAssetLoader _load;

  /// Dependency packages namespace manifest families. Register their original
  /// editor names for identical artwork without duplicating bundled fonts.
  final String fontFamilyPrefix;
  final bool loadOnlyUsedFonts;
  static final Map<String, Future<Set<String>>> _fonts = {};

  /// Lightweight pre-payment verification: same originals, fonts and effective
  /// resolution checks as export, without encoding PDFs or creating an order.
  Future<Map<String, dynamic>> verify({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int completed, int total)? onProgress,
  }) async {
    final document = PrintAlbumDocument.fromSnapshot(snapshot);
    document.validateSpec(spec);
    if (document.interiors.length > spec.pageCount) {
      throw const PrintPreflightException('print_paid_page_count_exceeded', []);
    }
    final fonts = await _fontsFor(document);
    final warnings = <String>[];
    final resolution = <Map<String, dynamic>>[];
    var completed = 0;
    for (final page in document.pages) {
      final images = <String, ui.Image>{};
      try {
        await _preparePage(
          page,
          page.isCover
              ? spec.front.size
              : Size(spec.trimWidthMm, spec.trimHeightMm),
          spec,
          images,
          fonts,
          warnings,
          resolution,
          sourceUrls,
        );
      } finally {
        for (final image in images.values.toSet()) {
          image.dispose();
        }
      }
      onProgress?.call(++completed, document.pages.length);
    }
    return {
      'missingAssets': <String>[],
      'warnings': warnings,
      'imageResolution': resolution,
      'pageCount': spec.pageCount,
      'sourceInteriorPages': document.interiors.length,
      'blankPagesAdded': spec.pageCount - document.interiors.length,
      'specVersion': spec.specVersion,
    };
  }

  Future<AlbumPrintExport> generate({
    required Map<String, dynamic> snapshot,
    required PrintVendorSpec spec,
    Map<String, String> sourceUrls = const {},
    void Function(int completed, int total)? onProgress,
  }) async {
    final document = PrintAlbumDocument.fromSnapshot(snapshot);
    document.validateSpec(spec);
    if (document.interiors.length > spec.pageCount) {
      throw const PrintPreflightException('print_paid_page_count_exceeded', []);
    }
    final fonts = await _fontsFor(document);
    final warnings = <String>[
      if (!spec.verified) 'vendor_spec_requires_review',
      'vendor_color_sample_required',
      'back_cover_uses_front_background',
      'bleed_uses_edge_extension',
    ];
    final resolution = <Map<String, dynamic>>[];
    final coverPdf = RasterPrintPdf(), interiorPdf = RasterPrintPdf();
    final padding = spec.pageCount - document.interiors.length;
    if (padding > 0) warnings.add('blank_interior_pages_added:$padding');
    final outputPages = [document.cover, ...document.interiors];
    var completed = 0;
    final total = 1 + spec.pageCount;
    for (final page in outputPages) {
      final target = page.isCover
          ? spec.front.size
          : Size(spec.trimWidthMm, spec.trimHeightMm);
      if ((page.canvasSize.aspectRatio - target.aspectRatio).abs() > .001) {
        warnings.add('page_${page.index}_fit_contain_with_margins');
      }
      final decoded = <String, ui.Image>{};
      try {
        final layers = await _preparePage(
          page,
          target,
          spec,
          decoded,
          fonts,
          warnings,
          resolution,
          sourceUrls,
        );
        final art = await renderPrintWidget(
          ProviderScope(
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.noScaling),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: 'NotoSans',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  child: ColoredBox(
                    color: page.backgroundColor,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox.fromSize(
                        size: page.canvasSize,
                        child: PrintAlbumPageCanvas(
                          page: page,
                          layers: layers,
                          images: decoded,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          target,
          spec.dpi / 25.4,
        );
        try {
          final media = page.isCover ? spec.coverSize : spec.interiorSize;
          final trim = page.isCover ? spec.front : spec.interiorTrim;
          final surface = await _placeArtwork(
            art,
            media,
            trim,
            page.backgroundColor,
            spec.dpi,
            page.isCover ? spec.coverBleedMm : spec.bleedMm,
            outerTrim: page.isCover ? spec.coverTrim : null,
          );
          try {
            await (page.isCover ? coverPdf : interiorPdf).addPage(
              surface,
              sizeMm: media,
              trimMm: page.isCover ? spec.coverTrim : trim,
            );
          } finally {
            surface.dispose();
          }
        } finally {
          art.dispose();
        }
      } finally {
        for (final image in decoded.values.toSet()) {
          image.dispose();
        }
      }
      onProgress?.call(++completed, total);
    }
    for (int index = 0; index < padding; index++) {
      if (index > 0) {
        interiorPdf.repeatLastPage();
        onProgress?.call(++completed, total);
        continue;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final width = (spec.interiorSize.width * spec.dpi / 25.4).ceil();
      final height = (spec.interiorSize.height * spec.dpi / 25.4).ceil();
      canvas.drawColor(Colors.white, BlendMode.src);
      final picture = recorder.endRecording();
      final blank = await picture.toImage(width, height);
      picture.dispose();
      try {
        await interiorPdf.addPage(
          blank,
          sizeMm: spec.interiorSize,
          trimMm: spec.interiorTrim,
        );
      } finally {
        blank.dispose();
      }
      onProgress?.call(++completed, total);
    }
    return AlbumPrintExport(
      coverPdf: coverPdf.save(),
      interiorPdf: interiorPdf.save(),
      interiorPageCount: interiorPdf.pageCount,
      report: {
        'renderer': 'flutter-layer-builder-raster-v1',
        'specVersion': spec.specVersion,
        'productId': spec.id,
        'coverType': spec.isHardcover ? 'HARD' : 'SOFT',
        'trimMm': [spec.trimWidthMm, spec.trimHeightMm],
        'pageCount': spec.pageCount,
        'sourceInteriorPages': document.interiors.length,
        'blankPagesAdded': padding,
        'missingAssets': <String>[],
        'warnings': warnings.toSet().toList(),
        'imageResolution': resolution,
        'dpi': spec.dpi,
        'colorSpace': 'sRGB',
        'iccProfileEmbedded': true,
        'imageEncoding': 'JPEG quality 95',
        'pdfStandard': 'PDF-1.4',
        'fit': 'contain',
        'specVerified': spec.verified,
        'interiorMediaMm': [spec.interiorSize.width, spec.interiorSize.height],
        'coverMediaMm': [spec.coverSize.width, spec.coverSize.height],
      },
    );
  }

  Future<List<LayerModel>> _preparePage(
    PrintAlbumPage page,
    Size target,
    PrintVendorSpec spec,
    Map<String, ui.Image> images,
    Set<String> fonts,
    List<String> warnings,
    List<Map<String, dynamic>> resolution,
    Map<String, String> sourceUrls,
  ) async {
    final result = <LayerModel>[];
    final requests = <String, List<({LayerModel layer, bool contain})>>{};
    void request(LayerModel layer, String source, {required bool contain}) {
      (requests[source] ??= []).add((layer: layer, contain: contain));
    }

    final physicalScale = math.min(
      target.width / page.canvasSize.width,
      target.height / page.canvasSize.height,
    );
    for (final layer in page.layers) {
      if (layer.type == LayerType.text) {
        final family = layer.textStyle?.fontFamily;
        if (family != null && family.isNotEmpty && !fonts.contains(family)) {
          throw PrintPreflightException('print_font_unavailable', [family]);
        }
        var raw = (layer.textFillImageUrl ?? '').trim();
        if ((layer.textFillMode ?? '').toLowerCase() == 'imageclip') {
          if (raw.startsWith('@')) {
            final key = raw.substring(1).toLowerCase();
            final photos = page.layers
                .where((p) => p.type == LayerType.image)
                .toList();
            final linked =
                photos
                    .where((p) => p.id.toLowerCase().contains(key))
                    .firstOrNull ??
                photos.firstOrNull;
            if (linked == null)
              throw PrintPreflightException('print_text_image_missing', [
                layer.id,
              ]);
            raw = printOriginalSource(linked);
          }
          if (raw.isEmpty)
            throw PrintPreflightException('print_text_image_missing', [
              layer.id,
            ]);
          request(layer, raw, contain: false);
          result.add(layer.copyWith(textFillImageUrl: raw));
        } else {
          result.add(layer);
        }
        continue;
      }
      if (layer.type == LayerType.decoration) {
        final deco = studioDecorationById(layer.imageBackground);
        final path =
            deco?.assetPath ??
            (deco?.id == 'studioBotanicalStamp'
                ? 'assets/sticker/studio/pressed_cosmos.png'
                : null);
        if (path != null) {
          request(layer, 'asset:$path', contain: true);
        }
        result.add(layer);
        continue;
      }
      final source = printOriginalSource(layer);
      final frameAsset = keepsakeFrameAssets[layer.imageBackground];
      if (frameAsset != null)
        request(layer, 'asset:$frameAsset', contain: true);
      request(
        layer,
        source,
        contain:
            layer.imageBackground != 'rasterCover' &&
            (layer.type == LayerType.sticker ||
                source.startsWith('asset:assets/sticker/')),
      );
      result.add(
        layer.copyWith(
          originalUrl: source,
          imageUrl: source,
          previewUrl: source,
        ),
      );
    }
    var decodedPixels = 0;
    for (final entry in requests.entries) {
      final source = entry.key;
      ui.ImmutableBuffer? buffer;
      ui.ImageDescriptor? descriptor;
      try {
        final bytes = await _load(
          sourceUrls[source] ?? source,
        ).timeout(const Duration(seconds: 45));
        if (bytes.length > 60 * 1024 * 1024) {
          throw PrintPreflightException('print_image_memory_limit', [source]);
        }
        buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        descriptor = await ui.ImageDescriptor.encoded(buffer);
        final originalSize = kIsWeb
            ? printEncodedImageSize(bytes)
            : Size(descriptor.width.toDouble(), descriptor.height.toDouble());
        var factor = 0.0;
        for (final request in entry.value) {
          // Check original dimensions, never the smaller decode or a thumbnail.
          _checkResolution(
            request.layer,
            originalSize,
            physicalScale,
            spec,
            page.index,
            warnings,
            resolution,
            contain: request.contain,
          );
          final widthPx =
              request.layer.width *
              request.layer.scale *
              physicalScale *
              spec.dpi /
              25.4;
          final heightPx =
              request.layer.height *
              request.layer.scale *
              physicalScale *
              spec.dpi /
              25.4;
          final x = widthPx / originalSize.width,
              y = heightPx / originalSize.height;
          factor = math.max(
            factor,
            request.contain ? math.min(x, y) : math.max(x, y),
          );
        }
        factor = factor.clamp(
          0.0,
          1.0,
        ); // Downsample originals only; never upscale.
        final width = math.max(1, (originalSize.width * factor).ceil());
        final height = math.max(1, (originalSize.height * factor).ceil());
        decodedPixels += width * height;
        if (width > 16384 || height > 16384 || decodedPixels > 40000000) {
          throw PrintPreflightException('print_image_memory_limit', [
            'page:${page.index}',
            source,
          ]);
        }
        final codec = await descriptor.instantiateCodec(
          targetWidth: width,
          targetHeight: height,
        );
        try {
          images[source] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        for (final row in resolution.where(
          (row) =>
              row['page'] == page.index &&
              entry.value.any((request) => request.layer.id == row['layerId']),
        )) {
          row['decodedWidthPx'] = images[source]!.width;
          row['decodedHeightPx'] = images[source]!.height;
        }
      } on PrintPreflightException {
        rethrow;
      } catch (_) {
        throw PrintPreflightException('print_original_load_failed', [source]);
      } finally {
        descriptor?.dispose();
        buffer?.dispose();
      }
    }
    return result;
  }

  static void _checkResolution(
    LayerModel layer,
    Size image,
    double scale,
    PrintVendorSpec spec,
    int page,
    List<String> warnings,
    List<Map<String, dynamic>> records, {
    required bool contain,
  }) {
    final w = layer.width * layer.scale * scale;
    final h = layer.height * layer.scale * scale;
    final ratios = [image.width / w, image.height / h];
    final ppi =
        (contain
            ? math.max(ratios[0], ratios[1])
            : math.min(ratios[0], ratios[1])) *
        25.4;
    records.add({
      'page': page,
      'layerId': layer.id,
      'widthPx': image.width.toInt(),
      'heightPx': image.height.toInt(),
      'effectivePpi': double.parse(ppi.toStringAsFixed(1)),
    });
    if (ppi + .1 < spec.minimumPhotoPpi) {
      throw PrintPreflightException('print_image_resolution_too_low', [
        'page:$page',
        'layer:${layer.id}',
        '${ppi.toStringAsFixed(0)}ppi',
      ]);
    }
    if (ppi + .1 < spec.dpi)
      warnings.add('page_${page}_${layer.id}_below_${spec.dpi}ppi');
  }

  static Future<Uint8List> _loadSource(String source) async {
    final asset = source.startsWith('asset:')
        ? source.substring(6)
        : bundledTemplateAssetPath(source);
    if (asset != null)
      return (await rootBundle.load(asset)).buffer.asUint8List();
    final url = await resolveStorageImageUrl(source);
    if (Uri.tryParse(url)?.scheme != 'https') {
      throw const FormatException('print_source_must_be_https_or_bundled');
    }
    final response = await Dio().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data!);
  }

  Future<Set<String>> _fontsFor(PrintAlbumDocument document) {
    final used = <String>{
      'NotoSans',
      for (final page in document.pages)
        for (final layer in page.layers)
          if (layer.textStyle?.fontFamily case final String name) name,
    };
    final sorted = used.toList()..sort();
    final key =
        '$fontFamilyPrefix:${loadOnlyUsedFonts ? jsonEncode(sorted) : '*'}';
    return _fonts[key] ??= _loadFonts(
      fontFamilyPrefix,
      loadOnlyUsedFonts ? used : null,
    );
  }

  static Future<Set<String>> _loadFonts(
    String prefix,
    Set<String>? used,
  ) async {
    final entries =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    final families = <String>{};
    for (final entry in entries.cast<Map>()) {
      final manifestName = entry['family'] as String;
      if (!manifestName.startsWith(prefix)) continue;
      final name = manifestName.substring(prefix.length);
      if (used != null && !used.contains(name)) continue;
      final loader = FontLoader(name);
      var valid = true;
      for (final font in entry['fonts'] as List) {
        final data = await rootBundle.load(font['asset'] as String);
        if (!printFontHeaderIsValid(data)) {
          valid = false;
          break;
        }
        loader.addFont(Future.value(data));
      }
      // Empty or invalid assets must never silently use a fallback font in PDF.
      // Unused invalid families do not prevent printing another album.
      if (!valid) continue;
      await loader.load();
      families.add(name);
    }
    return families;
  }
}

/// Legacy preview-only URLs are intentionally rejected. Bundled source artwork
/// is valid even when old templates stored it in imageUrl rather than originalUrl.
String printOriginalSource(LayerModel layer) {
  final original = layer.originalUrl?.trim();
  if (original != null && original.isNotEmpty) return original;
  for (final value in [layer.imageUrl, layer.previewUrl]) {
    if (value != null &&
        (value.startsWith('asset:') ||
            bundledTemplateAssetPath(value) != null)) {
      return value;
    }
  }
  throw PrintPreflightException('print_original_missing', [layer.id]);
}

/// The preview and PDF share the editor's exact fonts, scale, crop and frames.
/// Pass decoded originals for export; null uses normal interactive image loading.
class PrintAlbumPageCanvas extends ConsumerWidget {
  const PrintAlbumPageCanvas({
    super.key,
    required this.page,
    this.layers,
    this.images,
  });
  final PrintAlbumPage page;
  final List<LayerModel>? layers;
  final Map<String, ui.Image>? images;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final builder = LayerBuilder(
      LayerInteractionManager.preview(ref, () => page.canvasSize),
      () => page.canvasSize,
      printImages: images,
    );
    final sourceLayers = layers ?? page.layers;
    final localLayers = sourceLayers.map((layer) {
      final raw = layer.textFillImageUrl ?? '';
      if (!raw.startsWith('@')) return layer;
      final photos = sourceLayers
          .where((p) => p.type == LayerType.image)
          .toList();
      final key = raw.substring(1).toLowerCase();
      final linked =
          photos.where((p) => p.id.toLowerCase().contains(key)).firstOrNull ??
          photos.firstOrNull;
      return layer.copyWith(
        textFillImageUrl:
            linked?.originalUrl ?? linked?.previewUrl ?? linked?.imageUrl ?? '',
      );
    });
    return MediaQuery.withNoTextScaling(
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 14,
          color: Colors.black,
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (page.backgroundGradient != null)
              Positioned(
                left: -14,
                top: 0,
                width: 500,
                height: page.canvasSize.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: page.backgroundGradient),
                ),
              ),
            for (final layer in localLayers)
              layer.type == LayerType.text
                  ? builder.buildText(layer)
                  : builder.buildImage(layer),
          ],
        ),
      ),
    );
  }
}

/// A separate render tree avoids viewport limits and UI screenshots. All child
/// resources are synchronous and predecoded, so no arbitrary capture delay exists.
Future<ui.Image> renderPrintWidget(
  Widget child,
  Size size,
  double pixelRatio,
) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  final focus = FocusManager();
  final owner = BuildOwner(focusManager: focus);
  renderView.prepareInitialFrame();
  RenderObjectToWidgetElement<RenderBox>? element;
  try {
    // Flutter normally substitutes an ErrorWidget after rendering failures.
    // A print export must fail instead of quietly printing that replacement.
    FlutterErrorDetails? renderingError;
    final previousErrorHandler = FlutterError.onError;
    try {
      FlutterError.onError = (details) {
        renderingError ??= details;
      };
      element = RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
        child: SizedBox.fromSize(size: size, child: child),
      ).attachToRenderTree(owner);
      owner.buildScope(element);
      owner.finalizeTree();
      pipeline.flushLayout();
      pipeline.flushCompositingBits();
      pipeline.flushPaint();
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
    if (renderingError != null) {
      throw PrintPreflightException('print_render_failed', [
        renderingError!.exceptionAsString(),
      ]);
    }
    return await boundary.toImage(pixelRatio: pixelRatio);
  } finally {
    if (element != null) {
      RenderObjectToWidgetAdapter<RenderBox>(
        container: boundary,
      ).attachToRenderTree(owner, element);
      owner.buildScope(element!);
      owner.finalizeTree();
    }
    pipeline.rootNode = null;
    renderView.dispose();
    pipeline.dispose();
    focus.dispose();
  }
}

Future<ui.Image> _placeArtwork(
  ui.Image art,
  Size media,
  Rect trim,
  Color background,
  int dpi,
  double bleedMm, {
  Rect? outerTrim,
}) async {
  final ratio = dpi / 25.4;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(background, BlendMode.src);
  final dest = Rect.fromLTWH(
    trim.left * ratio,
    trim.top * ratio,
    trim.width * ratio,
    trim.height * ratio,
  );
  final src = Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble());
  final paint = Paint()..filterQuality = FilterQuality.high;
  // Extend only the finished trim edge into bleed; never crop or enlarge design.
  final b = bleedMm * ratio;
  // The front/spine join is not a cut edge: keep the intended blank spine.
  final leftBleed =
      outerTrim == null || (trim.left - outerTrim.left).abs() < .001 ? b : 0.0;
  final rightBleed =
      outerTrim == null || (trim.right - outerTrim.right).abs() < .001
      ? b
      : 0.0;
  canvas.drawImageRect(
    art,
    Rect.fromLTWH(0, 0, 1, art.height.toDouble()),
    Rect.fromLTWH(dest.left - leftBleed, dest.top, leftBleed, dest.height),
    paint,
  );
  canvas.drawImageRect(
    art,
    Rect.fromLTWH(art.width - 1.0, 0, 1, art.height.toDouble()),
    Rect.fromLTWH(dest.right, dest.top, rightBleed, dest.height),
    paint,
  );
  canvas.drawImageRect(
    art,
    Rect.fromLTWH(0, 0, art.width.toDouble(), 1),
    Rect.fromLTWH(dest.left, dest.top - b, dest.width, b),
    paint,
  );
  canvas.drawImageRect(
    art,
    Rect.fromLTWH(0, art.height - 1.0, art.width.toDouble(), 1),
    Rect.fromLTWH(dest.left, dest.bottom, dest.width, b),
    paint,
  );
  for (final dx in [0, 1]) {
    for (final dy in [0, 1]) {
      canvas.drawImageRect(
        art,
        Rect.fromLTWH(
          dx == 0 ? 0 : art.width - 1.0,
          dy == 0 ? 0 : art.height - 1.0,
          1,
          1,
        ),
        Rect.fromLTWH(
          dx == 0 ? dest.left - leftBleed : dest.right,
          dy == 0 ? dest.top - b : dest.bottom,
          dx == 0 ? leftBleed : rightBleed,
          b,
        ),
        paint,
      );
    }
  }
  canvas.drawImageRect(art, src, dest, paint);
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(
      (media.width * ratio).ceil(),
      (media.height * ratio).ceil(),
    );
  } finally {
    picture.dispose();
  }
}

/// Detect empty/placeholder font assets before Flutter can silently fall back.
bool printFontHeaderIsValid(ByteData data) {
  if (data.lengthInBytes < 12) return false;
  final signature = data.getUint32(0);
  return const {
    0x00010000, // TrueType sfnt.
    0x4f54544f, // OpenType CFF (OTTO).
    0x74746366, // TrueType collection (ttcf).
    0x74727565, // Apple TrueType (true).
    0x774f4646, // WOFF.
    0x774f4632, // WOFF2.
  }.contains(signature);
}
