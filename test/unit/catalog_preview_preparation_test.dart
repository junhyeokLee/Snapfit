import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/data/catalog_preview_preparation.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';

import '../support/catalog_preview_loading.dart';

PremiumTemplate _template(String name) => PremiumTemplate(
  id: 71,
  title: name,
  coverImageUrl: '',
  previewImages: const [],
  pageCount: 4,
  userCount: 0,
  templateJson: jsonEncode({
    'designWidth': 400,
    'designHeight': 600,
    'pages': [
      for (var page = 0; page < 5; page++)
        {
          'layers': [
            {
              'id': '$name-$page',
              'type': 'text',
              'text': name,
              'fontSize': 24,
              'x': .1,
              'y': .1,
              'width': .8,
              'height': .2,
            },
          ],
        },
    ],
  }),
);

void main() {
  testWidgets('shared cover is prepared once; spread waits for next frame', (
    tester,
  ) async {
    final preview = (await loadCatalogPreview(tester, _template('shared')))!;
    final both = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: true,
    );
    final cover = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: false,
    );
    var bothDone = false;
    var coverDone = false;
    both.future.then((_) => bothDone = true);
    cover.future.then((_) => coverDone = true);
    expect(preview.hasPreparedParts(cover: true), isFalse);
    await tester.pump();
    expect(coverDone, isTrue);
    expect(bothDone, isFalse);
    expect(preview.hasPreparedParts(cover: true), isTrue);
    expect(preview.hasPreparedParts(spread: true), isFalse);
    final firstCover = preview.cover;
    await tester.pump();
    expect(await both.future, same(preview));
    expect(bothDone, isTrue);
    expect(preview.cover, same(firstCover));
    expect(preview.spread.map((page) => page.single.id), [
      'shared-3',
      'shared-4',
    ]);
    final ready = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: true,
    );
    // An already prepared preview does not schedule another frame.
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump();
    expect(await ready.future, same(preview));
  });

  testWidgets('different previews share one frame budget with FIFO fairness', (
    tester,
  ) async {
    final first = (await loadCatalogPreview(tester, _template('first')))!;
    final second = (await loadCatalogPreview(tester, _template('second')))!;
    final firstRequest = CatalogPreviewPreparations.prepare(
      first,
      cover: true,
      spread: true,
    );
    final secondRequest = CatalogPreviewPreparations.prepare(
      second,
      cover: true,
      spread: false,
    );
    await tester.pump();
    expect(first.hasPreparedParts(cover: true), isTrue);
    expect(first.hasPreparedParts(spread: true), isFalse);
    expect(second.hasPreparedParts(cover: true), isFalse);
    await tester.pump();
    expect(await secondRequest.future, same(second));
    expect(first.hasPreparedParts(spread: true), isFalse);
    await tester.pump();
    expect(await firstRequest.future, same(first));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('last cancellation drops queued models and frame callbacks', (
    tester,
  ) async {
    final preview = (await loadCatalogPreview(tester, _template('cancel')))!;
    final first = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: false,
    );
    final second = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: false,
    );
    first.cancel();
    first.cancel(); // Repeated release must not affect the remaining client.
    expect(tester.binding.transientCallbackCount, 1);
    second.cancel();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump();
    expect(await first.future, isNull);
    expect(await second.future, isNull);
    expect(preview.hasPreparedParts(cover: true), isFalse);
    final retry = CatalogPreviewPreparations.prepare(
      preview,
      cover: true,
      spread: false,
    );
    await tester.pump();
    expect(await retry.future, same(preview));
  });
}
