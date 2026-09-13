import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/text_image_shader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'image-filled text keeps the same centered crop across scale and aspect',
    () async {
      final source = PictureRecorder();
      final canvas = Canvas(source);
      final colors = [
        const Color(0xFFFF0000),
        const Color(0xFF00FF00),
        const Color(0xFF0000FF),
        const Color(0xFFFFFF00),
      ];
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH((i % 2) * 6, (i ~/ 2) * 4, 6, 4),
          Paint()..color = colors[i],
        );
      }
      final sourcePicture = source.endRecording();
      final image = await sourcePicture.toImage(12, 8);
      sourcePicture.dispose();
      for (final size in [
        const Size(120, 80),
        const Size(240, 160),
        const Size(80, 160),
      ]) {
        final bounds = Rect.fromLTWH(10, 8, size.width, size.height);
        final recorder = PictureRecorder();
        final shader = textImageCoverShader(image, bounds);
        Canvas(recorder).drawRect(bounds, Paint()..shader = shader);
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(
          size.width.toInt() + 20,
          size.height.toInt() + 16,
        );
        final bytes = (await rendered.toByteData(
          format: ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        for (var i = 0; i < 4; i++) {
          final x = (10 + size.width * (i.isEven ? .25 : .75)).toInt();
          final y = (8 + size.height * (i < 2 ? .25 : .75)).toInt();
          final at = (y * rendered.width + x) * 4;
          final value = colors[i].toARGB32();
          expect(bytes.sublist(at, at + 4), [
            (value >> 16) & 255,
            (value >> 8) & 255,
            value & 255,
            255,
          ]);
        }
        rendered.dispose();
        picture.dispose();
        shader.dispose();
      }
      image.dispose();
    },
  );
}
