import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:snap_fit/features/album/printing/raster_print_pdf.dart';
import 'package:snap_fit/features/album/printing/srgb_profile.dart';

Map<String, ({int offset, int size})> _iccTags(Uint8List profile) {
  final bytes = ByteData.sublistView(profile);
  final count = bytes.getUint32(128);
  return {
    for (var index = 0; index < count; index++)
      ascii.decode(profile.sublist(132 + index * 12, 136 + index * 12)): (
        offset: bytes.getUint32(136 + index * 12),
        size: bytes.getUint32(140 + index * 12),
      ),
  };
}

String _tagType(Uint8List profile, ({int offset, int size}) tag) =>
    ascii.decode(profile.sublist(tag.offset, tag.offset + 4));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sRGB profile has genuine legacy v2 tags and valid stream bounds', () {
    final profile = printSrgbProfile;
    final bytes = ByteData.sublistView(profile);
    expect(bytes.getUint32(0), profile.length);
    expect(profile.sublist(8, 12), [2, 0x10, 0, 0]);
    expect(ascii.decode(profile.sublist(16, 24)), 'RGB XYZ ');
    expect(ascii.decode(profile.sublist(36, 40)), 'acsp');
    final tags = _iccTags(profile);
    for (final tag in tags.values) {
      expect(tag.offset % 4, 0);
      expect(tag.offset + tag.size, lessThanOrEqualTo(profile.length));
      expect(_tagType(profile, tag), isNot(anyOf('para', 'mluc')));
    }
    expect(_tagType(profile, tags['desc']!), 'desc');
    expect(_tagType(profile, tags['cprt']!), 'text');
    expect(latin1.decode(profile), contains('No copyright, use freely'));
    for (final name in ['rTRC', 'gTRC', 'bTRC']) {
      expect(_tagType(profile, tags[name]!), 'curv');
    }
  });

  test('legacy curve still describes the sRGB transfer and D50 primaries', () {
    final profile = printSrgbProfile;
    final bytes = ByteData.sublistView(profile);
    final tags = _iccTags(profile);
    for (final name in ['rTRC', 'gTRC', 'bTRC']) {
      final tag = tags[name]!;
      final count = bytes.getUint32(tag.offset + 8);
      expect(count, greaterThanOrEqualTo(1024));
      double sample(double encoded) =>
          bytes.getUint16(
            tag.offset + 12 + (encoded * (count - 1)).round() * 2,
          ) /
          65535;
      expect(sample(0), 0);
      expect(sample(1), 1);
      expect(sample(.03), closeTo(.03 / 12.92, .0001));
      expect(sample(.5), closeTo(.214041, .0003));
    }
    final expected = {
      'rXYZ': [.43604, .22249, .01392],
      'gXYZ': [.38512, .71690, .09707],
      'bXYZ': [.14305, .06061, .71391],
    };
    for (final entry in expected.entries) {
      final tag = tags[entry.key]!;
      expect(_tagType(profile, tag), 'XYZ ');
      for (var axis = 0; axis < 3; axis++) {
        expect(
          bytes.getInt32(tag.offset + 8 + axis * 4) / 65536,
          closeTo(entry.value[axis], .0001),
        );
      }
    }
  });

  testWidgets(
    'generated raster PDF preserves image and boxes with binary header',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawColor(const ui.Color(0xff234e70), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(8, 6);
        picture.dispose();
        final writer = RasterPrintPdf();
        try {
          await writer.addPage(
            image,
            sizeMm: const ui.Size(210, 160),
            trimMm: const ui.Rect.fromLTWH(5, 5, 200, 150),
          );
        } finally {
          image.dispose();
        }
        writer.repeatLastPage();
        final pdf = writer.save();
        final text = latin1.decode(pdf);
        expect(pdf.sublist(0, 9), ascii.encode('%PDF-1.4\n'));
        expect(pdf.sublist(9, 15), [0x25, 0xe2, 0xe3, 0xcf, 0xd3, 0x0a]);
        expect(RegExp(r'/Type /Page\b').allMatches(text).length, 2);
        expect(text, contains('/MediaBox [0 0 595.27559 453.54331]'));
        expect(
          text,
          contains('/TrimBox [14.17323 14.17323 581.10236 439.37008]'),
        );
        expect(text, contains('/BleedBox [0 0 595.27559 453.54331]'));
        expect(text, contains('/ColorSpace [/ICCBased'));
        expect(text, contains('/Alternate /DeviceRGB'));
        expect(text, isNot(contains('/SMask')));
        final imageObject = RegExp(
          r'/Subtype /Image /Width 8 /Height 6.*?/Length (\d+) >>\nstream\n',
        ).firstMatch(text)!;
        final jpeg = pdf.sublist(
          imageObject.end,
          imageObject.end + int.parse(imageObject.group(1)!),
        );
        final decoded = bitmap.decodeJpg(jpeg)!;
        expect((decoded.width, decoded.height, decoded.numChannels), (8, 6, 3));
        final pixel = decoded.getPixel(4, 3);
        expect(pixel.r, closeTo(0x23, 2));
        expect(pixel.g, closeTo(0x4e, 2));
        expect(pixel.b, closeTo(0x70, 2));
        final profileObject = RegExp(
          r'<< /N 3 /Alternate /DeviceRGB /Length (\d+) >>\nstream\n',
        ).firstMatch(text)!;
        expect(
          pdf.sublist(
            profileObject.end,
            profileObject.end + int.parse(profileObject.group(1)!),
          ),
          printSrgbProfile,
        );
        // Validate actual cross-reference offsets after the binary header change.
        final xref = RegExp(r'startxref\n(\d+)\n%%EOF').firstMatch(text)!;
        final offset = int.parse(xref.group(1)!);
        expect(text.substring(offset, offset + 5), 'xref\n');
        final entries = text.substring(offset).split('\n');
        for (var index = 3; index < entries.length; index++) {
          if (entries[index] == 'trailer') break;
          final entry = entries[index];
          final objectOffset = int.parse(entry.substring(0, 10));
          expect(
            text.substring(objectOffset),
            startsWith('${index - 2} 0 obj\n'),
          );
        }
      });
    },
  );
}
