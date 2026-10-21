import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/web/web_design.dart';

/// Lets selection chrome keep a constant screen size while the document view
/// zooms. This value is presentation state and never changes layer geometry.
class WebEditorViewportScale extends InheritedWidget {
  const WebEditorViewportScale({
    super.key,
    required this.zoom,
    required super.child,
  });

  final double zoom;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebEditorViewportScale>()?.zoom ??
      1;

  @override
  bool updateShouldNotify(WebEditorViewportScale oldWidget) =>
      oldWidget.zoom != zoom;
}

/// A view transform only. The document keeps the same finite layout constraints
/// at every zoom level, so fitting or moving the view never resizes album data.
class WebEditorViewport extends StatefulWidget {
  const WebEditorViewport({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<WebEditorViewport> createState() => _WebEditorViewportState();
}

class _WebEditorViewportState extends State<WebEditorViewport>
    with WidgetsBindingObserver {
  static const _minimumZoom = .25;
  static const _maximumZoom = 3.0;

  final _viewportKey = GlobalKey();
  final _activePointers = <int>{};
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _viewportSize = Size.zero;
  bool _hovering = false;
  bool _spacePressed = false;
  bool _panning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_handleKey);
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant WebEditorViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      _spacePressed = false;
      _panning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handleKey);
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _activePointers.clear();
      _releasePanMode();
    }
  }

  bool get _currentRoute => ModalRoute.of(context)?.isCurrent != false;

  bool get _editingText {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    if (focused.widget is EditableText) return true;
    var editable = false;
    focused.visitAncestorElements((element) {
      if (element.widget is EditableText) {
        editable = true;
        return false;
      }
      return true;
    });
    return editable;
  }

  void _handleFocusChange() {
    if (_editingText) _releasePanMode();
  }

  bool get _canUsePanKey {
    final keyboard = HardwareKeyboard.instance;
    return widget.enabled &&
        _currentRoute &&
        !_editingText &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        !keyboard.isAltPressed;
  }

  void _releasePanMode() {
    if (!mounted || (!_spacePressed && !_panning)) return;
    setState(() {
      _spacePressed = false;
      _panning = false;
    });
  }

  bool _handleKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.space) return false;
    if (event is KeyUpEvent) {
      final owned = _spacePressed;
      if (owned && mounted) setState(() => _spacePressed = false);
      return owned;
    }
    if (!mounted ||
        !_hovering ||
        !_canUsePanKey) {
      return false;
    }
    if (!_spacePressed) setState(() => _spacePressed = true);
    return true;
  }

  Offset _boundedPan(Offset pan, double zoom) {
    // Keep the page reachable even after a long pan; fit always recenters it.
    final extra = math.max(0.0, zoom - 1) / 2 + .25;
    final maxX = _viewportSize.width * extra;
    final maxY = _viewportSize.height * extra;
    return Offset(pan.dx.clamp(-maxX, maxX), pan.dy.clamp(-maxY, maxY));
  }

  void _zoomAt(Offset anchor, double requestedZoom) {
    if (!widget.enabled || !_currentRoute || _viewportSize.isEmpty) return;
    final next = requestedZoom.clamp(_minimumZoom, _maximumZoom).toDouble();
    if (next == _zoom) return;
    final center = _viewportSize.center(Offset.zero);
    final ratio = next / _zoom;
    final pan = anchor - center - (anchor - center - _pan) * ratio;
    setState(() {
      _zoom = next;
      _pan = _boundedPan(pan, next);
    });
  }

  void _handleWheel(PointerSignalEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event is! PointerScrollEvent ||
        !widget.enabled ||
        _activePointers.isNotEmpty ||
        !_currentRoute ||
        _editingText ||
        !(keyboard.isControlPressed || keyboard.isMetaPressed) ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      signal.respond(allowPlatformDefault: false);
      final box = _viewportKey.currentContext?.findRenderObject();
      if (!mounted || box is! RenderBox || !box.hasSize) return;
      final anchor = box.globalToLocal(signal.position);
      final factor = math.exp(-event.scrollDelta.dy.clamp(-600, 600) * .002);
      _zoomAt(anchor, _zoom * factor);
    });
  }

  bool _canStartPan(PointerDownEvent event) =>
      widget.enabled &&
      _currentRoute &&
      !_editingText &&
      event.kind == PointerDeviceKind.mouse &&
      (event.buttons == kMiddleMouseButton ||
          (event.buttons == kPrimaryMouseButton &&
              _canUsePanKey &&
              (_spacePressed ||
                  HardwareKeyboard.instance.logicalKeysPressed.contains(
                    LogicalKeyboardKey.space,
                  ))));

  void _startPan() {
    if (widget.enabled && mounted) setState(() => _panning = true);
  }

  void _movePan(Offset delta) {
    if (!widget.enabled || !_panning || !_currentRoute) return;
    setState(() => _pan = _boundedPan(_pan + delta, _zoom));
  }

  void _endPan() {
    if (mounted && _panning) setState(() => _panning = false);
  }

  void _fit() {
    if (!widget.enabled || !_currentRoute) return;
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  Widget _controls(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        key: const ValueKey('web-editor-zoom-out'),
        tooltip: '화면 축소',
        onPressed: widget.enabled && _zoom > _minimumZoom
            ? () => _zoomAt(_viewportSize.center(Offset.zero), _zoom - .25)
            : null,
        icon: const Icon(Icons.remove, size: 18),
      ),
      Tooltip(
        message: '화면 맞춤 크기를 기준으로 한 보기 배율',
        child: SizedBox(
          width: 58,
          child: Text(
            '${(_zoom * 100).round()}%',
            key: const ValueKey('web-editor-zoom-percent'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WebPalette.of(context).ink,
            ),
          ),
        ),
      ),
      IconButton(
        key: const ValueKey('web-editor-zoom-in'),
        tooltip: '화면 확대',
        onPressed: widget.enabled && _zoom < _maximumZoom
            ? () => _zoomAt(_viewportSize.center(Offset.zero), _zoom + .25)
            : null,
        icon: const Icon(Icons.add, size: 18),
      ),
      const SizedBox(width: 6),
      TextButton.icon(
        key: const ValueKey('web-editor-zoom-fit'),
        onPressed: widget.enabled ? _fit : null,
        icon: const Icon(Icons.fit_screen, size: 18),
        label: const Text('화면 맞춤'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _viewportSize = constraints.biggest;
            _pan = _boundedPan(_pan, _zoom);
            final center = _viewportSize.center(Offset.zero);
            final translation = center * (1 - _zoom) + _pan;
            final transform = Matrix4.diagonal3Values(_zoom, _zoom, 1)
              ..setTranslationRaw(translation.dx, translation.dy, 0);
            return ClipRect(
              key: const ValueKey('web-editor-viewport'),
              child: MouseRegion(
                onEnter: (_) {
                  _hovering = true;
                  if (_canUsePanKey &&
                      HardwareKeyboard.instance.logicalKeysPressed.contains(
                        LogicalKeyboardKey.space,
                      )) {
                    setState(() => _spacePressed = true);
                  }
                },
                onExit: (_) {
                  _hovering = false;
                  if (!_panning && _spacePressed) {
                    setState(() => _spacePressed = false);
                  }
                },
                cursor: _panning
                    ? SystemMouseCursors.grabbing
                    : _spacePressed
                    ? SystemMouseCursors.grab
                    : MouseCursor.defer,
                child: Listener(
                  key: _viewportKey,
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: _handleWheel,
                  onPointerDown: (event) => _activePointers.add(event.pointer),
                  onPointerUp: (event) => _activePointers.remove(event.pointer),
                  onPointerCancel: (event) =>
                      _activePointers.remove(event.pointer),
                  child: RawGestureDetector(
                    behavior: HitTestBehavior.opaque,
                    gestures: {
                      _ViewportPanGestureRecognizer:
                          GestureRecognizerFactoryWithHandlers<
                            _ViewportPanGestureRecognizer
                          >(
                            _ViewportPanGestureRecognizer.new,
                            (recognizer) => recognizer
                              ..canStart = _canStartPan
                              ..onStart = _startPan
                              ..onUpdate = _movePan
                              ..onEnd = _endPan,
                          ),
                    },
                    child: IgnorePointer(
                      ignoring: !widget.enabled || _spacePressed || _panning,
                      child: Transform(
                        key: const ValueKey('web-editor-viewport-transform'),
                        alignment: Alignment.topLeft,
                        transform: transform,
                        child: WebEditorViewportScale(
                          zoom: _zoom,
                          child: SizedBox.expand(child: widget.child),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: WebPalette.of(context).line)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hint = Text(
              constraints.maxWidth >= 640
                  ? '드래그: 요소 이동 · Space+드래그: 화면 이동 · Ctrl/⌘+휠: 확대·축소'
                  : 'Space+드래그 화면 이동 · Ctrl/⌘+휠 확대·축소',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: WebPalette.of(context).muted,
              ),
            );
            if (constraints.maxWidth >= 640) {
              return Row(
                children: [
                  Expanded(child: hint),
                  const SizedBox(width: 12),
                  _controls(context),
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: _controls(context)),
                const SizedBox(height: 2),
                hint,
              ],
            );
          },
        ),
      ),
    ],
  );
}

/// Only the explicit viewport-pan chord joins the gesture arena. Normal mouse
/// drags remain entirely owned by the document's layer gesture recognizers.
class _ViewportPanGestureRecognizer extends OneSequenceGestureRecognizer {
  bool Function(PointerDownEvent)? canStart;
  VoidCallback? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;
  int? _pointer;
  Offset? _lastPosition;
  bool _accepted = false;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      _pointer == null && canStart?.call(event) == true;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointer = event.pointer;
    _lastPosition = event.position;
    startTrackingPointer(event.pointer);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleNonAllowedPointer(PointerDownEvent event) {}

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer) return;
    _accepted = true;
    onStart?.call();
  }

  @override
  void rejectGesture(int pointer) => stopTrackingPointer(pointer);

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent && _accepted) {
      final previous = _lastPosition;
      _lastPosition = event.position;
      if (previous != null) onUpdate?.call(event.position - previous);
    }
    stopTrackingIfPointerNoLongerDown(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final accepted = _accepted;
    _pointer = null;
    _lastPosition = null;
    _accepted = false;
    if (accepted) onEnd?.call();
  }

  @override
  String get debugDescription => 'web editor viewport pan';
}
