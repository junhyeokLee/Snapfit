import 'package:flutter/material.dart';

import '../../core/theme/snapfit_design_tokens.dart';

/// One paint-only clock for pending covers in a catalog. Loaded artwork never
/// subscribes. Scroll/lifecycle/visibility changes stop the clock immediately.
class CatalogSkeletonShimmer extends StatefulWidget {
  const CatalogSkeletonShimmer({super.key, required this.child});
  final Widget child;

  @override
  State<CatalogSkeletonShimmer> createState() => _CatalogSkeletonShimmerState();
}

class _CatalogSkeletonShimmerState extends State<CatalogSkeletonShimmer>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final _clock = _SkeletonClock(_controller);
  bool _foreground = true;

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
    _sync();
  }

  void _sync() => _clock.setAllowed(
    _foreground && TickerMode.of(context) && !SnapFitMotion.reduced(context),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonScope(clock: _clock, child: widget.child);
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.clock, required super.child});
  final _SkeletonClock clock;
  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) => clock != oldWidget.clock;
}

class _SkeletonClient {
  const _SkeletonClient(this.positions, this.visible);
  final Set<ScrollPosition> positions;
  final bool Function() visible;
}

class _SkeletonClock extends ChangeNotifier {
  _SkeletonClock(this.controller) {
    controller.addListener(notifyListeners);
  }
  final AnimationController controller;
  final _clients = <Object, _SkeletonClient>{};
  final _positions = <ScrollPosition, int>{};
  bool _allowed = false;
  bool _scheduled = false;
  bool _disposed = false;

  bool get running => controller.isAnimating;
  double get phase => controller.value;

  void setAllowed(bool allowed) {
    if (_disposed) return;
    _allowed = allowed;
    if (!allowed) _animate(false);
    _schedule();
  }

  void attach(
    Object owner,
    Set<ScrollPosition> positions,
    bool Function() visible,
  ) {
    if (_disposed) return;
    detach(owner);
    _clients[owner] = _SkeletonClient(positions, visible);
    for (final position in positions) {
      if (!_positions.containsKey(position)) {
        position.addListener(_pixelsChanged);
        position.isScrollingNotifier.addListener(_activityChanged);
      }
      _positions[position] = (_positions[position] ?? 0) + 1;
    }
    _schedule();
  }

  void detach(Object owner) {
    if (_disposed) return;
    final previous = _clients.remove(owner);
    if (previous == null) return;
    for (final position in previous.positions) {
      final count = _positions[position]! - 1;
      if (count == 0) {
        _positions.remove(position);
        position.removeListener(_pixelsChanged);
        position.isScrollingNotifier.removeListener(_activityChanged);
      } else {
        _positions[position] = count;
      }
    }
    if (_clients.isEmpty) _animate(false);
    _schedule();
  }

  bool get _scrolling =>
      _positions.keys.any((p) => p.isScrollingNotifier.value);

  void _activityChanged() {
    if (_scrolling) _animate(false);
    _schedule();
  }

  void _pixelsChanged() {
    // One geometry pass after a jump or settling, never per tile/drag frame.
    if (!_scrolling) _schedule();
  }

  void _schedule() {
    if (_scheduled || _disposed) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      _animate(
        _allowed && !_scrolling && _clients.values.any((c) => c.visible()),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _animate(bool enabled) {
    if (enabled == running) return;
    if (enabled) {
      controller.repeat();
    } else {
      controller.stop();
    }
    // Switch back to the static paper once on pause; no widget builds per tick.
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final position in _positions.keys) {
      position.removeListener(_pixelsChanged);
      position.isScrollingNotifier.removeListener(_activityChanged);
    }
    _positions.clear();
    _clients.clear();
    controller.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Adds a clipped light sweep to the supplied placeholder shapes. Outside a
/// catalog scope it remains static, preserving home/creation placeholders.
class CatalogSkeletonSheen extends StatefulWidget {
  const CatalogSkeletonSheen({
    super.key,
    required this.child,
    required this.shapes,
  });
  final Widget child;
  final Path Function(Size) shapes;

  @override
  State<CatalogSkeletonSheen> createState() => _CatalogSkeletonSheenState();
}

class _CatalogSkeletonSheenState extends State<CatalogSkeletonSheen> {
  _SkeletonClock? _clock;
  List<ScrollableState> _viewports = const [];
  Size? _screen;
  bool _visible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context
        .dependOnInheritedWidgetOfExactType<_SkeletonScope>()
        ?.clock;
    if (!identical(next, _clock)) _clock?.detach(this);
    _clock = next;
    _visible = TickerMode.of(context);
    _screen = MediaQuery.maybeSizeOf(context);
    _viewports = [
      for (final axis in Axis.values)
        if (Scrollable.maybeOf(context, axis: axis) case final viewport?)
          viewport,
    ];
    _clock?.attach(this, _viewports.map((v) => v.position).toSet(), _isVisible);
  }

  Rect? _rect(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.isEmpty)
      return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
  }

  bool _isVisible() {
    if (!mounted || !_visible) return false;
    final initial = _rect(context);
    if (initial == null) return false;
    Rect bounds = initial;
    if (_screen case final size? when !size.isEmpty) {
      bounds = bounds.intersect(Offset.zero & size);
    }
    for (final viewport in _viewports) {
      final clip = _rect(viewport.context);
      if (clip == null) return false;
      bounds = bounds.intersect(clip);
    }
    return !bounds.isEmpty;
  }

  @override
  void dispose() {
    _clock?.detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      foregroundPainter: _SheenPainter(
        _visible ? _clock : null,
        widget.shapes,
        Theme.of(context).colorScheme.primary,
        Theme.of(context).brightness == Brightness.dark,
      ),
      child: widget.child,
    ),
  );
}

class _SheenPainter extends CustomPainter {
  _SheenPainter(this.clock, this.shapes, this.accent, this.dark)
    : super(repaint: clock);
  final _SkeletonClock? clock;
  final Path Function(Size) shapes;
  final Color accent;
  final bool dark;
  Size? _shapeSize;
  Path? _shapePath;
  Rect? _sweep;
  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    if (clock?.running != true || size.isEmpty) return;
    if (_shapeSize != size) {
      _shapeSize = size;
      _shapePath = shapes(size);
      _sweep = Rect.fromLTWH(0, 0, size.width * .8, size.height);
      final light = Colors.white.withValues(alpha: dark ? .22 : .88);
      final mint = accent.withValues(alpha: dark ? .18 : .1);
      _paint.shader = LinearGradient(
        begin: const Alignment(-1, -.25),
        end: const Alignment(1, .25),
        colors: [Colors.transparent, mint, light, mint, Colors.transparent],
        stops: const [0, .25, .5, .75, 1],
      ).createShader(_sweep!);
    }
    final width = _sweep!.width;
    final x = -width + clock!.phase * (size.width + width * 2);
    canvas.save();
    canvas.clipPath(_shapePath!);
    canvas.translate(x, 0);
    canvas.drawRect(_sweep!, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheenPainter oldDelegate) =>
      clock != oldDelegate.clock ||
      shapes != oldDelegate.shapes ||
      accent != oldDelegate.accent ||
      dark != oldDelegate.dark;
}
