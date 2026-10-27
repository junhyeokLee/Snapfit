import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/profile/presentation/widgets/customer_web_page.dart';
import 'package:snap_fit/shared/web/web_design.dart';

const _header = ValueKey('web-utility-header');
const _heading = ValueKey('customer-web-page-heading');
const _localAction = ValueKey('customer-local-action');

Future<void> _mount(
  WidgetTester tester, {
  String title = '계정 설정',
  Size size = const Size(1440, 900),
  bool dark = false,
  double textScale = 1,
  VoidCallback? onBack,
  VoidCallback? onAction,
  ValueChanged<WebSection>? onNavigate,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: SnapFitWebTheme.from(
          ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            splashFactory: NoSplash.splashFactory,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: WebNavigationScope(
          onNavigate: onNavigate ?? (_) {},
          onNotifications: () {},
          child: CustomerWebPage(
            title: title,
            description: '계정 정보와 설정을 확인하세요.',
            onBack: onBack,
            scrollBody: true,
            actions: [
              if (onAction != null)
                OutlinedButton(
                  key: _localAction,
                  onPressed: onAction,
                  child: const Text('설정 저장'),
                ),
            ],
            child: const SizedBox(height: 100, child: Text('계정 정보')),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('direct account pages do not show an unusable back button', (
    tester,
  ) async {
    await _mount(tester);
    expect(find.byKey(const ValueKey('customer-web-back')), findsNothing);
    expect(find.byKey(_heading), findsOneWidget);
    expect(
      find.byKey(const ValueKey('web-navigation-account')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(390, 700), Size(1440, 900)]) {
    testWidgets('local page actions keep the same website header at $size', (
      tester,
    ) async {
      await _mount(tester, size: size);
      final initialHeader = tester.getRect(find.byKey(_header));
      await _mount(
        tester,
        size: size,
        title: '알림 설정',
        onBack: () {},
        onAction: () {},
      );
      expect(tester.getRect(find.byKey(_header)), initialHeader);
      expect(
        find.descendant(
          of: find.byKey(_heading),
          matching: find.byKey(_localAction),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(_header),
          matching: find.byKey(_localAction),
        ),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byKey(_heading)).dy,
        greaterThanOrEqualTo(initialHeader.bottom),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'local actions and global navigation have independent callbacks',
    (tester) async {
      var back = 0;
      var saved = 0;
      final destinations = <WebSection>[];
      await _mount(
        tester,
        onBack: () => back++,
        onAction: () => saved++,
        onNavigate: destinations.add,
      );
      await tester.tap(find.byKey(const ValueKey('customer-web-back')));
      await tester.tap(find.byKey(_localAction));
      await tester.tap(find.byKey(const ValueKey('web-navigation-feed')));
      expect(back, 1);
      expect(saved, 1);
      expect(destinations, [WebSection.feed]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow dark account page retains readable reachable actions', (
    tester,
  ) async {
    var saved = false;
    await _mount(
      tester,
      size: const Size(320, 650),
      dark: true,
      textScale: 1.6,
      onBack: () {},
      onAction: () => saved = true,
    );
    final context = tester.element(find.byKey(_heading));
    expect(WebPalette.of(context), WebPalette.dark);
    await tester.ensureVisible(find.byKey(_localAction));
    await tester.tap(find.byKey(_localAction));
    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });
}
