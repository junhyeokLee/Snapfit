import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/navigation/app_root_route_observer.dart';
import 'package:snap_fit/core/navigation/notification_content_navigation.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_repository.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/views/album_reader_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_actions.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';
import 'package:snap_fit/features/profile/domain/order_detail_navigation.dart';

class _ReadyAuth extends AuthViewModel {
  @override
  Future<UserInfo?> build() async => null;
}

class _EmptyInvites extends PendingAlbumInviteStore {
  @override
  Future<PendingAlbumInvite?> read() async => null;
  @override
  Future<void> write(PendingAlbumInvite? invite) async {}
}

class _Albums extends Mock implements AlbumRepository {}

class _PreparingEditor extends AlbumEditorViewModel {
  final prepared = Completer<void>();
  bool started = false;
  @override
  AlbumEditorState build() => const AlbumEditorState();
  @override
  Future<void> prepareAlbumForEdit(
    Album album, {
    bool waitForCreation = false,
  }) async {
    started = true;
    await prepared.future;
  }
}

// Exercises the real deferred-target controller against actual native splash
// replacement. Authentication/network delivery are fixtures, not device pushes.
class _NavigationFixture {
  final navigator = GlobalKey<NavigatorState>();
  final navigation = NotificationContentNavigation()..observeOwner('owner');
  final orders = OrderDetailNavigation();
  late final observer = AppRootRouteObserver(
    onReady: () {
      rootReady = true;
      schedule();
    },
  );
  String? owner = 'owner', profile;
  bool rootReady = false, busy = false, disposed = false;
  Completer<void>? fetch;
  final opened = <NotificationContentTarget>[];
  final openedOrders = <String>[];

  void receive(
    NotificationContentTarget target, {
    String? expectedOwner = 'owner',
  }) {
    orders.cancel();
    navigation.receive(target, ownerId: expectedOwner);
    schedule();
  }

  void receiveOrder(String orderId) {
    navigation.cancel();
    orders.receive(orderId, ownerId: owner);
    schedule();
  }

  void schedule() {
    if (disposed ||
        busy ||
        !rootReady ||
        (!navigation.hasPending && !orders.hasPending))
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!disposed) unawaited(open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> open() async {
    if (disposed || busy) return;
    final order = orders.take(
      ownerId: owner,
      navigatorReady:
          rootReady && navigator.currentState != null && profile == owner,
      now: DateTime.utc(2026, 10, 19),
    );
    if (order != null) {
      openedOrders.add(order);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('order $order')),
          ),
        ),
      );
      return;
    }
    final opening = navigation.take(
      ownerId: owner,
      profileOwnerId: profile,
      navigatorReady: rootReady && navigator.currentState != null,
      now: DateTime.utc(2026, 10, 19),
    );
    if (opening == null) return;
    busy = true;
    var didOpen = false;
    try {
      await Future.any<void>([
        fetch?.future ?? Future<void>.value(),
        opening.cancelled,
      ]);
      if (disposed ||
          !navigation.isCurrent(
            opening,
            ownerId: owner,
            profileOwnerId: profile,
          ))
        return;
      opened.add(opening.target);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              key: ValueKey(
                'content-${opening.target.kind.name}-${opening.target.id}',
              ),
              body: Text('${opening.target.kind.name} ${opening.target.id}'),
            ),
          ),
        ),
      );
      didOpen = true;
    } finally {
      navigation.finish(
        opening,
        opened: didOpen,
        now: DateTime.utc(2026, 10, 19),
      );
      busy = false;
      if (!disposed) schedule();
    }
  }

  Widget app({bool splash = true}) => ProviderScope(
    overrides: [
      authViewModelProvider.overrideWith(_ReadyAuth.new),
      pendingAlbumInviteStoreProvider.overrideWithValue(_EmptyInvites()),
    ],
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [observer],
        onGenerateRoute: splash
            ? null
            : (_) => MaterialPageRoute<void>(
                settings: const AppRootRouteSettings(),
                builder: (_) => const Scaffold(body: Text('stable root')),
              ),
        home: splash ? const SplashScreen() : null,
      ),
    ),
  );
}

void main() {
  const album = NotificationContentTarget(NotificationContentKind.album, 7);
  const template = NotificationContentTarget(
    NotificationContentKind.template,
    12,
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  void viewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  for (final target in [album, template]) {
    testWidgets(
      'cold ${target.kind.name} notification survives the actual 900 ms splash replacement',
      (tester) async {
        viewport(tester);
        final fixture = _NavigationFixture();
        addTearDown(() => fixture.disposed = true);
        fixture.receive(target);
        await tester.pumpWidget(fixture.app());
        await tester.pump(const Duration(milliseconds: 100));
        fixture.profile = 'owner';
        await fixture.open();
        expect(fixture.opened, isEmpty);
        expect(fixture.navigation.hasPending, true);
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();
        expect(fixture.rootReady, true);
        expect(fixture.opened, [target]);
        final destination = find.byKey(
          ValueKey('content-${target.kind.name}-${target.id}'),
        );
        expect(destination, findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(destination, findsOneWidget);
        expect(fixture.opened, hasLength(1));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    for (final orderLast in [false, true]) {
      testWidgets(
        'cold order and ${target.kind.name} taps open only the latest target orderLast=$orderLast',
        (tester) async {
          viewport(tester);
          final fixture = _NavigationFixture()..profile = 'owner';
          addTearDown(() => fixture.disposed = true);
          if (orderLast) {
            fixture.receive(target);
            fixture.receiveOrder('latest-order');
          } else {
            fixture.receiveOrder('superseded-order');
            fixture.receive(target);
          }
          await tester.pumpWidget(fixture.app());
          await tester.pump(const Duration(milliseconds: 1000));
          await tester.pumpAndSettle();
          expect(fixture.opened, orderLast ? isEmpty : [target]);
          expect(fixture.openedOrders, orderLast ? ['latest-order'] : isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'order to content to the same order honors the latest deliberate tap',
    (tester) async {
      viewport(tester);
      final fixture = _NavigationFixture()..profile = 'owner';
      addTearDown(() => fixture.disposed = true);
      await tester.pumpWidget(fixture.app(splash: false));
      await tester.pumpAndSettle();
      fixture.receiveOrder('order-a');
      await tester.pumpAndSettle();
      fixture.receive(template);
      await tester.pumpAndSettle();
      fixture.receiveOrder('order-a');
      await tester.pumpAndSettle();
      expect(fixture.opened, [template]);
      expect(fixture.openedOrders, ['order-a', 'order-a']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'foreground and resumed-background taps wait for profile readiness and deduplicate',
    (tester) async {
      viewport(tester);
      final fixture = _NavigationFixture();
      addTearDown(() => fixture.disposed = true);
      await tester.pumpWidget(fixture.app(splash: false));
      await tester.pumpAndSettle();
      fixture.receive(album);
      await tester.pumpAndSettle();
      expect(fixture.opened, isEmpty);
      fixture.profile = 'cached-other-owner';
      fixture.schedule();
      await tester.pumpAndSettle();
      expect(fixture.opened, isEmpty);
      fixture.profile = 'owner';
      fixture.schedule();
      await tester.pumpAndSettle();
      expect(fixture.opened, [album]);
      fixture.receive(album);
      await tester.pumpAndSettle();
      expect(fixture.opened, [album]);
      fixture.receive(template);
      await tester.pumpAndSettle();
      expect(fixture.opened, [album, template]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a new target or account switch during a slow fetch cannot open the obsolete destination',
    (tester) async {
      viewport(tester);
      final fixture = _NavigationFixture()..profile = 'owner';
      addTearDown(() => fixture.disposed = true);
      await tester.pumpWidget(fixture.app(splash: false));
      await tester.pumpAndSettle();
      final pending = Completer<void>();
      fixture.fetch = pending;
      fixture.receive(album);
      await tester.pump();
      fixture.receive(template);
      pending.complete();
      await tester.pumpAndSettle();
      expect(fixture.opened, [template]);
      final accountRead = Completer<void>();
      fixture.fetch = accountRead;
      fixture.receive(album);
      await tester.pump();
      fixture.navigation.observeOwner('other');
      fixture.owner = fixture.profile = 'other';
      accountRead.complete();
      await tester.pumpAndSettle();
      expect(fixture.opened, [template]);
      expect(find.byKey(const ValueKey('content-album-7')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final changeAccount in [false, true]) {
    testWidgets(
      'real HomeAlbumActions checks the content lease after preparation accountChange=$changeAccount',
      (tester) async {
        viewport(tester);
        final editor = _PreparingEditor();
        final navigation = NotificationContentNavigation()
          ..observeOwner('owner')
          ..receive(album, ownerId: 'owner');
        final opening = navigation.take(
          ownerId: 'owner',
          profileOwnerId: 'owner',
          navigatorReady: true,
          now: DateTime.utc(2026, 10, 19),
        )!;
        String owner = 'owner';
        late BuildContext context;
        late WidgetRef widgetRef;
        var readersOpened = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumRepositoryProvider.overrideWithValue(_Albums()),
              albumEditorViewModelProvider.overrideWith(() => editor),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (buildContext, ref, _) {
                  context = buildContext;
                  widgetRef = ref;
                  return const Scaffold(body: Text('stable root'));
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final operation = HomeAlbumActions.openAlbum(
          context,
          widgetRef,
          const Album(id: 7, memberRole: 'VIEWER'),
          canContinue: () => navigation.isCurrent(
            opening,
            ownerId: owner,
            profileOwnerId: owner,
          ),
          onReaderOpened: () => readersOpened++,
        );
        await tester.pump();
        expect(editor.started, true);
        if (changeAccount) {
          owner = 'other';
          navigation.observeOwner(owner);
        } else {
          navigation.receive(template, ownerId: owner);
        }
        editor.prepared.complete();
        await operation;
        await tester.pumpAndSettle();
        expect(readersOpened, 0);
        expect(find.byType(AlbumReaderScreen), findsNothing);
        await HomeAlbumActions.waitForReaderToClose();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
