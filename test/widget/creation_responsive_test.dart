import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import '../fixtures/ai_template_design_fixture.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('dark mode and enlarged text at $size', (tester) async {
      await loadCreationFonts();
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final design = templateDesignDraft().design!;
      final canvas = coverCanvasBaseSize(design.coverSize);
      final pages = design.buildLayers(targetSize: canvas);
      for (final screen in <Widget>[
        AiTemplateDesignReview(
          design: design,
          onBack: () {},
          onAccept: () {},
          isAccepting: false,
        ),
        AiAlbumStartStep(onManualStart: () {}, onAiStart: () {}),
        AlbumCreateStep1(
          albumTitle: '우리들의 오랫동안 기억하고 싶은 여름',
          templateTitle: design.concept,
          selectedCover: design.coverSize,
          selectedPageCount: 8,
          minPageCount: 8,
          onTitleChanged: (_) {},
          onCoverSelected: (_) {},
          onPageCountChanged: (_) {},
          onNext: () {},
        ),
        TemplatePhotoFillStep(
          pages: pages,
          cover: design.coverSize,
          onChanged: (_) {},
          onContinue: () {},
        ),
        CreationTemplatePreview(
          title: design.concept,
          isPremium: true,
          pages: pages,
          canvas: canvas,
          onUse: () {},
          onRetry: () {},
        ),
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: wrapCreation(screen, dark: true, textScale: 1.5),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: screen.runtimeType.toString(),
        );
      }
    });
  }
}
