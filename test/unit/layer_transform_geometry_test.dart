import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_transform_geometry.dart';

void main() {
  test('scaled rotated bounds use the unscaled render centre', () {
    const geometry = LayerTransformGeometry(
      position: Offset(100, 200),
      baseSize: Size(120, 80),
      scale: 2,
      rotation: math.pi / 2,
    );
    expect(geometry.bounds.left, closeTo(80, .000001));
    expect(geometry.bounds.top, closeTo(120, .000001));
    expect(geometry.bounds.right, closeTo(240, .000001));
    expect(geometry.bounds.bottom, closeTo(360, .000001));
  });
  for (final corner in ResizeHandlePosition.values) {
    for (final degrees in [0, 30, 90, -135]) {
      for (final growth in [-.4, .4]) {
        test(
          '${corner.name}, $degrees degrees, $growth preserves the opposite corner',
          () {
            final angle = degrees * math.pi / 180;
            final before = LayerTransformGeometry(
              position: const Offset(100, 150),
              baseSize: const Size(120, 80),
              scale: 1.4,
              rotation: angle,
            );
            final direction = LayerTransformGeometry.cornerDirection(corner);
            final opposite =
                Offset(160, 190) -
                LayerTransformGeometry.rotate(
                  Offset(direction.dx * 84, direction.dy * 56),
                  angle,
                );
            final resized = before.resize(
              handle: corner,
              displacement: LayerTransformGeometry.rotate(
                Offset(direction.dx * 120 * growth, direction.dy * 80 * growth),
                angle,
              ),
            );
            expect(resized.scale, closeTo(1.4 + growth, .000001));
            final afterOpposite =
                resized.center -
                LayerTransformGeometry.rotate(
                  Offset(
                    direction.dx * 60 * resized.scale,
                    direction.dy * 40 * resized.scale,
                  ),
                  angle,
                );
            expect((afterOpposite - opposite).distance, lessThan(.000001));
            expect(resized.visibleSize.aspectRatio, closeTo(1.5, .000001));
          },
        );
      }
    }
  }

  test(
    'large inward and outward movement clamps without flipping the anchor',
    () {
      const geometry = LayerTransformGeometry(
        position: Offset(80, 100),
        baseSize: Size(100, 80),
        scale: 1,
        rotation: 0,
      );
      final small = geometry.resize(
        handle: ResizeHandlePosition.bottomRight,
        displacement: const Offset(-1000, -1000),
      );
      final large = geometry.resize(
        handle: ResizeHandlePosition.bottomRight,
        displacement: const Offset(1000, 1000),
      );
      expect(small.scale, .3);
      expect(large.scale, 3);
      expect(small.corner(ResizeHandlePosition.topLeft), const Offset(80, 100));
      expect(large.corner(ResizeHandlePosition.topLeft), const Offset(80, 100));
    },
  );

  test('resize uses total displacement rather than the latest event delta', () {
    const geometry = LayerTransformGeometry(
      position: Offset(80, 100),
      baseSize: Size(100, 80),
      scale: 1,
      rotation: 0,
    );
    final first = geometry.resize(
      handle: ResizeHandlePosition.topRight,
      displacement: const Offset(20, -16),
    );
    final second = geometry.resize(
      handle: ResizeHandlePosition.topRight,
      displacement: const Offset(50, -40),
    );
    expect(first.scale, closeTo(1.2, .000001));
    expect(second.scale, closeTo(1.5, .000001));
  });

  test(
    'rotation crosses the atan boundary and Shift snaps to fifteen degrees',
    () {
      const geometry = LayerTransformGeometry(
        position: Offset(0, 0),
        baseSize: Size(100, 100),
        scale: 1,
        rotation: 0,
      );
      final start =
          geometry.center +
          LayerTransformGeometry.rotate(
            const Offset(100, 0),
            179 * math.pi / 180,
          );
      final end =
          geometry.center +
          LayerTransformGeometry.rotate(
            const Offset(100, 0),
            -168 * math.pi / 180,
          );
      expect(
        geometry.rotationAt(initialPointer: start, pointer: end) *
            180 /
            math.pi,
        closeTo(13, .000001),
      );
      expect(
        geometry.rotationAt(initialPointer: start, pointer: end, snap: true) *
            180 /
            math.pi,
        closeTo(15, .000001),
      );
      expect(
        geometry.rotationAt(initialPointer: geometry.center, pointer: end),
        0,
      );
    },
  );
}
