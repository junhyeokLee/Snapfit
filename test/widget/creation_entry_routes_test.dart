import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_creation_entry_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';

import '../helpers/creation_draft_fixtures.dart'
    show FakeAuthViewModel, MemoryCreationDraftStore, creationDraftFixture;
import '../helpers/mock_repositories.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;

class _DraftStore extends MemoryCreationDraftStore {
  Completer<void>? loading;
  bool failLoad = false;
  int loads = 0;

  @override
  Future<AlbumCreationDraft?> load(String owner) async {
    loads++;
    await loading?.future;
    if (failLoad) throw StateError('Unavailable local storage');
    return draft;
  }
}

class _Albums extends HomeViewModel {
  @override
  Future<List<Album>> build() async => [];
}

AlbumCreationDraft _savedDraft() {
  final json = creationDraftFixture(
    pages: [
      [
        LayerModel(
          id: 'title',
          type: LayerType.text,
          position: const Offset(30, 40),
          width: 300,
          height: 50,
          text: '지키고 싶은 여행',
          textStyle: const TextStyle(fontFamily: 'NotoSans', fontSize: 24),
        ),
      ],
      [],
    ],
    showPhotoFill: false,
    step: 0,
  ).toJson();
  json['pendingPhotos'] = [];
  json['selectedPhotoId'] = null;
  json['selectedSlot'] = null;
  return AlbumCreationDraft.fromJson(json);
}

Future<void> _mount(
  WidgetTester tester,
  _DraftStore store,
  Widget screen,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repo = MockAlbumRepository();
  stubFetchMyAlbums(repo, []);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        homeUiStateProvider.overrideWith(
          () => HomeUiStateNotifier(initialIndex: 0),
        ),
        albumCreationDraftStoreProvider.overrideWithValue(store),
        albumRepositoryProvider.overrideWithValue(repo),
        homeViewModelProvider.overrideWith(_Albums.new),
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            const UserInfo(id: 'owner', name: '테스트', provider: 'email'),
          ),
        ),
        albumCreationCatalogProvider.overrideWith((_) => Stream.value([])),
        notificationUnreadCountProvider.overrideWith((_) async => 0),
      ],
      child: wrapCreation(screen, showShell: false),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });

  final entries = <String, Widget>{
    if (!kIsWeb) 'native home': const HomeScreen(),
    'web library': const WebAlbumLibraryScreen(),
    'album collection': const AlbumCategoryScreen(
      category: AlbumCategory.recent,
      initialAlbums: [],
      currentUserId: 'owner',
    ),
  };

  Finder start(String name) => switch (name) {
    'native home' => find.byKey(const ValueKey('empty-home-create')),
    'web library' => find.widgetWithText(FilledButton, '새 앨범 만들기'),
    _ =>
      kIsWeb
          ? find.widgetWithText(FilledButton, '앨범 만들기')
          : find.byTooltip('새 앨범 만들기'),
  };
  Finder choice(String value) =>
      find.byKey(ValueKey('album-creation-entry-$value'));

  for (final entry in entries.entries) {
    testWidgets(
      '${entry.key} awaits the latest draft and blocks repeated taps',
      (tester) async {
        final original = _savedDraft();
        final store = _DraftStore()
          ..draft = original
          ..loading = Completer<void>();
        await _mount(tester, store, entry.value);
        final button = start(entry.key);
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        await tester.pump();
        final reads = store.loads;
        await tester.tap(button, warnIfMissed: false);
        await tester.pump();
        expect(store.loads, reads);
        expect(find.byType(AlbumCreateFlowScreen), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        store.loading!.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(store.draft, same(original));
        expect(store.writes, 0);
        await tester.tap(choice('cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlbumCreateFlowScreen), findsNothing);
        expect(store.draft, same(original));
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(choice('resume'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<AlbumCreateFlowScreen>(find.byType(AlbumCreateFlowScreen))
              .initialDraft,
          same(original),
        );
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('${entry.key} does not start on a draft read failure', (
      tester,
    ) async {
      final original = _savedDraft();
      final store = _DraftStore()
        ..draft = original
        ..failLoad = true;
      await _mount(tester, store, entry.value);
      final button = start(entry.key);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('임시 저장한 앨범을 확인하지 못했어요. 다시 확인해 주세요.'), findsOneWidget);
      expect(store.draft, same(original));
      expect(store.writes, 0);
      store.failLoad = false;
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(choice('new'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AlbumCreateFlowScreen>(find.byType(AlbumCreateFlowScreen))
            .initialDraft,
        isNull,
      );
      expect(store.draft, same(original));
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'legacy named entry checks the saved draft before creating a flow',
    (tester) async {
      final original = _savedDraft();
      final store = _DraftStore()..draft = original;
      await _mount(
        tester,
        store,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AlbumCreationEntryScreen(),
                ),
              ),
              child: const Text('legacy-create'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('legacy-create'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      await tester.tap(choice('cancel'));
      await tester.pumpAndSettle();
      expect(find.text('legacy-create').hitTestable(), findsOneWidget);
      expect(store.draft, same(original));
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
