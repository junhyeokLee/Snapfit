import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/presentation/utils/album_document_worker.dart';
import 'package:snap_fit/features/album/presentation/utils/album_progress_document.dart';

void main() {
  test(
    'large cover/progress tasks serialize and skip cancelled queued work',
    () async {
      final started = Completer<void>();
      final release = Completer<int>();
      var secondRan = false;
      var wanted = true;
      final first = AlbumDocumentWorker.run(() {
        started.complete();
        return release.future;
      }, isCurrent: () => true);
      final second = AlbumDocumentWorker.run(() async {
        secondRan = true;
        return 2;
      }, isCurrent: () => wanted);
      await started.future;
      expect(secondRan, isFalse);
      wanted = false;
      release.complete(1);
      expect(await first, 1);
      expect(await second, isNull);
      expect(secondRan, isFalse);
      final failed = AlbumDocumentWorker.run<int>(
        () async => throw StateError('worker'),
        isCurrent: () => true,
      );
      await expectLater(failed, throwsStateError);
      expect(
        await AlbumDocumentWorker.run(() async => 3, isCurrent: () => true),
        3,
      );
    },
  );

  test(
    'a cancelled consumer discards an already running worker result',
    () async {
      final started = Completer<void>();
      final release = Completer<int>();
      var wanted = true;
      final task = AlbumDocumentWorker.run(() {
        started.complete();
        return release.future;
      }, isCurrent: () => wanted);
      await started.future;
      wanted = false;
      release.complete(12);
      expect(await task, isNull);
      expect(
        await AlbumDocumentWorker.run(() async => 3, isCurrent: () => true),
        3,
      );
    },
  );

  test(
    'document metadata includes only saved print dimensions and progress',
    () {
      final result = analyzeAlbumDocument(
        jsonEncode({
          'printProduct': {
            'id': 'REDP_300_HARD',
            'trimWidthMm': 300,
            'trimHeightMm': 300,
            'history': ['must not cross the worker boundary'],
          },
          'pages': [
            {'index': 0, 'layers': []},
            {
              'index': 1,
              'layers': [
                {
                  'type': 'TEXT',
                  'templateContent': false,
                  'payload': {'text': '기록'},
                },
              ],
            },
          ],
        }),
      );
      expect(result.completedPages, 1);
      expect(result.printProduct, {
        'id': 'REDP_300_HARD',
        'trimWidthMm': 300,
        'trimHeightMm': 300,
      });
      final malformed = analyzeAlbumDocument('{bad json');
      expect(malformed.completedPages, 0);
      expect(malformed.productId, isNull);
    },
  );

  test(
    'progress count preserves cover exclusion for verified personal layers',
    () {
      final source = jsonEncode({
        'pages': [
          {
            'index': 0,
            'layers': [
              {
                'type': 'TEXT',
                'templateContent': false,
                'payload': {'text': '표지'},
              },
            ],
          },
          {
            'index': 1,
            'layers': [
              {
                'type': 'TEXT',
                'templateContent': false,
                'payload': {'text': '기록'},
              },
            ],
          },
          {
            'index': 2,
            'layers': [
              {
                'type': 'IMAGE',
                'templateContent': false,
                'payload': {'previewUrl': 'https://upload.example/photo.jpg'},
              },
            ],
          },
          {
            'index': 3,
            'layers': [
              {
                'type': 'TEXT',
                'templateContent': false,
                'payload': {'text': '  '},
              },
            ],
          },
          {
            'isCover': true,
            'index': 4,
            'layers': [
              {
                'type': 'TEXT',
                'templateContent': false,
                'payload': {'text': '커버'},
              },
            ],
          },
        ],
      });
      expect(countCompletedAlbumPages(source), 2);
      expect(countCompletedAlbumPages('{bad json'), 0);
      expect(countCompletedAlbumPages('{}'), 0);
    },
  );
}
