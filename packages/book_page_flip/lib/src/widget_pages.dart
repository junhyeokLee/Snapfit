part of 'engine.dart';

// Keeps global page indices stable while distant photo pages finish preparing.
class _BookFlipPageSource extends ChangeNotifier {
  _BookFlipPageSource(this.pageCount, this.requestedSpread, this.onRequest);

  final int pageCount;
  final VoidCallback onRequest;
  int requestedSpread;
  List<ui.Image>? pages;
  final Map<int, ui.Image> captured = <int, ui.Image>{};
  final Set<int> prepared = <int>{};
  Set<int> packed = <int>{};
  int revision = 0;

  List<int> window(int spread) {
    final left = spread.clamp(0, math.max(0, pageCount ~/ 2 - 1)).toInt() * 2;
    return <int>[
      left,
      left + 1,
      left + 2,
      left + 3,
      left - 2,
      left - 1,
    ].where((page) => page >= 0 && page < pageCount).toList();
  }

  List<int> requiredPages(int currentSpread) {
    final current =
        currentSpread.clamp(0, math.max(0, pageCount ~/ 2 - 1)).toInt();
    final requested =
        requestedSpread.clamp(0, math.max(0, pageCount ~/ 2 - 1)).toInt();
    return requested == current
        ? window(current)
        : <int>[current * 2, current * 2 + 1, requested * 2, requested * 2 + 1];
  }

  bool isSpreadPacked(int spread) =>
      packed.contains(spread * 2) && packed.contains(spread * 2 + 1);

  void requestSpread(int spread) {
    final target = spread.clamp(0, math.max(0, pageCount ~/ 2 - 1)).toInt();
    if (target == requestedSpread) {
      notifyListeners();
      return;
    }
    requestedSpread = target;
    onRequest();
    notifyListeners();
  }

  void add(int index, ui.Image image) {
    // Unprepared slots are never used by a turn; sharing an existing image avoids
    // allocating placeholder textures or changing the atlas's global indices.
    pages ??= List<ui.Image>.filled(pageCount, image);
    pages![index] = image;
    captured[index] = image;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final image in captured.values) {
      image.dispose();
    }
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget pages → BookFlip.  Public entry point: [BookFlip.builder] (api.dart)
//  returns one of these.  It rasterises each page WIDGET to a ui.Image with the
//  already-proven [BookFlipPageRasterizer], OWNS the resulting images, then hands
//  them to an ordinary [BookFlip] — so widget pages reuse the EXACT same mesh /
//  atlas / flip engine with ZERO engine changes (geometry, rendering, scene and
//  the state hot path are untouched; they only ever see decoded images).
//
//  The captured images live exactly as long as this wrapper: re-captured when the
//  page definition changes, disposed on reconfigure and on teardown — so the
//  consumer never touches a ui.Image lifecycle (the disposal footgun of the raw
//  List<ui.Image> constructor simply does not exist on this path).
// ─────────────────────────────────────────────────────────────────────────────
class _BookFlipWidgetPages extends StatefulWidget {
  const _BookFlipWidgetPages({
    required this.pageCount,
    required this.pageBuilder,
    required this.pageSize,
    required this.pixelRatio,
    required this.preparePage,
    required this.progressive,
    required this.preparationPaused,
    required this.controller,
    required this.physics,
    required this.material,
    required this.curl,
    required this.effects,
    required this.fit,
    required this.transparentPages,
    required this.maxTextureDimension,
    required this.meshResolution,
    required this.onSpreadChanged,
    required this.onFlipStart,
    required this.onFlipEnd,
    required this.loadingBuilder,
    required this.errorBuilder,
    required this.pageLabel,
    super.key,
  });

  final int pageCount;
  final Widget Function(BuildContext context, int pageIndex) pageBuilder;
  final Size pageSize;
  final double? pixelRatio;
  final Future<void> Function(BuildContext context, int pageIndex)? preparePage;
  final bool progressive;
  final bool preparationPaused;
  final BookFlipController? controller;
  final BookFlipPhysics physics;
  final BookFlipMaterial material;
  final BookFlipCurl? curl;
  final BookFlipEffects effects;
  final BookFit fit;
  final Set<int> transparentPages;
  final int maxTextureDimension;
  final int meshResolution;
  final void Function(int spread)? onSpreadChanged;
  final void Function(int spread, FlipDirection direction)? onFlipStart;
  final void Function(int spread)? onFlipEnd;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;
  final Widget Function(BuildContext context, int page, int total)? pageLabel;

  @override
  State<_BookFlipWidgetPages> createState() => _BookFlipWidgetPagesState();
}

class _BookFlipWidgetPagesState extends State<_BookFlipWidgetPages> {
  // The captured page images. Non-null once rasterisation completes; OWNED here
  // (disposed on reconfigure and teardown) so the consumer never manages them.
  List<ui.Image>? _images;
  // Set if a capture fails → build() shows the retry UI instead of a dead cover.
  Object? _captureError;
  // Bumped on any capture-affecting change; keys the rasteriser so a reconfigure
  // (even mid-capture) remounts it fresh and abandons the stale in-flight capture.
  int _epoch = 0;
  int _captureEpoch = 0;
  _BookFlipPageSource? _source;
  BookFlipController? _sourceController;
  BookFlipController? _ownedController;
  final Map<int, Future<void>> _preparing = <int, Future<void>>{};

  BookFlipController get _controller =>
      widget.controller ?? (_ownedController ??= BookFlipController());

  @override
  void initState() {
    super.initState();
    _attachProgressiveSource();
  }

  void _attachProgressiveSource() {
    if (!widget.progressive) return;
    _source = _BookFlipPageSource(
      widget.pageCount,
      _controller.currentSpread,
      _prioritiseRequestedSpread,
    );
    _controller._pageSource = _source;
    _sourceController = _controller;
  }

  void _prioritiseRequestedSpread() {
    // Remount only the capture layer so a slow distant preparation cannot own
    // the newly requested window. The engine and active gesture stay attached.
    void reprioritise() {
      if (!mounted) return;
      setState(() {
        _captureEpoch++;
        _captureError = null;
      });
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reprioritise());
    } else {
      reprioritise();
    }
  }

  void _disposeProgressiveSource() {
    final source = _source;
    if (source == null) return;
    final controller = _sourceController;
    if (identical(controller?._pageSource, source)) {
      controller!._pageSource = null;
    }
    source.dispose();
    _source = null;
    _sourceController = null;
    _preparing.clear();
  }

  void _disposeImages() {
    final imgs = _images;
    if (imgs != null) {
      for (final img in imgs) {
        img.dispose();
      }
    }
  }

  @override
  void didUpdateWidget(_BookFlipWidgetPages old) {
    super.didUpdateWidget(old);
    // Any change to WHAT or HOW we capture → drop the stale capture and start over.
    final changed = old.pageCount != widget.pageCount ||
        old.pageSize != widget.pageSize ||
        old.pixelRatio != widget.pixelRatio ||
        old.transparentPages != widget.transparentPages ||
        old.progressive != widget.progressive;
    if (changed) {
      _disposeImages();
      _disposeProgressiveSource();
      _attachProgressiveSource();
      setState(() {
        _images = null; // null → re-enter the capture branch
        _captureError = null;
        _epoch++; // remount the rasteriser at the new configuration
      });
    }
    if (!identical(old.controller, widget.controller) && _source != null) {
      if (identical(old.controller?._pageSource, _source)) {
        old.controller!._pageSource = null;
      }
      _controller._pageSource = _source;
      _sourceController = _controller;
    }
  }

  @override
  void dispose() {
    _disposeImages();
    _disposeProgressiveSource();
    _ownedController?.dispose();
    super.dispose();
  }

  void _onCaptured(List<ui.Image> images) {
    if (!mounted) {
      // Capture finished after we were removed → never leak it.
      for (final img in images) {
        img.dispose();
      }
      return;
    }
    setState(() => _images = images);
  }

  void _onCaptureError(Object error, StackTrace stack) {
    if (!mounted) return;
    setState(() => _captureError = error);
  }

  void _retryCapture() {
    setState(() {
      _captureError = null;
      _epoch++; // fresh rasteriser → a new capture attempt
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_source != null) return _buildProgressive(context);
    final images = _images;
    if (images != null) {
      // Captured → an ordinary BookFlip, engine untouched. We own [images] and
      // outlive the book, so the book is left on its default "caller owns" footing
      // and we dispose them ourselves in [dispose].
      return BookFlip(
        pages: images,
        controller: widget.controller,
        physics: widget.physics,
        material: widget.material,
        curl: widget.curl,
        effects: widget.effects,
        fit: widget.fit,
        transparentPages: widget.transparentPages,
        pageAspectRatio: widget.pageSize.height > 0
            ? widget.pageSize.width / widget.pageSize.height
            : null,
        maxTextureDimension: widget.maxTextureDimension,
        meshResolution: widget.meshResolution,
        onSpreadChanged: widget.onSpreadChanged,
        onFlipStart: widget.onFlipStart,
        onFlipEnd: widget.onFlipEnd,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder,
      );
    }
    // Capture failed (e.g. GPU OOM) → the same tap-to-retry UI as the book's own
    // boot error, never a dead loading cover.
    if (_captureError != null) {
      return widget.errorBuilder?.call(context) ??
          _BookErrorView(onRetry: _retryCapture);
    }
    // Not captured yet → rasterise every page widget at [pageSize], hidden under
    // the loading cover; [_onCaptured] then swaps us to the real book. The rasteriser
    // is keyed by [_epoch] so any reconfigure remounts it fresh (correct page count,
    // new capture) instead of reusing a stale, wrong-length capture state.
    final ratio = widget.pixelRatio ?? MediaQuery.devicePixelRatioOf(context);
    return BookFlipPageRasterizer(
      key: ValueKey<int>(_epoch),
      pixelRatio: ratio,
      preparePage: widget.preparePage,
      logicalSize: widget.pageSize,
      cover: widget.loadingBuilder?.call(context) ?? const _BookLoadingView(),
      onCaptured: _onCaptured,
      onError: _onCaptureError,
      pages: <Widget>[
        for (var i = 0; i < widget.pageCount; i++)
          Builder(builder: (context) => _composePage(context, i)),
      ],
    );
  }

  int? _nextProgressivePage() {
    final source = _source!;
    for (final page in <int>[
      ...source.requiredPages(_controller.currentSpread),
      ...source.window(_controller.currentSpread),
      ...source.window(source.requestedSpread),
      for (var page = 0; page < widget.pageCount; page++) page,
    ]) {
      if (!source.captured.containsKey(page)) return page;
    }
    return null;
  }

  Future<void> _prepareProgressivePage(BuildContext context, int index) async {
    final source = _source!;
    final prepare = widget.preparePage;
    if (prepare == null) return;
    final currentWindow = source.window(_controller.currentSpread);
    final requestedWindow = source.window(source.requestedSpread);
    final batch = currentWindow.contains(index)
        ? currentWindow
        : requestedWindow.contains(index)
            ? requestedWindow
            : <int>[index];
    Future<void> prepareOne(int page) {
      if (source.prepared.contains(page)) return Future<void>.value();
      final pending = _preparing[page];
      if (pending != null) return pending;
      final work = () async {
        await prepare(context, page);
        if (!mounted || !context.mounted || !identical(source, _source)) {
          throw const BookFlipPreparationPaused();
        }
        source.prepared.add(page);
      }();
      _preparing[page] = work;
      void completed() {
        if (identical(_preparing[page], work)) _preparing.remove(page);
      }

      // Prefetch failures are observed now and surfaced when that page is used.
      unawaited(work.then<void>((_) => completed(),
          onError: (Object _, StackTrace __) {
        completed();
      }));
      return work;
    }

    for (final page in batch) {
      prepareOne(page);
    }
    // A slow neighbouring photo must not delay an already decoded turn face.
    await prepareOne(index);
  }

  Widget _buildProgressive(BuildContext context) {
    final source = _source!;
    final hasBook = source.pages != null &&
        (source
                .requiredPages(_controller.currentSpread)
                .every(source.captured.containsKey) ||
            _controller._state != null);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (_captureError == null && source.captured.length < widget.pageCount)
          Positioned(
            left: -widget.pageSize.width,
            top: 0,
            width: widget.pageSize.width,
            height: widget.pageSize.height,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, child) => TickerMode(
                enabled: !widget.preparationPaused && !_controller.isAnimating,
                child: child!,
              ),
              child: BookFlipPageRasterizer(
                key: ValueKey('progressive_${_epoch}_$_captureEpoch'),
                pixelRatio:
                    widget.pixelRatio ?? MediaQuery.devicePixelRatioOf(context),
                logicalSize: widget.pageSize,
                preparePage:
                    widget.preparePage == null ? null : _prepareProgressivePage,
                isPagePrepared: source.prepared.contains,
                nextPageIndex: _nextProgressivePage,
                onPageCaptured: (index, image) {
                  if (!mounted || !identical(source, _source)) {
                    image.dispose();
                    return;
                  }
                  source.add(index, image);
                  setState(() {});
                },
                onCaptured: (_) {},
                onError: _onCaptureError,
                pages: <Widget>[
                  for (var page = 0; page < widget.pageCount; page++)
                    Builder(builder: (context) => _composePage(context, page)),
                ],
              ),
            ),
          ),
        if (hasBook)
          BookFlip(
            key: ValueKey('progressive_book_$_epoch'),
            pages: source.pages!,
            controller: _controller,
            physics: widget.physics,
            material: widget.material,
            curl: widget.curl,
            effects: widget.effects,
            fit: widget.fit,
            transparentPages: widget.transparentPages,
            pageAspectRatio: widget.pageSize.width / widget.pageSize.height,
            maxTextureDimension: widget.maxTextureDimension,
            meshResolution: widget.meshResolution,
            onSpreadChanged: widget.onSpreadChanged,
            onFlipStart: widget.onFlipStart,
            onFlipEnd: widget.onFlipEnd,
            loadingBuilder: widget.loadingBuilder,
            errorBuilder: widget.errorBuilder,
          )
        else if (_captureError != null)
          widget.errorBuilder?.call(context) ??
              _BookErrorView(onRetry: _retryCapture)
        else
          widget.loadingBuilder?.call(context) ?? const _BookLoadingView(),
      ],
    );
  }

  // One page widget, with the optional page-number label composited on top — baked
  // into the capture, so numeration costs the engine nothing. The label widget
  // self-positions (wrap it in Align/Positioned). [page] passed out is 1-based.
  Widget _composePage(BuildContext context, int index) {
    final page = widget.pageBuilder(context, index);
    final label = widget.pageLabel?.call(context, index + 1, widget.pageCount);
    if (label == null) {
      return page;
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[page, label],
    );
  }
}
