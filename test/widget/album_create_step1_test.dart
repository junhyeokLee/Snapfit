import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import '../fixtures/ai_template_design_fixture.dart';

void main() {
  testWidgets('title, physical sizes and bounded page count remain editable', (
    tester,
  ) async {
    var title = '';
    var cover = defaultCoverSize;
    var pages = 10;
    await tester.pumpWidget(
      wrapCreation(
        StatefulBuilder(
          builder: (context, setState) => AlbumCreateStep1(
            albumTitle: title,
            selectedCover: cover,
            selectedPageCount: pages,
            onTitleChanged: (t) => title = t,
            onCoverSelected: (s) => setState(() => cover = s),
            onPageCountChanged: (n) => setState(() => pages = n),
            onNext: () {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), '우리의 여름');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );
    expect(find.text('세로형'), findsNothing);
    for (final size in coverSizes) {
      expect(
        find.byKey(ValueKey('print-size-${size.productId}')),
        findsOneWidget,
      );
    }
    final largeLandscape = find.byKey(
      const ValueKey('print-size-REDP_250X200_SOFT'),
    );
    await tester.ensureVisible(largeLandscape);
    await tester.tap(largeLandscape);
    await tester.pumpAndSettle();
    expect(cover.productId, 'REDP_250X200_SOFT');
    expect(cover.ratio, 1.25);
    await tester.ensureVisible(find.byTooltip('페이지 늘리기'));
    await tester.tap(find.byTooltip('페이지 늘리기'));
    await tester.pump();
    expect(pages, 11);
    expect(title, '우리의 여름');
  });

  testWidgets(
    'unavailable sizes remain disabled when an explicit restriction is supplied',
    (tester) async {
      var changes = 0;
      await tester.pumpWidget(
        wrapCreation(
          AlbumCreateStep1(
            albumTitle: '새 앨범',
            selectedCover: defaultCoverSize,
            selectedPageCount: 8,
            minPageCount: 8,
            availableCovers: [defaultCoverSize],
            templateTitle: '내 AI 디자인',
            onTitleChanged: (_) {},
            onCoverSelected: (_) => changes++,
            onPageCountChanged: (_) {},
            onNext: () {},
          ),
        ),
      );
      final unavailable = find.byKey(
        const ValueKey('print-size-REDP_250X200_SOFT'),
      );
      await tester.ensureVisible(unavailable);
      await tester.tap(unavailable);
      expect(changes, 0);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '페이지 줄이기',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('album setup layout $size', (tester) async {
      await loadCreationFonts();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final design = templateDesignDraft().design!;
      await tester.pumpWidget(
        wrapCreation(
          AlbumCreateStep1(
            albumTitle: '제주의 느린 오후',
            templateTitle: design.concept,
            sourceLabel: 'AI 템플릿',
            selectedCover: defaultCoverSize,
            coverLayers: design
                .buildLayers(targetSize: coverCanvasBaseSize(design.coverSize))
                .first,
            selectedPageCount: 8,
            minPageCount: 8,
            availableCovers: coverSizes,
            onTitleChanged: (_) {},
            onCoverSelected: (_) {},
            onPageCountChanged: (_) {},
            onNext: () {},
            onChangeDesign: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/creation_setup_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
      if (size.width == 390) {
        await tester.ensureVisible(
          find.byKey(const ValueKey('print-cover-hard')),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/creation_cover_type_390x844.png'),
        );
      }
    });
  }
}
