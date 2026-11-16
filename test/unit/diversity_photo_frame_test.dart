import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/templates/diversity_frame_specs.dart';
import 'package:snap_fit/shared/widgets/diversity_photo_frame.dart';

void main() {
  test(
    'hobby mounts retain a complete rectangular photo aperture at every size',
    () {
      expect(diversityFrameLabels, hasLength(9));
      expect(
        diversityFramePrices.keys,
        unorderedEquals(diversityFrameLabels.keys),
      );
      expect(
        diversityFramePrices.values.where((price) => price == 0),
        hasLength(3),
      );
      final apertureSignatures = <String>{};
      for (final style in diversityFrameLabels.keys) {
        for (final size in const [
          Size(48, 48),
          Size(500, 500),
          Size(600, 400),
          Size(400, 600),
        ]) {
          final insets = DiversityPhotoFrame.insets(style, size);
          final aperture = insets.deflateRect(Offset.zero & size);
          expect(aperture.width, greaterThan(0), reason: style);
          expect(aperture.height, greaterThan(0), reason: style);
          final outer = DiversityPhotoFrame.outer(style, size);
          // Sampling the full perimeter catches a decorative cut or eyelet
          // intruding into a portrait even when the center still fits.
          for (var n = 0; n <= 20; n++) {
            final x = aperture.left + aperture.width * n / 20;
            final y = aperture.top + aperture.height * n / 20;
            for (final point in [
              Offset(x, aperture.top),
              Offset(x, aperture.bottom),
              Offset(aperture.left, y),
              Offset(aperture.right, y),
            ]) {
              expect(
                outer.contains(point),
                isTrue,
                reason: '$style/$size/$point',
              );
            }
          }
          expect(
            outer.getBounds().left,
            greaterThanOrEqualTo(-.1),
            reason: '$style/$size/left',
          );
          expect(
            outer.getBounds().top,
            greaterThanOrEqualTo(-.1),
            reason: '$style/$size/top',
          );
          expect(
            outer.getBounds().right,
            lessThanOrEqualTo(size.width + .1),
            reason: '$style/$size/right',
          );
          expect(
            outer.getBounds().bottom,
            lessThanOrEqualTo(size.height + .1),
            reason: '$style/$size/bottom',
          );
        }
        final relative = DiversityPhotoFrame.insets(style, const Size(1, 1));
        apertureSignatures.add(
          '${relative.left}/${relative.top}/${relative.right}/${relative.bottom}',
        );
      }
      expect(apertureSignatures, hasLength(9));
    },
  );
}
