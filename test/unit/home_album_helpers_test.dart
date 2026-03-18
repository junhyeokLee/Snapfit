import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_helpers.dart';

void main() {
  group('home album progress helpers', () {
    test(
      'calculateAlbumProgress falls back to coverLayersJson when totalPages is 0',
      () {
        const coverLayersJson = '''
{
  "pages": [
    {
      "index": 0,
      "isCover": true,
      "layers": []
    },
    {
      "index": 1,
      "isCover": false,
      "layers": [
        {
          "type": "IMAGE",
          "payload": {
            "previewUrl": "https://example.com/1.jpg"
          }
        }
      ]
    },
    {
      "index": 2,
      "isCover": false,
      "layers": [
        {
          "type": "IMAGE",
          "payload": {
            "previewUrl": ""
          }
        }
      ]
    }
  ]
}
''';

        final album = Album(
          id: 1,
          coverLayersJson: coverLayersJson,
          totalPages: 0,
          targetPages: 5,
        );

        final progress = calculateAlbumProgress(album);

        expect(progress.completedPages, 1);
        expect(progress.targetPages, 5);
        expect(progress.ratio, 0.2);
        expect(progress.percentLabel, '20%');
      },
    );

    test(
      'calculateAlbumProgress prefers larger value between server totalPages and fallback',
      () {
        const coverLayersJson = '''
{
  "pages": [
    {"index": 0, "isCover": true, "layers": []},
    {"index": 1, "isCover": false, "layers": [{"type": "TEXT", "payload": {"text": "hello"}}]}
  ]
}
''';
        final album = Album(
          id: 1,
          coverLayersJson: coverLayersJson,
          totalPages: 3,
          targetPages: 6,
        );

        final progress = calculateAlbumProgress(album);
        expect(progress.completedPages, 3);
        expect(progress.percentLabel, '50%');
      },
    );

    test('isCompletedAlbum uses progress fallback parsing', () {
      const coverLayersJson = '''
{
  "pages": [
    {"index": 0, "isCover": true, "layers": []},
    {"index": 1, "isCover": false, "layers": [{"type": "TEXT", "payload": {"text": "a"}}]}
  ]
}
''';
      final album = Album(
        id: 1,
        coverLayersJson: coverLayersJson,
        totalPages: 0,
        targetPages: 1,
      );
      expect(isCompletedAlbum(album), isTrue);
      expect(isLiveEditingAlbum(album), isFalse);
    });
  });
}
