// The browser recovery controller is exercised with an in-memory image cache
// under the VM. There are no storage credentials, HTTP calls or file writes.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
// The cache-manager FileInfo contract uses package:file; this is test-only RAM.
// ignore: depend_on_referenced_packages
import 'package:file/memory.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

class _MemoryImages extends Fake
    implements BaseCacheManager, ImageCacheManager {
  final requested = <String>[];
  final file = MemoryFileSystem().file('/photo.png')
    ..writeAsBytesSync(browserPhotoFixture());
  bool failFirstDownload = true;

  // Native CachedNetworkImage requires this capability when disk resize
  // options are set. The fixture supplies a ready in-memory image directly.
  @override
  Stream<FileResponse> getImageFile(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
    int? maxHeight,
    int? maxWidth,
  }) => getFileStream(
    url,
    key: key,
    headers: headers,
    withProgress: withProgress,
  );

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requested.add(url);
    if (failFirstDownload && url.endsWith('/first')) {
      throw StateError('temporary_image_download_failure');
    }
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(hours: 1)),
      url,
    );
  }
}

Widget _wrap(Widget child, {double width = 320, double height = 220}) =>
    MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

Future<void> _until(WidgetTester tester, Finder target) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (target.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Image state did not settle');
}

void main() {
  testWidgets(
    'web download failure is re-signed once on click and recovers without reload',
    (tester) async {
      final cache = _MemoryImages();
      var resolutions = 0;
      await tester.pumpWidget(
        _wrap(
          SnapfitImage(
            urlOrGs: 'supabase://album-assets/recovery-test-cover/photo.jpg',
            enableWebStorageRecoveryForTesting: true,
            resolveStorageUrlForTesting: (_) async => ++resolutions == 1
                ? 'https://fixture.invalid/first'
                : 'https://fixture.invalid/fresh',
            cacheManager: cache,
            imageBuilder: (_, __) => const Text('photo decoded'),
          ),
        ),
      );
      await _until(
        tester,
        find.byKey(const ValueKey('web-storage-image-retry')),
      );
      expect(resolutions, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(resolutions, 1); // A failure never starts an automatic retry loop.
      await tester.tap(find.byKey(const ValueKey('web-storage-image-retry')));
      await _until(tester, find.text('photo decoded'));
      expect(resolutions, 2);
      expect(cache.requested, [
        'https://fixture.invalid/first',
        'https://fixture.invalid/fresh',
      ]);
      expect(
        find.byKey(const ValueKey('web-storage-image-retry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: kIsWeb,
  );

  testWidgets(
    'web signing failure can retry without an unhandled bookkeeping error',
    (tester) async {
      final cache = _MemoryImages()..failFirstDownload = false;
      var resolutions = 0;
      await tester.pumpWidget(
        _wrap(
          SnapfitImage(
            urlOrGs: 'supabase://album-assets/recovery-test-sign/photo.jpg',
            enableWebStorageRecoveryForTesting: true,
            resolveStorageUrlForTesting: (_) async {
              if (++resolutions == 1)
                throw StateError('temporary_signing_failure');
              return 'https://fixture.invalid/signed-again';
            },
            cacheManager: cache,
            imageBuilder: (_, __) => const Text('signed photo decoded'),
          ),
          width: 48,
          height: 48,
        ),
      );
      await _until(tester, find.byTooltip('사진 다시 불러오기'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('사진 다시 불러오기'));
      await _until(tester, find.text('signed photo decoded'));
      expect(resolutions, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: kIsWeb,
  );

  testWidgets(
    'custom web placeholder and error stay unchanged without a retry overlay',
    (tester) async {
      final resolution = Completer<String>();
      await tester.pumpWidget(
        _wrap(
          SnapfitImage(
            urlOrGs: 'supabase://album-assets/recovery-custom/photo.jpg',
            enableWebStorageRecoveryForTesting: true,
            resolveStorageUrlForTesting: (_) => resolution.future,
            placeholder: const Text('custom pending'),
            error: const Text('custom failure'),
          ),
        ),
      );
      expect(find.text('custom pending'), findsOneWidget);
      resolution.completeError(StateError('not available'));
      await tester.pumpAndSettle();
      expect(find.text('custom failure'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('web-storage-image-retry')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('native storage failure retains the existing custom error path', (
    tester,
  ) async {
    var resolutions = 0;
    await tester.pumpWidget(
      _wrap(
        SnapfitImage(
          urlOrGs: 'supabase://album-assets/recovery-native/photo.jpg',
          enableWebStorageRecoveryForTesting: false,
          resolveStorageUrlForTesting: (_) async {
            resolutions++;
            throw StateError('native resolver failed');
          },
          error: const Text('native custom failure'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('native custom failure'), findsOneWidget);
    expect(find.byKey(const ValueKey('web-storage-image-retry')), findsNothing);
    expect(resolutions, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'native cache, builder and URL options retain their normal values',
    (tester) async {
      final cache = _MemoryImages()..failFirstDownload = false;
      await tester.pumpWidget(
        _wrap(
          SnapfitImage(
            urlOrGs:
                'supabase://album-assets/recovery-native-options/photo.jpg',
            enableWebStorageRecoveryForTesting: false,
            resolveStorageUrlForTesting: (_) async =>
                'https://fixture.invalid/native-options',
            cacheManager: cache,
            memCacheWidth: 180,
            maxWidthDiskCache: 500,
            fit: BoxFit.contain,
            alignment: Alignment.topRight,
            imageBuilder: (_, __) => const Text('native photo decoded'),
          ),
        ),
      );
      await _until(tester, find.text('native photo decoded'));
      final network = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(network.fit, BoxFit.contain);
      expect(network.alignment, Alignment.topRight);
      expect(network.cacheManager, same(cache));
      expect(network.memCacheWidth, 180);
      expect(network.maxWidthDiskCache, 500);
      expect(
        find.byKey(const ValueKey('web-storage-image-retry')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
    skip: kIsWeb,
  );
}
