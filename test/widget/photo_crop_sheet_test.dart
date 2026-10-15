import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

Future<void> waitForCropPhoto(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    final apply = find.byKey(const ValueKey('photo-crop-apply'));
    if (apply.evaluate().isNotEmpty &&
        tester.widget<ElevatedButton>(apply).onPressed != null) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('The crop preview did not finish loading.');
}

void main() {
  for (final frame in ['circle', 'archSoft', 'polaroid']) {
    testWidgets(
      'crop $frame preserves its frame and draft through rotation, reset and confirm',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final layer = LayerModel(
          id: 'photo',
          type: LayerType.image,
          position: const Offset(30, 60),
          width: 250,
          height: 350,
          rotation: .2,
          imageBackground: frame,
          previewUrl: 'asset:assets/snapfit_home_square.jpg',
        );
        LayerModel? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: FilledButton(
                  onPressed: () async => result = await showPhotoCropSheet(
                    context,
                    layer: layer,
                    file: File('assets/snapfit_home_square.jpg'),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await waitForCropPhoto(tester);
        await tester.tap(find.byTooltip('사진 확대'));
        await tester.drag(
          find.byKey(const ValueKey('photo-crop-preview')),
          const Offset(30, -40),
        );
        await tester.pumpAndSettle();
        final draft = tester
            .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .layers
            .single;
        expect(draft.imageZoom, closeTo(1.1, .001));
        expect(draft.imageOffset, isNot(Offset.zero));
        expect(layer.imageZoom, 1);
        await tester.binding.setSurfaceSize(const Size(844, 390));
        await waitForCropPhoto(tester);
        final preview = tester.getRect(
          find.byKey(const ValueKey('photo-crop-preview')),
        );
        final apply = tester.getRect(
          find.byKey(const ValueKey('photo-crop-apply')),
        );
        expect(preview.height, greaterThan(220));
        expect(apply.left, greaterThan(preview.right));
        final rotated = tester
            .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .layers
            .single;
        expect(rotated.imageOffset, draft.imageOffset);
        expect(rotated.imageZoom, draft.imageZoom);
        await tester.tap(find.byTooltip('구도 초기화'));
        await tester.pump();
        final reset = tester
            .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
            .layers
            .single;
        expect(reset.imageZoom, 1);
        expect(reset.imageOffset, Offset.zero);
        await tester.tap(find.byTooltip('사진 확대'));
        await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
        await tester.pumpAndSettle();
        expect(result!.position, layer.position);
        expect(result!.rotation, layer.rotation);
        expect(result!.width, layer.width);
        expect(result!.height, layer.height);
        expect(result!.imageBackground, frame);
        expect(result!.imageZoom, closeTo(1.1, .001));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('large text and system insets leave crop apply button visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(640, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(2),
            padding: const EdgeInsets.only(bottom: 24, left: 44),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: PhotoCropSheet(
            layer: LayerModel(
              id: 'photo',
              type: LayerType.image,
              position: Offset.zero,
              width: 300,
              height: 300,
            ),
            file: File('assets/snapfit_home_square.jpg'),
          ),
        ),
      ),
    );
    await waitForCropPhoto(tester);
    final button = tester.getRect(
      find.byKey(const ValueKey('photo-crop-apply')),
    );
    expect(button.bottom, lessThanOrEqualTo(296));
    expect(button.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved bundled photo opens without a local file and cancel is inert',
    (tester) async {
      final original = LayerModel(
        id: 'saved',
        type: LayerType.image,
        position: const Offset(30, 20),
        width: 280,
        height: 300,
        previewUrl: 'asset:assets/snapfit_home_square.jpg',
        imageBackground: 'circle',
        imageZoom: 1.6,
        imageOffset: const Offset(10, 20),
      );
      LayerModel? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await showPhotoCropSheet(context, layer: original),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await waitForCropPhoto(tester);
      await tester.tap(find.byTooltip('사진 확대'));
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(original.imageZoom, 1.6);
      expect(original.imageOffset, const Offset(10, 20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed photo disables apply and can retry without losing crop draft',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('snapfit-crop-test-'),
      ))!;
      addTearDown(
        () => tester.runAsync(() => directory.delete(recursive: true)),
      );
      final file = File('${directory.path}/photo.jpg');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoCropSheet(
              layer: LayerModel(
                id: 'failed',
                type: LayerType.image,
                position: Offset.zero,
                width: 300,
                height: 300,
                imageZoom: 1.7,
                imageOffset: const Offset(15, -20),
              ),
              file: file,
            ),
          ),
        ),
      );
      for (var i = 0; i < 100 && find.text('다시 시도').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('사진을 불러오지 못했어요'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('photo-crop-apply')),
            )
            .onPressed,
        isNull,
      );
      await tester.runAsync(
        () async => file.writeAsBytes(
          await File('assets/snapfit_home_square.jpg').readAsBytes(),
        ),
      );
      await tester.tap(find.text('다시 시도'));
      await waitForCropPhoto(tester);
      final draft = tester
          .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .layers
          .single;
      expect(draft.imageZoom, 1.7);
      expect(draft.imageOffset, const Offset(15, -20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty photo slot cannot confirm a blank crop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhotoCropSheet(
            layer: LayerModel(
              id: 'empty',
              type: LayerType.image,
              position: Offset.zero,
              width: 200,
              height: 300,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('사진을 불러오지 못했어요'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('photo-crop-apply')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
