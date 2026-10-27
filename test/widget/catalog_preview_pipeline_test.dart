import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/data/catalog_preview.dart';
import 'package:snap_fit/shared/widgets/catalog_preview_builder.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/catalog_edition_artwork.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_catalog_tile.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/features/store/presentation/widgets/store_floating_cover.dart';

PremiumTemplate _lazy(
  String name,
  SendPort port, {
  int delay = 0,
  int innerPages = 6,
}) {
  final uiIsolate = Isolate.current.hashCode;
  final source = jsonEncode({
    'designWidth': 400,
    'designHeight': 600,
    'pages': [
      for (var index = 0; index <= innerPages; index++)
        {
          'layers': [
            {
              'id': '${name}_${index}_body',
              'type': 'text',
              'text': 'Live $name $index',
              'x': .1,
              'y': .1,
              'width': .8,
              'height': .2,
              'fontSize': 24,
              'fontFamily': 'NotoSans',
            },
          ],
        },
    ],
  });
  return PremiumTemplate(
    id: 7654321,
    title: name,
    coverImageUrl: '',
    previewImages: const [],
    pageCount: 999,
    userCount: 0,
    documentBuilder: () {
      if (Isolate.current.hashCode == uiIsolate) {
        throw StateError('Lazy document invoked on the UI isolate');
      }
      port.send(name);
      if (delay > 0) sleep(Duration(milliseconds: delay));
      return source;
    },
  );
}

Widget _artwork(PremiumTemplate template) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: [
        SizedBox.square(
          dimension: 180,
          child: CreationCatalogCover(template: template),
        ),
        SizedBox(
          width: 320,
          height: 160,
          child: CatalogSpreadPreview(template: template),
        ),
      ],
    ),
  ),
);

Future<T> _native<T>(WidgetTester tester, Future<T> future) async {
  var completed = false;
  future.then((_) => completed = true);
  // Native isolate completions must also be flushed through the widget test's
  // fake zone; awaiting that zone's future directly inside runAsync deadlocks.
  for (var attempt = 0; attempt < 250 && !completed; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(completed, isTrue, reason: 'Native preview did not complete');
  return future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sendable lazy cover and spread share real native compute', (
    tester,
  ) async {
    final port = ReceivePort();
    final reads = <Object?>[];
    final subscription = port.listen(reads.add);
    addTearDown(() async {
      await subscription.cancel();
      port.close();
    });
    final template = _lazy('custom', port.sendPort);
    await tester.pumpWidget(_artwork(template));
    expect(find.byType(TemplatePageRenderer), findsNothing);
    expect(find.text('표지 불러오는 중'), findsNothing);
    expect(
      find.byKey(ValueKey('catalog-cover-skeleton-${template.id}')),
      findsOneWidget,
    );
    expect(tester.hasRunningAnimations, isFalse);

    final preview = await _native(tester, CatalogPreviews.request(template));
    expect(preview, isNotNull);
    await tester.pumpAndSettle();
    expect(reads, ['custom']);
    final pages = tester.widgetList<TemplatePageRenderer>(
      find.byType(TemplatePageRenderer),
    );
    expect(pages.map((page) => page.layers.single.id), [
      'custom_0_body',
      'custom_3_body',
      'custom_4_body',
    ]);
    expect(
      pages.map((page) => page.designCanvasSize),
      everyElement(const Size(400, 600)),
    );
    await tester.pumpWidget(_artwork(template.copyWith(isLiked: true)));
    await tester.pump();
    expect(reads, ['custom']);
    expect(find.byType(TemplatePageRenderer), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'late cover and spread results cannot overwrite a same-ID replacement',
    (tester) async {
      final port = ReceivePort();
      final events = StreamIterator(port);
      addTearDown(() async {
        await events.cancel();
        port.close();
      });
      final old = _lazy('old', port.sendPort, delay: 80);
      final replacement = _lazy('replacement', port.sendPort, delay: 200);
      await tester.pumpWidget(_artwork(old));
      final oldRequest = CatalogPreviews.request(old);
      await _native(tester, events.moveNext());
      expect(events.current, 'old');

      await tester.pumpWidget(_artwork(replacement));
      expect(find.byType(TemplatePageRenderer), findsNothing);
      await _native(tester, oldRequest);
      await tester.pump();
      expect(find.byType(TemplatePageRenderer), findsNothing);

      final preview = await _native(
        tester,
        CatalogPreviews.request(replacement),
      );
      expect(preview, isNotNull);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .map((page) => page.layers.single.id),
        ['replacement_0_body', 'replacement_3_body', 'replacement_4_body'],
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tile composition uses the shared worker and ignores stale profiles',
    (tester) async {
      final port = ReceivePort();
      final reads = <Object?>[];
      final subscription = port.listen(reads.add);
      addTearDown(() async {
        await subscription.cancel();
        port.close();
      });
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final old = _lazy('old-profile', port.sendPort, delay: 80);
      final replacement = _lazy('new-profile', port.sendPort, innerPages: 2);
      Widget tile(PremiumTemplate template) => ProviderScope(
        overrides: [
          pointShopCatalogProvider.overrideWith((_) async => []),
          ownedPointShopKeysProvider.overrideWith((_) async => <String>{}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 420,
              child: TemplateCatalogTile(
                template: template,
                onOpen: () {},
                heroTag: 'preview-tile',
                scrollController: controller,
                previewRatio: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tile(old));
      expect(find.text('내지 구성 확인 중'), findsOneWidget);
      await tester.pumpWidget(tile(replacement));
      final preview = await _native(
        tester,
        CatalogPreviews.request(replacement),
      );
      expect(preview, isNotNull);
      await tester.pumpAndSettle();
      expect(find.text('사진 넣는 0곳 · 글쓰기 2쪽'), findsOneWidget);
      expect(find.text('사진 넣는 0곳 · 글쓰기 6쪽'), findsNothing);
      expect(reads.where((name) => name == 'new-profile'), hasLength(1));
      expect(find.byType(StoreFloatingCover), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('inactive or hidden consumers cancel pending layer preparation', (
    tester,
  ) async {
    final port = ReceivePort();
    addTearDown(port.close);
    final template = _lazy('visibility', port.sendPort);
    final preview = (await _native(tester, CatalogPreviews.request(template)))!;
    Widget page(bool visible) => MaterialApp(
      home: TickerMode(
        enabled: visible,
        child: CatalogPreviewBuilder(
          template: template,
          needsCover: true,
          needsSpread: true,
          builder: (_, snapshot) =>
              Text(snapshot.hasData ? 'ready' : 'waiting'),
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    expect(preview.hasPreparedParts(cover: true), isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(preview.hasPreparedParts(cover: true), isFalse);
    expect(tester.binding.transientCallbackCount, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // The first frame prepares the cover; the spread still awaits its turn.
    await tester.pump();
    expect(preview.hasPreparedParts(cover: true), isTrue);
    expect(preview.hasPreparedParts(spread: true), isFalse);
    // Stop the next frame's preparation before its callback can run.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpWidget(page(false));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(preview.hasPreparedParts(spread: true), isFalse);
    expect(find.text('ready'), findsNothing);
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
    expect(preview.hasPreparedParts(spread: true), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}
