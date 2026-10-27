import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/utils/template_detail_document.dart';

String _source(String id) => jsonEncode({
  'designWidth': 400,
  'designHeight': 400,
  'pages': [
    for (var i = 0; i < 101; i++)
      {
        'layers': [
          {
            'id': '$id-$i',
            'type': 'image',
            'x': .1,
            'y': .1,
            'width': .8,
            'height': .7,
          },
        ],
      },
  ],
  'variants': {
    'square': {
      'designWidth': 500,
      'designHeight': 500,
      'pages': [
        {
          'layers': [
            {'id': '$id-square', 'type': 'text', 'text': '표지'},
          ],
        },
      ],
    },
  },
});

PremiumTemplate _template({String? source, String Function()? builder}) =>
    PremiumTemplate(
      id: -40001,
      title: '검증 문서',
      coverImageUrl: '',
      previewImages: const [],
      pageCount: 100,
      userCount: 0,
      templateJson: source,
      documentBuilder: builder,
    );

PremiumTemplate _marked(String id, SendPort events) {
  final source = _source(id);
  final ui = Isolate.current.hashCode;
  return _template(
    builder: () {
      if (Isolate.current.hashCode == ui)
        throw StateError('UI builder executed');
      events.send(id);
      return source;
    },
  );
}

PremiumTemplate _slowMarked(SendPort events) {
  final source = _source('running');
  final ui = Isolate.current.hashCode;
  return _template(
    builder: () {
      if (Isolate.current.hashCode == ui)
        throw StateError('UI builder executed');
      events.send('started');
      final work = Stopwatch()..start();
      while (work.elapsedMilliseconds < 250) {
        // Simulate non-cancellable CPU work in the background isolate.
      }
      return source;
    },
  );
}

class _UnreadableTemplate extends PremiumTemplate {
  _UnreadableTemplate(PremiumTemplate source)
    : super(
        id: source.id,
        title: source.title,
        coverImageUrl: '',
        previewImages: const [],
        pageCount: source.pageCount,
        userCount: 0,
        documentBuilder: source.documentBuilder,
      );
  @override
  String? get templateJson => throw StateError('UI document getter executed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'published books load exact data without invoking the UI document getter',
    () async {
      final original = publishedCreationTemplates.first;
      final request = TemplateDetailDocuments.acquire(
        _UnreadableTemplate(original),
      );
      final document = await request.future;
      expect(document, isNotNull);
      expect(document!.book.pages, hasLength(original.pageCount + 1));
      expect(
        document.variants.keys,
        unorderedEquals(['square', 'landscape4x3', 'landscape5x4']),
      );
      expect(document.profile.innerPageCount, original.pageCount);
      expect(document.facts.innerPageCount, original.pageCount);
      expect(document.retired, isFalse);
      expect(TemplateDetailDocuments.hasPendingWork, isFalse);
    },
  );

  test(
    'custom generation and analysis run off the UI and share in-flight work',
    () async {
      final events = ReceivePort();
      final calls = <String>[];
      events.listen((value) => calls.add(value as String));
      addTearDown(events.close);
      final template = _marked('shared', events.sendPort);
      final first = TemplateDetailDocuments.acquire(template);
      final second = TemplateDetailDocuments.acquire(
        template.copyWith(isLiked: true),
      );
      final values = await Future.wait([first.future, second.future]);
      expect(values.first, isNotNull);
      expect(values.last, same(values.first));
      expect(values.first!.book.canvas.width, 400);
      expect(values.first!.book.pages, hasLength(101));
      expect(values.first!.profile.photoSlotCount, 101);
      expect(values.first!.variants['square']!.canvas.width, 500);
      expect(calls, ['shared']);
    },
  );

  test(
    'cancellation drops queued input without affecting a shared consumer',
    () async {
      final events = ReceivePort();
      final calls = <String>[];
      events.listen((value) => calls.add(value as String));
      addTearDown(events.close);
      final template = _marked('kept', events.sendPort);
      final kept = TemplateDetailDocuments.acquire(template);
      final shared = TemplateDetailDocuments.acquire(template);
      final dropped = TemplateDetailDocuments.acquire(
        _marked('dropped', events.sendPort),
      );
      shared.cancel();
      dropped.cancel();
      dropped.cancel();
      expect(await shared.future, isNull);
      expect(await dropped.future, isNull);
      expect(await kept.future, isNotNull);
      expect(calls, ['kept']);
      expect(TemplateDetailDocuments.hasPendingWork, isFalse);
    },
  );

  test('bad documents do not block subsequent jobs', () async {
    final bad = TemplateDetailDocuments.acquire(_template(source: '{'));
    final good = TemplateDetailDocuments.acquire(
      _template(source: _source('valid')),
    );
    expect(await bad.future, isNull);
    expect(await good.future, isNotNull);
    expect(TemplateDetailDocuments.hasPendingWork, isFalse);
  });

  test(
    'cancelling a running consumer releases its result and the next job still runs',
    () async {
      final events = ReceivePort();
      final started = Completer<void>();
      events.listen((_) {
        if (!started.isCompleted) started.complete();
      });
      addTearDown(events.close);
      final request = TemplateDetailDocuments.acquire(
        _slowMarked(events.sendPort),
      );
      await started.future;
      request.cancel();
      expect(await request.future, isNull);
      final next = TemplateDetailDocuments.acquire(
        _template(source: _source('next')),
      );
      expect((await next.future)!.book.pages.first['layers'], isNotEmpty);
      expect(TemplateDetailDocuments.hasPendingWork, isFalse);
    },
  );

  test(
    'selected published editions keep their exact page counts and facts',
    () async {
      final source = publishedCreationTemplates.firstWhere(
        (item) => item.id == -9501,
      );
      for (final count in [24, 32]) {
        final document = await TemplateDetailDocuments.acquire(
          source,
          innerPages: count,
        ).future;
        expect(document, isNotNull);
        expect(document!.book.pages, hasLength(count + 1));
        expect(document.profile.innerPageCount, count);
        for (final variant in document.variants.values) {
          expect(variant.pages, hasLength(count + 1));
        }
      }
    },
  );
}
