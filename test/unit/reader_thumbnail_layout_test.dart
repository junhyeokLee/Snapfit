import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/utils/reader_image_quality.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_thumbnail_strip.dart';

void main() {
  test(
    'constant-time spread indices preserve cover pairs and the final page',
    () {
      for (var count = 0; count <= 128; count++) {
        final expected = <List<int>>[
          if (count > 0) [0],
          for (var page = 1; page < count; page += 2)
            [page, if (page + 1 < count) page + 1],
        ];
        expect(AlbumReaderThumbnailStrip.spreadCount(count), expected.length);
        expect(AlbumReaderThumbnailStrip.spreads(count), expected);
        for (var index = 0; index < expected.length; index++) {
          expect(
            AlbumReaderThumbnailStrip.spreadPages(index, count),
            expected[index],
          );
        }
      }
      expect(AlbumReaderThumbnailStrip.spreadCount(1000000000), 500000001);
      expect(AlbumReaderThumbnailStrip.spreadPages(500000000, 1000000000), [
        999999999,
      ]);
    },
  );

  test('invalid spread indices remain out of range', () {
    expect(AlbumReaderThumbnailStrip.spreadCount(-1), 0);
    for (final input in [(0, 0), (-1, 10), (6, 10)]) {
      expect(
        () => AlbumReaderThumbnailStrip.spreadPages(input.$1, input.$2),
        throwsRangeError,
      );
    }
  });

  test(
    'thumbnail density is bucketed while full reader quality is unchanged',
    () {
      expect(readerThumbnailDecodeWidth(const Size(46, 46), 3), 192);
      expect(readerThumbnailDecodeWidth(const Size(22, 22), 3), 128);
      expect(readerThumbnailDecodeWidth(const Size(70, 105), 3), 320);
      expect(readerThumbnailDecodeWidth(const Size(1000, 2000), 4), 512);
      expect(readerThumbnailDecodeWidth(Size.zero, 3), 128);
      expect(readerThumbnailDecodeWidth(const Size(100, 100), double.nan), 128);
      expect(
        readerThumbnailDecodeWidth(const Size(double.infinity, 100), 3),
        128,
      );
      expect(readerPageDecodeWidth(const Size(180, 240), 3), 720);
      expect(readerPageDecodeWidth(const Size(900, 1200), 3), 1600);
      expect(readerCaptureByteBudget, 16 * 1024 * 1024);
    },
  );
}
