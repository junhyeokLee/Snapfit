import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/album_page_policy.dart';

void main() {
  test('new selections fit 20 to 80 interior pages in complete sheets', () {
    for (final count in [-1, 0, 1, 19, 20]) {
      expect(AlbumPagePolicy.normalize(count), 20);
    }
    expect(AlbumPagePolicy.normalize(21), 22);
    expect(AlbumPagePolicy.normalize(79), 80);
    expect(AlbumPagePolicy.normalize(81), 80);
    for (var count = 20; count <= 80; count += 2) {
      expect(AlbumPagePolicy.isValid(count), isTrue);
    }
    for (final count in [19, 21, 79, 81, 82]) {
      expect(AlbumPagePolicy.isValid(count), isFalse);
    }
  });

  test('template minimum preserves content beyond the print limit', () {
    expect(AlbumPagePolicy.minimumForContent(1), 20);
    expect(AlbumPagePolicy.minimumForContent(21), 22);
    expect(AlbumPagePolicy.minimumForContent(79), 80);
    expect(AlbumPagePolicy.minimumForContent(81), 82);
  });
}
