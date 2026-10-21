import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:snap_fit/shared/widgets/snapfit_app_bar_back_button.dart';
import 'package:snap_fit/shared/widgets/snapfit_motion.dart';
import 'package:snap_fit/shared/widgets/snapfit_primary_action_button.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _field = ValueKey('unified-field');
const _filled = ValueKey('unified-filled');
const _primary = ValueKey('unified-primary');
const _row = ValueKey('unified-row');
const _description = '같은 글자와 버튼으로 설정, 문의, 구매를 편하게 이어가요.';

/// This is a test composition of production widgets, not an app screen.
class _Showcase extends StatefulWidget {
  const _Showcase({super.key, required this.events, this.initialIndex = 0});
  final List<String> events;
  final int initialIndex;

  @override
  State<_Showcase> createState() => _ShowcaseState();
}

class _ShowcaseState extends State<_Showcase> {
  final input = TextEditingController();
  final inputFocus = FocusNode();
  late int index = widget.initialIndex;
  bool enabled = true, loading = false;

  void update({bool? enabled, bool? loading}) => setState(() {
    this.enabled = enabled ?? this.enabled;
    this.loading = loading ?? this.loading;
  });

  @override
  void dispose() {
    input.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height;
    final nav = HomeBottomNavigationBar(
      currentIndex: index,
      rail: wide,
      onTap: (next) {
        widget.events.add('nav:$next');
        setState(() => index = next);
      },
    );
    return Scaffold(
      appBar: ExperienceHeader(
        title: '앱 공통 디자인',
        onBack: () => widget.events.add('header-back'),
        showNotifications: false,
      ),
      bottomNavigationBar: wide ? null : nav,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide) nav,
            Expanded(
              child: ListView(
                key: const ValueKey('unified-content'),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    '공통 컴포넌트 검증용 화면 · 실제 앨범 아님',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '소중한 순간을\n더 편하게 이어가요',
                    key: const ValueKey('unified-headline'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _description,
                    style: ExperienceFormStyle.text(context, 14),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    key: const ValueKey('unified-card'),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ExperienceRow(
                        key: _row,
                        icon: Icons.notifications_none_rounded,
                        title: '알림 설정',
                        subtitle: '내가 선택한 소식만 받을 수 있어요.',
                        onTap: () => widget.events.add('row'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: _field,
                    controller: input,
                    focusNode: inputFocus,
                    style: ExperienceFormStyle.text(context, 14),
                    decoration: ExperienceFormStyle.input(
                      context,
                      hint: '문의 제목을 입력해 주세요',
                    ).copyWith(labelText: '문의 제목'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (value) => widget.events.add('submit:$value'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    key: _filled,
                    style: ExperienceFormStyle.primary(context),
                    onPressed: enabled
                        ? () => widget.events.add('filled')
                        : null,
                    child: const Text('작성한 내용 저장하기'),
                  ),
                  const SizedBox(height: 12),
                  SnapFitPrimaryActionButton(
                    key: _primary,
                    label: '선택한 설정으로 계속하기',
                    icon: Icons.arrow_forward_rounded,
                    isLoading: loading,
                    onPressed: enabled
                        ? () => widget.events.add('primary')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('unified-outlined'),
                    onPressed: () => widget.events.add('outlined'),
                    child: const Text('이전 내용 다시 확인하기'),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SnapFitAppBarBackButton(
                      key: const ValueKey('unified-back'),
                      onPressed: () => widget.events.add('back'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final events = <String>[];

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await loadCreationFonts();
  });
  setUp(events.clear);

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard == 0 ? 24 : 0)
        : FakeViewPadding(top: 24, bottom: keyboard == 0 ? 34 : 0);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<GlobalKey<_ShowcaseState>> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    bool reduceMotion = false,
    int index = 0,
    Widget? home,
    GlobalKey<NavigatorState>? navigator,
    bool settle = true,
  }) async {
    final state = GlobalKey<_ShowcaseState>();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduceMotion,
            ),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home:
              home ??
              _Showcase(key: state, events: events, initialIndex: index),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
    return state;
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      final content = find
          .descendant(
            of: find.byKey(const ValueKey('unified-content')),
            matching: find.byType(Scrollable),
          )
          .first;
      // Lazily built rows need to enter the viewport before ensureVisible can
      // locate them. Start at the first row so this works in either direction.
      tester.state<ScrollableState>(content).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: content,
        maxScrolls: 60,
      );
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
  }

  void visibleText(WidgetTester tester, Finder finder) {
    for (final paragraph
        in find
            .descendant(of: finder, matching: find.byType(RichText))
            .evaluate()) {
      final render = paragraph.renderObject! as RenderParagraph;
      expect(
        render.didExceedMaxLines,
        false,
        reason: render.text.toPlainText(),
      );
    }
  }

  void safeControl(WidgetTester tester, Finder finder, {double min = 48}) {
    final rect = tester.getRect(finder);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final padding = tester.view.padding;
    final inset = tester.view.viewInsets.bottom;
    expect(rect.height, greaterThanOrEqualTo(min));
    expect(rect.width, greaterThanOrEqualTo(min));
    expect(rect.left, greaterThanOrEqualTo(padding.left - 1));
    expect(rect.right, lessThanOrEqualTo(size.width - padding.right + 1));
    expect(rect.top, greaterThanOrEqualTo(padding.top - 1));
    expect(
      rect.bottom,
      lessThanOrEqualTo(size.height - (inset > 0 ? inset : padding.bottom) + 1),
    );
    expect(finder.hitTestable(), findsOneWidget);
    visibleText(tester, finder);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('UNIFIED_DESIGN_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('output/all-screens-qa/unified-system-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in const [
    Size(320, 740),
    Size(390, 844),
    Size(648, 360),
    Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'shared components ${size.width.toInt()} ${dark ? 'dark' : 'light'} keep labels and callbacks usable',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(tester, dark: dark);
          expect(find.text(_description), findsOneWidget);
          visibleText(tester, find.byKey(const ValueKey('unified-headline')));
          await capture(
            tester,
            'overview-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          await reveal(tester, find.byKey(_filled));
          safeControl(tester, find.byKey(_filled));
          await tester.tap(find.byKey(_filled));
          await tester.pumpAndSettle();
          await reveal(tester, find.byKey(_primary));
          safeControl(tester, find.byKey(_primary));
          await tester.tap(find.byKey(_primary));
          await tester.pumpAndSettle();
          expect(events, containsAllInOrder(['filled', 'primary']));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in const [Size(320, 740), Size(648, 360)]) {
    for (final dark in [false, true]) {
      testWidgets(
        '180 percent shared controls ${size.width.toInt()} ${dark ? 'dark' : 'light'} grow and scroll',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(tester, dark: dark, scale: 1.8);
          await reveal(tester, find.byKey(_primary));
          safeControl(tester, find.byKey(_primary));
          await tester.tap(find.byKey(_primary));
          await tester.pumpAndSettle();
          expect(events, ['primary']);
          await capture(
            tester,
            'large180-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          await reveal(tester, find.byKey(_row));
          safeControl(tester, find.byKey(_row));
          await tester.tap(find.byKey(_row));
          await tester.pumpAndSettle();
          expect(events, ['primary', 'row']);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in const [Size(320, 740), Size(648, 360)]) {
    testWidgets(
      '240 percent text ${size.width.toInt()} keeps primary and navigation operable',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        await mount(tester, scale: 2.4, dark: true);
        await reveal(tester, find.byKey(_primary));
        safeControl(tester, find.byKey(_primary));
        await tester.tap(find.byKey(_primary));
        await tester.pumpAndSettle();
        expect(events, ['primary']);
        final nav = find.byType(HomeBottomNavigationBar);
        final album = find.descendant(of: nav, matching: find.text('내 앨범'));
        await reveal(tester, album);
        visibleText(tester, nav);
        await tester.tap(album);
        await tester.pumpAndSettle();
        expect(events.last, 'nav:0');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'disabled and in-progress actions never dispatch a second request',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final state = await mount(tester);
      state.currentState!.update(enabled: false);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(_primary));
      await tester.tap(find.byKey(_primary));
      expect(events, isEmpty);
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(_primary),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      state.currentState!.update(enabled: true, loading: true);
      await tester.pump();
      await tester.tap(find.byKey(_primary));
      await tester.pump(const Duration(milliseconds: 100));
      expect(events, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(_primary),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      state.currentState!.update(loading: false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_primary));
      await tester.pumpAndSettle();
      expect(events, ['primary']);
      expect(tester.takeException(), isNull);
    },
  );

  for (final rail in [false, true]) {
    testWidgets(
      '${rail ? 'rail' : 'bottom'} navigation keeps destination indices and semantic selection',
      (tester) async {
        reset(tester);
        metrics(tester, rail ? const Size(844, 390) : const Size(390, 844));
        final semantics = tester.ensureSemantics();
        try {
          await mount(tester, index: 5);
          final nav = find.byType(HomeBottomNavigationBar);
          final labels = ['내 앨범', '스토어', '내 디자인', '마이'];
          final indices = [0, 2, 6, 4];
          for (var i = 0; i < labels.length; i++) {
            final destination = find.descendant(
              of: nav,
              matching: find.text(labels[i]),
            );
            await reveal(tester, destination);
            await tester.tap(destination);
            await tester.pumpAndSettle();
            expect(events.last, 'nav:${indices[i]}');
            final selected = find.descendant(
              of: nav,
              matching: find.bySemanticsLabel(labels[i]),
            );
            expect(
              tester
                  .getSemantics(selected)
                  .hasFlag(ui.SemanticsFlag.isSelected),
              true,
            );
            expect(
              tester.getSemantics(selected).hasFlag(ui.SemanticsFlag.isButton),
              true,
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }

  testWidgets(
    'keyboard focus and input survive landscape rotation with large text',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final state = await mount(tester, scale: 1.8, dark: true);
      await reveal(tester, find.byKey(_field));
      await tester.enterText(find.byKey(_field), '사진을 오래 보관하고 싶어요');
      await tester.showKeyboard(find.byKey(_field));
      metrics(tester, const Size(844, 390), keyboard: 160);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(_field));
      expect(state.currentState!.input.text, '사진을 오래 보관하고 싶어요');
      expect(state.currentState!.inputFocus.hasFocus, true);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(events, ['submit:사진을 오래 보관하고 싶어요']);
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(_filled));
      final filledLabel = find.descendant(
        of: find.byKey(_filled),
        matching: find.text('작성한 내용 저장하기'),
      );
      Focus.of(tester.element(filledLabel)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(events.last, 'filled');
      expect(state.currentState!.input.text, '사진을 오래 보관하고 싶어요');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'both back controls expose a named touch target and call only their callback',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(320, 740));
      await mount(tester, scale: 1.8);
      final header = find.descendant(
        of: find.byType(ExperienceHeader),
        matching: find.byTooltip('뒤로가기'),
      );
      safeControl(tester, header, min: 44);
      await tester.tap(header);
      await tester.pumpAndSettle();
      final back = find.byKey(const ValueKey('unified-back'));
      await reveal(tester, back);
      safeControl(tester, back, min: 44);
      await tester.tap(back);
      await tester.pumpAndSettle();
      expect(events, ['header-back', 'back']);
      expect(
        find.descendant(of: back, matching: find.byTooltip('뒤로가기')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'normal route returns its result and reduced-motion route is visible immediately',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final navigator = GlobalKey<NavigatorState>();
      await mount(
        tester,
        navigator: navigator,
        home: const Scaffold(body: Text('원래 화면')),
      );
      final route = snapFitRoute<String>(
        page: const Scaffold(body: Text('다음 화면')),
      );
      final result = navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      expect(find.text('다음 화면').hitTestable(), findsOneWidget);
      navigator.currentState!.pop('선택 완료');
      await tester.pumpAndSettle();
      expect(await result, '선택 완료');
      expect(find.text('원래 화면').hitTestable(), findsOneWidget);
      await mount(
        tester,
        navigator: navigator,
        reduceMotion: true,
        home: const Scaffold(body: Text('원래 화면')),
      );
      final reduced = snapFitRoute<void>(
        page: const Scaffold(body: Text('동작 줄이기 화면')),
      );
      navigator.currentState!.push(reduced);
      await tester.pump();
      await tester.pump();
      expect(reduced.transitionDuration, Duration.zero);
      expect(reduced.reverseTransitionDuration, Duration.zero);
      expect(find.text('동작 줄이기 화면').hitTestable(), findsOneWidget);
      for (final fade
          in find
              .ancestor(
                of: find.text('동작 줄이기 화면'),
                matching: find.byType(FadeTransition),
              )
              .evaluate()) {
        expect((fade.widget as FadeTransition).opacity.value, 1);
      }
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('원래 화면').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced-motion entrance remains opaque and never shifts its content',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(
        tester,
        reduceMotion: true,
        settle: false,
        home: const Scaffold(
          body: SnapFitFadeIn(
            delay: Duration(milliseconds: 200),
            child: Text('바로 읽을 수 있는 내용'),
          ),
        ),
      );
      expect(find.text('바로 읽을 수 있는 내용').hitTestable(), findsOneWidget);
      final opacities = find.ancestor(
        of: find.text('바로 읽을 수 있는 내용'),
        matching: find.byType(Opacity),
      );
      for (final opacity in opacities.evaluate()) {
        expect((opacity.widget as Opacity).opacity, 1);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'standard platform route honors reduced-motion visibility and still pops',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final navigator = GlobalKey<NavigatorState>();
      await mount(
        tester,
        navigator: navigator,
        reduceMotion: true,
        home: const Scaffold(body: Text('처음 화면')),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('기본 경로 화면')),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('기본 경로 화면').hitTestable(), findsOneWidget);
      for (final fade
          in find
              .ancestor(
                of: find.text('기본 경로 화면'),
                matching: find.byType(FadeTransition),
              )
              .evaluate()) {
        expect((fade.widget as FadeTransition).opacity.value, 1);
      }
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('처음 화면').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      '${dark ? 'dark' : 'light'} form and primary text meet normal-text contrast',
      (tester) async {
        reset(tester);
        metrics(tester, const Size(390, 844));
        await mount(tester, dark: dark);
        final context = tester.element(find.byKey(_filled));
        double contrast(Color a, Color b) {
          final x = a.computeLuminance(), y = b.computeLuminance();
          return x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05);
        }

        final style = tester.widget<FilledButton>(find.byKey(_filled)).style!;
        expect(
          contrast(
            style.backgroundColor!.resolve({})!,
            style.foregroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        final primary = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(_primary),
            matching: find.byType(FilledButton),
          ),
        );
        expect(
          contrast(
            primary.style!.backgroundColor!.resolve({})!,
            primary.style!.foregroundColor!.resolve({})!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            ExperienceFormStyle.ink(context),
            ExperienceFormStyle.surface(context),
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(
            ExperienceFormStyle.muted(context),
            ExperienceFormStyle.surface(context),
          ),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
