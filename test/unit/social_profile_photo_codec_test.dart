import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/features/social/data/social_profile_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final jpeg in [false, true]) {
    test(
      'photo codec normalizes ${jpeg ? 'JPEG' : 'PNG'} on this platform',
      () async {
        final source = img.Image(width: 1600, height: 1000);
        img.fill(source, color: img.ColorRgb8(71, 113, 92));
        final input = Uint8List.fromList(
          jpeg ? img.encodeJpg(source) : img.encodePng(source),
        );
        final png = await prepareSocialProfilePhoto(input);
        expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1024);
        expect(frame.image.height, 640);
        frame.image.dispose();
        codec.dispose();
      },
    );
  }
}
