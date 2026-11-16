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
import 'package:snap_fit/features/album/domain/album_creation_start_mode.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_category_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/album_creation_entry_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';

import '../helpers/creation_draft_fixtures.dart'
    show FakeAuthViewModel, MemoryCreationDraftStore, creationDraftFixture;
import '../helpers/mock_repositories.dart';
import '../helpers/fake_album.dart';
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
  _Albums(this.albums);
  final List<Album> albums;

  @override
  Future<List<Album>> build() async => albums;
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
  Widget screen, {
  Size size = const Size(1000, 800),
  double textScale = 1,
  MomentJournal? journal,
  List<Album> albums = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repo = MockAlbumRepository();
  stubFetchMyAlbums(repo, albums);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, __) => null,
      overrides: [
        homeUiStateProvider.overrideWith(
          () => HomeUiStateNotifier(initialIndex: 0),
        ),
        albumCreationDraftStoreProvider.overrideWithValue(store),
        // This entry test starts in an already settled owner session.
        albumCollaborationActorProvider.overrideWithValue('owner'),
        albumRepositoryProvider.overrideWithValue(repo),
        homeViewModelProvider.overrideWith(() => _Albums(albums)),
        if (journal != null)
          momentEntryJournalProvider.overrideWith((_) async => journal),
        authViewModelProvider.overrideWith(
          () => FakeAuthViewModel(
            const UserInfo(id: 'owner', name: '테스트', provider: 'email'),
          ),
        ),
        albumCreationCatalogProvider.overrideWith((_) => Stream.value([])),
        notificationUnreadCountProvider.overrideWith((_) async => 0),
      ],
      child: wrapCreation(screen, showShell: false, textScale: textScale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    if (!kIsWeb) await loadCreationFonts();
  });

  testWidgets(
    'web main shows the weekly entry before albums without old follow-up sections',
    (tester) async {
      final today = DateTime.utc(2026, 11, 11);
      await _mount(
        tester,
        _DraftStore()..draft = _savedDraft(),
        const WebAlbumLibraryScreen(),
        size: const Size(1000, 1200),
        albums: [fakeAlbum(id: 51, ratio: '1').copyWith(userId: 'owner')],
        journal: MomentJournal(
          today: today,
          month: momentMonth(today),
          weekStart: momentWeekStart(today),
          records: const [],
          weekPhotoCount: 0,
        ),
      );
      final week = find.byKey(const ValueKey('home-monthly-feed-week'));
      final album = find.byKey(const ValueKey('web-album-card-51'));
      expect(week, findsOneWidget);
      expect(album, findsOneWidget);
      expect(tester.getTopLeft(week).dy, lessThan(tester.getTopLeft(album).dy));
      for (final key in [
        'first-book-next-step',
        'home-monthly-feed-counts',
        'home-monthly-reward',
        'moments-photo-calendar',
      ]) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      for (final text in ['모아둔 순간', '남기던 순간 이어 쓰기', '모은 순간을 한 권의 앨범으로']) {
        expect(find.text(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

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

  Future<void> openEntry(
    WidgetTester tester,
    String name,
    Finder button,
  ) async {
    await tester.tap(button);
    await tester.pumpAndSettle();
    if (name == 'native home' || name == 'web library') {
      expect(
        find.byKey(const ValueKey('album-creation-start-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('album-creation-start-manual')),
      );
      await tester.pump();
    }
  }

  if (!kIsWeb) {
    testWidgets(
      'home plus opens two choices and dismissal leaves the draft intact',
      (tester) async {
        final original = _savedDraft();
        final store = _DraftStore()..draft = original;
        await _mount(tester, store, const HomeScreen());
        final reads = store.loads;
        await tester.tap(find.byKey(const ValueKey('home-create-album')));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.text('직접 만들기'), findsOneWidget);
        expect(find.text('디자인으로 시작하기'), findsOneWidget);
        expect(find.text('완성 예시'), findsNothing);
        expect(find.byType(AlbumCreateFlowScreen), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(store.loads, reads);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsNothing);
        expect(store.draft, same(original));
        expect(store.writes, 0);
        expect(tester.takeException(), isNull);
      },
    );

    for (final mode in AlbumCreationStartMode.values) {
      testWidgets(
        'home ${mode.name} enters its destination without a method page',
        (tester) async {
          final store = _DraftStore();
          await _mount(tester, store, const HomeScreen());
          await tester.tap(find.byKey(const ValueKey('home-create-album')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('album-creation-start-${mode.name}')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
          expect(find.text('완성 예시'), findsNothing);
          expect(
            find.byKey(const PageStorageKey('creation-method-entry')),
            findsNothing,
          );
          if (mode == AlbumCreationStartMode.manual) {
            expect(find.byType(AlbumCreateStep1), findsOneWidget);
          } else {
            expect(
              find.byKey(const ValueKey('creation-search')),
              findsOneWidget,
            );
            for (final filter in ['전체', '무료', '유료']) {
              expect(
                find.byKey(ValueKey('creation-price-$filter')),
                findsOneWidget,
              );
            }
          }
          expect(store.writes, 0);
          await tester.tap(find.byTooltip('뒤로가기'));
          await tester.pumpAndSettle();
          if (mode == AlbumCreationStartMode.manual) {
            expect(find.text('앨범 만들기를 나갈까요?'), findsOneWidget);
            await tester.tap(find.text('저장 안 함'));
            await tester.pumpAndSettle();
          }
          expect(find.byType(AlbumCreateFlowScreen), findsNothing);
          expect(
            find.byKey(const PageStorageKey('creation-method-entry')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('home method choices remain reachable at 320 with large text', (
      tester,
    ) async {
      await _mount(
        tester,
        _DraftStore(),
        const HomeScreen(),
        size: const Size(320, 568),
        textScale: 2,
      );
      await tester.tap(find.byKey(const ValueKey('home-create-album')));
      await tester.pumpAndSettle();
      for (final mode in AlbumCreationStartMode.values) {
        final choice = find.byKey(
          ValueKey('album-creation-start-${mode.name}'),
        );
        await tester.ensureVisible(choice);
        await tester.pumpAndSettle();
        expect(choice.hitTestable(), findsOneWidget);
        expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
      }
      expect(find.text('완성 예시'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

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
        await openEntry(tester, entry.key, button);
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
        await openEntry(tester, entry.key, button);
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
      await openEntry(tester, entry.key, button);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateFlowScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('임시 저장한 앨범을 확인하지 못했어요. 다시 확인해 주세요.'), findsOneWidget);
      expect(store.draft, same(original));
      expect(store.writes, 0);
      store.failLoad = false;
      await openEntry(tester, entry.key, button);
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
