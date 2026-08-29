import 'package:flutter/material.dart';

/// Shared motion primitives for SnapFit's premium-feeling interactions.
///
/// Keep durations short and curves soft so motion supports the content instead
/// of making album/template editing feel slow.
class SnapFitMotion {
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);
  static const Duration pageTurn = Duration(milliseconds: 390);
  static const Duration pageTurnFast = Duration(milliseconds: 220);

  static const Curve entrance = Curves.easeOutCubic;
  static const Curve settle = Curves.easeOutQuart;
  static const Curve pageTurnCurve = Curves.easeOutQuart;
  static const Curve pageTurnExitCurve = Curves.easeInCubic;
}

class SnapFitFadeIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const SnapFitFadeIn({
    super.key,
    required this.child,
    this.duration = SnapFitMotion.slow,
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.035),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: delay + duration,
      curve: SnapFitMotion.entrance,
      builder: (context, value, child) {
        final totalMs = (delay + duration).inMilliseconds;
        final delayedValue = delay == Duration.zero
            ? value
            : ((value * totalMs - delay.inMilliseconds) /
                      duration.inMilliseconds)
                  .clamp(0.0, 1.0);
        return Opacity(
          opacity: delayedValue,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1 - delayedValue) * 100,
              beginOffset.dy * (1 - delayedValue) * 100,
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class SnapFitPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final BorderRadius? borderRadius;

  const SnapFitPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.borderRadius,
  });

  @override
  State<SnapFitPressable> createState() => _SnapFitPressableState();
}

class _SnapFitPressableState extends State<SnapFitPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed ? widget.pressedScale : 1,
      duration: SnapFitMotion.fast,
      curve: SnapFitMotion.settle,
      child: widget.child,
    );

    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        child: widget.borderRadius == null
            ? child
            : ClipRRect(borderRadius: widget.borderRadius!, child: child),
      ),
    );
  }
}

PageRoute<T> snapFitRoute<T>({required Widget page, RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: SnapFitMotion.medium,
    reverseTransitionDuration: SnapFitMotion.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: SnapFitMotion.entrance,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

PageRoute<T> snapFitAlbumOpenRoute<T>({
  required Widget page,
  RouteSettings? settings,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: SnapFitMotion.medium,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: curved,
        child: child,
        builder: (context, child) {
          final value = curved.value;
          final fold = 1 - value;
          final matrix = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..translate(18.0 * fold, 6.0 * fold)
            ..rotateY(-0.20 * fold)
            ..rotateX(0.025 * fold);

          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
              Opacity(
                opacity: (0.18 + (0.82 * value)).clamp(0.0, 1.0),
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: matrix,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final height = constraints.maxHeight;
                      final revealWidth = width * (0.72 + (0.28 * value));

                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: revealWidth,
                          height: height,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.centerLeft,
                              minWidth: width,
                              maxWidth: width,
                              minHeight: height,
                              maxHeight: height,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: child,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: 0.16 * fold,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x26FFFFFF),
                          Color(0x22000000),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
