import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/snapfit_design_tokens.dart';
export '../../core/theme/snapfit_design_tokens.dart' show SnapFitMotion;

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
    if (SnapFitMotion.reduced(context) || duration == Duration.zero)
      return child;
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
  final String? semanticLabel;
  final bool? selected;

  const SnapFitPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.975,
    this.borderRadius,
    this.semanticLabel,
    this.selected,
  });

  @override
  State<SnapFitPressable> createState() => _SnapFitPressableState();
}

class _SnapFitPressableState extends State<SnapFitPressable> {
  bool _pressed = false;
  bool _focused = false;
  bool _showFocus = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final child = AnimatedScale(
      scale: _pressed && !SnapFitMotion.reduced(context)
          ? widget.pressedScale
          : 1,
      duration: SnapFitMotion.duration(context, SnapFitMotion.fast),
      curve: SnapFitMotion.settle,
      child: widget.child,
    );

    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      focusable: enabled,
      focused: _focused,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        includeFocusSemantics: false,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onFocusChange: (value) => setState(() => _focused = value),
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius:
                  widget.borderRadius ??
                  BorderRadius.circular(SnapFitRadius.sm),
              border: _showFocus && enabled
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2,
                    )
                  : null,
            ),
            child: widget.borderRadius == null
                ? child
                : ClipRRect(borderRadius: widget.borderRadius!, child: child),
          ),
        ),
      ),
    );
  }
}

PageRoute<T> snapFitRoute<T>({required Widget page, RouteSettings? settings}) {
  return _SnapFitPageRoute<T>(
    settings: settings,
    transitionDuration: SnapFitMotion.medium,
    reverseTransitionDuration: SnapFitMotion.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (SnapFitMotion.reduced(context)) return child;
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

class _SnapFitPageRoute<T> extends PageRouteBuilder<T> {
  _SnapFitPageRoute({
    required super.pageBuilder,
    required super.transitionsBuilder,
    super.settings,
    super.transitionDuration,
    super.reverseTransitionDuration,
  });

  bool get _reduceMotion =>
      navigator != null && SnapFitMotion.reduced(navigator!.context);

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : super.transitionDuration;

  @override
  Duration get reverseTransitionDuration =>
      _reduceMotion ? Duration.zero : super.reverseTransitionDuration;
}

PageRoute<T> snapFitAlbumOpenRoute<T>({
  required Widget page,
  RouteSettings? settings,
}) {
  return _SnapFitPageRoute<T>(
    settings: settings,
    transitionDuration: SnapFitMotion.slow,
    reverseTransitionDuration: SnapFitMotion.fast,
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (SnapFitMotion.reduced(context)) return child;
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
