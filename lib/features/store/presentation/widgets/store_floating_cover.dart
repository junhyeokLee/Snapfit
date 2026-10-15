import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Only the transform ticks; native page layers remain in a repaint boundary.
class StoreFloatingCover extends StatefulWidget {
  const StoreFloatingCover({
    super.key,
    required this.child,
    required this.scrollController,
    required this.seed,
  });
  final Widget child;
  final ScrollController scrollController;
  final int seed;

  @override
  State<StoreFloatingCover> createState() => _StoreFloatingCoverState();
}

class _StoreFloatingCoverState extends State<StoreFloatingCover>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
    value: (widget.seed.abs() % 13) / 13,
  );
  bool _foreground = true;
  bool _checkScheduled = false;
  ScrollPosition? _position;

  void _scrollActivityChanged() {
    if (_position?.isScrollingNotifier.value ?? false) _motion.stop();
    _scheduleCheck();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController.addListener(_scheduleCheck);
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _position) {
      _position?.isScrollingNotifier.removeListener(_scrollActivityChanged);
      _position = position;
      _position?.isScrollingNotifier.addListener(_scrollActivityChanged);
    }
    _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _scheduleCheck();
  }

  void _scheduleCheck() {
    // Scroll activity already stops motion. Check geometry once after settling,
    // not once per card on every drag/ballistic frame.
    if (_position?.isScrollingNotifier.value ?? false) return;
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final viewport =
          Scrollable.maybeOf(context)?.context.findRenderObject() as RenderBox?;
      var visible = false;
      if (box != null && viewport != null && box.hasSize && viewport.hasSize) {
        final top = box.localToGlobal(Offset.zero).dy;
        final viewportTop = viewport.localToGlobal(Offset.zero).dy;
        visible =
            top < viewportTop + viewport.size.height &&
            top + box.size.height > viewportTop;
      }
      final animate =
          visible &&
          _foreground &&
          !(_position?.isScrollingNotifier.value ?? false) &&
          TickerMode.of(context) &&
          !MediaQuery.disableAnimationsOf(context);
      if (animate && !_motion.isAnimating) _motion.repeat();
      if (!animate) _motion.stop();
    });
  }

  @override
  void dispose() {
    _position?.isScrollingNotifier.removeListener(_scrollActivityChanged);
    widget.scrollController.removeListener(_scheduleCheck);
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: RepaintBoundary(child: widget.child),
    builder: (context, child) {
      final phase = math.sin(_motion.value * math.pi * 2);
      final reduced = MediaQuery.disableAnimationsOf(context);
      return Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..translate(0.0, reduced ? 0.0 : -3.0 * (phase + 1))
          ..rotateY(reduced ? -.06 : -.09 + phase * .035)
          ..rotateZ(reduced ? -.02 : -.02 + phase * .018),
        child: child,
      );
    },
  );
}
