import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../controllers/layer_transform_geometry.dart';
import '../web/web_editor_viewport.dart';

export '../../controllers/layer_transform_geometry.dart'
    show ResizeHandlePosition;

class SelectionFrame extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final bool showHandles;
  final VoidCallback? onDelete;
  final Function(ScaleStartDetails)? onScaleStart;
  final Function(ScaleUpdateDetails)? onScaleUpdate;
  final Function(ScaleEndDetails)? onScaleEnd;
  final void Function(ResizeHandlePosition pos, DragStartDetails details)?
  onResizeStart;
  final void Function(ResizeHandlePosition pos, DragUpdateDetails details)?
  onResizeUpdate;
  final void Function(ResizeHandlePosition pos, DragEndDetails details)?
  onResizeEnd;

  const SelectionFrame({
    super.key,
    required this.child,
    required this.isSelected,
    this.onDelete,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.showHandles = true,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSelected) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main Content with Border
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? SnapFitColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: child,
        ),

        // Corners (Visual Anchors)
        if (showHandles) ...[
          _buildCorner(pos: ResizeHandlePosition.topLeft, top: -4, left: -4),
          _buildCorner(pos: ResizeHandlePosition.topRight, top: -4, right: -4),
          _buildCorner(
            pos: ResizeHandlePosition.bottomLeft,
            bottom: -4,
            left: -4,
          ),
          _buildCorner(
            pos: ResizeHandlePosition.bottomRight,
            bottom: -4,
            right: -4,
          ),
        ],
      ],
    );
  }

  Widget _buildCorner({
    required ResizeHandlePosition pos,
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onPanStart: onResizeStart == null
            ? null
            : (details) => onResizeStart!(pos, details),
        onPanUpdate: onResizeUpdate == null
            ? null
            : (details) => onResizeUpdate!(pos, details),
        onPanEnd: onResizeEnd == null
            ? null
            : (details) => onResizeEnd!(pos, details),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: SnapFitColors.accent, width: 2),
          ),
        ),
      ),
    );
  }
}

/// Full-canvas sibling controls: the hit targets are not clipped by a layer's
/// small unscaled box, and do not inherit that layer's own scale/rotation.
class WebSelectionFrame extends StatefulWidget {
  const WebSelectionFrame({
    super.key,
    required this.layerId,
    required this.geometry,
    required this.canvasSize,
    required this.viewportScale,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onCancel,
    required this.onRotateStart,
    required this.onRotateUpdate,
    required this.onRotateEnd,
    this.showHandles = true,
  });

  final String layerId;
  final LayerTransformGeometry geometry;
  final Size canvasSize;
  final double Function() viewportScale;
  final bool showHandles;
  final void Function(ResizeHandlePosition, DragStartDetails) onResizeStart;
  final void Function(ResizeHandlePosition, DragUpdateDetails) onResizeUpdate;
  final void Function(ResizeHandlePosition, DragEndDetails) onResizeEnd;
  final VoidCallback onCancel;
  final GestureDragStartCallback onRotateStart;
  final GestureDragUpdateCallback onRotateUpdate;
  final GestureDragEndCallback onRotateEnd;

  @override
  State<WebSelectionFrame> createState() => _WebSelectionFrameState();
}

class _WebSelectionFrameState extends State<WebSelectionFrame> {
  double _viewportScale = 1;

  @override
  void initState() {
    super.initState();
    _measureAfterLayout();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WebEditorViewportScale.of(context);
    _measureAfterLayout();
  }

  @override
  void didUpdateWidget(covariant WebSelectionFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    _measureAfterLayout();
  }

  void _measureAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scale = widget.viewportScale();
      if (!scale.isFinite ||
          scale <= 0 ||
          (scale - _viewportScale).abs() < .0001)
        return;
      setState(() => _viewportScale = scale);
    });
  }

  Offset _insideCanvas(Offset point, double inset) => Offset(
    point.dx.clamp(inset, mathMax(inset, widget.canvasSize.width - inset)),
    point.dy.clamp(inset, mathMax(inset, widget.canvasSize.height - inset)),
  );

  // Keeps this UI helper independent from dart:math's num return inference.
  double mathMax(double a, double b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final targetSize = 30 / _viewportScale;
    final dotSize = 10 / _viewportScale;
    final geometry = widget.geometry;
    final top =
        geometry.center +
        LayerTransformGeometry.rotate(
          Offset(0, -geometry.visibleSize.height / 2),
          geometry.rotation,
        );
    final rotatePoint = _insideCanvas(
      geometry.center +
          LayerTransformGeometry.rotate(
            Offset(0, -geometry.visibleSize.height / 2 - 30 / _viewportScale),
            geometry.rotation,
          ),
      targetSize / 2,
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _WebSelectionPainter(
                geometry: geometry,
                lineWidth: 1.5 / _viewportScale,
                rotationStart: widget.showHandles ? top : null,
                rotationEnd: widget.showHandles ? rotatePoint : null,
              ),
            ),
          ),
        ),
        if (widget.showHandles) ...[
          for (final corner in ResizeHandlePosition.values)
            _handle(
              key: ValueKey(
                'web-layer-resize-${widget.layerId}-${corner.name}',
              ),
              point: _insideCanvas(geometry.corner(corner), targetSize / 2),
              targetSize: targetSize,
              dotSize: dotSize,
              cursor:
                  corner == ResizeHandlePosition.topLeft ||
                      corner == ResizeHandlePosition.bottomRight
                  ? SystemMouseCursors.resizeUpLeftDownRight
                  : SystemMouseCursors.resizeUpRightDownLeft,
              onStart: (details) => widget.onResizeStart(corner, details),
              onUpdate: (details) => widget.onResizeUpdate(corner, details),
              onEnd: (details) => widget.onResizeEnd(corner, details),
            ),
          _handle(
            key: ValueKey('web-layer-rotate-${widget.layerId}'),
            point: rotatePoint,
            targetSize: targetSize,
            dotSize: 18 / _viewportScale,
            cursor: SystemMouseCursors.grab,
            onStart: widget.onRotateStart,
            onUpdate: widget.onRotateUpdate,
            onEnd: widget.onRotateEnd,
            rotation: true,
          ),
        ],
      ],
    );
  }

  Widget _handle({
    required Key key,
    required Offset point,
    required double targetSize,
    required double dotSize,
    required MouseCursor cursor,
    required GestureDragStartCallback onStart,
    required GestureDragUpdateCallback onUpdate,
    required GestureDragEndCallback onEnd,
    bool rotation = false,
  }) => Positioned(
    left: point.dx - targetSize / 2,
    top: point.dy - targetSize / 2,
    width: targetSize,
    height: targetSize,
    child: MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: onStart,
        onPanUpdate: onUpdate,
        onPanEnd: onEnd,
        onPanCancel: widget.onCancel,
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: SnapFitColors.accent,
                width: 1.5 / _viewportScale,
              ),
            ),
            child: rotation
                ? Icon(
                    Icons.rotate_right,
                    color: SnapFitColors.accent,
                    size: 13 / _viewportScale,
                  )
                : null,
          ),
        ),
      ),
    ),
  );
}

class _WebSelectionPainter extends CustomPainter {
  const _WebSelectionPainter({
    required this.geometry,
    required this.lineWidth,
    this.rotationStart,
    this.rotationEnd,
  });
  final LayerTransformGeometry geometry;
  final double lineWidth;
  final Offset? rotationStart;
  final Offset? rotationEnd;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SnapFitColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    canvas.save();
    canvas.translate(geometry.center.dx, geometry.center.dy);
    canvas.rotate(geometry.rotation);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset.zero,
        width: geometry.visibleSize.width,
        height: geometry.visibleSize.height,
      ),
      paint,
    );
    canvas.restore();
    if (rotationStart != null && rotationEnd != null)
      canvas.drawLine(rotationStart!, rotationEnd!, paint);
  }

  @override
  bool shouldRepaint(covariant _WebSelectionPainter oldDelegate) => true;
}
