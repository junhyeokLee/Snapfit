import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/app_root_route_observer.dart';
import 'package:snap_fit/features/profile/domain/order_detail_navigation.dart';

void main() {
  testWidgets('web starts on a stable root without a splash replacement', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final pending = OrderDetailNavigation()
      ..receive('web-order', ownerId: 'owner');
    var rootReady = false;
    var readyCalls = 0;
    final observer = AppRootRouteObserver(
      onReady: () {
        rootReady = true;
        readyCalls++;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const AppRootRouteSettings(),
          builder: (_) => const Scaffold(body: Text('계정 확인')),
        ),
      ),
    );
    await tester.pump();

    expect(rootReady, isTrue);
    expect(readyCalls, 1);
    expect(nav.currentState!.canPop(), isFalse);
    expect(
      pending.take(
        ownerId: null,
        navigatorReady: rootReady,
        now: DateTime.utc(2026, 10, 18),
      ),
      isNull,
    );
    expect(pending.hasPending, isTrue);

    final order = pending.take(
      ownerId: 'owner',
      navigatorReady: rootReady,
      now: DateTime.utc(2026, 10, 18),
    );
    nav.currentState!.push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('주문 상세 $order')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('주문 상세 web-order'), findsOneWidget);
    expect(readyCalls, 1);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('계정 확인'), findsOneWidget);
    expect(nav.currentState!.canPop(), isFalse);
  });

  testWidgets('a cold-start order survives replacement of the splash route', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final pending = OrderDetailNavigation()
      ..receive('owned-order', ownerId: 'owner');
    var rootReady = false;
    var readyCalls = 0;
    void openPending() {
      final order = pending.take(
        ownerId: 'owner',
        navigatorReady: nav.currentState != null && rootReady,
        now: DateTime.utc(2026, 10, 15),
      );
      if (order != null) {
        nav.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('주문 상세 $order')),
          ),
        );
      }
    }

    final observer = AppRootRouteObserver(
      onReady: () {
        rootReady = true;
        readyCalls++;
        WidgetsBinding.instance.addPostFrameCallback((_) => openPending());
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('시작 화면')),
      ),
    );
    openPending();
    await tester.pump();
    expect(find.text('시작 화면'), findsOneWidget);
    expect(find.text('주문 상세 owned-order'), findsNothing);
    expect(pending.hasPending, isTrue);
    nav.currentState!.pushReplacement<void, void>(
      MaterialPageRoute(
        settings: const AppRootRouteSettings(),
        builder: (_) => const Scaffold(body: Text('내 앨범')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('주문 상세 owned-order'), findsOneWidget);
    expect(find.text('시작 화면'), findsNothing);
    expect(pending.hasPending, isFalse);
    expect(readyCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('주문 상세 owned-order'), findsOneWidget);
  });

  testWidgets('a cold-start notification waits for its own account to log in', (
    tester,
  ) async {
    final nav = GlobalKey<NavigatorState>();
    final pending = OrderDetailNavigation()
      ..receive('owned-order', ownerId: 'owner-a');
    String? owner;
    var rootReady = false;
    final observer = AppRootRouteObserver(onReady: () => rootReady = true);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('시작 화면')),
      ),
    );
    nav.currentState!.pushReplacement<void, void>(
      MaterialPageRoute(
        settings: const AppRootRouteSettings(),
        builder: (_) => const Scaffold(body: Text('로그인')),
      ),
    );
    await tester.pumpAndSettle();
    expect(rootReady, isTrue);
    expect(
      pending.take(
        ownerId: owner,
        navigatorReady: rootReady,
        now: DateTime.utc(2026, 10, 15),
      ),
      isNull,
    );
    expect(pending.hasPending, isTrue);
    owner = 'owner-b';
    expect(
      pending.take(
        ownerId: owner,
        navigatorReady: rootReady,
        now: DateTime.utc(2026, 10, 15),
      ),
      isNull,
    );
    expect(pending.hasPending, isFalse);
  });
}
