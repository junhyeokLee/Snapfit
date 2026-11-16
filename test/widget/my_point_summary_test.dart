import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/profile/presentation/widgets/my_point_balance_card.dart';

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() =>
      const UserInfo(id: 'owner-a', name: '우리', provider: 'email');
  void owner(String id) =>
      state = AsyncData(UserInfo(id: id, name: '우리', provider: 'email'));
}

Future<void> _mount(
  WidgetTester tester, {
  _Auth? auth,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  FutureOr<int> Function()? balance,
  VoidCallback? onCharge,
  VoidCallback? onHistory,
  ValueNotifier<bool>? visible,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final container = ProviderContainer(
    overrides: [
      authViewModelProvider.overrideWith(() => auth ?? _Auth()),
      myPointBalanceProvider.overrideWith(
        (_) async => balance == null ? 2750 : await balance(),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(authViewModelProvider.future);
  final card = MyPointBalanceCard(
    ownerId: 'owner-a',
    compact: true,
    onCharge: onCharge ?? () {},
    onHistory: onHistory ?? () {},
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: visible == null
                ? card
                : ValueListenableBuilder<bool>(
                    valueListenable: visible,
                    builder: (_, value, _) =>
                        value ? card : const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester) async {
  final summary = find.byKey(const ValueKey('my-point-summary'));
  await tester.ensureVisible(summary);
  await tester.pumpAndSettle();
  await tester.tap(summary);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('my-point-details')), findsOneWidget);
}

void main() {
  testWidgets(
    'balance stays a quiet accessible row until its menu is requested',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var charges = 0, history = 0;
        await _mount(
          tester,
          onCharge: () => charges++,
          onHistory: () => history++,
        );
        final card = find.byKey(const ValueKey('my-point-balance-card'));
        expect(tester.widget<Material>(card).type, MaterialType.transparency);
        expect(tester.getSize(card).height, inInclusiveRange(48, 64));
        expect(find.text('2,750 P'), findsOneWidget);
        expect(find.byKey(const ValueKey('my-point-charge')), findsNothing);
        expect(find.byKey(const ValueKey('my-point-history')), findsNothing);
        final summarySemantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('포인트 메뉴 열기')),
        );
        expect(summarySemantics.hasFlag(ui.SemanticsFlag.isButton), isTrue);
        expect(
          summarySemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await _open(tester);
        await tester.tap(find.byKey(const ValueKey('my-point-charge')));
        await tester.pumpAndSettle();
        expect(charges, 1);
        expect(history, 0);
        await _open(tester);
        await tester.tap(find.byKey(const ValueKey('my-point-history')));
        await tester.pumpAndSettle();
        expect(charges, 1);
        expect(history, 1);
        expect(find.byKey(const ValueKey('my-point-details')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'a failed balance can retry while both account destinations stay available',
    (tester) async {
      var reads = 0;
      await _mount(
        tester,
        balance: () {
          if (++reads == 1) throw StateError('offline');
          return -200;
        },
      );
      expect(find.text('잔액 확인 필요'), findsOneWidget);
      expect(find.text('0 P'), findsNothing);
      await _open(tester);
      expect(find.byKey(const ValueKey('my-point-charge')), findsOneWidget);
      expect(find.byKey(const ValueKey('my-point-history')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('my-point-retry')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('my-point-details')),
          matching: find.text('-200 P'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('my-point-close')));
      await tester.pumpAndSettle();
      expect(find.text('-200 P'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'long balance and both actions fit 320px large type dark=$dark',
      (tester) async {
        await _mount(
          tester,
          size: const Size(320, 568),
          scale: 1.8,
          dark: dark,
          balance: () => 1234567890,
        );
        expect(find.text('1,234,567,890 P'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('my-point-summary')).hitTestable(),
          findsOneWidget,
        );
        await _open(tester);
        for (final id in ['charge', 'history']) {
          final action = find.byKey(ValueKey('my-point-$id'));
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          expect(action.hitTestable(), findsOneWidget);
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('my-point-close')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('my-point-close')));
        await tester.pumpAndSettle();
        expect(find.text('1,234,567,890 P'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'account A B A hides the private sheet and rejects its stale action',
    (tester) async {
      final auth = _Auth();
      var charges = 0;
      await _mount(tester, auth: auth, onCharge: () => charges++);
      await _open(tester);
      final stale = tester
          .widget<ListTile>(find.byKey(const ValueKey('my-point-charge')))
          .onTap!;
      auth.owner('owner-b');
      await tester.pump();
      expect(find.byKey(const ValueKey('my-point-details')), findsNothing);
      expect(find.text('2,750 P'), findsNothing);
      auth.owner('owner-a');
      await tester.pumpAndSettle();
      stale();
      await tester.pumpAndSettle();
      expect(charges, 0);
      expect(find.byKey(const ValueKey('my-point-details')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing the summary dismisses only its own sheet behind another route',
    (tester) async {
      final visible = ValueNotifier(true);
      addTearDown(visible.dispose);
      await _mount(tester, visible: visible);
      await _open(tester);
      final navigator = Navigator.of(
        tester.element(find.byKey(const ValueKey('my-point-details'))),
        rootNavigator: true,
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('새 화면 유지')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.text('새 화면 유지'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('my-point-details'), skipOffstage: false),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
