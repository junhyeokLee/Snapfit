import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_saved_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_photo_design_view.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../helpers/memory_moment_publication_repository.dart';

const _asset = 'assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg';
final _today = DateTime.utc(2026, 11, 12);

class _Photo extends MomentPhoto {
  const _Photo({super.design})
    : super(id: 'saved-photo', path: '', width: 1200, height: 800);

  @override
  String get storageUri => 'asset:$_asset';
}

class _Engagement extends Fake implements MomentEngagementRepository {
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async => false;
}

MomentPhotoDesign _artwork(CoverSize cover) {
  final canvas = coverCanvasBaseSize(cover);
  return MomentPhotoDesign.fromLayers(
    canvasSize: canvas,
    backgroundColor: const Color(0xFFF9E8BE),
    photoSource: momentPhotoOriginalSource,
    layers: [
      LayerModel(
        id: 'saved-original',
        type: LayerType.image,
        position: const Offset(18, 24),
        width: canvas.width - 36,
        height: canvas.height * .65,
        originalUrl: momentPhotoOriginalSource,
        imageZoom: 1.25,
        imageOffset: const Offset(7, -4),
      ),
      LayerModel(
        id: 'saved-lettering',
        type: LayerType.text,
        position: Offset(24, canvas.height * .8),
        width: canvas.width - 48,
        height: 40,
        text: '내가 남긴 문구',
        textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 22),
        zIndex: 1,
      ),
    ],
  );
}

Future<void> _mount(WidgetTester tester, MomentRecord record) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        momentsCurrentUserIdProvider.overrideWithValue('owner'),
        momentEngagementRepositoryProvider.overrideWithValue(_Engagement()),
        momentPublicationRepositoryProvider.overrideWithValue(
          MemoryMomentPublicationRepository(),
        ),
      ],
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        home: MomentSavedPreviewScreen(
          record: record,
          journal: MomentJournal(
            today: _today,
            weekStart: momentWeekStart(_today),
            month: momentMonth(_today),
            records: [
              MomentRecord(
                id: 'another-day',
                recordDate: DateTime.utc(2026, 11, 11),
                caption: '합성 표지에 섞이면 안 되는 다른 날',
                revision: 1,
                photos: const [
                  MomentPhoto(
                    id: 'another-photo',
                    path: '',
                    url: 'asset:assets/frame_preview/forest_trail.jpg',
                    width: 1000,
                    height: 667,
                  ),
                ],
              ),
              record,
            ],
            weekPhotoCount: 2,
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(() async {
    await precacheImage(
      ResizeImage(const AssetImage(_asset), width: 1200),
      tester.element(find.byType(MomentSavedPreviewScreen)),
    );
  });
  for (var frame = 0; frame < 6; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 32));
  }
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

MomentRecord _record(MomentPhoto photo) => MomentRecord(
  id: 'saved',
  recordDate: _today,
  caption: '방금 저장한 순간',
  photos: [photo],
  revision: 1,
);

void main() {
  for (final cover in [defaultCoverSize, coverSizes[1], coverSizes[2]]) {
    testWidgets(
      'saved ${cover.productId} shows the untouched photo artboard without generated cover layers',
      (tester) async {
        final design = _artwork(cover);
        final before = design.toJson();
        final photo = _Photo(design: design);
        await _mount(tester, _record(photo));

        final preview = find.byKey(const ValueKey('moment-saved-photo'));
        expect(preview, findsOneWidget);
        final view = tester.widget<MomentPhotoView>(preview);
        expect(view.photo, same(photo));
        expect(view.fit, BoxFit.contain);
        expect(view.backgroundColor, Colors.transparent);
        final size = tester.getSize(preview);
        expect(size.aspectRatio, closeTo(design.aspectRatio, .000001));
        final artwork = tester.widget<MomentPhotoDesignView>(
          find.descendant(
            of: preview,
            matching: find.byType(MomentPhotoDesignView),
          ),
        );
        expect(artwork.design, same(design));
        expect(design.toJson(), before);
        expect(design.backgroundColor, const Color(0xFFF9E8BE));
        expect(find.byType(TemplatePageRenderer), findsNothing);
        expect(find.text('2026년 11월의 순간들'), findsNothing);
        expect(find.text('사진 1 / 2'), findsNothing);
        expect(find.text('나의 한 달에\n한 장이 더 쌓였어요.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'an original photo keeps its own proportion without added paper',
    (tester) async {
      const photo = _Photo();
      await _mount(tester, _record(photo));
      final preview = find.byKey(const ValueKey('moment-saved-photo'));
      final view = tester.widget<MomentPhotoView>(preview);
      expect(view.photo, same(photo));
      expect(view.aspectRatio, 1.5);
      expect(view.backgroundColor, Colors.transparent);
      expect(tester.getSize(preview).aspectRatio, closeTo(1.5, .000001));
      expect(find.byType(TemplatePageRenderer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
