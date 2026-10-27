import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/data/catalog_preview.dart';
import '../../core/data/catalog_preview_preparation.dart';
import '../../features/store/domain/entities/premium_template.dart';

/// Retained tabs release their worker interests while hidden. The shared
/// broker cancels unneeded queued jobs and ignores an active job's late result.
/// Scrolling consumers reuse compiled previews and defer unfinished work until
/// idle. Hidden tabs unmount artwork so image streams and textures can be freed.
class CatalogPreviewBuilder extends StatefulWidget {
  const CatalogPreviewBuilder({
    super.key,
    required this.template,
    required this.builder,
    this.needsCover = false,
    this.needsSpread = false,
  });

  final PremiumTemplate template;

  /// Declare the surfaces read by [builder] so they are prepared before paint.
  /// Profile-only labels leave both flags false.
  final bool needsCover;
  final bool needsSpread;
  final Widget Function(BuildContext, AsyncSnapshot<CatalogPreview?>) builder;

  @override
  State<CatalogPreviewBuilder> createState() => _CatalogPreviewBuilderState();
}

class _CatalogPreviewBuilderState extends State<CatalogPreviewBuilder>
    with WidgetsBindingObserver {
  CatalogPreviewRequest? _request;
  CatalogPreviewPreparation? _preparation;
  Future<CatalogPreview?>? _preparedFuture;
  Widget? _lastChild;
  Object _subscriptionKey = Object();
  bool _visible = false;
  bool _foreground = true;
  bool _requestCompleted = false;
  bool _scrolling = false;
  bool _rebuildScheduled = false;
  Set<ScrollPosition> _scrollPositions = {};

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
    _visible = TickerMode.of(context);
    // A horizontal collection can sit inside the store's vertical feed.
    // Either scroll should defer new artwork, without polling every frame.
    final positions = <ScrollPosition>{
      for (final axis in Axis.values)
        if (Scrollable.maybeOf(context, axis: axis) case final scrollable?)
          scrollable.position,
    };
    for (final position in _scrollPositions.difference(positions)) {
      position.isScrollingNotifier.removeListener(_onScrollActivityChanged);
    }
    for (final position in positions.difference(_scrollPositions)) {
      position.isScrollingNotifier.addListener(_onScrollActivityChanged);
    }
    _scrollPositions = positions;
    _scrolling = _isScrolling;
    _syncRequest();
  }

  @override
  void didUpdateWidget(CatalogPreviewBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visible = TickerMode.of(context);
    if (!identical(oldWidget.template, widget.template) ||
        oldWidget.needsCover != widget.needsCover ||
        oldWidget.needsSpread != widget.needsSpread) {
      // Acquire before releasing so favorite-only copies keep their shared
      // queued job. Hidden consumers must never acquire replacement work.
      final previous = _request;
      _preparation?.cancel();
      _preparation = null;
      _request = null;
      _preparedFuture = null;
      _requestCompleted = false;
      _lastChild = null;
      _subscriptionKey = Object();
      _syncRequest();
      previous?.release();
    } else {
      _syncRequest();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (!mounted || _foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _syncRequest();
    });
  }

  bool get _isScrolling =>
      _scrollPositions.any((position) => position.isScrollingNotifier.value);

  void _onScrollActivityChanged() {
    if (!mounted || _scrolling == _isScrolling) return;
    _scrolling = _isScrolling;
    final previous = _request;
    _syncRequest();
    // Already loaded artwork needs no rebuild when scrolling starts/stops.
    if (identical(previous, _request)) return;
    // Scroll physics can settle during layout. Release work immediately, but
    // leave the corresponding widget update until that frame has finished.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_rebuildScheduled) return;
      _rebuildScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rebuildScheduled = false;
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  void _syncRequest() {
    if (!_visible || !_foreground) {
      _preparation?.cancel();
      _preparation = null;
      _request?.release();
      _request = null;
      _preparedFuture = null;
      _lastChild = null;
      _requestCompleted = false;
      // The completed future also retains its preview result.
      _subscriptionKey = Object();
      return;
    }
    if (_scrolling && !_requestCompleted) {
      _preparation?.cancel();
      _preparation = null;
      _request?.release();
      _request = null;
      _preparedFuture = null;
    }
    if (_request == null) {
      final request = _scrolling
          ? CatalogPreviews.acquireCached(
              widget.template,
              needsCover: widget.needsCover,
              needsSpread: widget.needsSpread,
            )
          : CatalogPreviews.acquire(widget.template);
      if (request != null) {
        _requestCompleted = false;
        _request = request;
        _preparedFuture = request.future.then((preview) {
          bool isCurrent() => mounted && identical(_request, request);
          if (!isCurrent()) return null;
          if (preview == null ||
              preview.hasPreparedParts(
                cover: widget.needsCover,
                spread: widget.needsSpread,
              )) {
            return preview;
          }
          // Cached raw parts must not all compile in the same microtask turn
          // when entering a department. The shared queue paces native work.
          if (_scrolling || !_visible || !_foreground) return null;
          final preparation = CatalogPreviewPreparations.prepare(
            preview,
            cover: widget.needsCover,
            spread: widget.needsSpread,
          );
          _preparation = preparation;
          return preparation.future.whenComplete(() {
            if (identical(_preparation, preparation)) _preparation = null;
          });
        });
        _subscriptionKey = _preparedFuture!;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _scrollPositions) {
      position.isScrollingNotifier.removeListener(_onScrollActivityChanged);
    }
    _request?.release();
    _preparation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || !_foreground) return const SizedBox.shrink();
    return FutureBuilder<CatalogPreview?>(
      key: ObjectKey(_subscriptionKey),
      future: _preparedFuture,
      builder: (context, snapshot) {
        if (_request == null) {
          return _lastChild ??= widget.builder(
            context,
            const AsyncSnapshot<CatalogPreview?>.waiting(),
          );
        }
        _requestCompleted = snapshot.connectionState == ConnectionState.done;
        return _lastChild = widget.builder(context, snapshot);
      },
    );
  }
}
