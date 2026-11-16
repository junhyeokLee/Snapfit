import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/fonts/document_fonts.dart';

ByteData fontBytes(int marker) => ByteData(16)
  ..setUint32(0, 0x00010000)
  ..setUint32(12, marker);

Map<String, dynamic> declaration(String family, List<String> paths) => {
  'family': family,
  'fonts': [
    for (final path in paths) {'asset': path},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'every versioned document URL identifies the exact original bundled bytes',
    () async {
      final sources = <String>{
        for (final family in DocumentFonts.sourceDeclarations)
          for (final font in family['fonts'] as List)
            (font as Map)['asset'] as String,
      };
      expect(DocumentFonts.immutableAssetPaths.keys.toSet(), sources);
      for (final source in sources) {
        final original = await rootBundle.load(source);
        final bytes = original.buffer.asUint8List(
          original.offsetInBytes,
          original.lengthInBytes,
        );
        final digest = sha256.convert(bytes).toString().substring(0, 20);
        final extension = source
            .substring(source.lastIndexOf('.'))
            .toLowerCase();
        expect(
          DocumentFonts.immutableAssetPaths[source],
          'web_fonts/$digest$extension',
          reason: source,
        );
      }
    },
    // Audit original source bytes on the VM. Packaged web rendering is checked
    // by tool/verify_web_document_quality.cjs against the release fixture.
    skip: kIsWeb,
  );

  test(
    'overlapping requests share a family and preserve all face bytes in order',
    () async {
      final regular = Completer<ByteData>();
      final bold = Completer<ByteData>();
      final loads = <String>[];
      final registrations = <(String, List<int>)>[];
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('SavedBook', ['regular.ttf', 'bold.ttf']),
        ],
        loadAsset: (path) {
          loads.add(path);
          return path == 'regular.ttf' ? regular.future : bold.future;
        },
        register: (family, assets) async {
          final bytes = await Future.wait(assets);
          registrations.add((
            family,
            bytes.map((data) => data.getUint32(12)).toList(),
          ));
        },
      );
      final first = registry.ensure(['SavedBook']);
      final second = registry.ensure(['SavedBook', 'SavedBook']);
      await Future<void>.delayed(Duration.zero);
      expect(registry.areReady(['SavedBook']), isFalse);
      bold.complete(fontBytes(700));
      regular.complete(fontBytes(400));
      await Future.wait([first, second]);
      expect(loads, ['regular.ttf', 'bold.ttf']);
      expect(registrations, hasLength(1));
      expect(registrations.single.$1, 'SavedBook');
      expect(registrations.single.$2, [400, 700]);
      expect(registry.allReady, isTrue);
      await registry.ensureAll();
      expect(registrations, hasLength(1));
    },
  );

  test(
    'aliases share pending original bytes but register each historical family name',
    () async {
      final data = Completer<ByteData>();
      var loads = 0;
      final registered = <String>[];
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('Cormorant', ['same.ttf']),
          declaration('Cormorant Garamond', ['same.ttf']),
        ],
        loadAsset: (_) {
          loads++;
          return data.future;
        },
        register: (family, assets) async {
          await Future.wait(assets);
          registered.add(family);
        },
      );
      final pending = registry.ensureAll();
      await Future<void>.delayed(Duration.zero);
      expect(loads, 1);
      data.complete(fontBytes(400));
      await pending;
      expect(registered, containsAll(['Cormorant', 'Cormorant Garamond']));
      expect(registry.allReady, isTrue);
    },
  );

  test(
    'startup and unknown historical families do not request document bytes',
    () async {
      var loads = 0;
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('UI', ['ui.ttf']),
          declaration('Album', ['album.ttf']),
        ],
        readyFamilies: ['UI'],
        loadAsset: (_) async {
          loads++;
          return fontBytes(400);
        },
        register: (_, assets) async {
          await Future.wait(assets);
        },
      );
      await registry.ensure(['UI', 'Unknown legacy name']);
      expect(loads, 0);
      expect(registry.areReady(['UI', 'Unknown legacy name']), isTrue);
      expect(registry.allReady, isFalse);
      await registry.ensure(['Album']);
      expect(loads, 1);
      expect(registry.allReady, isTrue);
    },
  );

  for (final synchronous in [false, true]) {
    test(
      'failed ${synchronous ? 'synchronous' : 'asynchronous'} fetch can retry',
      () async {
        var attempts = 0;
        var registrations = 0;
        Future<ByteData> load(String _) {
          attempts++;
          if (attempts == 1) {
            if (synchronous) throw StateError('offline');
            return Future.error(StateError('offline'));
          }
          return Future.value(fontBytes(400));
        }

        final registry = DocumentFontRegistry(
          declarations: [
            declaration('Album', ['album.ttf']),
          ],
          loadAsset: load,
          register: (_, assets) async {
            await Future.wait(assets);
            registrations++;
          },
        );
        await expectLater(registry.ensure(['Album']), throwsStateError);
        expect(registry.allReady, isFalse);
        await registry.ensure(['Album']);
        expect(attempts, 2);
        expect(registrations, 1);
        expect(registry.allReady, isTrue);
      },
    );
  }

  test(
    'an HTML/error payload cannot be accepted as a successfully loaded font',
    () async {
      var attempts = 0;
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('Album', ['album.ttf']),
        ],
        loadAsset: (_) async => ++attempts == 1 ? ByteData(16) : fontBytes(400),
        register: (_, assets) async {
          await Future.wait(assets);
        },
      );
      await expectLater(registry.ensureAll(), throwsFormatException);
      expect(registry.allReady, isFalse);
      await registry.ensureAll();
      expect(attempts, 2);
      expect(registry.allReady, isTrue);
    },
  );

  test(
    'registration failure stays unready and is not retained after retry',
    () async {
      var attempts = 0;
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('Album', ['album.ttf']),
        ],
        loadAsset: (_) async => fontBytes(400),
        register: (_, assets) async {
          await Future.wait(assets);
          if (++attempts == 1) throw StateError('registration failed');
        },
      );
      await expectLater(registry.ensureAll(), throwsStateError);
      expect(registry.allReady, isFalse);
      await registry.ensureAll();
      expect(attempts, 2);
      expect(registry.allReady, isTrue);
    },
  );

  test(
    'explicit validated print registration satisfies subsequent canvas gates',
    () async {
      final registry = DocumentFontRegistry(
        declarations: [
          declaration('PrintedBook', ['album.ttf']),
        ],
        loadAsset: (_) => throw StateError('must not request a ready font'),
        register: (_, __) => throw StateError('must not register twice'),
      );
      registry.markLoaded('PrintedBook');
      await registry.ensureAll();
      expect(registry.allReady, isTrue);
    },
  );

  for (final lateError in [false, true]) {
    test(
      'a stalled shared asset releases retry and ignores its late ${lateError ? 'failure' : 'completion'}',
      () {
        fakeAsync((clock) {
          final first = Completer<ByteData>();
          final retry = Completer<ByteData>();
          var loads = 0;
          Object? firstFailure;
          final registrations = <(String, int)>[];
          final registry = DocumentFontRegistry(
            declarations: [
              declaration('Alias A', ['original.ttf']),
              declaration('Alias B', ['original.ttf']),
            ],
            assetTimeout: const Duration(seconds: 2),
            registrationTimeout: const Duration(seconds: 1),
            loadAsset: (_) => ++loads == 1 ? first.future : retry.future,
            register: (family, assets) async {
              final faces = await Future.wait(assets);
              registrations.add((family, faces.single.getUint32(12)));
            },
          );
          unawaited(
            registry
                .ensure(['Alias A'])
                .then<void>(
                  (_) {},
                  onError: (Object error) {
                    firstFailure = error;
                  },
                ),
          );
          clock.flushMicrotasks();
          expect(loads, 1);
          clock.elapse(const Duration(seconds: 2));
          clock.flushMicrotasks();
          expect(firstFailure, isA<TimeoutException>());
          expect(registrations, isEmpty);
          expect(registry.allReady, isFalse);

          unawaited(registry.ensure(['Alias A']));
          clock.flushMicrotasks();
          expect(loads, 2);
          if (lateError) {
            first.completeError(StateError('old request failed late'));
          } else {
            first.complete(fontBytes(100));
          }
          clock.flushMicrotasks();
          unawaited(registry.ensure(['Alias B']));
          clock.flushMicrotasks();
          expect(
            loads,
            2,
            reason: 'The alias must share the new retry, not fetch again.',
          );
          expect(registrations, isEmpty);
          retry.complete(fontBytes(400));
          clock.flushMicrotasks();
          expect(
            registrations,
            containsAll([('Alias A', 400), ('Alias B', 400)]),
          );
          expect(registry.allReady, isTrue);
          expect(clock.nonPeriodicTimerCount, 0);
        });
      },
    );
  }

  test(
    'a late engine acknowledgement cannot unlock a pending registration retry',
    () {
      fakeAsync((clock) {
        final first = Completer<void>();
        final retry = Completer<void>();
        var registrations = 0;
        Object? firstFailure;
        final registry = DocumentFontRegistry(
          declarations: [
            declaration('Book', ['original.ttf']),
          ],
          assetTimeout: const Duration(seconds: 2),
          registrationTimeout: const Duration(seconds: 1),
          loadAsset: (_) async => fontBytes(400),
          register: (_, __) =>
              ++registrations == 1 ? first.future : retry.future,
        );
        unawaited(
          registry.ensureAll().then<void>(
            (_) {},
            onError: (Object error) {
              firstFailure = error;
            },
          ),
        );
        clock.flushMicrotasks();
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        expect(firstFailure, isA<TimeoutException>());
        expect(registry.allReady, isFalse);
        unawaited(registry.ensureAll());
        clock.flushMicrotasks();
        expect(registrations, 2);
        first.complete();
        clock.flushMicrotasks();
        expect(registry.allReady, isFalse);
        unawaited(registry.ensureAll());
        clock.flushMicrotasks();
        expect(registrations, 2);
        retry.complete();
        clock.flushMicrotasks();
        expect(registry.allReady, isTrue);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );

  test(
    'retry keeps completed families and never registers an incomplete face set',
    () {
      fakeAsync((clock) {
        final stalled = Completer<ByteData>();
        final retry = Completer<ByteData>();
        final loads = <String>[];
        var stalledLoads = 0;
        final registrations = <String>[];
        Object? firstFailure;
        final registry = DocumentFontRegistry(
          declarations: [
            declaration('Ready', ['ready.ttf']),
            declaration('Blocked', ['regular.ttf', 'bold.ttf']),
          ],
          assetTimeout: const Duration(seconds: 2),
          registrationTimeout: const Duration(seconds: 1),
          loadAsset: (path) {
            loads.add(path);
            if (path != 'bold.ttf') return Future.value(fontBytes(400));
            return ++stalledLoads == 1 ? stalled.future : retry.future;
          },
          register: (family, faces) async {
            await Future.wait(faces);
            registrations.add(family);
          },
        );
        unawaited(
          registry.ensureAll().then<void>(
            (_) {},
            onError: (Object error) {
              firstFailure = error;
            },
          ),
        );
        clock.flushMicrotasks();
        expect(registrations, ['Ready']);
        clock.elapse(const Duration(seconds: 2));
        clock.flushMicrotasks();
        expect(firstFailure, isA<TimeoutException>());
        expect(registry.areReady(['Ready']), isTrue);
        expect(registry.areReady(['Blocked']), isFalse);
        unawaited(registry.ensureAll());
        clock.flushMicrotasks();
        expect(loads.where((path) => path == 'ready.ttf'), hasLength(1));
        retry.complete(fontBytes(700));
        clock.flushMicrotasks();
        expect(registrations, ['Ready', 'Blocked']);
        expect(registry.allReady, isTrue);
        stalled.complete(fontBytes(100));
        clock.flushMicrotasks();
        expect(registrations, ['Ready', 'Blocked']);
        expect(clock.nonPeriodicTimerCount, 0);
      });
    },
  );
}
