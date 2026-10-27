import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_single_page_view.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/book_page_view.dart';

class _TrackedPageController extends PageController {
  _TrackedPageController({super.initialPage});

  final callbacks = <VoidCallback>[];

  @override
  void addListener(VoidCallback listener) {
    callbacks.add(listener);
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    callbacks.remove(listener);
    super.removeListener(listener);
  }
}

class _ReaderModel extends AlbumEditorViewModel {
  @override
  FutureOr<AlbumEditorState> build() => const AlbumEditorState();
}

void main() {
  testWidgets('book offsets start at the requested nonzero page', (
    tester,
  ) async {
    final controller = _TrackedPageController(initialPage: 3);
    addTearDown(controller.dispose);
    final offsets = <int, double>{};
    await tester.pumpWidget(
      MaterialApp(
        home: BookPageView(
          itemCount: 8,
          pageController: controller,
          itemBuilder: (_, index, offset) {
            offsets[index] = offset;
            return Text('page-$index');
          },
        ),
      ),
    );
    expect(controller.page, 3);
    expect(offsets[3], 0, reason: 'The first visible page must be at rest.');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.callbacks, isEmpty);
  });

  testWidgets(
    'book controller replacement detaches and follows the new scroll',
    (tester) async {
      final controllers = List.generate(
        3,
        (index) => _TrackedPageController(initialPage: index),
      );
      for (final controller in controllers) {
        addTearDown(controller.dispose);
      }
      final selected = ValueNotifier<PageController>(controllers.first);
      addTearDown(selected.dispose);
      final offsets = <int, double>{};
      await tester.pumpWidget(
        MaterialApp(
          home: ValueListenableBuilder<PageController>(
            valueListenable: selected,
            builder: (_, controller, _) => BookPageView(
              itemCount: 8,
              pageController: controller,
              itemBuilder: (_, index, offset) {
                offsets[index] = offset;
                return Text('page-$index');
              },
            ),
          ),
        ),
      );
      final state = tester.state(find.byType(BookPageView));
      for (var step = 0; step < 6; step++) {
        final previous = selected.value as _TrackedPageController;
        final next = controllers[(step + 1) % controllers.length];
        final previousPage = previous.page!.round();
        offsets.clear();
        selected.value = next;
        await tester.pump();
        expect(tester.state(find.byType(BookPageView)), same(state));
        expect(previous.callbacks, isEmpty);
        expect(previous.hasClients, isFalse);
        expect(next.page, previousPage);
        expect(offsets[previousPage], 0);
        offsets.clear();
        next.jumpToPage(step + 1);
        await tester.pump();
        expect(next.page, step + 1);
        expect(offsets[step + 1], 0);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      for (final controller in controllers) {
        expect(controller.callbacks, isEmpty);
        expect(controller.hasClients, isFalse);
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final focusMode in [false, true]) {
    testWidgets('reader releases replaced scroll listeners focus=$focusMode', (
      tester,
    ) async {
      final controllers = List.generate(3, (_) => _TrackedPageController());
      for (final controller in controllers) {
        addTearDown(controller.dispose);
      }
      final selected = ValueNotifier<PageController>(controllers.first);
      addTearDown(selected.dispose);
      final canvas = coverCanvasBaseSize(defaultCoverSize);
      final interaction = LayerInteractionManager.printPreview(() => canvas);
      addTearDown(interaction.dispose);
      final builder = LayerBuilder(interaction, () => canvas);
      final canvasKey = GlobalKey();
      final pages = List.generate(
        9,
        (index) => AlbumPage(
          id: 'controller-page-$index',
          pageIndex: index,
          isCover: index == 0,
          layers: const [],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            albumEditorViewModelProvider.overrideWith(_ReaderModel.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ValueListenableBuilder<PageController>(
                valueListenable: selected,
                builder: (_, controller, _) => Column(
                  children: [
                    Expanded(
                      child: AlbumReaderSinglePageView(
                        allPages: pages,
                        selectedCover: defaultCoverSize,
                        coverTheme: CoverTheme.classic,
                        pageController: controller,
                        interaction: interaction,
                        layerBuilder: builder,
                        canvasKey: canvasKey,
                        onCanvasSizeChanged: (_) {},
                        onPageChanged: (_) {},
                        onStateChanged: () {},
                        focusMode: focusMode,
                      ),
                    ),
                    // The focus renderer can follow an externally attached
                    // spread navigator; the ordinary reader owns its PageView.
                    if (focusMode)
                      SizedBox(
                        height: 1,
                        child: PageView.builder(
                          controller: controller,
                          itemCount: 5,
                          itemBuilder: (_, index) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      final state = tester.state(find.byType(AlbumReaderSinglePageView));
      for (var step = 0; step < 6; step++) {
        final previous = selected.value as _TrackedPageController;
        final next = controllers[(step + 1) % controllers.length];
        selected.value = next;
        await tester.pump();
        expect(
          tester.state(find.byType(AlbumReaderSinglePageView)),
          same(state),
        );
        expect(previous.callbacks, isEmpty);
        expect(previous.hasClients, isFalse);
        expect(next.callbacks, isNotEmpty);
        if (focusMode) {
          final spread = step % 4 + 1;
          next.jumpToPage(spread);
          await tester.pump();
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('reader-live-spread')),
              matching: find.byKey(
                ValueKey('book_flip_album_page_${spread * 2 - 1}'),
              ),
            ),
            findsOneWidget,
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      for (final controller in controllers) {
        expect(controller.callbacks, isEmpty);
        expect(controller.hasClients, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
