import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/cover_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_actions.dart';
import 'package:snap_fit/features/album/service/album_collaboration_session.dart';

class _Editor extends AlbumEditorViewModel {
  final prepared = <Album>[];
  Completer<void>? pending;
  @override
  AlbumEditorState build() =>
      const AlbumEditorState(selectedTheme: CoverTheme.nature1);
  @override
  Album? get album => prepared.lastOrNull;
  @override
  Future<void> prepareAlbumForEdit(
    Album album, {
    bool waitForCreation = false,
  }) async {
    prepared.add(album);
    await pending?.future;
  }
}

class _Routes extends NavigatorObserver {
  final opened = <MaterialPageRoute<dynamic>>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && route is MaterialPageRoute) opened.add(route);
  }
}

class _Fixture {
  final editor = _Editor();
  final routes = _Routes();
  final navigator = GlobalKey<NavigatorState>();
  late final ProviderContainer container;
  late BuildContext context;
  late WidgetRef ref;
  String actor = 'owner';

  Future<void> mount(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        albumCollaborationActorProvider.overrideWith((_) => actor),
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
              return const Scaffold(body: Text('기록 화면'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    // Inspect the real route builder without mounting the complete editor;
    // document preparation/sync/auth gates are exercised by HomeAlbumActions.
    for (final route in routes.opened) {
      if (route.isActive) navigator.currentState!.removeRoute(route);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    container.dispose();
  }
}

void main() {
  const album = Album(id: 73, userId: 'owner', memberRole: 'OWNER');
  for (final startWithPages in [false, true]) {
    testWidgets(
      'editor route preserves prepared document and cover sync startWithPages=$startWithPages',
      (tester) async {
        final fixture = _Fixture();
        await fixture.mount(tester);
        try {
          if (startWithPages) {
            await HomeAlbumActions.onEditSelected(
              fixture.context,
              fixture.ref,
              album,
              startWithPages: true,
            );
          } else {
            await HomeAlbumActions.onEditSelected(
              fixture.context,
              fixture.ref,
              album,
            );
          }
          expect(fixture.editor.prepared, [album]);
          expect(
            fixture.container.read(coverViewModelProvider).value!.selectedTheme,
            CoverTheme.nature1,
          );
          expect(fixture.routes.opened, hasLength(1));
          final route = fixture.routes.opened.single;
          expect(
            (route.settings as WebAppRouteSettings).location,
            const WebAppLocation(WebAppPage.editor, '73'),
          );
          final screen = route.builder(fixture.context);
          if (startWithPages) {
            expect(screen, isA<PageEditorScreen>());
            expect((screen as PageEditorScreen).initialPageIndex, 0);
          } else {
            expect(screen, isA<AddCoverScreen>());
            expect((screen as AddCoverScreen).editAlbum, album);
          }
        } finally {
          await fixture.close(tester);
        }
      },
    );
  }

  testWidgets('direct page entry still rejects a viewer before preparing', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.mount(tester);
    try {
      await HomeAlbumActions.onEditSelected(
        fixture.context,
        fixture.ref,
        album.copyWith(memberRole: 'VIEWER'),
        startWithPages: true,
      );
      expect(fixture.editor.prepared, isEmpty);
      expect(fixture.routes.opened, isEmpty);
    } finally {
      await fixture.close(tester);
    }
  });

  testWidgets(
    'direct page entry does not navigate after account changes during preparation',
    (tester) async {
      final fixture = _Fixture();
      final pending = Completer<void>();
      fixture.editor.pending = pending;
      await fixture.mount(tester);
      try {
        final opening = HomeAlbumActions.onEditSelected(
          fixture.context,
          fixture.ref,
          album,
          startWithPages: true,
        );
        await tester.pump();
        expect(fixture.editor.prepared, [album]);
        fixture.actor = 'another-owner';
        fixture.container.invalidate(albumCollaborationActorProvider);
        pending.complete();
        await opening;
        expect(fixture.routes.opened, isEmpty);
      } finally {
        await fixture.close(tester);
      }
    },
  );
}
