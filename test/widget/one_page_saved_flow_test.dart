import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_save_progress.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import 'page_editor_screen_golden_test.dart'
    show MockAlbumRepository, FakeStorageService, FakeAlbumPersistenceService;

/// Uses the real editor/canvas/navigation with an isolated save acknowledgement.
/// A pending or failed response never counts as a confirmed account save.
class _Editor extends AlbumEditorViewModel {
  Completer<bool> response = Completer<bool>();
  var saves = 0;
  var dirty = true;
  var editedDuringSave = false;

  @override
  Album get album => const Album(
    id: 71,
    userId: 'owner',
    updatedAt: 'saved-revision',
    memberRole: 'OWNER',
  );
  @override
  bool get editingAllowed => true;
  @override
  bool get hasUnsavedChanges => dirty;
  @override
  Object get lastSaveError => StateError('temporary save failure');
  @override
  Future<void> checkRemoteAlbum() async {}
  @override
  Future<bool> saveFullAlbum({
    Uint8List? coverImageBytes,
    void Function(AlbumSaveProgress)? onProgress,
  }) async {
    saves++;
    final saved = await response.future;
    if (saved && !editedDuringSave) dirty = false;
    return saved;
  }
}

class _Fixture {
  final editor = _Editor();
  late ProviderContainer container;

  Future<void> mount(
    WidgetTester tester, {
    bool firstPageComplete = true,
    bool secondPageComplete = false,
    int initialPageIndex = 1,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
        albumEditorOwnerChangesProvider.overrideWith(
          (_) => const Stream.empty(),
        ),
        albumEditorViewModelProvider.overrideWith(() => editor),
      ],
    );
    await container.read(albumEditorViewModelProvider.future);
    editor.startLocalTemplateAlbum(
      albumTitle: '한 쪽씩 남기는 앨범',
      initialCover: coverSizes.first,
      pages: [
        [
          LayerModel(
            id: 'cover',
            type: LayerType.text,
            position: Offset.zero,
            text: '표지',
          ),
        ],
        [
          LayerModel(
            id: 'first-note',
            type: LayerType.text,
            position: const Offset(60, 60),
            text: firstPageComplete ? '오늘 남긴 나의 기록' : '기본 문구',
            isTemplateContent: !firstPageComplete,
            textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 20),
          ),
        ],
        [
          LayerModel(
            id: 'next-note',
            type: LayerType.text,
            position: const Offset(60, 60),
            text: secondPageComplete ? '나의 두 번째 기록' : '다음 쪽의 기본 문구',
            isTemplateContent: !secondPageComplete,
            textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 20),
          ),
        ],
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) => MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PageEditorScreen(
                        initialPageIndex: initialPageIndex,
                        onePageGoal: true,
                      ),
                    ),
                  ),
                  child: const Text('홈에서 한 쪽 시작'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('홈에서 한 쪽 시작'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
  }
}

Future<void> _saveCurrentPage(WidgetTester tester) async {
  // Native and web use their own editor chrome. Exercise the same visible
  // action in both instead of depending on the native-only button key.
  final action = find.text('이 쪽 저장');
  expect(action, findsOneWidget);
  await tester.ensureVisible(action);
  await tester.tap(action);
}

void main() {
  testWidgets(
    'next-page choice appears only after a confirmed save, then opens the next unfinished page',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      try {
        expect(find.text('이 쪽 저장'), findsOneWidget);
        await _saveCurrentPage(tester);
        await tester.pump();
        expect(fixture.editor.saves, 1);
        expect(
          find.byKey(const ValueKey('one-page-saved-choice')),
          findsNothing,
        );
        expect(find.byType(PageEditorScreen), findsOneWidget);
        fixture.editor.response.complete(true);
        await tester.pumpAndSettle();
        expect(find.text('1쪽을 완성했어요.'), findsOneWidget);
        expect(find.text('2쪽 이어 채우기'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('one-page-next')));
        await tester.pumpAndSettle();
        expect(fixture.editor.currentPageIndex, 2);
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'saved second page offers its earlier unfinished page without calling it next',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(
        tester,
        firstPageComplete: false,
        secondPageComplete: true,
        initialPageIndex: 2,
      );
      try {
        expect(fixture.editor.currentPageIndex, 2);
        final unfinishedPageId = fixture.editor.pages[1].id;
        await _saveCurrentPage(tester);
        await tester.pump();
        fixture.editor.response.complete(true);
        await tester.pumpAndSettle();

        expect(find.text('2쪽을 완성했어요.'), findsOneWidget);
        expect(find.text('1쪽 이어 채우기'), findsOneWidget);
        // 앞쪽 미완성 쪽으로 돌아가도 저장한 쪽이나 다른 쪽을 열지 않는다.
        await tester.tap(find.byKey(const ValueKey('one-page-next')));
        await tester.pumpAndSettle();
        expect(fixture.editor.currentPageIndex, 1);
        expect(
          fixture.editor.pages[fixture.editor.currentPageIndex].id,
          unfinishedPageId,
        );
        expect(
          find.byKey(const ValueKey('one-page-saved-choice')),
          findsNothing,
        );
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'failed save stays in the editor and a successful retry permits finishing today',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester, firstPageComplete: false);
      try {
        await _saveCurrentPage(tester);
        await tester.pump();
        fixture.editor.response.complete(false);
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('one-page-saved-choice')),
          findsNothing,
        );
        expect(fixture.editor.hasUnsavedChanges, isTrue);
        fixture.editor.response = Completer<bool>();
        await _saveCurrentPage(tester);
        await tester.pump();
        fixture.editor.response.complete(true);
        await tester.pumpAndSettle();
        expect(fixture.editor.saves, 2);
        expect(find.text('1쪽을 저장했어요.'), findsOneWidget);
        expect(find.text('1쪽을 완성했어요.'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('one-page-finish-today')));
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsNothing);
        expect(find.text('홈에서 한 쪽 시작'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'a successful acknowledgement with newer local edits never offers a finish action',
    (tester) async {
      final fixture = _Fixture()..editor.editedDuringSave = true;
      await fixture.mount(tester);
      try {
        await _saveCurrentPage(tester);
        await tester.pump();
        fixture.editor.response.complete(true);
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        expect(
          find.byKey(const ValueKey('one-page-saved-choice')),
          findsNothing,
        );
        expect(find.text('저장 중 새 편집이 있어요. 남은 변경 내용도 저장해 주세요.'), findsOneWidget);
        expect(fixture.editor.hasUnsavedChanges, isTrue);
      } finally {
        await fixture.close(tester);
      }
    },
  );
}
