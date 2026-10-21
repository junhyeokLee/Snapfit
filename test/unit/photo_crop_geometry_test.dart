import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/utils/photo_crop_geometry.dart';

Offset _sourcePoint({
  required Size photo,
  required Size viewport,
  required Alignment alignment,
  required double zoom,
  required Offset point,
}) {
  final covered = PhotoCropGeometry.coveredSize(photo, viewport, zoom: zoom);
  return Offset(
    (point.dx + (covered.width - viewport.width) * (alignment.x + 1) / 2) /
        covered.width,
    (point.dy + (covered.height - viewport.height) * (alignment.y + 1) / 2) /
        covered.height,
  );
}

void main() {
  test('portrait in a wide cover requires review without guessing a face', () {
    expect(
      PhotoCropGeometry.visibleFraction(
        const Size(600, 1200),
        const Size(400, 200),
      ),
      .25,
    );
    expect(
      PhotoCropGeometry.needsReview(
        const Size(600, 1200),
        const Size(400, 200),
      ),
      true,
    );
    expect(
      PhotoCropGeometry.needsReview(
        const Size(1200, 600),
        const Size(400, 200),
      ),
      false,
    );
    expect(
      PhotoCropGeometry.needsReview(Size.zero, const Size(400, 200)),
      false,
    );
  });

  for (final photo in [const Size(600, 1200), const Size(1800, 600)]) {
    for (final zoom in [1.0, 1.8, 4.0]) {
      test('drag follows the photograph at $photo zoom $zoom', () {
        const viewport = Size(400, 240);
        const alignment = Alignment(.1, -.15);
        const delta = Offset(9, -13);
        const point = Offset(180, 110);
        final moved = PhotoCropGeometry.move(
          photo: photo,
          viewport: viewport,
          alignment: alignment,
          previousZoom: zoom,
          zoom: zoom,
          focalPoint: point + delta,
          delta: delta,
        );
        final before = _sourcePoint(
          photo: photo,
          viewport: viewport,
          alignment: alignment,
          zoom: zoom,
          point: point,
        );
        final after = _sourcePoint(
          photo: photo,
          viewport: viewport,
          alignment: moved,
          zoom: zoom,
          point: point + delta,
        );
        final covered = PhotoCropGeometry.coveredSize(
          photo,
          viewport,
          zoom: zoom,
        );
        if (covered.width > viewport.width + .01) {
          expect(after.dx, closeTo(before.dx, 1e-9));
        } else {
          expect(moved.x, alignment.x);
        }
        if (covered.height > viewport.height + .01) {
          expect(after.dy, closeTo(before.dy, 1e-9));
        } else {
          expect(moved.y, alignment.y);
        }
      });
    }
  }

  test('pinch keeps the same source point under an off-centre finger', () {
    const photo = Size(600, 1200);
    const viewport = Size(400, 240);
    const alignment = Alignment(.15, -.3);
    const point = Offset(140, 80);
    final moved = PhotoCropGeometry.move(
      photo: photo,
      viewport: viewport,
      alignment: alignment,
      previousZoom: 1.5,
      zoom: 2,
      focalPoint: point,
      delta: Offset.zero,
    );
    final before = _sourcePoint(
      photo: photo,
      viewport: viewport,
      alignment: alignment,
      zoom: 1.5,
      point: point,
    );
    final after = _sourcePoint(
      photo: photo,
      viewport: viewport,
      alignment: moved,
      zoom: 2,
      point: point,
    );
    expect(after.dx, closeTo(before.dx, 1e-9));
    expect(after.dy, closeTo(before.dy, 1e-9));
  });

  test('edge drags remain covered and invalid sizes retain existing crop', () {
    final moved = PhotoCropGeometry.move(
      photo: const Size(600, 1200),
      viewport: const Size(400, 240),
      alignment: Alignment.center,
      previousZoom: 2,
      zoom: 2,
      focalPoint: const Offset(200, 120),
      delta: const Offset(10000, -10000),
    );
    expect(moved, const Alignment(-1, 1));
    expect(
      PhotoCropGeometry.move(
        photo: Size.zero,
        viewport: const Size(400, 240),
        alignment: const Alignment(.3, -.4),
        previousZoom: 1,
        zoom: 2,
        focalPoint: const Offset(200, 120),
        delta: const Offset(10, 20),
      ),
      const Alignment(.3, -.4),
    );
  });
}
