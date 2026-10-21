import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _Environment {
  const _Environment({
    this.reduce = false,
    this.accessible = false,
    this.scale = 1,
  });
  final bool reduce, accessible;
  final double scale;
}

class _NavigationLog extends NavigatorObserver {
  final pushed = <Route<dynamic>>[], popped = <Route<dynamic>>[];
  int gesturesStarted = 0, gesturesStopped = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      pushed.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);

  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) => gesturesStarted++;

  @override
  void didStopUserGesture() => gesturesStopped++;
}

class _DraftPage extends StatefulWidget {
  const _DraftPage({super.key});

  @override
  State<_DraftPage> createState() => _DraftPageState();
}

class _DraftPageState extends State<_DraftPage> {
  final input = TextEditingController();

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('수정 중인 화면')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: TextField(
          key: const ValueKey('motion-route-input'),
          controller: input,
          decoration: const InputDecoration(labelText: '작성한 내용'),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCreationFonts);

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> mount(
    WidgetTester tester, {
    required ValueNotifier<_Environment> environment,
    TargetPlatform platform = TargetPlatform.iOS,
    GlobalKey<NavigatorState>? navigator,
    _NavigationLog? log,
    Widget? home,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [if (log != null) log],
        theme: SnapFitTheme.light().copyWith(platform: platform),
        builder: (context, child) => ValueListenableBuilder<_Environment>(
          valueListenable: environment,
          child: child,
          builder: (context, environment, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: environment.reduce,
              accessibleNavigation: environment.accessible,
              textScaler: TextScaler.linear(environment.scale),
            ),
            child: child!,
          ),
        ),
        home: home ?? const Scaffold(body: Center(child: Text('처음 화면'))),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> backEvent(
    WidgetTester tester,
    String method, [
    Map<String, Object>? arguments,
  ]) async {
    // Uses Flutter's documented platform-channel test protocol, never a device.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
    await tester.pump();
  }

  const start = <String, Object>{
    'touchOffset': <double>[5, 200],
    'progress': 0.0,
    'swipeEdge': 0,
  };
  const progress = <String, Object>{
    'x': 260.0,
    'y': 200.0,
    'progress': .65,
    'swipeEdge': 0,
  };

  for (final reduced in [false, true]) {
    testWidgets(
      'iOS MaterialPageRoute ${reduced ? 'reduced' : 'normal'} edge-back cancels and commits without replacing the route',
      (tester) async {
        reset(tester);
        viewport(tester, const Size(390, 844));
        final environment = ValueNotifier(_Environment(reduce: reduced));
        addTearDown(environment.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final log = _NavigationLog();
        await mount(
          tester,
          environment: environment,
          navigator: navigator,
          log: log,
        );
        final origin = log.pushed.single;
        final draft = GlobalKey<_DraftPageState>();
        final route = MaterialPageRoute<String>(
          settings: const RouteSettings(name: '/motion/ios-draft'),
          builder: (_) => _DraftPage(key: draft),
        );
        var completed = false;
        String? result = '미완료';
        navigator.currentState!.push(route).then((value) {
          completed = true;
          result = value;
        });
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('motion-route-input')),
          '취소해도 남아 있는 입력',
        );
        draft.currentState!.input.selection = const TextSelection.collapsed(
          offset: 3,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final originalState = draft.currentState;

        final cancel = await tester.startGesture(const Offset(5, 220));
        await cancel.moveBy(
          const Offset(90, 0),
          timeStamp: const Duration(milliseconds: 150),
        );
        await tester.pump();
        expect(navigator.currentState!.userGestureInProgress, true);
        expect(route.popGestureInProgress, true);
        await cancel.moveBy(
          const Offset(-80, 0),
          timeStamp: const Duration(milliseconds: 350),
        );
        await cancel.up(timeStamp: const Duration(milliseconds: 550));
        await tester.pumpAndSettle();
        expect(route.isCurrent, true);
        expect(route.isActive, true);
        expect(completed, false);
        expect(log.popped, isEmpty);
        expect(log.pushed, [origin, route]);
        expect(draft.currentState, same(originalState));
        expect(draft.currentState!.input.text, '취소해도 남아 있는 입력');
        expect(draft.currentState!.input.selection.baseOffset, 3);
        expect(navigator.currentState!.userGestureInProgress, false);

        final commit = await tester.startGesture(const Offset(5, 220));
        await commit.moveBy(
          const Offset(30, 0),
          timeStamp: const Duration(milliseconds: 100),
        );
        await commit.moveBy(
          const Offset(270, 0),
          timeStamp: const Duration(milliseconds: 300),
        );
        await tester.pump();
        expect(route.popGestureInProgress, true);
        await commit.up(timeStamp: const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(completed, true);
        expect(result, isNull);
        expect(log.popped, [route]);
        expect(log.gesturesStarted, 2);
        expect(log.gesturesStopped, 2);
        expect(log.pushed.first, same(origin));
        expect(origin.isCurrent, true);
        expect(find.text('처음 화면').hitTestable(), findsOneWidget);
        expect(find.text('수정 중인 화면'), findsNothing);
        expect(navigator.currentState!.canPop(), false);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets(
      'Android MaterialPageRoute ${reduced ? 'reduced' : 'normal'} predictive-back detector handles cancel and commit',
      (tester) async {
        reset(tester);
        viewport(tester, const Size(390, 844));
        final environment = ValueNotifier(_Environment(reduce: reduced));
        addTearDown(environment.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final log = _NavigationLog();
        await mount(
          tester,
          environment: environment,
          platform: TargetPlatform.android,
          navigator: navigator,
          log: log,
        );
        final origin = log.pushed.single;
        final draft = GlobalKey<_DraftPageState>();
        final route = MaterialPageRoute<void>(
          builder: (_) => _DraftPage(key: draft),
        );
        var completed = false;
        navigator.currentState!.push(route).then((_) => completed = true);
        await tester.pumpAndSettle();
        final originalState = draft.currentState;
        await tester.enterText(
          find.byKey(const ValueKey('motion-route-input')),
          '예측 뒤로가기도 입력 유지',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        await backEvent(tester, 'startBackGesture', start);
        expect(route.popGestureInProgress, true);
        await backEvent(tester, 'updateBackGestureProgress', progress);
        expect(navigator.currentState!.userGestureInProgress, true);
        await backEvent(tester, 'cancelBackGesture');
        await tester.pumpAndSettle();
        expect(route.isCurrent, true);
        expect(completed, false);
        expect(log.popped, isEmpty);
        expect(draft.currentState, same(originalState));
        expect(draft.currentState!.input.text, '예측 뒤로가기도 입력 유지');
        expect(navigator.currentState!.userGestureInProgress, false);

        await backEvent(tester, 'startBackGesture', start);
        expect(route.popGestureInProgress, true);
        await backEvent(tester, 'updateBackGestureProgress', progress);
        await backEvent(tester, 'commitBackGesture');
        await tester.pumpAndSettle();
        expect(completed, true);
        expect(log.popped, [route]);
        expect(log.pushed, [origin, route]);
        expect(origin.isCurrent, true);
        expect(find.text('처음 화면').hitTestable(), findsOneWidget);
        expect(navigator.currentState!.canPop(), false);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  for (final mode in ['normal', 'disableAnimations', 'accessibleNavigation']) {
    testWidgets(
      'pressable $mode preserves tap and cancel with the appropriate scale',
      (tester) async {
        reset(tester);
        viewport(tester, const Size(390, 844));
        final environment = ValueNotifier(
          _Environment(
            reduce: mode == 'disableAnimations',
            accessible: mode == 'accessibleNavigation',
          ),
        );
        addTearDown(environment.dispose);
        var taps = 0;
        await mount(
          tester,
          environment: environment,
          home: Scaffold(
            body: Center(
              child: SnapFitPressable(
                key: const ValueKey('motion-pressable'),
                onTap: () => taps++,
                child: const SizedBox(
                  width: 220,
                  height: 60,
                  child: Center(child: Text('선택한 내용 열기')),
                ),
              ),
            ),
          ),
        );
        final pressable = find.byKey(const ValueKey('motion-pressable'));
        final animated = find.descendant(
          of: pressable,
          matching: find.byType(AnimatedScale),
        );
        final gesture = await tester.startGesture(tester.getCenter(pressable));
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 200));
        final scale = tester.widget<AnimatedScale>(animated);
        expect(scale.scale, mode == 'normal' ? .975 : 1);
        if (mode != 'normal') expect(scale.duration, Duration.zero);
        expect(taps, 0);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedScale>(animated).scale, 1);
        expect(taps, 0);
        await tester.tap(pressable);
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'live accessibility and large-text changes keep route identity and entered text',
    (tester) async {
      reset(tester);
      viewport(tester, const Size(390, 844));
      final environment = ValueNotifier(const _Environment());
      addTearDown(environment.dispose);
      final navigator = GlobalKey<NavigatorState>();
      await mount(tester, environment: environment, navigator: navigator);
      final draft = GlobalKey<_DraftPageState>();
      final route = snapFitRoute<String>(page: _DraftPage(key: draft));
      final result = navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      final originalState = draft.currentState;
      await tester.enterText(
        find.byKey(const ValueKey('motion-route-input')),
        '화면을 바꿔도 이 내용은 그대로',
      );
      environment.value = const _Environment(accessible: true, scale: 1.8);
      viewport(tester, const Size(844, 390));
      await tester.pumpAndSettle();
      expect(route.isCurrent, true);
      expect(draft.currentState, same(originalState));
      expect(draft.currentState!.input.text, '화면을 바꿔도 이 내용은 그대로');
      expect(route.transitionDuration, Duration.zero);
      expect(route.reverseTransitionDuration, Duration.zero);
      environment.value = const _Environment(reduce: true, scale: 1.8);
      await tester.pumpAndSettle();
      expect(route.transitionDuration, Duration.zero);
      environment.value = const _Environment();
      await tester.pumpAndSettle();
      expect(route.transitionDuration, SnapFitMotion.medium);
      expect(route.reverseTransitionDuration, SnapFitMotion.fast);
      expect(draft.currentState, same(originalState));
      navigator.currentState!.pop('입력 유지 확인');
      await tester.pumpAndSettle();
      expect(await result, '입력 유지 확인');
      expect(find.text('처음 화면').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
