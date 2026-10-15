import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;
import '../fixtures/ai_template_design_fixture.dart';

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('RESPONSIVE_QA')) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/all-screens-qa')..createSync(recursive: true);
    File(
      '${dir.path}/responsive-$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List)
        loader.addFont(rootBundle.load(asset['asset'] as String));
      await loader.load();
    }
  });
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native creation layouts and enlarged text at $size dark=$dark',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = size.width > size.height
              ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
              : const FakeViewPadding(top: 24, bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final design = templateDesignDraft().design!;
          final canvas = coverCanvasBaseSize(design.coverSize);
          final pages = design.buildLayers(targetSize: canvas);
          final screens = <String, Widget>{
            'ai-review': AiTemplateDesignReview(
              design: design,
              onBack: () {},
              onAccept: () {},
              isAccepting: false,
            ),
            'creation-start': AiAlbumStartStep(
              onManualStart: () {},
              onAiStart: () {},
            ),
            'ai-brief': AiTemplateBriefStep(onContinue: (_) {}, onBack: () {}),
            'ai-confirm': AiAlbumPointConfirmationStep(
              designBrief: AiTemplateBrief(
                prompt: '제주 바다와 여행의 순간들',
                aspect: design.aspect,
                printProductId: design.coverSize.productId,
                pageCount: 20,
              ),
              theme: AlbumTheme.custom,
              range: AiPhotoRange.manualSelection,
              pointCost: 500,
              balance: 1000,
              onConfirm: () {},
              onBack: () {},
            ),
            'creation-settings': AlbumCreateStep1(
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
            'photo-fill': TemplatePhotoFillStep(
              pages: pages,
              cover: design.coverSize,
              onChanged: (_) {},
              onContinue: () {},
            ),
            'creation-preview': CreationTemplatePreview(
              title: design.concept,
              isPremium: true,
              pages: pages,
              canvas: canvas,
              onUse: () {},
              onRetry: () {},
            ),
          };
          for (final entry in screens.entries) {
            final screen = entry.value;
            final key = GlobalKey();
            await tester.pumpWidget(
              RepaintBoundary(
                key: key,
                child: ProviderScope(
                  child: wrapCreation(
                    screen is CreationTemplatePreview
                        ? screen
                        : Scaffold(
                            appBar: AppBar(
                              toolbarHeight: size.width > size.height ? 48 : 60,
                              title: const Text(
                                '앨범 만들기',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                            body: screen,
                          ),
                    showShell: false,
                    dark: dark,
                    textScale: 1.5,
                  ),
                ),
              ),
            );
            await _capture(
              tester,
              key,
              '${entry.key}-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
            );
            expect(tester.takeException(), isNull);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: screen.runtimeType.toString(),
            );
          }
        },
      );
    }
  }
}
