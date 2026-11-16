part of 'engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Widget → ui.Image rasteriser. Turns arbitrary page WIDGETS (Text, RichText,
//  Image, Icon, whole subtrees) into the decoded images the atlas pipeline already
//  knows how to pack and flip — so a BookFlip built from widgets reuses the exact
//  same, already-proven mesh/atlas/shading path, with zero engine changes.
//
//  CAPTURE MECHANISM (deliberately the version-stable one): each page is mounted
//  inside the live BookFlip subtree wrapped in a RepaintBoundary and rasterised
//  with RenderRepaintBoundary.toImage. That API is stable across the whole
//  supported Flutter range (3.22 → current), unlike the off-tree RenderView/
//  ViewConfiguration pipeline whose constructor churned between versions. Mounting
//  in-tree also means each page inherits the ambient Directionality, MediaQuery,
//  DefaultTextStyle and Theme, so Text/TextSpan "just work" with no extra wiring.
//
//  The pages paint UNDER an opaque cover (the loading view), so they are captured
//  but never visible. They are painted (not Offstage / not Opacity-0, both of which
//  SKIP painting the child and would make toImage fail) — occlusion by a sibling
//  does not stop a child from painting, so the capture is reliable.
// ─────────────────────────────────────────────────────────────────────────────

/// Rasterises page [pages] to [ui.Image]s (via [RepaintBoundary.toImage]) so a
/// [BookFlip] can turn arbitrary widgets — text, rich text, images, whole
/// subtrees — exactly like decoded image pages.
///
/// Mounted hidden inside the BookFlip subtree during loading: each page inherits
/// the ambient [Directionality], [MediaQuery] and [Theme], renders at
/// [logicalSize], and is captured at [pixelRatio]× that size (so pages stay crisp
/// on high-density screens). [onCaptured] fires once with the decoded images, in
/// page order; the caller then owns and must dispose them.
///
/// This is package-internal (not exported); it is annotated [visibleForTesting]
/// only so the package's own tests can drive the capture directly.
@visibleForTesting
class BookFlipPageRasterizer extends StatefulWidget {
  /// Creates a hidden rasteriser that captures [pages] at [logicalSize] (scaled by
  /// [pixelRatio]) and reports the decoded images to [onCaptured].
  const BookFlipPageRasterizer({
    required this.pages,
    required this.logicalSize,
    required this.onCaptured,
    this.pixelRatio = 1.0,
    this.preparePage,
    this.isPagePrepared,
    this.nextPageIndex,
    this.onPageCaptured,
    this.cover = const SizedBox.expand(),
    this.onError,
    super.key,
  });

  /// The page contents, in reading order. Each becomes one [ui.Image].
  final List<Widget> pages;

  /// The logical size each page is laid out at before capture. The resulting
  /// image is [logicalSize] × [pixelRatio] pixels.
  final Size logicalSize;

  /// Called once with the decoded page images, in order. The receiver owns them
  /// and is responsible for disposing them.
  final void Function(List<ui.Image> images) onCaptured;

  /// Called if capture fails (e.g. GPU OOM) instead of throwing, so the host can
  /// show an error/retry UI rather than leaving a dead loading cover. When null, a
  /// capture failure rethrows (the original behaviour, used by the test harness).
  final void Function(Object error, StackTrace stack)? onError;

  /// Resolution multiplier applied at capture time. Pass the device pixel ratio
  /// (or more) for crisp pages on high-density screens.
  final double pixelRatio;

  /// Resolve asynchronous artwork before freezing a page. Only one page is
  /// prepared at a time; a fresh painted frame follows completion.
  final Future<void> Function(BuildContext context, int pageIndex)? preparePage;

  // Progressive hosts prepare a small window together and retain each image.
  final bool Function(int pageIndex)? isPagePrepared;
  final int? Function()? nextPageIndex;
  final void Function(int pageIndex, ui.Image image)? onPageCaptured;

  /// Painted on top of the (hidden) capture layer while rasterising — typically
  /// the loading view, so the user never sees the pages being captured.
  final Widget cover;

  @override
  State<BookFlipPageRasterizer> createState() => _BookFlipPageRasterizerState();
}

/// A host can stop preparing a page when it becomes hidden. The same page is
/// prepared again on resume, so a partial preparation is never captured as done.
class BookFlipPreparationPaused implements Exception {
  const BookFlipPreparationPaused();
}

class _BookFlipPageRasterizerState extends State<BookFlipPageRasterizer>
    with WidgetsBindingObserver {
  final GlobalKey _pageKey = GlobalKey();
  final List<ui.Image> _images = <ui.Image>[];
  int _pageIndex = 0;
  bool _captured = false;
  bool _preparing = false;
  bool _rasterizing = false;
  int? _preparedPage;
  final Set<int> _capturedPages = <int>{};

  bool get _active {
    // Keep the local package's Flutter 3.22 compatibility.
    // ignore: deprecated_member_use
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    // ignore: deprecated_member_use
    return TickerMode.of(context) &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  void _scheduleCapture([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture(attempt));
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.nextPageIndex?.call() ?? 0;
    WidgetsBinding.instance.addObserver(this);
    // Capture AFTER the first frame is painted (post-frame), so every boundary's
    // layer exists. A handful of retries covers the rare not-yet-laid-out frame.
    _scheduleCapture();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_active) _scheduleCapture();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {});
    if (state == AppLifecycleState.resumed) _scheduleCapture();
  }

  Future<void> _capture([int attempt = 0]) async {
    if (_captured || _preparing || _rasterizing || !mounted || !_active) {
      return;
    }
    if (_capturedPages.contains(_pageIndex)) {
      _advanceCapturedPage();
      return;
    }
    if (widget.preparePage != null &&
        _preparedPage != _pageIndex &&
        !(widget.isPagePrepared?.call(_pageIndex) ?? false)) {
      _preparing = true;
      try {
        await widget.preparePage!(context, _pageIndex);
      } on BookFlipPreparationPaused {
        // Dependencies/lifecycle schedule resume. If visibility changed twice
        // during the await, resume now rather than losing that notification.
        if (mounted && _active) _scheduleCapture();
        return;
      } on Object catch (error, stack) {
        if (!mounted) return;
        _captured = true;
        for (final image in _images) {
          image.dispose();
        }
        _images.clear();
        if (widget.onError != null) {
          widget.onError!(error, stack);
          return;
        }
        Error.throwWithStackTrace(error, stack);
      } finally {
        _preparing = false;
      }
      if (!mounted) return;
      _preparedPage = _pageIndex;
      _scheduleCapture();
      return;
    }
    final object = _pageKey.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      if (attempt < 12) {
        _scheduleCapture(attempt + 1);
      }
      return;
    }
    if (object.debugNeedsPaint) {
      if (attempt < 30) {
        _scheduleCapture(attempt + 1);
      } else {
        widget.onError?.call(
          StateError(
              'BookFlip page $_pageIndex was not painted before capture.'),
          StackTrace.current,
        );
      }
      return;
    }

    try {
      _rasterizing = true;
      final image = await object.toImage(pixelRatio: widget.pixelRatio);
      if (!mounted) {
        image.dispose();
        return;
      }
      _capturedPages.add(_pageIndex);
      if (widget.onPageCaptured != null) {
        widget.onPageCaptured!(_pageIndex, image);
      } else {
        _images.add(image);
      }
    } on Object catch (error, stack) {
      if (!mounted || !_active) return;
      _captured = true;
      for (final image in _images) {
        image.dispose(); // never leak a partial capture
      }
      _images.clear();
      final onError = widget.onError;
      if (onError != null) {
        onError(error, stack); // host shows retry UI — never a dead cover
        return;
      }
      rethrow;
    } finally {
      _rasterizing = false;
    }
    if (!mounted) {
      for (final image in _images) {
        image.dispose();
      }
      _images.clear();
      return;
    }

    // A screenshot already in flight may finish after the route is covered.
    // Keep it, but don't mount the next photo page until the route resumes.
    if (!_active) return;
    _advanceCapturedPage();
  }

  void _advanceCapturedPage() {
    if (widget.nextPageIndex != null) {
      final next = widget.nextPageIndex!();
      if (next != null) {
        setState(() => _pageIndex = next);
        _scheduleCapture();
        return;
      }
      _captured = true;
      widget.onCaptured(const <ui.Image>[]);
      return;
    }
    if (_images.length < widget.pages.length) {
      setState(() => _pageIndex += 1);
      _scheduleCapture();
      return;
    }

    _captured = true;
    widget.onCaptured(List<ui.Image>.of(_images));
    _images.clear();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offstage routes still build. Mounting the next hidden page alone could
    // start image downloads even before preparePage gets a chance to pause.
    if (!_active) return SizedBox.expand(child: widget.cover);
    final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final size = widget.logicalSize;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: 0,
          top: 0,
          width: size.width,
          height: size.height,
          child: RepaintBoundary(
            key: _pageKey,
            child: Directionality(
              textDirection: direction,
              child: KeyedSubtree(
                key: ValueKey<int>(_pageIndex),
                child: widget.pages[_pageIndex],
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.cover),
      ],
    );
  }
}
