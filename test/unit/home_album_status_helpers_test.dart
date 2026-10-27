import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_helpers.dart';

void main() {
  test(
    'legacy lock metadata does not claim another user is currently editing',
    () {
      const album = Album(
        id: 170,
        title: '성수동 카페 투어',
        coverImageUrl: 'https://example.com/cover.jpg',
        targetPages: 10,
        totalPages: 2,
        lockedBy: 'other-user',
        lockedById: 'other-id',
      );

      final status = getAlbumStatusInfo(album, 'my-id');

      expect(status.isLocked, isFalse);
      expect(status.label, '작성 중');
      expect(status.label, isNot(contains('other-user')));
    },
  );

  test('getAlbumStatusInfo returns done when pages are completed', () {
    final album = Album(
      id: 171,
      coverLayersJson: jsonEncode({
        'pages': [
          {'index': 0, 'layers': []},
          for (var i = 1; i <= 8; i++)
            {
              'index': i,
              'layers': [
                {
                  'type': 'TEXT',
                  'templateContent': false,
                  'payload': {'text': 'My page $i'},
                },
              ],
            },
        ],
      }),
      title: '완료 앨범',
      coverImageUrl: 'https://example.com/cover.jpg',
      targetPages: 8,
      totalPages: 8,
      lockedBy: null,
      lockedById: null,
    );

    final status = getAlbumStatusInfo(album, 'my-id');

    expect(status.isLocked, isFalse);
    expect(status.label, '작성 완료');
  });

  test('getAlbumStatusInfo returns working for in-progress album', () {
    const album = Album(
      id: 172,
      title: '진행중 앨범',
      coverImageUrl: 'https://example.com/cover.jpg',
      targetPages: 8,
      totalPages: 3,
      lockedBy: null,
      lockedById: null,
    );

    final status = getAlbumStatusInfo(album, 'my-id');

    expect(status.isLocked, isFalse);
    expect(status.label, '작성 중');
  });
}
