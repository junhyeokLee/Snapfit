import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Static catalog art follows the same lifetime as worker-backed previews:
/// release image streams while a retained tab is hidden, and defer mounting
/// new images/painters until both the feed and any horizontal shelf are idle.
class CatalogArtworkVisibility extends StatefulWidget {
  const CatalogArtworkVisibility({super.key, required this.child});

  final Widget child;

  @override
  State<CatalogArtworkVisibility> createState() =>
      _CatalogArtworkVisibilityState();
}

class _CatalogArtworkVisibilityState extends State<CatalogArtworkVisibility>
    with WidgetsBindingObserver {
  Set<ScrollPosition> _positions = {};
  bool _visible = false;
  bool _foreground = true;
  bool _show = false;
  bool _rebuildScheduled = false;

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
    final positions = <ScrollPosition>{
      for (final axis in Axis.values)
        if (Scrollable.maybeOf(context, axis: axis) case final scrollable?)
          scrollable.position,
    };
    for (final position in _positions.difference(positions)) {
      position.isScrollingNotifier.removeListener(_onScrollChanged);
    }
    for (final position in positions.difference(_positions)) {
      position.isScrollingNotifier.addListener(_onScrollChanged);
    }
    _positions = positions;
    _sync();
  }

  void _sync() {
    _show =
        _visible &&
        _foreground &&
        (_show || !_positions.any((p) => p.isScrollingNotifier.value));
  }

  void _onScrollChanged() {
    final previous = _show;
    _sync();
    // Artwork that has already mounted stays put during subsequent scrolling.
    if (previous == _show) return;
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final position in _positions) {
      position.isScrollingNotifier.removeListener(_onScrollChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _show ? widget.child : const SizedBox.shrink();
}
