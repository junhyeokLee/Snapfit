import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/cache/memory_pressure_caches.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_builder.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

Future<void> _frames(WidgetTester tester, [int count = 10]) async {
  for (var i = 0; i < count; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _clear() {
  MemoryPressureCaches.clear();
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
}

void main() {
  setUp(_clear);
  tearDown(_clear);

  for (final background in [false, true]) {
    for (final spine in [false, true]) {
      testWidgets(
        'local ${spine ? 'spine' : 'page'} photo defers decoding during ${background ? 'background' : 'route hiding'} and releases handles',
        (tester) async {
          final asset = (await tester.runAsync(
            () => BrowserPhotoAsset.fromBytes(
              ownerId: 'review',
              name: 'photo.png',
              bytes: browserPhotoFixture(),
            ),
          ))!;
          final created = <ui.Image>[];
          final previous = ui.Image.onCreate;
          ui.Image.onCreate = (image) {
            created.add(image);
            previous?.call(image);
          };
          addTearDown(() => ui.Image.onCreate = previous);
          addTearDown(
            () => tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            ),
          );
          final active = ValueNotifier(background);
          addTearDown(active.dispose);
          if (background)
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
          const size = Size(100, 100);
          final interaction = LayerInteractionManager.printPreview(() => size);
          addTearDown(interaction.dispose);
          final builder = LayerBuilder(
            interaction,
            () => size,
            previewImageDecodeWidth: 128,
          );
          final photo = LayerModel(
            id: 'local',
            type: LayerType.image,
            position: Offset.zero,
            width: 100,
            height: 100,
            asset: asset,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: active,
                    builder: (_, enabled, __) => TickerMode(
                      enabled: enabled,
                      child: SizedBox.square(
                        dimension: 100,
                        child: Stack(
                          children: [
                            builder.buildImage(
                              photo,
                              isCover: true,
                              wrapSpine: spine,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await _frames(tester);
          expect(
            created,
            isEmpty,
            reason: 'A hidden AssetEntity branch must not decode pixels',
          );
          if (background) {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          } else {
            active.value = true;
          }
          await tester.pump();
          for (
            var i = 0;
            i < 100 && !created.any((image) => !image.debugDisposed);
            i++
          ) {
            await _frames(tester, 1);
          }
          expect(created.any((image) => !image.debugDisposed), isTrue);
          for (var i = 0; i < 4; i++) {
            active.value = false;
            await tester.pump();
            active.value = true;
            await tester.pump();
            await _frames(tester, 2);
          }
          await tester.pumpWidget(const SizedBox());
          _clear();
          await _frames(tester);
          expect(created.where((image) => !image.debugDisposed), isEmpty);
          expect(PaintingBinding.instance.imageCache.liveImageCount, 0);
          expect(PaintingBinding.instance.imageCache.pendingImageCount, 0);
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
