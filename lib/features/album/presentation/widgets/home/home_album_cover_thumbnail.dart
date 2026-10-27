import 'dart:collection';

import 'package:flutter/foundation.dart' show compute, SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/cover_theme.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../core/cache/snapfit_cache_manager.dart';
import '../../../../../core/cache/memory_pressure_caches.dart';
import '../../../domain/entities/album.dart';
import '../../../domain/entities/layer.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../utils/cover_background_color.dart';
import '../../utils/home_cover_document.dart';
import '../../utils/album_document_worker.dart';
import '../cover/cover.dart';
import '../cover/album_spine_image.dart';
import 'home_cover_frame.dart';
import 'home_album_helpers.dart';

/// Share only immutable cover data, never widgets, refs or interaction state.
class _ParsedHomeCover {
  static const _maxEntries = 24;
  static const _maxSourceCharacters = 2 * 1024 * 1024;
  static const _asyncDecodeThreshold = 32 * 1024;
  static final _cache = <(String, Size), _ParsedHomeCover>{};
  static int _sourceCharacters = 0;
  static int _cacheEpoch = 0;

  final List<LayerModel>? layers;
  final Color? backgroundColor;

  const _ParsedHomeCover(this.layers, this.backgroundColor);

  static void clearCache() {
    _cache.clear();
    _sourceCharacters = 0;
    _cacheEpoch++;
  }

  static Future<_ParsedHomeCover?> resolve(
    String source,
    Size canvasSize, {
    required bool Function() isCurrent,
  }) {
    MemoryPressureCaches.register('home-cover-data', clearCache);
    final key = (source, canvasSize);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return SynchronousFuture(cached);
    }
    final epoch = _cacheEpoch;
    _ParsedHomeCover? finish(Map<String, dynamic>? document) {
      // A hidden, disposed or edited thumbnail no longer needs native layers.
      if (!isCurrent()) return null;
      final parsedLayers = document == null
          ? null
          : parseCoverLayersFromDocument(document, canvasSize: canvasSize);
      final parsed = _ParsedHomeCover(
        parsedLayers == null ? null : List.unmodifiable(parsedLayers),
        document == null
            ? null
            : extractCoverBackgroundColorFromDocument(document),
      );
      // Pressure cleanup must not be undone by a worker started beforehand.
      if (epoch == _cacheEpoch && source.length <= _maxSourceCharacters) {
        _cache[key] = parsed;
        _sourceCharacters += source.length;
        while (_cache.length > _maxEntries ||
            _sourceCharacters > _maxSourceCharacters) {
          final oldest = _cache.keys.first;
          _cache.remove(oldest);
          _sourceCharacters -= oldest.$1.length;
        }
      }
      return parsed;
    }

    if (source.length <= _asyncDecodeThreshold) {
      return SynchronousFuture(finish(compactHomeCoverDocument(source)));
    }
    return AlbumDocumentWorker.run(
      () => compute(
        compactHomeCoverDocument,
        source,
        debugLabel: 'home-cover-document',
      ),
      isCurrent: isCurrent,
    ).then(finish, onError: (Object _, StackTrace __) => finish(null));
  }
}

/// 앨범 커버 썸네일
class HomeAlbumCoverThumbnail extends ConsumerStatefulWidget {
  final Album album;
  final double height;
  final double? maxWidth;
  final bool showShadow;
  final double shadowScaleMultiplier;
  final String? fallbackAsset;
  final bool showBookDepth;
  final Listenable? bookMotion;

  const HomeAlbumCoverThumbnail({
    super.key,
    required this.album,
    required this.height,
    this.maxWidth,
    this.showShadow = true,
    this.shadowScaleMultiplier = 1.0,
    this.fallbackAsset,
    this.showBookDepth = false,
    this.bookMotion,
  });

  @override
  ConsumerState<HomeAlbumCoverThumbnail> createState() =>
      _HomeAlbumCoverThumbnailState();
}

class _HomeAlbumCoverThumbnailState
    extends ConsumerState<HomeAlbumCoverThumbnail>
    with WidgetsBindingObserver {
  // Spread document parsing and artwork mounting over frames on first entry.
  // The focused cover is queued before the lazy shelf's visible previews.
  static final _pendingLoads = Queue<_HomeAlbumCoverThumbnailState>();
  static int? _loadFrame;
  static bool _loadRunning = false;
  bool _loadQueued = false;
  bool _loadInFlight = false;
  int _loadVersion = 0;
  bool _loadEnabled = false;
  bool _visible = false;
  bool _foreground = true;
  Size? _requestedSize;
  String? _coverJson;
  Size? _canvasSize;
  List<LayerModel>? _layers;
  Color? _backgroundColor;
  LayerInteractionManager? _interaction;
  LayerBuilder? _builder;
  Widget? _artwork;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _artwork = null;
    _visible = TickerMode.of(context);
    _syncLoadEnabled();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (!mounted || _foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _syncLoadEnabled();
      _artwork = null;
    });
  }

  void _syncLoadEnabled() {
    _loadEnabled = _visible && _foreground;
    if (_loadEnabled) return;
    _cancelCoverLoad();
    _artwork = null;
    _layers = null;
    _coverJson = null;
    _canvasSize = null;
    _backgroundColor = null;
    _interaction?.dispose();
    _interaction = null;
    _builder = null;
  }

  @override
  void didUpdateWidget(covariant HomeAlbumCoverThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.album, widget.album) ||
        oldWidget.height != widget.height ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.showShadow != widget.showShadow ||
        oldWidget.shadowScaleMultiplier != widget.shadowScaleMultiplier ||
        oldWidget.fallbackAsset != widget.fallbackAsset ||
        oldWidget.showBookDepth != widget.showBookDepth ||
        !identical(oldWidget.bookMotion, widget.bookMotion)) {
      _artwork = null;
    }
  }

  void _queueCoverLoad() {
    if (!_loadEnabled || _loadQueued || _loadInFlight) return;
    _loadQueued = true;
    _pendingLoads.add(this);
    _scheduleCoverLoad();
  }

  static void _scheduleCoverLoad() {
    if (_loadFrame != null || _loadRunning || _pendingLoads.isEmpty) return;
    _loadFrame = WidgetsBinding.instance.scheduleFrameCallback((_) {
      _loadFrame = null;
      final thumbnail = _pendingLoads.removeFirst();
      thumbnail._loadQueued = false;
      if (thumbnail.mounted && thumbnail._loadEnabled) {
        if (Scrollable.recommendDeferredLoadingForContext(thumbnail.context)) {
          thumbnail._queueCoverLoad();
        } else {
          _loadCover(thumbnail);
        }
      }
      _scheduleCoverLoad();
    });
  }

  static Future<void> _loadCover(
    _HomeAlbumCoverThumbnailState thumbnail,
  ) async {
    _loadRunning = true;
    thumbnail._loadInFlight = true;
    final source = thumbnail.widget.album.coverLayersJson;
    final canvasSize = thumbnail._requestedSize!;
    final version = thumbnail._loadVersion;
    bool isCurrent() =>
        thumbnail.mounted &&
        thumbnail._loadEnabled &&
        thumbnail._loadVersion == version &&
        thumbnail.widget.album.coverLayersJson == source &&
        thumbnail._requestedSize == canvasSize;
    try {
      final parsed = await _ParsedHomeCover.resolve(
        source,
        canvasSize,
        isCurrent: isCurrent,
      );
      if (parsed != null &&
          isCurrent() &&
          !Scrollable.recommendDeferredLoadingForContext(thumbnail.context)) {
        thumbnail.setState(
          () => thumbnail._applyCover(source, canvasSize, parsed),
        );
      }
    } on Object {
      if (isCurrent()) {
        thumbnail.setState(
          () => thumbnail._applyCover(
            source,
            canvasSize,
            const _ParsedHomeCover(null, null),
          ),
        );
      }
    } finally {
      thumbnail._loadInFlight = false;
      _loadRunning = false;
      if (thumbnail.mounted &&
          thumbnail._loadEnabled &&
          (thumbnail._coverJson != thumbnail.widget.album.coverLayersJson ||
              thumbnail._canvasSize != thumbnail._requestedSize)) {
        thumbnail._queueCoverLoad();
      }
      _scheduleCoverLoad();
    }
  }

  void _applyCover(String source, Size canvasSize, _ParsedHomeCover parsed) {
    _coverJson = source;
    _canvasSize = canvasSize;
    _artwork = null;
    _layers = parsed.layers;
    _backgroundColor = parsed.backgroundColor;
    _interaction?.dispose();
    _interaction = null;
    _builder = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelCoverLoad();
    _interaction?.dispose();
    super.dispose();
  }

  void _cancelCoverLoad() {
    _loadVersion++;
    _pendingLoads.remove(this);
    _loadQueued = false;
    if (_pendingLoads.isEmpty && _loadFrame != null) {
      WidgetsBinding.instance.cancelFrameCallbackWithId(_loadFrame!);
      _loadFrame = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadEnabled) {
      return SizedBox(height: widget.height, width: widget.maxWidth);
    }
    return _artwork ??= _buildArtwork(context);
  }

  // Shelf selection and parent rebuilds reuse the mounted layer tree. Input,
  // media/theme dependency and decoded-document changes invalidate it above.
  Widget _buildArtwork(BuildContext context) {
    final album = widget.album;
    final ratio = parseCoverRatio(album.ratio);

    // 1. 실제 표시될 대상(TARGET) 크기 결정
    double targetW;
    double targetH;
    final sw = MediaQuery.sizeOf(context).width;
    final resolvedMaxWidth =
        widget.maxWidth ?? (ratio > 1 ? sw * (140 / 390) : sw * (150 / 390));
    final height = widget.height;

    if (ratio >= 1) {
      targetW = resolvedMaxWidth;
      targetH = targetW / ratio;
      if (targetH > height) {
        targetH = height;
        targetW = targetH * ratio;
      }
    } else {
      targetH = height;
      targetW = targetH * ratio;
      if (targetW > resolvedMaxWidth) {
        targetW = resolvedMaxWidth;
        targetH = targetW / ratio;
      }
    }

    // 2. [핵심] 고정된 기준(REFERENCE) 사이즈 정의 (비례 유지를 위해 충분히 큰 사이즈 사용)
    const double refWidth = kCoverReferenceWidth;
    final double refHeight = refWidth / ratio;
    final Size refCanvasSize = Size(refWidth, refHeight);

    // 3. 기준 사이즈를 바탕으로 레이어 파싱 (비비율 보존)
    _requestedSize = refCanvasSize;
    if (_coverJson != album.coverLayersJson || _canvasSize != refCanvasSize) {
      if (album.coverLayersJson.isEmpty || album.coverLayersJson == '{}') {
        _applyCover(
          album.coverLayersJson,
          refCanvasSize,
          const _ParsedHomeCover(null, null),
        );
      } else {
        _queueCoverLoad();
        return SizedBox(
          width: targetW,
          height: targetH,
          child: ColoredBox(
            color: resolveCoverTheme(album.coverTheme).gradient.colors.first,
          ),
        );
      }
    }
    final layers = _layers;

    final shadowScale =
        ((targetH / 280).clamp(0.25, 1.15) * widget.shadowScaleMultiplier)
            .clamp(0.2, 18.0);
    final theme = resolveCoverTheme(album.coverTheme);
    final coverBackgroundColor = _backgroundColor;

    // 4. 기준 사이즈로 렌더링 후 FittedBox로 전체 스케일링
    Widget buildFrame({required List<LayerModel> layers}) {
      // Preview interaction state is only needed for layered/themed covers.
      final coverInteraction = _interaction ??= LayerInteractionManager.preview(
        ref,
        () => _canvasSize!,
      );
      final pixels = targetW * MediaQuery.devicePixelRatioOf(context);
      final decodeWidth = ((pixels / 128).ceil() * 128).clamp(128, 1536);
      if (_builder?.previewImageDecodeWidth != decodeWidth) {
        _builder = LayerBuilder(
          coverInteraction,
          () => _canvasSize!,
          previewImageDecodeWidth: decodeWidth,
        );
      }
      final coverBuilder = _builder!;
      final artwork = CoverLayout(
        aspect: ratio,
        layers: layers,
        isInteracting: false,
        leftSpine: kCoverSpineWidth,
        wrapSpineArtwork: widget.showBookDepth,
        backgroundColor: coverBackgroundColor,
        onCoverSizeChanged: (_) {},
        buildImage: (layer) => coverBuilder.buildImage(layer, isCover: true),
        buildWrappedImage: (layer) =>
            coverBuilder.buildImage(layer, isCover: true, wrapSpine: true),
        buildText: (layer) => coverBuilder.buildText(layer, isCover: true),
        sortedByZ: coverInteraction.sortByZ,
        theme: theme,
      );
      return SizedBox(
        width: targetW,
        height: targetH,
        child: FittedBox(
          fit: BoxFit.contain,
          child: HomeCoverFrame(
            width: refWidth,
            height: refHeight,
            shadowScale: shadowScale, // 그림자는 대상 크기에 맞게 미리 계산됨
            showShadow: widget.showShadow,
            showBookDepth: widget.showBookDepth,
            bookDepth: HomeCoverFrame.depthForWidth(targetW),
            bookMotion: widget.bookMotion,
            bindingColor: coverBackgroundColor ?? theme.gradient.colors.first,
            bindingArtwork: widget.showBookDepth
                ? artwork.bindingPreview(refCanvasSize)
                : null,
            child: RepaintBoundary(child: artwork),
          ),
        ),
      );
    }

    if (layers != null && layers.isNotEmpty) {
      return buildFrame(layers: layers);
    }

    // 레이어가 없어도 테마가 있으면 테마 배경 유지
    if (album.coverTheme?.isNotEmpty == true) {
      return buildFrame(layers: const []);
    }

    final imageSources =
        [album.coverThumbnailUrl, album.coverPreviewUrl, album.coverImageUrl]
            .whereType<String>()
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toSet()
            .toList(growable: false);
    final imageUrl = imageSources.firstOrNull;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ((targetW * pixelRatio / 128).ceil() * 128).clamp(
      128,
      1536,
    );
    final fallbackAsset = widget.fallbackAsset;

    Widget fallbackArtwork({bool binding = false}) => imageUrl != null
        ? SnapfitImage(
            urlOrGs: imageUrl,
            fallbackSources: imageSources.skip(1).toList(growable: false),
            automaticStorageRefresh: true,
            fit: BoxFit.cover,
            cacheManager: snapfitImageCacheManager,
            memCacheWidth: cacheWidth,
            placeholder: binding ? const SizedBox() : null,
            error: binding ? const SizedBox() : null,
            imageBuilder: widget.showBookDepth && !binding
                ? (context, provider) => AlbumSpineImage(image: provider)
                : null,
          )
        : fallbackAsset != null
        ? widget.showBookDepth && !binding
              ? AlbumSpineImage(
                  image: ResizeImage.resizeIfNeeded(
                    cacheWidth,
                    null,
                    AssetImage(fallbackAsset),
                  ),
                )
              : Image.asset(
                  fallbackAsset,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                )
        : Container(
            color: Colors.grey[300],
            child: binding
                ? null
                : Icon(
                    Icons.photo_album_outlined,
                    size: 28,
                    color: Colors.grey[600],
                  ),
          );

    return HomeCoverFrame(
      width: targetW,
      height: targetH,
      shadowScale: shadowScale,
      showShadow: widget.showShadow,
      showBookDepth: widget.showBookDepth,
      bookMotion: widget.bookMotion,
      bindingColor: coverBackgroundColor ?? theme.gradient.colors.first,
      bindingArtwork: widget.showBookDepth
          ? fallbackArtwork(binding: true)
          : null,
      child: RepaintBoundary(child: fallbackArtwork()),
    );
  }
}
