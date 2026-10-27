import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/templates/studio_decoration_catalog.dart';
import '../../../core/templates/studio_photo_frame_catalog.dart';
import '../../../core/utils/image_url_policy.dart';
import '../../../core/utils/storage_url_resolver.dart';
import '../../album/domain/entities/album.dart';
import '../../album/domain/entities/layer.dart';
import '../../album/printing/album_print_exporter.dart';
import '../../album/printing/print_album_document.dart';
import '../../album/printing/print_image_header.dart';
import '../../album/presentation/controllers/layer_builder.dart';
import '../../album/presentation/controllers/layer_interaction_manager.dart';

/// A local read-only rendering source. Only renderPage's PNG crosses the
/// publication boundary, never this document, private URLs or unselected pages.
class SocialAlbumSnapshot {
  SocialAlbumSnapshot._(this.pages);
  final List<PrintAlbumPage> pages;

  factory SocialAlbumSnapshot.fromAlbum(Album album) {
    final raw = jsonDecode(album.coverLayersJson);
    if (raw is! Map) throw const FormatException('저장된 앨범 내용을 확인할 수 없어요.');
    final document = Map<String, dynamic>.from(raw);
    final sourcePages = document['pages'];
    final List<dynamic> entries;
    if (sourcePages is List && sourcePages.isNotEmpty) {
      entries = sourcePages;
    } else if (document['layers'] is List) {
      // Legacy covers can be published on their own. Never invent empty
      // interior pages when the saved document does not contain their content.
      entries = [document];
    } else {
      throw const FormatException('공개할 저장 페이지가 없어요. 앨범을 저장한 뒤 다시 시도해 주세요.');
    }
    document['pages'] = [
      for (final entry in entries.indexed) _normalizedPage(entry.$2, entry.$1),
    ];
    final parsed = PrintAlbumDocument.fromSnapshot({
      'album': {
        'ratio': album.ratio.isEmpty ? '1:1' : album.ratio,
        'cover_theme': album.coverTheme ?? 'classic',
        'cover_layers_json': document,
      },
    });
    return SocialAlbumSnapshot._(List.unmodifiable(parsed.pages));
  }

  static Map<String, dynamic> _normalizedPage(dynamic raw, int index) {
    if (raw is! Map || raw['layers'] is! List) {
      throw const FormatException('저장 페이지의 내용을 확인할 수 없어요.');
    }
    // Selection IDs are array positions, independent from legacy index gaps.
    return {
      ...Map<String, dynamic>.from(raw),
      'index': index,
      'isCover': index == 0,
      'layers': [
        for (final value in raw['layers'] as List)
          if (value is Map)
            {
              ...Map<String, dynamic>.from(value),
              'rotation': value['rotation'] ?? 0,
            }
          else
            throw const FormatException('페이지의 구성 요소를 확인할 수 없어요.'),
      ],
    };
  }
}

typedef SocialSnapshotLoader = Future<Uint8List> Function(String source);

class SocialSnapshotRenderer {
  SocialSnapshotRenderer({SocialSnapshotLoader? loader})
    : _loader = loader ?? _load;
  final SocialSnapshotLoader _loader;
  static final _fonts = <String, Future<void>>{};

  /// Explicitly load the artwork's saved families before starting the separate
  /// render tree. First-time publication must not capture fallback glyphs.
  Future<void> prepareFonts(Iterable<PrintAlbumPage> pages) async {
    final used = <String>{
      'NotoSans',
      for (final page in pages)
        for (final layer in page.layers)
          if (layer.textStyle?.fontFamily case final String family) family,
    };
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final family in used) {
      final entry = manifest
          .cast<Map>()
          .where((item) => item['family'] == family)
          .firstOrNull;
      if (entry == null)
        throw const FormatException(
          '공개할 페이지의 글꼴을 확인할 수 없어요. 앨범에서 글꼴을 다시 선택해 주세요.',
        );
      Future<void> load() async {
        final loader = FontLoader(family);
        for (final font in entry['fonts'] as List) {
          final bytes = await rootBundle.load((font as Map)['asset'] as String);
          if (!printFontHeaderIsValid(bytes))
            throw const FormatException('글꼴을 불러오지 못했어요. 잠시 후 다시 시도해 주세요.');
          loader.addFont(Future.value(bytes));
        }
        await loader.load();
      }

      try {
        await (_fonts[family] ??= load());
      } catch (_) {
        _fonts.remove(family);
        rethrow;
      }
    }
  }

  static Future<Uint8List> _load(String source) async {
    final asset = source.startsWith('asset:')
        ? source.substring(6)
        : bundledTemplateAssetPath(source);
    if (asset != null)
      return (await rootBundle.load(asset)).buffer.asUint8List();
    final url = await resolveStorageImageUrl(source);
    if (Uri.tryParse(url)?.scheme != 'https')
      throw const FormatException('사진 주소를 확인해 주세요.');
    final response = await Dio()
        .get<List<int>>(url, options: Options(responseType: ResponseType.bytes))
        .timeout(const Duration(seconds: 30));
    return Uint8List.fromList(response.data!);
  }

  /// Sequential rendering bounds native/Web memory and strips source metadata.
  Future<Uint8List> renderPage(
    PrintAlbumPage page, {
    required ThemeData theme,
  }) async {
    final images = <String, ui.Image>{};
    final layers = <LayerModel>[];
    var pixels = 0;
    Future<void> prepare(String source) async {
      if (images.containsKey(source)) return;
      final bytes = await _loader(source).timeout(const Duration(seconds: 30));
      if (bytes.isEmpty || bytes.length > 40 * 1024 * 1024) {
        throw const FormatException('사진을 불러올 수 없어요. 다른 페이지를 선택하거나 다시 시도해 주세요.');
      }
      // Web decodes an original frame before the size callback. Check encoded
      // dimensions first so a small compressed file cannot allocate huge pixels.
      final Size originalSize;
      try {
        originalSize = printEncodedImageSize(bytes);
      } catch (_) {
        throw const FormatException('사진을 읽지 못했어요. 다른 사진이 있는 페이지를 선택해 주세요.');
      }
      if (originalSize.width * originalSize.height > 40000000) {
        throw const FormatException('사진 크기가 너무 커요. 더 작은 사진이 있는 페이지를 선택해 주세요.');
      }
      ui.Codec? codec;
      try {
        // This API owns its input buffer on native and web. Its callback uses
        // decoded dimensions, including any camera orientation adjustment.
        codec = await ui.instantiateImageCodecWithSize(
          await ui.ImmutableBuffer.fromUint8List(bytes),
          getTargetSize: (width, height) {
            if (width <= 0 || height <= 0 || width * height > 40000000) {
              throw const FormatException('사진 크기를 확인할 수 없어요. 다른 페이지를 선택해 주세요.');
            }
            final scale = math.min(1.0, 2048 / math.max(width, height));
            final targetWidth = math.max(1, (width * scale).round());
            final targetHeight = math.max(1, (height * scale).round());
            if (pixels + targetWidth * targetHeight > 20000000) {
              throw const FormatException(
                '이 페이지에 사진이 너무 많아요. 다른 페이지를 선택해 주세요.',
              );
            }
            return ui.TargetImageSize(width: targetWidth, height: targetHeight);
          },
        );
        final image = (await codec.getNextFrame()).image;
        if (pixels + image.width * image.height > 20000000) {
          image.dispose();
          throw const FormatException('이 페이지에 사진이 너무 많아요. 다른 페이지를 선택해 주세요.');
        }
        pixels += image.width * image.height;
        images[source] = image;
      } finally {
        codec?.dispose();
      }
    }

    String sourceOf(LayerModel layer) {
      for (final value in [
        layer.originalUrl,
        layer.previewUrl,
        layer.imageUrl,
      ]) {
        if (value != null && value.trim().isNotEmpty) return value.trim();
      }
      throw const FormatException(
        '사진이 준비되지 않은 페이지가 있어요. 앨범을 다시 저장하거나 다른 페이지를 선택해 주세요.',
      );
    }

    try {
      for (final original in page.layers) {
        if (original.opacity <= 0) continue;
        var layer = original;
        if (layer.type == LayerType.decoration) {
          final deco = studioDecorationById(layer.imageBackground);
          final path =
              deco?.assetPath ??
              (deco?.id == 'studioBotanicalStamp'
                  ? 'assets/sticker/studio/pressed_cosmos.png'
                  : null);
          if (path != null) await prepare('asset:$path');
        } else if (layer.type == LayerType.text) {
          if ((layer.textFillMode ?? '').toLowerCase() == 'imageclip') {
            var source = (layer.textFillImageUrl ?? '').trim();
            if (source.startsWith('@')) {
              final key = source.substring(1).toLowerCase();
              final photos = page.layers.where(
                (p) => p.type == LayerType.image,
              );
              final linked =
                  photos
                      .where((p) => p.id.toLowerCase().contains(key))
                      .firstOrNull ??
                  photos.firstOrNull;
              if (linked == null)
                throw const FormatException('글자에 적용한 사진을 확인해 주세요.');
              source = sourceOf(linked);
            }
            if (source.isEmpty)
              throw const FormatException('글자에 적용한 사진을 확인해 주세요.');
            await prepare(source);
            layer = layer.copyWith(textFillImageUrl: source);
          }
        } else {
          final source = sourceOf(layer);
          await prepare(source);
          final frame = keepsakeFrameAssets[layer.imageBackground];
          if (frame != null) await prepare('asset:$frame');
          layer = layer.copyWith(
            originalUrl: source,
            imageUrl: source,
            previewUrl: source,
          );
        }
        layers.add(layer);
      }
      final image = await renderPrintWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: page.canvasSize),
            child: Theme(
              data: theme,
              child: ColoredBox(
                color: page.backgroundColor,
                child: PrintAlbumPageCanvas(
                  page: page,
                  layers: layers,
                  images: images,
                ),
              ),
            ),
          ),
        ),
        page.canvasSize,
        1440 / math.max(page.canvasSize.width, page.canvasSize.height),
      );
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null || bytes.lengthInBytes > 8 * 1024 * 1024) {
          throw const FormatException('공개 이미지를 준비하지 못했어요. 다른 페이지로 다시 시도해 주세요.');
        }
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      for (final image in images.values.toSet()) {
        image.dispose();
      }
    }
  }
}

class SocialPublicationPagePreview extends StatelessWidget {
  const SocialPublicationPagePreview({super.key, required this.page});
  final PrintAlbumPage page;
  @override
  Widget build(BuildContext context) {
    final builder = LayerBuilder(
      LayerInteractionManager.printPreview(() => page.canvasSize),
      () => page.canvasSize,
      previewImageDecodeWidth: 500,
    );
    return AspectRatio(
      aspectRatio: page.canvasSize.aspectRatio,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox.fromSize(
          size: page.canvasSize,
          child: ColoredBox(
            color: page.backgroundColor,
            child: ClipRect(
              child: Stack(
                children: [
                  if (page.backgroundGradient != null)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: page.backgroundGradient,
                        ),
                      ),
                    ),
                  for (final layer in page.layers)
                    layer.type == LayerType.text
                        ? builder.buildText(layer)
                        : builder.buildImage(layer),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
