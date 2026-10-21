import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/data/gallery/photo_asset_image_provider.dart';

Uint8List browserPhotoFixture({int width = 20, int height = 30}) {
  final pixels = image.Image(width: width, height: height);
  image.fill(pixels, color: image.ColorRgb8(230, 100, 40));
  return Uint8List.fromList(image.encodePng(pixels));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'browser photos preserve exact original bytes, true MIME and separate preview',
    () async {
      final original = browserPhotoFixture();
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-a',
        name: 'camera.png',
        bytes: original,
      );
      expect(photo.originalBytes, orderedEquals(original));
      expect(photo.contentSha256, sha256.convert(original).toString());
      expect(photo.mimeType, 'image/png');
      expect(photo.extension, 'png');
      expect(photo.width, 20);
      expect(photo.height, 30);
      expect(photo.previewBytes.take(2), [0xff, 0xd8]);
      expect(identical(photo.previewBytes, photo.originalBytes), isFalse);
      expect(photo.id, startsWith('browser_'));
      expect(photo.id, isNot(contains(photo.contentSha256)));
      expect(photoAssetImageProvider(photo), isA<MemoryImage>());
      expect(
        (photoAssetImageProvider(photo, original: true) as MemoryImage).bytes,
        same(photo.originalBytes),
      );
    },
  );

  for (final orientation in [6, 8]) {
    test(
      'EXIF $orientation keeps the upright crop ratio and preview direction without changing original bytes',
      () async {
        final pixels = image.Image(width: 40, height: 60);
        for (var y = 0; y < pixels.height; y++) {
          for (var x = 0; x < pixels.width; x++) {
            final top = y < 30, left = x < 20;
            pixels.setPixelRgb(
              x,
              y,
              top ? (left ? 255 : 0) : (left ? 0 : 255),
              top ? (left ? 0 : 255) : (left ? 0 : 255),
              !top && left ? 255 : 0,
            );
          }
        }
        final raw = image.encodeJpg(pixels, quality: 100);
        final exif = image.ExifData()..imageIfd.orientation = orientation;
        final original = Uint8List.fromList(image.injectJpgExif(raw, exif)!);
        final photo = await BrowserPhotoAsset.fromBytes(
          ownerId: 'owner-a',
          name: 'rotated.jpg',
          bytes: original,
        );
        expect((photo.width, photo.height), (60, 40));
        expect(photo.orientation, 0);
        expect(photo.originalBytes, orderedEquals(original));
        expect(photo.contentSha256, sha256.convert(original).toString());
        final preview = image.decodeJpg(photo.previewBytes)!;
        expect((preview.width, preview.height), (60, 40));
        final topLeft = preview.getPixel(15, 10);
        if (orientation == 6) {
          // Clockwise: the original bottom-left blue quadrant is now top-left.
          expect(topLeft.b, greaterThan(topLeft.r + 80));
          expect(topLeft.b, greaterThan(topLeft.g + 80));
        } else {
          // Counterclockwise: original top-right green becomes top-left.
          expect(topLeft.g, greaterThan(topLeft.r + 80));
          expect(topLeft.g, greaterThan(topLeft.b + 80));
        }
        expect(
          image.decodeJpgExif(photo.previewBytes)?.imageIfd.orientation,
          anyOf(isNull, 1),
        );
      },
    );
  }

  test(
    'picker imports a valid subset, rejects unsupported/oversize before allocation and deduplicates content',
    () async {
      var reads = 0;
      final bytes = browserPhotoFixture();
      final repo = BrowserGalleryRepository(currentOwner: () => 'owner-a');
      BrowserPhotoFile file(String name) => BrowserPhotoFile(
        name: name,
        size: bytes.length,
        readBytes: () async {
          reads++;
          return bytes;
        },
      );
      final result = await repo.importFiles([
        file('first.png'),
        file('same-again.png'),
        BrowserPhotoFile(
          name: 'too-large.jpg',
          size: 50000001,
          readBytes: () async {
            throw StateError('must never read');
          },
        ),
        BrowserPhotoFile(
          name: 'invalid.gif',
          size: 4,
          readBytes: () async => Uint8List.fromList([71, 73, 70, 56]),
        ),
      ]);
      expect(reads, 2);
      expect(result.added.length, 1);
      expect(repo.photos.length, 1);
      expect(result.messages.join(' '), contains('50MB'));
      expect(result.messages.join(' '), contains('JPG'));
      final album = (await repo.loadAlbums()).single;
      expect(await repo.loadImagesPaged(album, 0, 40), repo.photos);
    },
  );

  test(
    'local import reports each file including duplicates and errors',
    () async {
      final bytes = browserPhotoFixture();
      final repository = BrowserGalleryRepository(
        currentOwner: () => 'owner-a',
      );
      final progress = <BrowserPhotoImportProgress>[];
      await repository.importFiles([
        for (final name in ['first.png', 'again.png'])
          BrowserPhotoFile(
            name: name,
            size: bytes.length,
            readBytes: () async => bytes,
          ),
        BrowserPhotoFile(
          name: 'too-big.jpg',
          size: 50000001,
          readBytes: () => throw StateError('must not read oversize file'),
        ),
      ], onProgress: progress.add);
      expect(
        progress.where((item) => item.isComplete).map((item) => item.state),
        [
          BrowserPhotoImportState.ready,
          BrowserPhotoImportState.duplicate,
          BrowserPhotoImportState.failed,
        ],
      );
      expect(progress.map((item) => item.total), everyElement(3));
      expect(
        progress.where((item) => item.isComplete).map((item) => item.fileName),
        ['first.png', 'again.png', 'too-big.jpg'],
      );
      expect(progress.last.message, contains('50MB'));
    },
  );

  test(
    'an account change during browser file read cannot expose or import the previous owner photo',
    () async {
      String? owner = 'owner-a';
      final bytes = browserPhotoFixture();
      final pending = Completer<Uint8List>();
      final repo = BrowserGalleryRepository(currentOwner: () => owner);
      final future = repo.importFiles([
        BrowserPhotoFile(
          name: 'private.png',
          size: bytes.length,
          readBytes: () => pending.future,
        ),
      ]);
      owner = 'owner-b';
      pending.complete(bytes);
      await expectLater(future, throwsA(isA<BrowserPhotoException>()));
      expect(repo.photos, isEmpty);
    },
  );

  test(
    'AI gallery import uses explicitly selected browser files without calling a native gallery',
    () async {
      final bytes = browserPhotoFixture();
      var picks = 0;
      final repo = BrowserGalleryRepository(
        currentOwner: () => 'owner-a',
        selectFiles: () async {
          picks++;
          return [
            BrowserPhotoFile(
              name: 'chosen.png',
              size: bytes.length,
              readBytes: () async => bytes,
            ),
          ];
        },
      );
      expect(await repo.requestPermission(), isTrue);
      expect(picks, 1);
      expect(repo.photos.length, 1);
      expect(await repo.requestPermission(), isTrue);
      expect(picks, 1);
    },
  );
}
