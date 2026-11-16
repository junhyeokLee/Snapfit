import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_archive_shelf.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_reader_page_content.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_month_calendar.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_photo_design_view.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

const _asset =
    'asset:assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg';
final _today = DateTime.utc(2026, 11, 4);

// Use an existing bundled photograph, while production still resolves each
// owner's private storage source through the shared image widget.
class _Photo extends MomentPhoto {
  const _Photo({super.design, super.width = 1200, super.height = 800})
    : super(id: 'photo', path: 'owner/moments/record/photo.png');
  @override
  String get storageUri => _asset;
}

MomentPhotoDesign _legacyDesign() => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(400, 600),
  backgroundColor: const Color(0xFFF3E8DA),
  photoSource: momentPhotoOriginalSource,
  layers: [
    LayerModel(
      id: 'original',
      type: LayerType.image,
      position: const Offset(20, 30),
      width: 360,
      height: 430,
      originalUrl: momentPhotoOriginalSource,
      imageZoom: 1.5,
      imageOffset: const Offset(8, -6),
    ),
    LayerModel(
      id: 'note',
      type: LayerType.text,
      position: const Offset(30, 490),
      width: 330,
      height: 60,
      text: '오래 기억할 바다',
      zIndex: 1,
      textStyle: const TextStyle(fontSize: 26, fontFamily: 'NotoSans'),
    ),
  ],
);

Future<void> _mount(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: SnapFitTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

Future<void> _settlePhoto(WidgetTester tester) async {
  for (var pass = 0; pass < 6; pass++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  await tester.pumpAndSettle();
}

void main() {
  test(
    'display aspect uses the saved canvas and gives old originals the default album frame',
    () {
      const raw = _Photo(width: 900, height: 1600);
      expect(raw.aspectRatio, 900 / 1600);
      expect(momentPhotoAspect(raw), defaultCoverSize.ratio);
      final legacy = _Photo(design: _legacyDesign());
      expect(momentPhotoAspect(legacy), 2 / 3);
      final formatted = _Photo(
        design: newMomentPhotoDesign(
          photoSize: const Size(1200, 800),
          cover: coverSizes[1],
        ),
      );
      expect(momentPhotoAspect(formatted), 4 / 3);
    },
  );

  testWidgets('old originals share a square frame with no photo cropping', (
    tester,
  ) async {
    await _mount(
      tester,
      const SizedBox(
        width: 240,
        child: MomentPhotoView(
          photo: _Photo(width: 900, height: 1600),
          imageDecodeWidth: 256,
        ),
      ),
    );
    final frame = tester.getSize(find.byType(MomentPhotoView));
    expect(frame.width / frame.height, 1);
    final image = tester.widget<SnapfitImage>(find.byType(SnapfitImage));
    expect(image.fit, BoxFit.contain);
    expect(image.memCacheWidth, 256);
    expect(image.urlOrGs, _asset);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a legacy artboard retains its exact ratio, edits and canvas', (
    tester,
  ) async {
    final design = _legacyDesign();
    await _mount(
      tester,
      Center(
        child: SizedBox(
          width: 240,
          child: MomentPhotoView(photo: _Photo(design: design)),
        ),
      ),
    );
    await tester.pump();
    final frame = tester.getSize(find.byType(MomentPhotoView));
    expect(frame.width / frame.height, closeTo(2 / 3, .000001));
    expect(find.text('오래 기억할 바다'), findsOneWidget);
    final page = tester.widget<AlbumReaderPageContent>(
      find.byType(AlbumReaderPageContent),
    );
    expect(page.baseCanvasSize, const Size(400, 600));
    expect(page.layers.first.imageZoom, 1.5);
    expect(page.layers.first.imageOffset, const Offset(8, -6));
    expect(design.canvasSize, const Size(400, 600));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'small slots contain the complete artwork at a bounded decode width',
    (tester) async {
      final design = _legacyDesign();
      await _mount(
        tester,
        Center(
          child: SizedBox(
            width: 112,
            height: 80,
            child: MomentPhotoView(
              photo: _Photo(design: design),
              imageDecodeWidth: 112,
            ),
          ),
        ),
      );
      await tester.pump();
      final view = tester.widget<MomentPhotoDesignView>(
        find.byType(MomentPhotoDesignView),
      );
      expect(view.fit, BoxFit.contain);
      expect(view.imageDecodeWidth, 112);
      final page = tester.widget<AlbumReaderPageContent>(
        find.byType(AlbumReaderPageContent),
      );
      expect(page.targetW / page.targetH, closeTo(2 / 3, .000001));
      expect(page.previewBuilder.previewImageDecodeWidth, 112);
      expect(find.text('오래 기억할 바다'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('saved overflow stays clipped inside a wider thumbnail slot', (
    tester,
  ) async {
    final design = MomentPhotoDesign.fromLayers(
      canvasSize: const Size(100, 200),
      backgroundColor: Colors.white,
      photoSource: momentPhotoOriginalSource,
      layers: [
        LayerModel(
          id: 'original',
          type: LayerType.image,
          position: Offset.zero,
          width: 100,
          height: 200,
          originalUrl: momentPhotoOriginalSource,
          opacity: 0,
        ),
        LayerModel(
          id: 'overflow',
          type: LayerType.decoration,
          position: const Offset(-20, 50),
          width: 40,
          height: 50,
          imageBackground: 'stickerTapeBeige',
          zIndex: 1,
        ),
      ],
    );
    final key = GlobalKey();
    await _mount(
      tester,
      Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 240,
            height: 80,
            child: ColoredBox(
              color: Colors.green,
              child: MomentPhotoView(
                photo: _Photo(design: design),
                imageDecodeWidth: 128,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final pixels = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    });
    Color at(int x, int y) {
      final index = (y * 240 + x) * 4;
      return Color.fromARGB(
        pixels!.getUint8(index + 3),
        pixels.getUint8(index),
        pixels.getUint8(index + 1),
        pixels.getUint8(index + 2),
      );
    }

    expect(at(90, 30).toARGB32(), Colors.green.toARGB32());
    expect(at(103, 30).toARGB32(), isNot(Colors.green.toARGB32()));
    expect(at(103, 30).toARGB32(), isNot(Colors.white.toARGB32()));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact home and independent archive retain saved artwork and date actions',
    (tester) async {
      final design = _legacyDesign();
      MomentRecord record(String id, DateTime day) => MomentRecord(
        id: id,
        recordDate: day,
        caption: '오늘의 기록',
        photos: [_Photo(design: design)],
        revision: 1,
      );
      final previous = DateTime.utc(2026, 11, 3);
      final journal = MomentJournal(
        today: _today,
        weekStart: momentWeekStart(_today),
        month: momentMonth(_today),
        records: [record('today', _today), record('yesterday', previous)],
        weekPhotoCount: 2,
      );
      DateTime? opened;
      await tester.binding.setSurfaceSize(const Size(390, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            momentEntryJournalProvider.overrideWith((ref) async => journal),
          ],
          child: MaterialApp(
            theme: SnapFitTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeMomentSummaryCard(
                      onRecord: () {},
                      onOpenMonth: () {},
                      onSignIn: () {},
                      onOpenDate: (day) => opened = day,
                    ),
                    HomeMomentArchiveShelf(
                      onOpenDate: (day) => opened = day,
                      onOpenMonth: (_) {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final home = find.byType(HomeMomentSummaryCard);
      final archive = find.byType(HomeMomentArchiveShelf);
      // 홈 주간 표시는 사진을 중복 렌더링하지 않으며 각 경로는 원본 지면을 보존한다.
      expect(
        find.descendant(of: home, matching: find.byType(MomentPhotoDesignView)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: archive,
          matching: find.byType(MomentPhotoDesignView),
        ),
        findsOneWidget,
      );
      final preview = find.byKey(
        const ValueKey('home-monthly-feed-today-photo'),
      );
      final previewSize = tester.getSize(preview);
      expect(previewSize.width, lessThanOrEqualTo(104));
      expect(previewSize.height, lessThanOrEqualTo(120));
      expect(
        previewSize.aspectRatio,
        closeTo(momentPhotoAspect(_Photo(design: design)), .000001),
      );
      for (final view in tester.widgetList<MomentPhotoView>(
        find.byType(MomentPhotoView),
      )) {
        expect(view.photo!.design, same(design));
        expect(view.fit, BoxFit.contain);
        expect(view.aspectRatio, closeTo(design.aspectRatio, .000001));
        expect(view.imageDecodeWidth, lessThanOrEqualTo(384));
      }
      for (final page in tester.widgetList<AlbumReaderPageContent>(
        find.byType(AlbumReaderPageContent),
      )) {
        expect(page.baseCanvasSize, const Size(400, 600));
        expect(page.layers.first.imageZoom, 1.5);
        expect(page.layers.first.imageOffset, const Offset(8, -6));
      }
      await tester.tap(
        find.byKey(const ValueKey('home-monthly-feed-today-photo')),
      );
      expect(opened, _today);
      await tester.tap(
        find.byKey(const ValueKey('home-moment-archive-2026-11-03')),
      );
      expect(opened, previous);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'calendar keeps the saved composition and small decode budget without changing date navigation',
    (tester) async {
      final design = _legacyDesign();
      DateTime? opened;
      await _mount(
        tester,
        SizedBox(
          width: 390,
          child: MomentMonthCalendar(
            month: momentMonth(_today),
            records: [
              MomentRecord(
                id: 'today',
                recordDate: _today,
                caption: '',
                photos: [_Photo(design: design)],
                revision: 1,
              ),
            ],
            onDateSelected: (day) => opened = day,
          ),
        ),
      );
      await tester.pump();
      final view = tester.widget<MomentPhotoView>(find.byType(MomentPhotoView));
      expect(view.photo!.design, same(design));
      expect(view.imageDecodeWidth, 112);
      final page = tester.widget<AlbumReaderPageContent>(
        find.byType(AlbumReaderPageContent),
      );
      expect(page.baseCanvasSize, const Size(400, 600));
      expect(page.previewBuilder.previewImageDecodeWidth, 112);
      await tester.tap(
        find.byKey(const ValueKey('moments-calendar-2026-11-04')),
      );
      expect(opened, _today);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated local previews reuse bounded decoded photo preparation',
    (tester) async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 32, height: 48)),
      );
      final design = newMomentPhotoDesign(photoSize: const Size(32, 48));
      await _mount(
        tester,
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              SizedBox(
                width: 128,
                height: 128,
                child: MomentPhotoView(
                  bytes: bytes,
                  design: design,
                  imageDecodeWidth: 128,
                ),
              ),
          ],
        ),
      );
      await _settlePhoto(tester);
      final pages = tester
          .widgetList<AlbumReaderPageContent>(
            find.byType(AlbumReaderPageContent),
          )
          .toList();
      expect(pages, hasLength(2));
      expect(pages.first.layers.first.asset, isNotNull);
      expect(
        pages.first.layers.first.asset,
        same(pages.last.layers.first.asset),
      );
      expect(pages.first.previewBuilder.previewImageDecodeWidth, 128);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
