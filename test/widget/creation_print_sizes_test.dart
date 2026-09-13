import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';

import 'ai_album_start_step_test.dart' show wrapCreation;

void main() {
  testWidgets(
    'all five physical sizes survive template selection and photo handoff',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sourceCover = coverSizeForProduct('REDP_200X150_SOFT')!;
      final source = coverCanvasBaseSize(sourceCover);
      final layer = LayerModel(
        id: 'ratio-proof',
        type: LayerType.image,
        position: const Offset(20, 10),
        width: 100,
        height: 50,
      );
      await tester.pumpWidget(
        wrapCreation(
          AlbumCreateFlowScreen(
            initialCreationTemplate: AlbumCreationTemplate(
              title: '가로 템플릿',
              previewUrl: '',
              isPremium: false,
              cover: sourceCover,
              pages: [
                [layer],
                [layer],
              ],
              pagesCanvasSize: source,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final cover in coverSizes) {
        final option = find.byKey(ValueKey('print-size-${cover.productId}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        final setup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(setup.selectedCover!.productId, cover.productId);
        expect(setup.selectedCover!.realSize, cover.realSize);
        expect(
          setup.coverLayers!.single.width / setup.coverLayers!.single.height,
          2,
        );
      }
      final current = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      final layersBeforeBindingChange = current.coverLayers;
      final hard = find.byKey(const ValueKey('print-cover-hard'));
      await tester.ensureVisible(hard);
      await tester.tap(hard);
      await tester.pumpAndSettle();
      final hardcoverSetup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(hardcoverSetup.selectedCover!.coverType, PrintCoverType.hard);
      expect(hardcoverSetup.coverLayers, same(layersBeforeBindingChange));
      final target = coverSizeForProduct('REDP_250X200_HARD')!;
      await tester.ensureVisible(
        find.byKey(ValueKey('print-size-${target.sizeProductId}')),
      );
      await tester.tap(
        find.byKey(ValueKey('print-size-${target.sizeProductId}')),
      );
      await tester.pumpAndSettle();
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(setup.coverLayers!.single.width, closeTo(125, .0001));
      expect(setup.coverLayers!.single.height, closeTo(62.5, .0001));
      expect(setup.coverLayers!.single.position.dy, closeTo(25.4, .0001));
      await tester.ensureVisible(find.text('사진 채우기'));
      await tester.tap(find.text('사진 채우기'));
      await tester.pumpAndSettle();
      final fill = tester.widget<TemplatePhotoFillStep>(
        find.byType(TemplatePhotoFillStep),
      );
      expect(fill.cover.productId, target.productId);
      expect(fill.cover.ratio, 1.25);
      expect(fill.pages[1].single.width, closeTo(125, .0001));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new album with a legacy portrait template chooses a supported square',
    (tester) async {
      await tester.pumpWidget(
        wrapCreation(
          AlbumCreateFlowScreen(
            initialAlbumTitle: '이전 세로 템플릿',
            initialCoverSize: legacyCoverSizes.first,
            initialTemplatePages: const [[], []],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(setup.selectedCover!.productId, defaultCoverSize.productId);
      expect(find.text('세로형'), findsNothing);
      expect(setup.availableCovers!.length, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
