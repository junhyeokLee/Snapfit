import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/social/data/social_profile_photo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('publication re-encodes a real photo as a bounded PNG', () async {
    final source = await File(
      'assets/templates/original_editorial/images/travel_harbor.png',
    ).readAsBytes();
    final png = await prepareSocialProfilePhoto(source);
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(png.length, lessThanOrEqualTo(socialProfilePhotoMaxBytes));
    final buffer = await ui.ImmutableBuffer.fromUint8List(png);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    expect(descriptor.width, 1024);
    expect(descriptor.height, 683);
    descriptor.dispose();
    buffer.dispose();
    // A fresh canvas encoding contains no source camera or text metadata.
    final chunks = <String>[];
    for (var offset = 8; offset + 12 <= png.length;) {
      final length = ByteData.sublistView(png, offset, offset + 4).getUint32(0);
      chunks.add(String.fromCharCodes(png.sublist(offset + 4, offset + 8)));
      offset += length + 12;
    }
    expect(chunks, isNot(contains('eXIf')));
    expect(chunks, isNot(contains('tEXt')));
  });
  test('invalid or oversized inputs never reach upload', () async {
    await expectLater(
      prepareSocialProfilePhoto(Uint8List(0)),
      throwsFormatException,
    );
    await expectLater(
      prepareSocialProfilePhoto(Uint8List(socialProfilePhotoInputMaxBytes + 1)),
      throwsFormatException,
    );
    await expectLater(
      prepareSocialProfilePhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
}
