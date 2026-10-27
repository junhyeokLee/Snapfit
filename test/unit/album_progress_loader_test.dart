import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress.dart';

// These tests exercise a real compute isolate, without a widget tree or the
// fake async clock used by widget tests. Only the loader's frame callbacks run.
class _MetadataBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void drawFrame() {}
}

void main() {
  final binding = _MetadataBinding();

  test(
    'a large document counts only-filled first interior in its worker',
    () async {
      final album = Album(
        targetPages: 2,
        coverLayersJson: jsonEncode({
          'padding': 'x' * (64 * 1024),
          'pages': [
            {'index': 0, 'isCover': true, 'layers': []},
            for (var page = 1; page <= 2; page++)
              {
                'index': page,
                'isCover': false,
                'layers': [
                  {
                    'type': 'IMAGE',
                    'templateContent': page != 1,
                    'payload': {
                      'previewUrl': page == 1
                          ? 'https://uploads.test/first.jpg'
                          : '',
                    },
                  },
                ],
              },
          ],
        }),
      );
      final request = AlbumProgressLoader.request(album);
      try {
        binding.handleBeginFrame(Duration.zero);
        binding.handleDrawFrame();
        final result = await request.result.timeout(const Duration(seconds: 5));
        expect(result!.completedPages, 1);
        expect(result.targetPages, 2);
        expect(result.ratio, .5);
      } finally {
        request.cancel();
      }
    },
  );

  for (final pressure in [false, true]) {
    test(
      'running metadata analysis is reused, memory pressure=$pressure',
      () async {
        final album = Album(
          id: 9030,
          ratio: '1',
          targetPages: 10,
          coverLayersJson: jsonEncode({
            'padding': 'x' * (64 * 1024),
            'printProduct': {
              'id': 'REDP_300_HARD',
              'trimWidthMm': 300,
              'trimHeightMm': 300,
            },
            'pages': [
              {'index': 0, 'layers': []},
              for (var index = 1; index <= 2; index++)
                {
                  'index': index,
                  'layers': [
                    {
                      'type': 'TEXT',
                      'templateContent': false,
                      'payload': {'text': '기록 $index'},
                    },
                  ],
                },
            ],
          }),
        );
        final first = AlbumProgressLoader.request(album);
        binding.handleBeginFrame(Duration.zero);
        binding.handleDrawFrame();
        first.cancel();
        expect(await first.result, isNull);
        if (pressure) MemoryPressureCaches.clear();
        final resumed = AlbumProgressLoader.request(album);
        try {
          // A replacement job would require a new frame. Finish without drawing
          // another frame to prove that this request joins the running isolate.
          final result = await resumed.result.timeout(
            const Duration(seconds: 5),
          );
          expect(result!.completedPages, 2);
          expect(result.coverSize!.productId, 'REDP_300_HARD');
          expect(result.coverSize!.realSize.width, 30);
          if (pressure) {
            expect(cachedAlbumProgress(album), isNull);
            expect(album.cachedPhysicalCoverSize, isNull);
          } else {
            expect(cachedAlbumProgress(album), same(result));
            expect(album.cachedPhysicalCoverSize, same(result.coverSize));
          }
        } finally {
          resumed.cancel();
        }
      },
    );
  }

  test(
    'large legacy documents remain unfinished and fresh edits are reanalyzed',
    () async {
      Album document({required bool verified}) => Album(
        id: 9040,
        targetPages: 2,
        totalPages: 24,
        coverLayersJson: jsonEncode({
          'padding': 'x' * (64 * 1024),
          'pages': [
            {'index': 0, 'layers': []},
            for (var page = 1; page <= 2; page++)
              {
                'index': page,
                'layers': [
                  {
                    'type': 'TEXT',
                    if (verified) 'templateContent': false,
                    'payload': {
                      'text': verified ? '직접 작성 $page' : '예시 문구 $page',
                    },
                  },
                ],
              },
          ],
        }),
      );
      final legacy = document(verified: false);
      final first = AlbumProgressLoader.request(legacy);
      binding.handleBeginFrame(Duration.zero);
      binding.handleDrawFrame();
      expect((await first.result)!.isCompleted, isFalse);
      expect(cachedAlbumProgress(legacy)!.completedPages, 0);
      final personal = document(verified: true);
      final updated = AlbumProgressLoader.request(personal);
      binding.handleBeginFrame(Duration.zero);
      binding.handleDrawFrame();
      expect((await updated.result)!.isCompleted, isTrue);
      expect(cachedAlbumProgress(personal)!.completedPages, 2);
      expect(cachedAlbumProgress(legacy)!.isCompleted, isFalse);
    },
  );
}
