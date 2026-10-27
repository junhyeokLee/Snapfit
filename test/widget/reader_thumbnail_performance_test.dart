import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_page_content.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_thumbnail_strip.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

const _prefix = 'assets/reader-thumbnail-review/';

class _Editor extends AlbumEditorViewModel {
  @override
  FutureOr<AlbumEditorState> build() => const AlbumEditorState();
}

class _Photos extends CachingAssetBundle {
  final bytes = browserPhotoFixture();

  @override
  Future<ByteData> load(String key) async => key.startsWith(_prefix)
      ? ByteData.sublistView(bytes)
      : rootBundle.load(key);
}

Future<void> _frames(WidgetTester tester, [int count = 20]) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<LayerBuilder> _show(
  WidgetTester tester,
  ValueNotifier<int> selected, {
  int pages = 201,
  bool reduced = false,
  bool accessible = false,
  int? maximumWidth,
}) async {
  const canvas = Size(500, 500);
  final interaction = LayerInteractionManager.printPreview(() => canvas);
  addTearDown(interaction.dispose);
  final builder = LayerBuilder(
    interaction,
    () => canvas,
    previewImageDecodeWidth: maximumWidth,
  );
  final album = [
    for (var page = 0; page < pages; page++)
      AlbumPage(
        id: '$page',
        pageIndex: page,
        isCover: page == 0,
        layers: [
          LayerModel(
            id: 'page-$page',
            type: LayerType.image,
            position: Offset.zero,
            width: 500,
            height: 500,
            imageUrl: 'asset:${_prefix}page-$page.png',
          ),
        ],
      ),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [albumEditorViewModelProvider.overrideWith(_Editor.new)],
      child: MaterialApp(
        home: DefaultAssetBundle(
          bundle: _Photos(),
          child: MediaQuery(
            data:
                const MediaQueryData(
                  size: Size(390, 844),
                  devicePixelRatio: 3,
                ).copyWith(
                  disableAnimations: reduced,
                  accessibleNavigation: accessible,
                ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: ValueListenableBuilder<int>(
                    valueListenable: selected,
                    builder: (_, value, __) => AlbumReaderThumbnailStrip(
                      pages: album,
                      currentSpreadIndex: value,
                      onSpreadSelected: (value) => selected.value = value,
                      previewBuilder: builder,
                      baseCanvasSize: canvas,
                      height: 46,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await _frames(tester);
  return builder;
}

ScrollController _scroll(WidgetTester tester) => tester
    .widget<ListView>(find.byKey(const ValueKey('reader-spread-strip')))
    .controller!;

String? _photoName(ImageProvider provider) {
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage && provider.assetName.startsWith(_prefix)
      ? provider.assetName
      : null;
}

void main() {
  tearDown(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets(
    'a distant reader selection skips intermediate thumbnail artwork',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await _show(tester, selected);
      selected.value = 80;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final firstOffset = _scroll(tester).offset;
      final middlePages = <int>{};
      for (var frame = 0; frame < 22; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        for (final element in find.byType(AlbumReaderPageContent).evaluate()) {
          final widget = element.widget as AlbumReaderPageContent;
          for (final layer in widget.layers) {
            final page = int.parse(layer.id.substring('page-'.length));
            if (page >= 20 && page <= 130) middlePages.add(page);
          }
        }
      }
      expect(middlePages, isEmpty);
      expect(firstOffset, closeTo(_scroll(tester).offset, .01));
      expect(
        find.byKey(const ValueKey('reader-spread-80')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await _frames(tester, 3);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reader cover and interior thumbnails use bounded decoding', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final mainBuilder = await _show(tester, selected, pages: 9);
    final photos = tester
        .widgetList<Image>(find.byType(Image))
        .where((photo) => _photoName(photo.image) != null);
    expect(photos, isNotEmpty);
    for (final photo in photos) {
      expect(photo.image, isA<ResizeImage>());
      expect((photo.image as ResizeImage).width, inInclusiveRange(128, 512));
    }
    expect(mainBuilder.previewImageDecodeWidth, isNull);
    await tester.pumpWidget(const SizedBox());
    await _frames(tester, 3);
    expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
    expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nearby reader selection keeps natural thumbnail motion', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _show(tester, selected);
    final start = _scroll(tester).offset;
    selected.value = 3;
    await tester.pump();
    final offsets = <double>[];
    for (var frame = 0; frame < 22; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      offsets.add(_scroll(tester).offset);
    }
    final end = _scroll(tester).offset;
    expect(end, greaterThan(start + 1));
    expect(
      offsets.any((offset) => offset > start + 1 && offset < end - 1),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid return cancels a thumbnail animation before it moves', (
    tester,
  ) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    await _show(tester, selected);
    selected.value = 3;
    await tester.pump();
    selected.value = 0;
    await tester.pump();
    await _frames(tester);
    expect(_scroll(tester).offset, closeTo(0, .01));
    expect(_scroll(tester).position.isScrollingNotifier.value, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  for (final accessible in [false, true]) {
    testWidgets(
      'reader thumbnail selection respects reduced motion accessible=$accessible',
      (tester) async {
        final selected = ValueNotifier(0);
        addTearDown(selected.dispose);
        await _show(
          tester,
          selected,
          reduced: !accessible,
          accessible: accessible,
        );
        selected.value = 3;
        await tester.pump();
        final offset = _scroll(tester).offset;
        await _frames(tester);
        expect(offset, greaterThan(0));
        expect(_scroll(tester).offset, closeTo(offset, .01));
        expect(_scroll(tester).position.isScrollingNotifier.value, isFalse);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('an existing smaller preview budget is retained', (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);
    final builder = await _show(tester, selected, pages: 9, maximumWidth: 64);
    final photos = tester
        .widgetList<Image>(find.byType(Image))
        .where((photo) => _photoName(photo.image) != null);
    expect(photos, isNotEmpty);
    for (final photo in photos) {
      expect(photo.image, isA<ResizeImage>());
      expect((photo.image as ResizeImage).width, 64);
    }
    expect(builder.previewImageDecodeWidth, 64);
    await tester.pumpWidget(const SizedBox());
    await _frames(tester, 3);
    expect(tester.takeException(), isNull);
  });
}
