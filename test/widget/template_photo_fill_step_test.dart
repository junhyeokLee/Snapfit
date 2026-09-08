import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import '../fixtures/ai_template_design_fixture.dart';

class _Photo extends Mock implements AssetEntity {}

void main() {
  testWidgets(
    'inserting a photo changes only the selected slot, including after rotation',
    (tester) async {
      final design = templateDesignDraft().design!;
      var pages = design.buildLayers(
        targetSize: coverCanvasBaseSize(design.coverSize),
      );
      final photo = _Photo();
      when(
        () => photo.file,
      ).thenAnswer((_) async => File('assets/snapfit_home_square.jpg'));
      final original = pages.first.where((l) => l.type.name == 'image').single;
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: wrapCreation(
            StatefulBuilder(
              builder: (context, setState) => TemplatePhotoFillStep(
                pages: pages,
                cover: design.coverSize,
                onChanged: (value) => setState(() => pages = value),
                onContinue: () {},
                pickPhoto: () async => photo,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('사진 추가'));
      await tester.pumpAndSettle();
      final filled = pages.first.where((l) => l.type.name == 'image').single;
      expect(filled.asset, same(photo));
      expect(filled.position, original.position);
      expect(filled.width, original.width);
      expect(filled.height, original.height);
      expect(
        pages[1].where((l) => l.type.name == 'image').single.asset,
        isNull,
      );
      expect(find.text('1 / 9'), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(844, 390));
      await tester.pumpAndSettle();
      expect(find.text('1 / 9'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'slot taps open selection, cancellation keeps the design and page rail selects pages',
    (tester) async {
      var selections = 0, changes = 0, continued = 0;
      final design = templateDesignDraft().design!;
      await tester.pumpWidget(
        ProviderScope(
          child: wrapCreation(
            TemplatePhotoFillStep(
              pages: design.buildLayers(
                targetSize: coverCanvasBaseSize(design.coverSize),
              ),
              cover: design.coverSize,
              onChanged: (_) => changes++,
              onContinue: () => continued++,
              pickPhoto: () async {
                selections++;
                return null;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('사진 추가'));
      await tester.pumpAndSettle();
      expect(selections, 1);
      expect(changes, 0);
      await tester.tap(find.byKey(const ValueKey('fill-page-2')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('나중에 채우기'));
      expect(continued, 1);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(320, 568),
  ]) {
    testWidgets('photo fill layout $size', (tester) async {
      await loadCreationFonts();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final design = templateDesignDraft().design!;
      await tester.pumpWidget(
        ProviderScope(
          child: wrapCreation(
            TemplatePhotoFillStep(
              pages: design.buildLayers(
                targetSize: coverCanvasBaseSize(design.coverSize),
              ),
              cover: design.coverSize,
              onChanged: (_) {},
              onContinue: () {},
              pickPhoto: () async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (size.width > size.height) {
        await tester.tap(find.byKey(const ValueKey('fill-page-1')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/creation_photos_${size.width.toInt()}x${size.height.toInt()}.png',
        ),
      );
    });
  }
}
