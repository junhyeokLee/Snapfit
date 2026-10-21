import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/app_root_route_observer.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';

class _Harness {
  final navigator = GlobalKey<NavigatorState>();
  final requested = <WebAppLocation>[];
  late final WebAppRouter router = WebAppRouter(
    navigatorKey: navigator,
    observers: const [],
    onLocationRequested: requested.add,
    routeBuilder: (_) => MaterialPageRoute<void>(
      settings: const AppRootRouteSettings(),
      builder: (_) => const Scaffold(body: Text('root home')),
    ),
  );

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: router,
        routeInformationParser: const WebAppRouteParser(),
      ),
    );
    await tester.pumpAndSettle();
    router.finishInitialNavigation();
    await tester.pumpAndSettle();
    requested.clear();
  }

  Route<void> route(WebAppLocation location, {Widget? child}) =>
      MaterialPageRoute<void>(
        settings: WebAppRouteSettings(location),
        builder: (_) => Scaffold(body: child ?? Text(location.uri.toString())),
      );

  Future<void> push(
    WidgetTester tester,
    WebAppLocation location, {
    Widget? child,
  }) async {
    unawaited(
      navigator.currentState!.push<void>(route(location, child: child)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    router.dispose();
  }
}

void main() {
  const album = WebAppLocation(WebAppPage.album, '69');
  const editor = WebAppLocation(WebAppPage.editor, '69');
  const print = WebAppLocation(WebAppPage.print, '69');

  testWidgets(
    'catalog addresses change in place and browser back preserves list work',
    (tester) async {
      final harness = _Harness();
      final catalog = WebAppRouteController(
        WebAppLocation.designs,
        pages: const {WebAppPage.designs, WebAppPage.materials},
      );
      addTearDown(catalog.dispose);
      await harness.mount(tester);
      unawaited(
        harness.navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            settings: WebAppRouteSettings(
              WebAppLocation.designs,
              controller: catalog,
            ),
            builder: (_) => Scaffold(
              body: ValueListenableBuilder<WebAppLocation>(
                valueListenable: catalog,
                builder: (_, location, _) => Column(
                  children: [
                    Text(location.uri.toString()),
                    const TextField(key: ValueKey('catalog-query')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final listState = tester.state(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'preserved private query');
      catalog.update(WebAppLocation.materials);
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, WebAppLocation.materials);
      expect(harness.router.observedLocation, WebAppLocation.materials);
      expect(harness.requested, isEmpty);

      // The application checks ownership before applying this browser request.
      await harness.router.setNewRoutePath(WebAppLocation.designs);
      expect(harness.requested, [WebAppLocation.designs]);
      expect(
        harness.router.updateDisplayedLocation(WebAppLocation.designs),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('/designs'), findsOneWidget);
      expect(tester.state(find.byType(TextField)), same(listState));
      expect(find.text('preserved private query'), findsOneWidget);
      expect(harness.router.currentConfiguration.uri.hasQuery, isFalse);
      expect(harness.router.updateDisplayedLocation(editor), isFalse);
      expect(harness.router.currentConfiguration, WebAppLocation.designs);

      await harness.router.setNewRoutePath(WebAppLocation.materials);
      expect(
        harness.router.updateDisplayedLocation(WebAppLocation.materials),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TextField)), same(listState));
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, WebAppLocation.home);
      catalog.update(WebAppLocation.designs);
      expect(harness.router.currentConfiguration, WebAppLocation.home);
      await harness.close(tester);
    },
  );

  testWidgets('a modal or another page cannot be replaced by a catalog tab', (
    tester,
  ) async {
    final harness = _Harness();
    final catalog = WebAppRouteController(
      WebAppLocation.designs,
      pages: const {WebAppPage.designs, WebAppPage.materials},
    );
    addTearDown(catalog.dispose);
    await harness.mount(tester);
    unawaited(
      harness.navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          settings: WebAppRouteSettings(
            WebAppLocation.designs,
            controller: catalog,
          ),
          builder: (_) => const Scaffold(body: Text('catalog work')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: harness.navigator.currentContext!,
        builder: (_) => const AlertDialog(title: Text('keep modal')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      harness.router.updateDisplayedLocation(WebAppLocation.materials),
      isFalse,
    );
    expect(catalog.value, WebAppLocation.designs);
    expect(find.text('keep modal'), findsOneWidget);
    harness.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await harness.push(tester, editor);
    expect(
      harness.router.updateDisplayedLocation(WebAppLocation.materials),
      isFalse,
    );
    expect(harness.router.currentConfiguration, editor);
    await harness.close(tester);
  });

  testWidgets(
    'imperative typed push and back update location without requesting another route',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      expect(harness.router.currentConfiguration, WebAppLocation.home);
      await harness.push(tester, album);
      expect(harness.router.currentConfiguration, album);
      await harness.push(tester, editor);
      expect(harness.router.currentConfiguration, editor);
      harness.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, album);
      expect(find.text('/albums/69'), findsOneWidget);
      expect(harness.requested, isEmpty);
      await harness.close(tester);
    },
  );

  testWidgets(
    'untagged dialog never replaces the underlying typed browser location',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.push(tester, editor);
      var updates = 0;
      harness.router.addListener(() => updates++);
      unawaited(
        showDialog<void>(
          context: harness.navigator.currentContext!,
          builder: (context) => AlertDialog(
            title: const Text('save changes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('close dialog'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, editor);
      expect(find.text('save changes?'), findsOneWidget);
      await tester.tap(find.text('close dialog'));
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, editor);
      expect(updates, 0);
      expect(harness.requested, isEmpty);
      await harness.close(tester);
    },
  );

  testWidgets(
    'typed replacements and removals reveal the correct remaining location',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.push(tester, album);
      await harness.push(tester, editor);
      final printRoute = harness.route(print);
      unawaited(
        harness.navigator.currentState!.pushReplacement<void, void>(printRoute),
      );
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, print);
      harness.navigator.currentState!.removeRoute(printRoute);
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, album);
      expect(harness.requested, isEmpty);
      await harness.close(tester);
    },
  );

  testWidgets(
    'browser route requests call root once with the exact typed target',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.router.setNewRoutePath(editor);
      expect(harness.requested, [editor]);
      // The application owns authentication and navigation for this request.
      // The delegate must not create a second route or infer successful access.
      expect(find.text('root home'), findsOneWidget);
      expect(harness.navigator.currentState!.canPop(), isFalse);
      await harness.push(tester, editor);
      harness.router.finishInitialNavigation();
      expect(harness.router.currentConfiguration, editor);
      expect(harness.requested, [editor]);
      await harness.router.setNewRoutePath(WebAppLocation.orders);
      expect(harness.requested, [editor, WebAppLocation.orders]);
      await harness.close(tester);
    },
  );

  testWidgets('a blocked editor pop restores its address and preserves work', (
    tester,
  ) async {
    final harness = _Harness();
    final mayLeave = ValueNotifier(false);
    addTearDown(mayLeave.dispose);
    final attempts = <bool>[];
    await harness.mount(tester);
    await harness.push(
      tester,
      editor,
      child: ValueListenableBuilder<bool>(
        valueListenable: mayLeave,
        builder: (_, allowed, _) => PopScope<void>(
          canPop: allowed,
          onPopInvokedWithResult: (didPop, _) => attempts.add(didPop),
          child: const Text('unsaved editor work'),
        ),
      ),
    );
    await harness.router.setNewRoutePath(WebAppLocation.home);
    final blocked = await harness.router.returnToRoot();
    await tester.pumpAndSettle();
    expect(blocked, isFalse);
    expect(attempts, [false]);
    expect(harness.router.currentConfiguration, editor);
    expect(find.text('unsaved editor work'), findsOneWidget);
    expect(harness.requested, [WebAppLocation.home]);
    mayLeave.value = true;
    await tester.pumpAndSettle();
    final returned = await harness.router.returnToRoot();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(attempts, [false, true]);
    expect(harness.router.currentConfiguration, WebAppLocation.home);
    expect(find.text('root home'), findsOneWidget);
    await harness.close(tester);
  });

  testWidgets(
    'a synchronous save prompt stays open and cancel preserves the editor',
    (tester) async {
      final harness = _Harness();
      final draft = TextEditingController(text: 'unsaved edited album text');
      addTearDown(draft.dispose);
      var prompts = 0;
      final attempts = <bool>[];
      await harness.mount(tester);
      await harness.push(
        tester,
        editor,
        child: Builder(
          builder: (editorContext) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              attempts.add(didPop);
              if (didPop) return;
              prompts++;
              unawaited(
                showDialog<void>(
                  context: editorContext,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('save edited album?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('cancel leaving'),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: TextField(controller: draft),
          ),
        ),
      );

      await harness.router.setNewRoutePath(WebAppLocation.home);
      final returned = await harness.router.returnToRoot();
      await tester.pumpAndSettle();

      expect(returned, isFalse);
      expect(prompts, 1);
      expect(attempts, [false]);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(harness.router.currentConfiguration, editor);
      expect(harness.router.observedLocation, editor);
      expect(draft.text, 'unsaved edited album text');

      await tester.tap(find.text('cancel leaving'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(prompts, 1);
      expect(attempts, [false]);
      expect(draft.text, 'unsaved edited album text');
      expect(harness.router.currentConfiguration, editor);
      expect(harness.router.observedLocation, editor);
      expect(harness.navigator.currentState!.canPop(), isTrue);
      expect(harness.requested, [WebAppLocation.home]);
      await harness.close(tester);
    },
  );

  testWidgets('a pending browser target survives intermediate pops to root', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.mount(tester);
    await harness.push(tester, album);
    await harness.router.setNewRoutePath(print);
    expect(harness.requested, [print]);
    final returned = await harness.router.returnToRoot();
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(harness.router.currentConfiguration, print);
    expect(find.text('root home'), findsOneWidget);
    await harness.push(tester, print);
    harness.router.finishInitialNavigation();
    expect(harness.router.currentConfiguration, print);
    expect(harness.requested, [print]);
    await harness.close(tester);
  });

  testWidgets(
    'initial public target survives startup root observations until navigation finishes',
    (tester) async {
      final harness = _Harness();
      await harness.router.setNewRoutePath(editor);
      expect(harness.requested, [editor]);
      // Mount Navigator directly so a platform route-information provider cannot
      // inject an unrelated initial '/' into this cold-start ordering assertion.
      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: harness.router.build)),
      );
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, editor);
      await harness.push(tester, editor);
      harness.router.finishInitialNavigation();
      expect(harness.router.currentConfiguration, editor);
      expect(harness.requested, [editor]);
      await harness.close(tester);
    },
  );

  for (final publicPage in [
    WebAppLocation.printProducts,
    const WebAppLocation(WebAppPage.policy, 'refund'),
  ]) {
    testWidgets(
      'public ${publicPage.uri} survives account loss and root auth restoration',
      (tester) async {
        final harness = _Harness();
        await harness.mount(tester);
        await harness.push(tester, publicPage);
        final published = <WebAppLocation>[];
        harness.router.addListener(
          () => published.add(harness.router.currentConfiguration),
        );
        harness.router.resetForSessionChange();
        await tester.pumpAndSettle();
        expect(harness.router.currentConfiguration, publicPage);
        expect(harness.requested, [publicPage]);
        expect(find.text('root home'), findsOneWidget);
        // Account restoration and AuthGate may rebuild underneath the public
        // route. Root observations must never replace its browser address.
        await harness.push(tester, publicPage);
        harness.router.finishInitialNavigation();
        await tester.pumpAndSettle();
        expect(find.text(publicPage.uri.toString()), findsOneWidget);
        expect(published, everyElement(publicPage));
        expect(harness.router.currentConfiguration, publicPage);
        await harness.close(tester);
      },
    );

    testWidgets(
      'public ${publicPage.uri} pending during account loss is restored after private routes clear',
      (tester) async {
        final harness = _Harness();
        await harness.mount(tester);
        await harness.push(tester, editor);
        harness.router.requestLocation(publicPage);
        harness.requested.clear();
        harness.router.resetForSessionChange(pendingLocation: publicPage);
        await tester.pumpAndSettle();
        expect(harness.router.currentConfiguration, publicPage);
        expect(harness.requested, [publicPage]);
        expect(find.text(editor.uri.toString()), findsNothing);
        await harness.push(tester, publicPage);
        harness.router.finishInitialNavigation();
        expect(harness.router.currentConfiguration, publicPage);
        await harness.close(tester);
      },
    );
  }

  testWidgets(
    'session changes remove private album and order history without restoring access',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.push(tester, editor);
      await harness.push(tester, WebAppLocation.orders);
      harness.router.resetForSessionChange();
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, WebAppLocation.home);
      expect(find.text(editor.uri.toString()), findsNothing);
      expect(find.text('/orders'), findsNothing);
      expect(harness.requested, isEmpty);
      expect(find.text('root home'), findsOneWidget);
      await harness.close(tester);
    },
  );

  testWidgets(
    'a newer private request does not retain the previous public page after session change',
    (tester) async {
      final harness = _Harness();
      await harness.mount(tester);
      await harness.push(tester, WebAppLocation.printProducts);
      harness.router.resetForSessionChange(
        pendingLocation: WebAppLocation.orders,
      );
      await tester.pumpAndSettle();
      expect(harness.router.currentConfiguration, WebAppLocation.home);
      expect(harness.requested, isEmpty);
      await harness.close(tester);
    },
  );
}
