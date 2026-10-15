import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Projects the back and side planes through the same camera as the front face.
class AlbumBookVolume extends StatefulWidget {
  const AlbumBookVolume({
    super.key,
    required this.depth,
    required this.child,
    this.motion,
    this.bindingColor = const Color(0xfff2f3f0),
    this.bindingArtwork,
  });

  final double depth;
  final Widget child;
  final Listenable? motion;
  final Color bindingColor;
  final Widget? bindingArtwork;

  static const double depthRatio = .026;

  static BorderRadius radiusForWidth(double width) => BorderRadius.only(
    topLeft: Radius.circular(width * .010),
    bottomLeft: Radius.circular(width * .010),
    topRight: Radius.circular(width * .018),
    bottomRight: Radius.circular(width * .018),
  );

  @override
  State<AlbumBookVolume> createState() => _AlbumBookVolumeState();
}

class _AlbumBookVolumeState extends State<AlbumBookVolume> {
  final _geometryKey = GlobalKey();

  Matrix4 _worldTransform() {
    final box = _geometryKey.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize
        ? box.getTransformTo(null)
        : Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: _geometryKey,
    clipBehavior: Clip.none,
    fit: StackFit.expand,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: AlbumBookDepthPainter(
              depth: widget.depth,
              worldTransform: _worldTransform,
              motion: widget.motion,
              bindingColor: widget.bindingColor,
              texturedBinding: widget.bindingArtwork != null,
            ),
          ),
        ),
      ),
      if (widget.bindingArtwork != null)
        Positioned.fill(
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: _BookBindingArtwork(
                depth: widget.depth,
                worldTransform: _worldTransform,
                motion: widget.motion,
                child: widget.bindingArtwork!,
              ),
            ),
          ),
        ),
      widget.child,
    ],
  );
}

class _BookProjection {
  _BookProjection(Size size, double? depth, Matrix4? worldTransform) {
    final camera = Matrix4.copy(worldTransform ?? Matrix4.identity());
    final zScale = AlbumBookDepthPainter._axisScale(camera, 2);
    camera.multiply(
      Matrix4.identity()
        ..setEntry(
          0,
          2,
          -.08 * zScale / AlbumBookDepthPainter._axisScale(camera, 0),
        )
        ..setEntry(
          1,
          2,
          .025 * zScale / AlbumBookDepthPainter._axisScale(camera, 1),
        ),
    );
    final inverse = AlbumBookDepthPainter._plane(camera, 0);
    valid = inverse.invert().abs() >= .0000001;
    thickness = depth ?? size.width * AlbumBookVolume.depthRatio;
    front = inverse..multiply(camera);
  }

  late final bool valid;
  late final double thickness;
  late final Matrix4 front;

  Matrix4 atDepth(double z) => AlbumBookDepthPainter._plane(front, z);
  Offset on(Matrix4 plane, double x, double y) =>
      MatrixUtils.transformPoint(plane, Offset(x, y));

  Path bindingPath(Size size) {
    final back = atDepth(thickness);
    final overlap = size.width * .002;
    final side = Path()
      ..addPolygon([
        Offset(overlap, 0),
        Offset(overlap, size.height),
        on(back, 0, size.height),
        on(back, 0, 0),
      ], true);
    final rounded = Path()
      ..addRRect(
        AlbumBookVolume.radiusForWidth(size.width).toRRect(Offset.zero & size),
      );
    final silhouette = Path.combine(
      PathOperation.union,
      rounded,
      rounded.transform(back.storage),
    );
    return Path.combine(PathOperation.intersect, side, silhouette);
  }

  Matrix4 bindingTransform(Size size) {
    // Source x=0 meets the front; the next narrow strip wraps towards the back.
    final transform = Matrix4.identity();
    final dz = thickness / (size.width * .02);
    final dx = .002 / .02;
    final overlap = size.width * .002;
    for (final row in [0, 1, 3]) {
      transform.setEntry(
        row,
        0,
        front.entry(row, 2) * dz - front.entry(row, 0) * dx,
      );
      transform.setEntry(row, 1, front.entry(row, 1));
      transform.setEntry(
        row,
        3,
        front.entry(row, 3) + front.entry(row, 0) * overlap,
      );
    }
    return transform;
  }
}

class _BookBindingArtwork extends SingleChildRenderObjectWidget {
  const _BookBindingArtwork({
    required this.depth,
    required this.worldTransform,
    this.motion,
    required super.child,
  });

  final double depth;
  final Matrix4 Function() worldTransform;
  final Listenable? motion;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBookBinding(
    depth: depth,
    worldTransform: worldTransform,
    motion: motion,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBookBinding renderObject,
  ) {
    renderObject
      ..bookThickness = depth
      ..worldTransform = worldTransform
      ..motion = motion;
    renderObject.markNeedsPaint();
  }
}

class _RenderBookBinding extends RenderProxyBox {
  _RenderBookBinding({
    required double depth,
    required this.worldTransform,
    Listenable? motion,
  }) : bookThickness = depth,
       _motion = motion;

  double bookThickness;
  Matrix4 Function() worldTransform;
  Listenable? _motion;

  set motion(Listenable? value) {
    if (value == _motion) return;
    if (attached) _motion?.removeListener(markNeedsPaint);
    _motion = value;
    if (attached) _motion?.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _motion?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  Rect get paintBounds {
    if (!hasSize) return super.paintBounds;
    final projection = _BookProjection(size, bookThickness, worldTransform());
    return projection.valid
        ? projection.bindingPath(size).getBounds().inflate(1)
        : Rect.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty || child == null) return;
    final projection = _BookProjection(size, bookThickness, worldTransform());
    if (!projection.valid) return;
    final path = projection.bindingPath(size);
    final bounds = path.getBounds();
    if (bounds.width < .01 || bounds.height < .01) return;
    context.pushClipPath(needsCompositing, offset, bounds, path, (
      context,
      offset,
    ) {
      context.pushTransform(
        needsCompositing,
        offset,
        projection.bindingTransform(size),
        (context, offset) {
          context.paintChild(child!, offset);
        },
      );
    }, clipBehavior: Clip.hardEdge);
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.black.withValues(alpha: .16),
            Colors.black.withValues(alpha: .08),
          ],
        ).createShader(bounds),
    );
    canvas.restore();
  }
}

class AlbumBookDepthPainter extends CustomPainter {
  AlbumBookDepthPainter({
    this.depth,
    this.worldTransform,
    this.bindingColor = const Color(0xfff2f3f0),
    this.texturedBinding = false,
    Listenable? motion,
  }) : super(repaint: motion);

  final double? depth;
  final Matrix4 Function()? worldTransform;
  final Color bindingColor;
  final bool texturedBinding;

  static double _axisScale(Matrix4 matrix, int column) {
    final w = matrix.entry(3, 3);
    if (w.abs() < .0000001) return 1;
    var lengthSquared = 0.0;
    for (var row = 0; row < 3; row++) {
      final value =
          (matrix.entry(row, column) -
              matrix.entry(row, 3) * matrix.entry(3, column) / w) /
          w;
      lengthSquared += value * value;
    }
    return math.sqrt(lengthSquared).clamp(.0001, double.infinity);
  }

  // Flutter canvases flatten z at layer boundaries. Project the real 3D corners,
  // then inverse-map them into the front plane to avoid losing the side faces.
  static Matrix4 _plane(Matrix4 camera, double z) {
    final plane = Matrix4.identity();
    for (final row in [0, 1, 3]) {
      plane.setEntry(row, 0, camera.entry(row, 0));
      plane.setEntry(row, 1, camera.entry(row, 1));
      plane.setEntry(row, 3, camera.entry(row, 3) + z * camera.entry(row, 2));
    }
    return plane;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final projection = _BookProjection(size, depth, worldTransform?.call());
    if (!projection.valid) return;
    final thickness = projection.thickness;
    final atDepth = projection.atDepth;
    final back = atDepth(thickness);
    final board = thickness * .12;
    final paperFront = atDepth(board);
    final paperBack = atDepth(thickness - board);
    Offset on(Matrix4 plane, double x, double y) =>
        MatrixUtils.transformPoint(plane, Offset(x, y));

    final cloth = Color.lerp(const Color(0xffe9ece6), bindingColor, .24)!;
    final rear = Path()
      ..addRRect(
        AlbumBookVolume.radiusForWidth(size.width).toRRect(Offset.zero & size),
      );
    canvas.drawPath(rear.transform(back.storage), Paint()..color = cloth);

    void face(List<Offset> corners, Gradient gradient) {
      if (corners.any((point) => !point.dx.isFinite || !point.dy.isFinite))
        return;
      final path = Path()..addPolygon(corners, true);
      final bounds = path.getBounds();
      if (bounds.width < .01 || bounds.height < .01) return;
      canvas.drawPath(path, Paint()..shader = gradient.createShader(bounds));
    }

    const paper = <Color>[
      Color(0xffeef0e9),
      Color(0xffe0e4dc),
      Color(0xffe8ebe3),
    ];
    final inset = size.width * .018;
    for (final y in [size.width * .004, size.height - size.width * .004]) {
      face(
        [
          on(paperFront, inset, y),
          on(paperFront, size.width - inset, y),
          on(paperBack, size.width - inset, y),
          on(paperBack, inset, y),
        ],
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: paper,
        ),
      );
    }
    final right = size.width - size.width * .004;
    face([
      on(paperFront, right, inset),
      on(paperFront, right, size.height - inset),
      on(paperBack, right, size.height - inset),
      on(paperBack, right, inset),
    ], const LinearGradient(colors: paper));
    if (!texturedBinding)
      face(
        [
          Offset.zero,
          Offset(0, size.height),
          on(back, 0, size.height),
          on(back, 0, 0),
        ],
        LinearGradient(
          colors: [
            Color.lerp(cloth, Colors.white, .18)!,
            Color.lerp(cloth, Colors.black, .035)!,
          ],
        ),
      );
  }

  @override
  bool shouldRepaint(covariant AlbumBookDepthPainter oldDelegate) => true;
}
