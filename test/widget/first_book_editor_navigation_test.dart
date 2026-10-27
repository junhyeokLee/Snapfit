import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_actions.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

class _Repository extends Mock implements AlbumRepository {}

class _Editor extends AlbumEditorViewModel {
  Album? prepared;
  var restored = false;
  var prepareCount = 0;
  @override
  AlbumEditorState build() => const AlbumEditorState();
  @override
  Album? get album => prepared;
  @override
  Future<void> prepareAlbumForEdit(
    Album album, {
    bool waitForCreation = false,
  }) async {
    prepareCount++;
    prepared = album;
  }

  @override
  void loadPendingEditAlbumIfNeeded(Size canvasSize) => restored = true;
  @override
  List<AlbumPage> get pages => [
    AlbumPage(id: 'cover', pageIndex: 0, isCover: true, layers: []),
    AlbumPage(
      id: 'first',
      pageIndex: 1,
      layers: restored
          ? [
              LayerModel(
                id: 'personal',
                type: LayerType.image,
                position: Offset.zero,
                previewUrl: 'https://uploads.test/personal.jpg',
              ),
            ]
          : [],
    ),
    AlbumPage(id: 'second', pageIndex: 2, layers: []),
  ];
}

class _Routes extends NavigatorObserver {
  final opened = <MaterialPageRoute<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is MaterialPageRoute) opened.add(route);
  }
}

class _Fixture {
  final repository = _Repository();
  final editor = _Editor();
  final routes = _Routes();
  final navigator = GlobalKey<NavigatorState>();
  final sessionChanges = StreamController<String?>.broadcast(sync: true);
  late ProviderContainer container;
  late BuildContext context;
  late WidgetRef ref;
  var actor = 'owner';

  Future<void> mount(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        albumRepositoryProvider.overrideWithValue(repository),
        albumCollaborationActorProvider.overrideWith((_) => actor),
        albumEditorOwnerChangesProvider.overrideWith(
          (_) => sessionChanges.stream,
        ),
        albumEditorViewModelProvider.overrideWith(() => editor),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [routes],
          home: Consumer(
            builder: (context, ref, _) {
              this.context = context;
              this.ref = ref;
              return const Scaffold(body: Text('첫 한 권'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    for (final route in routes.opened) {
      if (route.isActive) navigator.currentState!.removeRoute(route);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
    await sessionChanges.close();
  }
}

void main() {
  const listed = Album(id: 73, userId: 'owner', memberRole: 'OWNER');
  final fresh = listed.copyWith(title: '서버에서 갱신된 앨범');

  testWidgets(
    'first-book action restores fresh layers before choosing a page',
    (tester) async {
      final fixture = _Fixture();
      when(
        () => fixture.repository.fetchAlbum('73'),
      ).thenAnswer((_) async => fresh);
      await fixture.mount(tester);
      try {
        await HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          listed,
          startAtFirstIncompletePage: true,
        );
        expect(fixture.editor.prepared, same(fresh));
        expect(fixture.editor.restored, isTrue);
        expect(fixture.routes.opened, hasLength(1));
        final screen = fixture.routes.opened.single.builder(fixture.context);
        expect(screen, isA<PageEditorScreen>());
        expect((screen as PageEditorScreen).initialPageIndex, 2);
        verify(() => fixture.repository.fetchAlbum('73')).called(1);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets('freshly revoked editing permission blocks first-book entry', (
    tester,
  ) async {
    final fixture = _Fixture();
    when(
      () => fixture.repository.fetchAlbum('73'),
    ).thenAnswer((_) async => fresh.copyWith(memberRole: 'VIEWER'));
    await fixture.mount(tester);
    try {
      await HomeAlbumActions.onEditSelected(
        fixture.context,
        fixture.ref,
        listed,
        startAtFirstIncompletePage: true,
      );
      expect(fixture.editor.prepared, isNull);
      expect(fixture.routes.opened, isEmpty);
      await tester.pump();
      expect(find.text('보기 전용 앨범이에요. 편집 권한을 요청해 주세요.'), findsOneWidget);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('account change during fresh lookup never enters the old book', (
    tester,
  ) async {
    final fixture = _Fixture();
    final pending = Completer<Album>();
    when(
      () => fixture.repository.fetchAlbum('73'),
    ).thenAnswer((_) => pending.future);
    await fixture.mount(tester);
    try {
      final opening = HomeAlbumActions.onEditSelected(
        fixture.context,
        fixture.ref,
        listed,
        startAtFirstIncompletePage: true,
      );
      await tester.pump();
      fixture.actor = 'another-owner';
      fixture.container.invalidate(albumCollaborationActorProvider);
      pending.complete(fresh);
      await opening;
      expect(fixture.editor.prepared, isNull);
      expect(fixture.routes.opened, isEmpty);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets('duplicate taps share one preparation and one navigation', (
    tester,
  ) async {
    final fixture = _Fixture();
    final pending = Completer<Album>();
    when(
      () => fixture.repository.fetchAlbum('73'),
    ).thenAnswer((_) => pending.future);
    await fixture.mount(tester);
    try {
      final first = HomeAlbumActions.onEditSelected(
        fixture.context,
        fixture.ref,
        listed,
        startAtFirstIncompletePage: true,
      );
      final duplicate = HomeAlbumActions.onEditSelected(
        fixture.context,
        fixture.ref,
        listed,
        startAtFirstIncompletePage: true,
      );
      await duplicate;
      verify(() => fixture.repository.fetchAlbum('73')).called(1);
      pending.complete(fresh);
      await first;
      expect(fixture.editor.prepareCount, 1);
      expect(fixture.routes.opened, hasLength(1));
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets(
    'new account can prepare immediately while the old lookup is pending',
    (tester) async {
      final fixture = _Fixture();
      final pending = Completer<Album>();
      const nextBook = Album(
        id: 74,
        userId: 'another-owner',
        memberRole: 'OWNER',
      );
      when(
        () => fixture.repository.fetchAlbum('73'),
      ).thenAnswer((_) => pending.future);
      when(
        () => fixture.repository.fetchAlbum('74'),
      ).thenAnswer((_) async => nextBook);
      await fixture.mount(tester);
      try {
        final old = HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          listed,
          startAtFirstIncompletePage: true,
        );
        fixture.actor = 'another-owner';
        fixture.container.invalidate(albumCollaborationActorProvider);
        await tester.pump();
        await HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          nextBook,
          startAtFirstIncompletePage: true,
        );
        pending.complete(fresh);
        await old;
        expect(fixture.editor.prepared, same(nextBook));
        expect(fixture.editor.prepareCount, 1);
        expect(fixture.routes.opened, hasLength(1));
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'raw account transitions invalidate preparation even when UI identity batches A to B to A',
    (tester) async {
      final fixture = _Fixture();
      final pending = Completer<Album>();
      when(
        () => fixture.repository.fetchAlbum('73'),
      ).thenAnswer((_) => pending.future);
      await fixture.mount(tester);
      try {
        final old = HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          listed,
          startAtFirstIncompletePage: true,
        );
        fixture.actor = 'another-owner';
        fixture.container.invalidate(albumCollaborationActorProvider);
        fixture.sessionChanges.add('another-owner');
        fixture.actor = 'owner';
        fixture.container.invalidate(albumCollaborationActorProvider);
        fixture.sessionChanges.add('owner');
        pending.complete(fresh);
        await old;
        expect(fixture.editor.prepareCount, 0);
        expect(fixture.routes.opened, isEmpty);
      } finally {
        await fixture.close(tester);
      }
    },
  );

  testWidgets(
    'failed preparation releases the gate so retry can open the editor',
    (tester) async {
      final fixture = _Fixture();
      var attempts = 0;
      when(() => fixture.repository.fetchAlbum('73')).thenAnswer((_) async {
        if (attempts++ == 0) throw StateError('temporary lookup failure');
        return fresh;
      });
      await fixture.mount(tester);
      try {
        await HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          listed,
          startAtFirstIncompletePage: true,
        );
        expect(fixture.routes.opened, isEmpty);
        await HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          listed,
          startAtFirstIncompletePage: true,
        );
        expect(fixture.editor.prepareCount, 1);
        expect(fixture.routes.opened, hasLength(1));
        verify(() => fixture.repository.fetchAlbum('73')).called(2);
      } finally {
        await fixture.close(tester);
      }
    },
  );
}
