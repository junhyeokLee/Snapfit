// 실제 웹용 사진 위젯과 번들 사진을 사용하며 파일 선택창·서버 요청은 호출하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_plan.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/shared/widgets/browser_photo_selection_sheet.dart';

import 'file:///tmp/snapfit-ux-applied-20261116/audit_support.dart';

class _PhotoOwner extends Notifier<String?> {
  @override
  String? build() => 'audit-owner-a';
  void change(String? value) => state = value;
}

final _photoOwner = NotifierProvider<_PhotoOwner, String?>(_PhotoOwner.new);

class _Fixture {
  _Fixture(this.container, this.photos);
  final ProviderContainer container;
  final List<AssetEntity> photos;
  List<AssetEntity>? returned;
  bool completed = false;
  Finder photo(String name) => find.byKey(
    ValueKey(
      'browser-photo-${photos.singleWhere((photo) => photo.title == name).id}',
    ),
  );
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  double textScale = 1,
}) async {
  auditViewport(tester, size: size);
  late ProviderContainer container;
  final repository = BrowserGalleryRepository(
    currentOwner: () => container.read(_photoOwner),
  );
  container = ProviderContainer(
    overrides: [
      visibleOrderOwnerProvider.overrideWith((ref) => ref.watch(_photoOwner)),
      galleryRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
  });
  final images = [
    ('A-첫 장면.jpg', 'assets/snapfit_home_square.jpg'),
    ('B-중간 장면.jpg', 'assets/snapfit_home_landscape.jpg'),
    ('C-마지막 장면.jpg', 'assets/snapfit_home_portrait.jpg'),
  ];
  await tester.runAsync(() async {
    final files = <BrowserPhotoFile>[];
    for (final (name, path) in images) {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      files.add(
        BrowserPhotoFile(
          name: name,
          size: bytes.length,
          readBytes: () async => bytes,
        ),
      );
    }
    final result = await repository.importFiles(files);
    expect(result.messages, isEmpty);
    expect(result.added, hasLength(3));
  });
  final fixture = _Fixture(container, repository.photos);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: auditFrame(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            appBar: AppBar(title: const Text('앨범 만들기')),
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async {
                    fixture.returned = await showBrowserPhotosSelectionSheet(
                      context,
                      maxSelection: 10,
                    );
                    fixture.completed = true;
                  },
                  child: const Text('사진 추가'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _open(WidgetTester tester, _Fixture fixture) async {
  fixture.returned = null;
  fixture.completed = false;
  await tester.tap(find.text('사진 추가'));
  await tester.pumpAndSettle();
}

Future<void> _closeChangedOwner(WidgetTester tester, _Fixture fixture) async {
  expect(find.byType(Image), findsNothing);
  expect(
    find.byKey(const ValueKey('confirm-browser-photo-selection')),
    findsNothing,
  );
  final close = find.text('닫기');
  await tester.ensureVisible(close);
  await tester.pumpAndSettle();
  expect(close.hitTestable(), findsOneWidget);
  await tester.tap(close);
  await tester.pumpAndSettle();
  expect(fixture.completed, isTrue);
  expect(fixture.returned, isNull);
  expect(find.byType(BrowserPhotoSelectionSheet), findsNothing);
}

void main() {
  setUpAll(auditFonts);

  testWidgets(
    'capture web photo tap order badges return order and explicit account close',
    (tester) async {
      final fixture = await _mount(tester);
      await _open(tester, fixture);
      await tester.tap(fixture.photo('C-마지막 장면.jpg'));
      await tester.tap(fixture.photo('A-첫 장면.jpg'));
      await tester.pumpAndSettle();
      expect(find.text('2장 선택 완료'), findsOneWidget);
      expect(
        find.descendant(
          of: fixture.photo('C-마지막 장면.jpg'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: fixture.photo('A-첫 장면.jpg'),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await auditCapture(tester, '20-web-photo-selected-c1-a2-390-light');
      await tester.tap(
        find.byKey(const ValueKey('confirm-browser-photo-selection')),
      );
      await tester.pumpAndSettle();
      expect(fixture.completed, isTrue);
      expect(fixture.returned!.map((photo) => photo.title), [
        'C-마지막 장면.jpg',
        'A-첫 장면.jpg',
      ]);
      final plan = TemplatePhotoFillPlan.create(
        pages: [
          for (var index = 0; index < 2; index++)
            [
              LayerModel(
                id: 'empty-$index',
                type: LayerType.image,
                position: Offset.zero,
                width: 100,
                height: 100,
              ),
            ],
        ],
        photos: fixture.returned!,
      );
      expect(plan.placements.map((placement) => placement.photo.title), [
        'C-마지막 장면.jpg',
        'A-첫 장면.jpg',
      ]);
      debugPrint('PHOTO_ORDER: tapped=C,A; returned=C,A; placement=C,A');

      await _open(tester, fixture);
      fixture.container.read(_photoOwner.notifier).change('audit-owner-b');
      await tester.pumpAndSettle();
      expect(find.textContaining('사진 선택창을 닫고 다시 열어주세요'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await auditCapture(tester, '21-web-photo-account-changed-390-light');
      await _closeChangedOwner(tester, fixture);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('capture web photo account notice small dark at large text', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      size: const Size(320, 568),
      dark: true,
      textScale: 1.8,
    );
    await _open(tester, fixture);
    fixture.container.read(_photoOwner.notifier).change('audit-owner-b');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('닫기').hitTestable(), findsOneWidget);
    await auditCapture(tester, '22-web-photo-account-changed-320-dark-text180');
    await _closeChangedOwner(tester, fixture);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
