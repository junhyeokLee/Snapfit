import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/utils/photo_crop_geometry.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import 'ai_album_start_step_test.dart' show wrapCreation;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

BrowserPhotoAsset _portrait() {
  // Memory-only source with real portrait metadata. No preview file is written.
  final pixels = bitmap.Image(width: 60, height: 120);
  bitmap.fill(pixels, color: bitmap.ColorRgb8(40, 90, 75));
  final bytes = Uint8List.fromList(bitmap.encodePng(pixels));
  return BrowserPhotoAsset.fromStored(
    ownerId: 'crop-owner',
    id: 'browser_portrait_crop_fixture',
    name: 'portrait.png',
    width: 60,
    height: 120,
    createdAtSecond: 0,
    originalBytes: bytes,
    previewBytes: bytes,
    contentSha256: sha256.convert(bytes).toString(),
  );
}

LayerModel _slot(String id, {BrowserPhotoAsset? photo}) => LayerModel(
  id: id,
  type: LayerType.image,
  position: const Offset(40, 60),
  width: 420,
  height: 180,
  imageBackground: 'none',
  asset: photo,
);

class _Host extends StatefulWidget {
  const _Host({super.key, required this.pages, required this.photo});
  final List<List<LayerModel>> pages;
  final BrowserPhotoAsset photo;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<List<LayerModel>> pages = widget.pages;
  int changes = 0;
  final session = TemplatePhotoFillSession();

  @override
  Widget build(BuildContext context) => TemplatePhotoFillStep(
    pages: pages,
    session: session,
    cover: defaultCoverSize,
    pickPhoto: () async => widget.photo,
    onChanged: (value) => setState(() {
      pages = value;
      changes++;
    }),
    onContinue: () {},
  );
}

Future<void> _boot(
  WidgetTester tester,
  GlobalKey<_HostState> host,
  BrowserPhotoAsset photo,
  List<List<LayerModel>> pages,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    wrapCreation(_Host(key: host, pages: pages, photo: photo)),
  );
  await tester.pumpAndSettle();
}

void _select(WidgetTester tester, String id) {
  final renderer = tester
      .widgetList<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
      .firstWhere(
        (renderer) =>
            renderer.onLayerTap != null &&
            renderer.layers.any((layer) => layer.id == id),
      );
  renderer.onLayerTap!(id);
}

void main() {
  final photo = _portrait();

  for (final zoom in [1.0, 2.0]) {
    testWidgets('portrait drag matches visible crop distance at zoom $zoom', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PhotoCropSheet(
              layer: _slot('crop', photo: photo).copyWith(imageZoom: zoom),
            ),
          ),
        ),
      );
      await waitForCropPhoto(tester);
      final preview = find.byKey(const ValueKey('photo-crop-preview'));
      final viewport = tester.getSize(preview);
      LayerModel current() => tester
          .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .layers
          .single;
      final gesture = await tester.startGesture(tester.getCenter(preview));
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      final before = current().imageAlignment;
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      final overflow =
          PhotoCropGeometry.coveredSize(
            const Size(60, 120),
            viewport,
            zoom: zoom,
          ).height -
          viewport.height;
      expect(
        current().imageAlignment.y,
        closeTo(before.y - 40 / overflow, .001),
      );
      expect(current().imageZoom, zoom);
      await gesture.up();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'portrait cover review can be cancelled without a history entry',
    (tester) async {
      final host = GlobalKey<_HostState>();
      final original = _slot('cover');
      await _boot(tester, host, photo, [
        [original],
      ]);
      await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
      await waitForCropPhoto(tester);
      expect(find.text('표지 사진 구도'), findsOneWidget);
      expect(host.currentState!.changes, 0);
      expect(host.currentState!.pages.single.single, same(original));
      await tester.tap(find.byKey(const ValueKey('photo-crop-cancel')));
      await tester.pumpAndSettle();
      expect(host.currentState!.changes, 0);
      expect(host.currentState!.pages.single.single, same(original));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('photo-fill-undo')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cover top crop commits once, survives undo and reopens unchanged',
    (tester) async {
      final host = GlobalKey<_HostState>();
      final original = _slot('cover');
      await _boot(tester, host, photo, [
        [original],
      ]);
      await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
      await waitForCropPhoto(tester);
      await tester.tap(find.text('위쪽'));
      await tester.tap(find.byTooltip('사진 확대'));
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await tester.pumpAndSettle();
      final cropped = host.currentState!.pages.single.single;
      expect(host.currentState!.changes, 1);
      expect(cropped.asset, same(photo));
      expect(cropped.imageAlignment.y, -1);
      expect(cropped.imageZoom, closeTo(1.1, .001));
      expect(cropped.position, original.position);
      expect(cropped.width, original.width);
      expect(cropped.height, original.height);
      await tester.tap(find.byKey(const ValueKey('photo-fill-undo')));
      await tester.pumpAndSettle();
      expect(host.currentState!.pages.single.single, same(original));
      await tester.tap(find.byKey(const ValueKey('photo-fill-redo')));
      await tester.pumpAndSettle();
      expect(
        host.currentState!.pages.single.single.imageOffset,
        cropped.imageOffset,
      );
      expect(
        host.currentState!.pages.single.single.imageZoom,
        cropped.imageZoom,
      );
      await tester.tap(find.byTooltip('사진 구도 조정'));
      await waitForCropPhoto(tester);
      final reopened = tester
          .widget<PhotoCropSheet>(find.byType(PhotoCropSheet))
          .layer;
      expect(reopened.imageOffset, cropped.imageOffset);
      expect(reopened.imageZoom, cropped.imageZoom);
      await tester.tap(find.byKey(const ValueKey('photo-crop-apply')));
      await tester.pumpAndSettle();
      expect(host.currentState!.changes, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'interior photo insertion stays immediate with optional crop action',
    (tester) async {
      final host = GlobalKey<_HostState>();
      await _boot(tester, host, photo, [
        [],
        [_slot('interior')],
      ]);
      await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoCropSheet), findsNothing);
      expect(host.currentState!.pages[1].single.asset, same(photo));
      expect(host.currentState!.changes, 1);
      await tester.tap(find.text('구도 조정'));
      await waitForCropPhoto(tester);
      await tester.tap(find.byKey(const ValueKey('photo-crop-cancel')));
      await tester.pumpAndSettle();
      expect(host.currentState!.changes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'choosing the same photograph keeps its manual crop and history',
    (tester) async {
      final host = GlobalKey<_HostState>();
      final original = _slot(
        'cover',
        photo: photo,
      ).copyWith(imageZoom: 2.3, imageOffset: const Offset(23, 71));
      await _boot(tester, host, photo, [
        [original],
      ]);
      _select(tester, 'cover');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('사진 교체'));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoCropSheet), findsNothing);
      expect(host.currentState!.pages.single.single, same(original));
      expect(host.currentState!.pages.single.single.imageZoom, 2.3);
      expect(
        host.currentState!.pages.single.single.imageOffset,
        const Offset(23, 71),
      );
      expect(host.currentState!.changes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
