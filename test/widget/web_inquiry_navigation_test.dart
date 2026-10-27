import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/navigation/app_root_route_observer.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';
import 'package:snap_fit/features/profile/presentation/widgets/customer_web_page.dart';
import 'package:snap_fit/features/profile/presentation/widgets/inquiry_exit_guard.dart';
import 'package:snap_fit/shared/web/web_design.dart';

/// Exercises the real site shell and inquiry guard through the same guarded
/// router exit used by application-wide navigation. No form is submitted.
class _InquiryNavigationHarness {
  _InquiryNavigationHarness(this.title, {this.width = 1440});

  final String title;
  final double width;
  final navigator = GlobalKey<NavigatorState>();
  final edits = TextEditingController();
  final busy = ValueNotifier(false);
  final allowedExits = <bool>[];
  late final WebAppRouter router = WebAppRouter(
    navigatorKey: navigator,
    observers: const [],
    routeBuilder: (_) => MaterialPageRoute<void>(
      settings: const AppRootRouteSettings(),
      builder: (_) => const Scaffold(body: Text('내 앨범 원래 화면')),
    ),
    onLocationRequested: (location) {
      if (location != WebAppLocation.feed) return;
      unawaited(
        router.returnToRoot().then((allowed) {
          allowedExits.add(allowed);
          if (allowed) {
            unawaited(
              navigator.currentState!.push<void>(
                WebAppPageRoute<void>(
                  settings: const WebAppRouteSettings(WebAppLocation.feed),
                  builder: (_) => const Scaffold(body: Text('이동한 피드')),
                ),
              ),
            );
          }
        }),
      );
    },
  );

  Future<void> mount(WidgetTester tester) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: SnapFitWebTheme.from(ThemeData()),
          routerDelegate: router,
          routeInformationParser: const WebAppRouteParser(),
          builder: (context, child) => WebNavigationScope(
            onNavigate: (_) => router.requestLocation(WebAppLocation.feed),
            onNotifications: () {},
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    router.finishInitialNavigation();
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: busy,
            builder: (_, sending, _) => InquiryExitGuard(
              edits: edits,
              hasUnsavedChanges: () => edits.text.isNotEmpty,
              busy: sending,
              child: CustomerWebPage(
                title: title,
                scrollBody: true,
                child: TextField(
                  key: const ValueKey('inquiry-navigation-draft'),
                  controller: edits,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> navigate(WidgetTester tester) async {
    // Apply the editor's Listenable update before the next user action.
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('web-navigation-menu'));
    if (menu.evaluate().isNotEmpty) {
      await tester.tap(menu);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('web-navigation-feed')));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    edits.dispose();
    busy.dispose();
    router.dispose();
  }
}

void main() {
  for (final title in ['고객센터', '주문 문의']) {
    for (final width in [390.0, 1440.0]) {
      testWidgets('$title global menu protects a draft at $width px', (
        tester,
      ) async {
        final harness = _InquiryNavigationHarness(title, width: width);
        await harness.mount(tester);
        await tester.enterText(
          find.byKey(const ValueKey('inquiry-navigation-draft')),
          '계속 작성할 문의 내용',
        );
        await harness.navigate(tester);
        expect(
          find.byKey(const ValueKey('inquiry-exit-dialog')),
          findsOneWidget,
        );
        expect(harness.allowedExits, [false]);
        expect(find.text('이동한 피드'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('inquiry-exit-continue')));
        await tester.pumpAndSettle();
        expect(harness.edits.text, '계속 작성할 문의 내용');
        expect(
          find.byKey(const ValueKey('inquiry-navigation-draft')),
          findsOneWidget,
        );
        await harness.navigate(tester);
        await tester.tap(find.byKey(const ValueKey('inquiry-exit-discard')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('inquiry-navigation-draft')),
          findsNothing,
        );
        expect(find.text('내 앨범 원래 화면'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await harness.dispose(tester);
      });
    }

    testWidgets('$title global menu cannot leave while a request is sending', (
      tester,
    ) async {
      final harness = _InquiryNavigationHarness(title);
      await harness.mount(tester);
      harness.edits.text = '전송 중인 문의';
      harness.busy.value = true;
      await tester.pumpAndSettle();
      await harness.navigate(tester);
      expect(find.byKey(const ValueKey('inquiry-exit-dialog')), findsNothing);
      expect(
        find.byKey(const ValueKey('inquiry-navigation-draft')),
        findsOneWidget,
      );
      expect(find.text('이동한 피드'), findsNothing);
      expect(harness.edits.text, '전송 중인 문의');
      expect(harness.allowedExits, [false]);
      expect(tester.takeException(), isNull);
      await harness.dispose(tester);
    });

    testWidgets(
      '$title empty form permits global navigation without a warning',
      (tester) async {
        final harness = _InquiryNavigationHarness(title);
        await harness.mount(tester);
        await harness.navigate(tester);
        expect(find.byKey(const ValueKey('inquiry-exit-dialog')), findsNothing);
        expect(
          find.byKey(const ValueKey('inquiry-navigation-draft')),
          findsNothing,
        );
        expect(find.text('이동한 피드'), findsOneWidget);
        expect(harness.allowedExits, [true]);
        expect(tester.takeException(), isNull);
        await harness.dispose(tester);
      },
    );
  }
}
