import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/gallery_repository.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_plan.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/shared/widgets/browser_photo_selection_sheet.dart';

import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change(String? owner) => state = owner;
}

class _NativeGallery extends Fake implements GalleryRepository {}

final _ownerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

BrowserPhotoFile _file(String name) {
  // 다른 너비는 사진별 해시를 구분한다. 네트워크와 기기 사진첩은 사용하지 않는다.
  final bytes = browserPhotoFixture(width: 20 + name.codeUnitAt(0) - 65);
  return BrowserPhotoFile(
    name: '$name.png',
    size: bytes.length,
    readBytes: () async => bytes,
  );
}

class _Fixture {
  _Fixture(this.container, this.repository);
  final ProviderContainer container;
  final BrowserGalleryRepository repository;
  List<AssetEntity>? result;
  bool completed = false;

  Finder photo(String name) => find.byKey(
    ValueKey(
      'browser-photo-${repository.photos.singleWhere((photo) => photo.title == '$name.png').id}',
    ),
  );
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  int maxSelection = 10,
  bool nativeRepository = false,
  Future<List<BrowserPhotoFile>> Function()? selectFiles,
}) async {
  tester.view.physicalSize = const Size(1000, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  late ProviderContainer container;
  final repository = BrowserGalleryRepository(
    currentOwner: () => container.read(_ownerProvider),
  );
  container = ProviderContainer(
    overrides: [
      galleryRepositoryProvider.overrideWithValue(
        nativeRepository ? _NativeGallery() : repository,
      ),
      visibleOrderOwnerProvider.overrideWith(
        (ref) => ref.watch(_ownerProvider),
      ),
    ],
  );
  final fixture = _Fixture(container, repository);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });
  if (!nativeRepository) {
    await tester.runAsync(
      () => repository.importFiles([
        for (final name in ['A', 'B', 'C']) _file(name),
      ]),
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                // 순서와 복구는 실제 공개 모달 API를 사용한다. 파일 가져오기만 공개 주입점을 쓴다.
                fixture.result = selectFiles == null
                    ? await showBrowserPhotosSelectionSheet(
                        context,
                        maxSelection: maxSelection,
                      )
                    : await showDialog<List<AssetEntity>>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => Dialog(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 1040,
                              maxHeight: 820,
                            ),
                            child: BrowserPhotoSelectionSheet(
                              maxSelection: maxSelection,
                              selectFiles: selectFiles,
                            ),
                          ),
                        ),
                      );
                fixture.completed = true;
              },
              child: const Text('사진 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('사진 열기'));
  await tester.pumpAndSettle();
  return fixture;
}

Future<void> _confirm(WidgetTester tester) async {
  // 선택 직후의 활성화 상태를 반영한 뒤 실제 완료 버튼을 누른다.
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('confirm-browser-photo-selection')),
  );
  await tester.pumpAndSettle();
}

Future<void> _importFiles(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('browser-photo-pick-files')));
  // 실제 이미지 코덱의 완료를 기다린다. 테스트의 가상 시간만 진행하면 디코딩이 끝나지 않는다.
  for (var frame = 0; frame < 80; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    if (find.text('사진 읽는 중').evaluate().isEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Local photo import did not complete');
}

void main() {
  testWidgets(
    'returns tapped C then A and fills template slots in that order',
    (tester) async {
      final fixture = await _mount(tester);
      await tester.tap(fixture.photo('C'));
      await tester.tap(fixture.photo('A'));
      await _confirm(tester);
      expect(fixture.completed, isTrue);
      expect(fixture.result!.map((photo) => photo.title), ['C.png', 'A.png']);
      final plan = TemplatePhotoFillPlan.create(
        pages: [
          for (var page = 0; page < 2; page++)
            [
              LayerModel(
                id: 'empty-$page',
                type: LayerType.image,
                position: Offset.zero,
                width: 100,
                height: 100,
              ),
            ],
        ],
        photos: fixture.result!,
      );
      expect(plan.placements.map((placement) => placement.photo.title), [
        'C.png',
        'A.png',
      ]);
    },
  );

  testWidgets(
    'selection badges and spoken order follow deselect and reselect',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final fixture = await _mount(tester);
        await tester.tap(fixture.photo('C'));
        await tester.tap(fixture.photo('A'));
        await tester.tap(fixture.photo('C'));
        await tester.tap(fixture.photo('C'));
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: fixture.photo('A'), matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: fixture.photo('C'), matching: find.text('2')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'A\.png.*1번째 선택')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'C\.png.*2번째 선택')),
          findsOneWidget,
        );
        await _confirm(tester);
        expect(fixture.result!.map((photo) => photo.title), ['A.png', 'C.png']);
      } finally {
        // 위젯 테스트 종료 불변식 검사 전에 접근성 핸들을 해제한다.
        semantics.dispose();
      }
    },
  );

  testWidgets('imports append auto-selected photos after existing choices', (
    tester,
  ) async {
    final fixture = await _mount(
      tester,
      selectFiles: () async => [_file('D'), _file('E')],
    );
    await tester.tap(fixture.photo('C'));
    await _importFiles(tester);
    expect(find.text('3장 선택 완료'), findsOneWidget);
    await _confirm(tester);
    expect(fixture.result!.map((photo) => photo.title), [
      'C.png',
      'D.png',
      'E.png',
    ]);
  });

  testWidgets(
    'import and manual selection respect the maximum without losing order',
    (tester) async {
      final fixture = await _mount(
        tester,
        maxSelection: 2,
        selectFiles: () async => [_file('D'), _file('E')],
      );
      await tester.tap(fixture.photo('C'));
      await _importFiles(tester);
      expect(find.text('2장 선택 완료'), findsOneWidget);
      await tester.tap(fixture.photo('A'));
      await tester.pumpAndSettle();
      expect(find.textContaining('한 번에 최대 2장'), findsOneWidget);
      await _confirm(tester);
      expect(fixture.result!.map((photo) => photo.title), ['C.png', 'D.png']);
    },
  );

  testWidgets('busy file selection keeps close and photo actions disabled', (
    tester,
  ) async {
    final pending = Completer<List<BrowserPhotoFile>>();
    final fixture = await _mount(tester, selectFiles: () => pending.future);
    await tester.tap(fixture.photo('C'));
    await tester.tap(find.byKey(const ValueKey('browser-photo-pick-files')));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == '사진 선택 닫기',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('confirm-browser-photo-selection')),
          )
          .onPressed,
      isNull,
    );
    expect(tester.widget<InkWell>(fixture.photo('A')).onTap, isNull);
    pending.complete(const []);
    await tester.pumpAndSettle();
    await _confirm(tester);
    expect(fixture.result!.map((photo) => photo.title), ['C.png']);
  });

  testWidgets('account change hides photos and explicit close returns null', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await tester.tap(fixture.photo('C'));
    fixture.container.read(_ownerProvider.notifier).change('owner-b');
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const ValueKey('confirm-browser-photo-selection')),
      findsNothing,
    );
    expect(find.textContaining('로그인한 계정이 변경됐어요'), findsOneWidget);
    expect(
      tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).dismissible,
      isFalse,
    );
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(fixture.completed, isTrue);
    expect(fixture.result, isNull);
    expect(find.byType(BrowserPhotoSelectionSheet), findsNothing);
  });

  testWidgets(
    'account change can close a pending chooser without importing its late result',
    (tester) async {
      final pending = Completer<List<BrowserPhotoFile>>();
      final fixture = await _mount(tester, selectFiles: () => pending.future);
      await tester.tap(fixture.photo('C'));
      await tester.tap(find.byKey(const ValueKey('browser-photo-pick-files')));
      await tester.pump();
      fixture.container.read(_ownerProvider.notifier).change('owner-b');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(fixture.completed, isTrue);
      expect(fixture.result, isNull);
      // 닫힌 이전 계정의 파일 선택 결과가 도착해도 새 계정의 보관 목록에 들어가면 안 된다.
      pending.complete([_file('D')]);
      await tester.pumpAndSettle();
      expect(fixture.repository.photos, isEmpty);
      expect(fixture.result, isNull);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(BrowserPhotoSelectionSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable browser repository can be closed without returning photos',
    (tester) async {
      final fixture = await _mount(tester, nativeRepository: true);
      expect(find.byType(Image), findsNothing);
      expect(
        find.byKey(const ValueKey('browser-photo-pick-files')),
        findsNothing,
      );
      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(fixture.completed, isTrue);
      expect(fixture.result, isNull);
      expect(find.byType(BrowserPhotoSelectionSheet), findsNothing);
    },
  );
}
