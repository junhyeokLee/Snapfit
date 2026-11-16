import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_photo_design_view.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

const _asset =
    'asset:assets/templates/jeju_travel/images/figma_small/jeju_ocean.jpg';

class _Photo extends MomentPhoto {
  const _Photo({required super.id, super.design})
    : super(path: '', width: 1200, height: 800);

  @override
  String get storageUri => _asset;
}

final _design = MomentPhotoDesign.fromLayers(
  canvasSize: const Size(400, 600),
  backgroundColor: const Color(0xFFF3E8DA),
  photoSource: momentPhotoOriginalSource,
  layers: [
    LayerModel(
      id: 'photo',
      type: LayerType.image,
      position: const Offset(20, 30),
      width: 360,
      height: 430,
      originalUrl: momentPhotoOriginalSource,
      imageZoom: 1.5,
      imageOffset: const Offset(8, -6),
    ),
  ],
);

MomentRecord _record(String id, {List<MomentPhoto>? photos}) => MomentRecord(
  id: id,
  recordDate: DateTime.utc(2026, 11, 4),
  caption: '그날 저장했던 바다의 빛',
  photos: photos ?? [_Photo(id: '$id-first', design: _design)],
  revision: 1,
);

Future<void> _mount(
  WidgetTester tester,
  MomentRecord record, {
  bool initiallyExpanded = false,
  int? expandRequest,
  VoidCallback? onEdit,
  ValueChanged<MomentPhoto>? onShare,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: SnapFitTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: MomentRecordCard(
              key: const ValueKey('same-record-slot'),
              record: record,
              initiallyExpanded: initiallyExpanded,
              expandRequest: expandRequest,
              onEdit: onEdit ?? () {},
              onShare: onShare,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  // 실제 엔진 사진 디코딩은 가상 시간을 진행하는 것만으로 끝나지 않는다.
  for (var frame = 0; frame < 8; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 35));
  }
  expect(tester.takeException(), isNull);
}

Future<void> _toggle(WidgetTester tester, String id) async {
  final header = find.byKey(ValueKey('moment-record-toggle-$id'));
  await tester.ensureVisible(header);
  await tester.tap(header);
  await _settle(tester);
}

void main() {
  testWidgets(
    'saved record opens its original artwork and closes without editing',
    (tester) async {
      var edits = 0;
      final record = _record('one');
      await _mount(tester, record, onEdit: () => edits++);

      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
      expect(find.byType(MomentPhotoView), findsNothing);
      expect(find.byKey(const ValueKey('moment-edit-one')), findsNothing);

      await _toggle(tester, 'one');
      final photo = tester.widget<MomentPhotoView>(
        find.byType(MomentPhotoView),
      );
      expect(photo.photo, same(record.photos.first));
      expect(photo.aspectRatio, _design.aspectRatio);
      expect(photo.fit, BoxFit.contain);
      expect(
        tester
            .widget<MomentPhotoDesignView>(find.byType(MomentPhotoDesignView))
            .design,
        same(_design),
      );
      expect(find.text(record.caption), findsOneWidget);
      expect(edits, 0);

      await _toggle(tester, 'one');
      expect(find.byType(MomentPhotoView), findsNothing);
      expect(edits, 0);
    },
  );

  testWidgets(
    'expanded actions share the selected saved photograph and label editing',
    (tester) async {
      String? shared;
      var edits = 0;
      final record = _record(
        'two',
        photos: const [
          _Photo(id: 'first'),
          _Photo(id: 'second'),
        ],
      );
      await _mount(
        tester,
        record,
        onShare: (photo) => shared = photo.id,
        onEdit: () => edits++,
      );
      await _toggle(tester, 'two');
      final photos = find.byKey(const ValueKey('moment-photos-two'));
      await tester.ensureVisible(photos);
      await tester.drag(photos, const Offset(-800, 0));
      await _settle(tester);
      final share = find.byKey(const ValueKey('moment-share-two'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      expect(shared, 'second');
      expect(edits, 0);
      await _toggle(tester, 'two');
      await _toggle(tester, 'two');
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.ensureVisible(share);
      await tester.tap(share);
      expect(shared, 'first');
      final edit = find.byKey(const ValueKey('moment-edit-two'));
      expect(
        find.descendant(of: edit, matching: find.text('기록 다듬기')),
        findsOneWidget,
      );
      await tester.tap(edit);
      expect(edits, 1);
    },
  );

  testWidgets('a different record in the same slot starts closed', (
    tester,
  ) async {
    await _mount(tester, _record('old'));
    await _toggle(tester, 'old');
    expect(find.byType(MomentPhotoView), findsOneWidget);
    await _mount(tester, _record('new'));
    await _settle(tester);
    expect(find.byType(MomentPhotoView), findsNothing);
    expect(
      find.byKey(const ValueKey('moment-record-toggle-new')),
      findsOneWidget,
    );
  });

  testWidgets(
    'date navigation reopens on a new request but a refresh preserves a manual close',
    (tester) async {
      final record = _record('selected');
      await _mount(tester, record);
      await _mount(tester, record, initiallyExpanded: true, expandRequest: 1);
      await _settle(tester);
      expect(find.byType(MomentPhotoView), findsOneWidget);
      await _toggle(tester, 'selected');
      await _mount(tester, record, initiallyExpanded: true, expandRequest: 1);
      await _settle(tester);
      expect(find.byType(MomentPhotoView), findsNothing);
      await _mount(tester, record, initiallyExpanded: true, expandRequest: 2);
      await _settle(tester);
      expect(find.byType(MomentPhotoView), findsOneWidget);
    },
  );

  testWidgets('disclosure and saved aspect fit 320 pixels with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _mount(tester, _record('large'), scale: 2);
    await _toggle(tester, 'large');
    final size = tester.getSize(
      find.byKey(const ValueKey('moment-photo-frame-large')),
    );
    expect(size.width / size.height, closeTo(_design.aspectRatio, .001));
    expect(tester.takeException(), isNull);
  });
}
