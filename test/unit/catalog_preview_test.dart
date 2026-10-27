import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

PremiumTemplate _template({String? source, String Function()? builder}) =>
    PremiumTemplate(
      id: 42,
      title: 'Preview',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 20,
      userCount: 0,
      templateJson: source,
      documentBuilder: builder,
    );

String _document(String id) => jsonEncode({
  'designWidth': 400,
  'designHeight': 600,
  'pages': [
    for (var page = 0; page < 10; page++)
      {
        'layers': [
          {
            'id': '$id-$page',
            'type': 'text',
            'text': 'Page $page',
            'x': .1,
            'y': .1,
            'width': .8,
            'height': .2,
            'fontSize': 24,
          },
        ],
      },
  ],
});

class _UnreadableTemplate extends PremiumTemplate {
  _UnreadableTemplate(PremiumTemplate original)
    : super(
        id: original.id,
        title: original.title,
        coverImageUrl: '',
        previewImages: const [],
        pageCount: original.pageCount,
        userCount: 0,
        documentBuilder: original.documentBuilder,
      );

  @override
  String? get templateJson => throw StateError('UI document getter accessed');
}

PremiumTemplate _markedTemplate(String id, SendPort port) {
  final source = _document(id);
  return _template(
    builder: () {
      port.send(id);
      return source;
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'published preview resolves by ID without reading the UI document',
    () async {
      final template = _UnreadableTemplate(publishedCreationTemplates.first);
      final stopwatch = Stopwatch()..start();
      final pending = CatalogPreviews.request(template);
      expect(
        CatalogPreviews.request(template.copyWith(isLiked: true)),
        same(pending),
      );
      final preview = await pending;
      stopwatch.stop();
      // Keep actual native worker timing visible in the targeted test report.
      // ignore: avoid_print
      print(
        'Native preview worker: ${stopwatch.elapsedMilliseconds}ms; rendered: ${preview != null}',
      );
      expect(preview, isNotNull);
      expect(preview!.cover, isNotEmpty);
      expect(preview.spread, hasLength(2));
      expect(preview.profile.innerPageCount, template.pageCount);
    },
  );

  test(
    'custom builders execute only in the worker and share favorite copies',
    () async {
      final uiIsolate = Isolate.current.hashCode;
      final source = _document('worker');
      final template = _template(
        builder: () {
          if (Isolate.current.hashCode == uiIsolate) {
            throw StateError('builder invoked on UI isolate');
          }
          return source;
        },
      );
      final stopwatch = Stopwatch()..start();
      final pending = CatalogPreviews.request(template);
      expect(
        CatalogPreviews.request(template.copyWith(isLiked: true)),
        same(pending),
      );
      final preview = await pending;
      stopwatch.stop();
      // Keep actual native worker timing visible in the targeted test report.
      // ignore: avoid_print
      print(
        'Native preview worker: ${stopwatch.elapsedMilliseconds}ms; rendered: ${preview != null}',
      );
      expect(preview, isNotNull);
      expect(preview!.cover.single.id, 'worker-0');
      expect(preview.spread.map((page) => page.single.id), [
        'worker-3',
        'worker-4',
      ]);
      expect(preview.profile.innerPageCount, 9);
      expect(await CatalogPreviews.request(template), same(preview));
    },
  );

  test(
    'same ID eager replacements keep their own artwork and counts',
    () async {
      final canonical = publishedCreationTemplates.first;
      final template = canonical.copyWith(
        templateJson: _document('replacement'),
      );
      expect(canonicalCatalogPreviewId(template), isNull);
      final preview = await CatalogPreviews.request(template);
      expect(preview!.cover.single.id, 'replacement-0');
      expect(preview.spread.map((page) => page.single.id), [
        'replacement-3',
        'replacement-4',
      ]);
      expect(preview.profile.innerPageCount, 9);
      expect(preview.canvas.width, 400);
      expect(preview.canvas.height, 600);
    },
  );

  test(
    'malformed or missing documents fail without blocking later requests',
    () async {
      for (final source in [
        null,
        '{',
        '[]',
        '{"designWidth":0}',
        '{"pages":false}',
      ]) {
        expect(
          await CatalogPreviews.request(_template(source: source)),
          isNull,
        );
      }
      expect(
        await CatalogPreviews.request(_template(source: _document('valid'))),
        isNotNull,
      );
    },
  );

  test('queued work cancels only when its final consumer releases', () async {
    final port = ReceivePort();
    addTearDown(port.close);
    final template = _markedTemplate('shared', port.sendPort);
    final first = CatalogPreviews.acquire(template);
    final second = CatalogPreviews.acquire(template.copyWith(isLiked: true));
    expect(first.future, same(second.future));
    first.release();
    expect((await second.future)!.cover.single.id, 'shared-0');
    second.release();
  });

  test(
    'released queued cards never build and first visible card goes first',
    () async {
      final port = ReceivePort();
      final built = <String>[];
      final subscription = port.listen((id) => built.add(id as String));
      addTearDown(() async {
        await subscription.cancel();
        port.close();
      });
      final oldest = CatalogPreviews.acquire(
        _markedTemplate('old', port.sendPort),
      );
      final cancelled = CatalogPreviews.acquire(
        _markedTemplate('cancelled', port.sendPort),
      );
      final newest = CatalogPreviews.acquire(
        _markedTemplate('new', port.sendPort),
      );
      cancelled.release();
      expect(await cancelled.future, isNull);
      expect(await newest.future, isNotNull);
      expect(await oldest.future, isNotNull);
      newest.release();
      oldest.release();
      expect(built, ['old', 'new']);
    },
  );

  test(
    'LRU keeps recent compact previews and evicts older documents',
    () async {
      final first = _template(source: _document('oldest'));
      final original = await CatalogPreviews.request(first);
      late PremiumTemplate newest;
      CatalogPreview? recent;
      for (var index = 0; index < CatalogPreviews.cacheLimit; index++) {
        newest = _template(source: _document('entry-$index'));
        recent = await CatalogPreviews.request(newest);
      }
      expect(await CatalogPreviews.request(newest), same(recent));
      expect(await CatalogPreviews.request(first), isNot(same(original)));
    },
  );

  test(
    'memory pressure clears previews and pre-pressure queued work cannot refill the cache',
    () async {
      final warm = _template(source: _document('pressure-warm'));
      final original = await CatalogPreviews.request(warm);
      expect(original, isNotNull);
      final cached = CatalogPreviews.acquireCached(warm);
      expect(cached, isNotNull);
      cached!.release();

      final next = _template(source: _document('pressure-queued'));
      final queued = CatalogPreviews.acquire(next);
      MemoryPressureCaches.clear();
      expect(CatalogPreviews.acquireCached(warm), isNull);
      expect(
        await queued.future,
        isNotNull,
        reason: 'Mounted consumers must still receive their active result',
      );
      queued.release();
      expect(
        CatalogPreviews.acquireCached(next),
        isNull,
        reason: 'Older work must not refill the cleared cache',
      );
      expect(await CatalogPreviews.request(warm), isNot(same(original)));
    },
  );
}
