import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/theme_settings_sheet.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Support extends Fake implements SupportInquiryRepository {
  final calls = <({String category, String subject, String message})>[];
  Future<void>? pending;
  bool reject = false;
  @override
  Future<void> createInquiry({
    required String category,
    required String subject,
    required String message,
  }) async {
    calls.add((category: category, subject: subject, message: message));
    await pending;
    if (reject) throw Exception('네트워크 연결을 확인해주세요.');
  }
}

void main() {
  _Binding();
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(648, 320),
    Size(740, 360),
    Size(844, 390),
  ];
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
  });
  Finder key(String id) => find.byKey(ValueKey(id));
  Finder editable(String id) =>
      find.descendant(of: key(id), matching: find.byType(EditableText));
  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard > 0 ? 0 : 24)
        : FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<void> tap(
    WidgetTester tester,
    Finder finder, {
    bool settle = true,
  }) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> enter(WidgetTester tester, String id, String value) async {
    await tester.ensureVisible(key(id));
    await tester.pumpAndSettle();
    await tester.enterText(key(id), value);
    await tester.pumpAndSettle();
  }

  void safe(
    WidgetTester tester,
    Finder finder,
    Size size, {
    double keyboard = 0,
  }) {
    final rect = tester.getRect(finder), wide = size.width > size.height;
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height -
            (keyboard > 0
                ? keyboard
                : wide
                ? 24
                : 34),
      ),
    );
    expect(finder.hitTestable(), findsOneWidget);
  }

  Future<void> mount(
    WidgetTester tester,
    _Support support, {
    bool dark = false,
    double scale = 1.3,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportInquiryRepositoryProvider.overrideWithValue(support),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: Scaffold(
              key: const ValueKey('help-origin'),
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SupportInquiryScreen(),
                      ),
                    ),
                    child: const Text('문의 열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('문의 열기'));
  }

  Future<void> theme(
    WidgetTester tester,
    ThemeMode mode,
    List<ThemeMode> changes,
  ) async {
    final context = navigator.currentContext!;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 520),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: ThemeSettingsSheet(
            selected: mode,
            onSelected: (selected) {
              changes.add(selected);
              Navigator.pop(sheetContext);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(
    WidgetTester tester,
    String id,
    Size size,
    bool dark, {
    bool pending = false,
  }) async {
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('HELP_SCREENS_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/$id-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> draft(WidgetTester tester) async {
    await tap(tester, key('support-category'));
    await tap(tester, find.text('앨범 편집 · 오류').last);
    await enter(tester, 'support-subject', '앨범에 사진을 추가할 때 문의드려요');
    await enter(
      tester,
      'support-message',
      '가족 앨범을 꾸미고 있어요. 사진을 선택한 뒤 프레임에 넣으려는데 적용되지 않아요.\n확인 부탁드려요.',
    );
  }

  for (final size in sizes) {
    for (final dark in [false, true]) {
      testWidgets('native support and theme layouts $size dark=$dark', (
        tester,
      ) async {
        reset(tester);
        metrics(tester, size);
        final support = _Support();
        await mount(tester, support, dark: dark);
        if (size.width > size.height) {
          expect(
            tester.getRect(find.text('0/80')).bottom,
            lessThanOrEqualTo(size.height - 24),
          );
          expect(find.text('0/80').hitTestable(), findsOneWidget);
        }
        await capture(tester, 'help-compose', size, dark);
        await tap(tester, key('support-submit'));
        expect(find.text('제목을 입력해주세요.'), findsOneWidget);
        expect(find.text('문의 내용을 입력해주세요.'), findsOneWidget);
        expect(support.calls, isEmpty);
        await capture(tester, 'help-validation', size, dark);
        await draft(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await capture(tester, 'help-draft', size, dark);
        await enter(
          tester,
          'support-message',
          '사진을 프레임에 넣으려는데 적용되지 않아요. 확인 부탁드려요.',
        );
        final input = tester.state<EditableTextState>(
          editable('support-message'),
        );
        final keyboard = size.width > size.height ? 140.0 : 260.0;
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        expect(
          tester.state<EditableTextState>(editable('support-message')),
          same(input),
        );
        expect(input.widget.focusNode.hasFocus, true);
        expect(
          tester.getRect(editable('support-message')).bottom,
          lessThanOrEqualTo(size.height - keyboard),
        );
        await capture(tester, 'help-keyboard', size, dark);
        await tester.ensureVisible(key('support-submit'));
        await tester.pumpAndSettle();
        safe(tester, key('support-submit'), size, keyboard: keyboard);
        final pending = Completer<void>();
        support.pending = pending.future;
        await tap(tester, key('support-submit'), settle: false);
        expect(support.calls.length, 1);
        expect(support.calls.single.category, 'BUG');
        final back = tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byTooltip('뒤로가기'),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed!;
        back();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(SupportInquiryScreen), findsOneWidget);
        metrics(tester, size);
        await capture(tester, 'help-sending', size, dark, pending: true);
        support.reject = true;
        pending.complete();
        await tester.pumpAndSettle();
        expect(key('support-error'), findsOneWidget);
        expect(
          tester.widget<TextFormField>(key('support-message')).controller!.text,
          contains('프레임'),
        );
        await tester.ensureVisible(key('support-error'));
        await tester.pumpAndSettle();
        await capture(tester, 'help-error', size, dark);
        support.pending = null;
        support.reject = false;
        await tap(tester, key('support-submit'));
        expect(support.calls.length, 2);
        expect(find.byType(SupportInquiryScreen), findsNothing);
        final changes = <ThemeMode>[];
        await theme(tester, dark ? ThemeMode.dark : ThemeMode.light, changes);
        safe(tester, key('theme-close'), size);
        await capture(tester, 'help-theme', size, dark);
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        await tester.ensureVisible(key('theme-option-dark'));
        await tester.pumpAndSettle();
        safe(tester, key('theme-close'), size, keyboard: keyboard);
        safe(tester, key('theme-option-dark'), size, keyboard: keyboard);
        await capture(tester, 'help-theme-keyboard', size, dark);
        await tap(tester, key('theme-option-dark'));
        expect(changes, [ThemeMode.dark]);
        expect(find.byType(ThemeSettingsSheet), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets('large text, dropdown and keyboard controls $size', (
      tester,
    ) async {
      reset(tester);
      metrics(tester, size);
      final support = _Support();
      await mount(tester, support, dark: true, scale: 1.8);
      await draft(tester);
      final keyboard = size.width > size.height ? 140.0 : 260.0;
      metrics(tester, size, keyboard: keyboard);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(editable('support-message')).bottom,
        lessThanOrEqualTo(size.height - keyboard),
      );
      await tester.ensureVisible(key('support-submit'));
      await tester.pumpAndSettle();
      safe(tester, key('support-submit'), size, keyboard: keyboard);
      await tap(tester, key('support-submit'));
      expect(support.calls.length, 1);
      final changes = <ThemeMode>[];
      await theme(tester, ThemeMode.dark, changes);
      await tester.ensureVisible(key('theme-option-light'));
      await tester.pumpAndSettle();
      safe(tester, key('theme-close'), size, keyboard: keyboard);
      safe(tester, key('theme-option-light'), size, keyboard: keyboard);
      await tap(tester, key('theme-close'));
      expect(changes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'rotation preserves exact message input state, selection, category and draft',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final support = _Support();
      await mount(tester, support);
      await draft(tester);
      final input = tester.state<EditableTextState>(
        editable('support-message'),
      );
      input.widget.controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 8,
      );
      metrics(tester, const Size(648, 320), keyboard: 140);
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(editable('support-message')),
        same(input),
      );
      expect(
        input.widget.controller.selection,
        const TextSelection(baseOffset: 3, extentOffset: 8),
      );
      expect(input.widget.focusNode.hasFocus, true);
      expect(
        tester.getRect(editable('support-message')).bottom,
        lessThanOrEqualTo(180),
      );
      expect(find.text('앨범 편집 · 오류'), findsOneWidget);
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(
        tester.state<EditableTextState>(editable('support-message')),
        same(input),
      );
      expect(support.calls, isEmpty);
      await tap(tester, key('support-submit'));
      expect(support.calls.single.category, 'BUG');
      expect(support.calls.single.message, startsWith('가족 앨범'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'single-flight submit rejects cached, covered and disposed callbacks',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(844, 390));
      final support = _Support(), pending = Completer<void>();
      support.pending = pending.future;
      await mount(tester, support);
      await draft(tester);
      final submit = tester
          .widget<FilledButton>(key('support-submit'))
          .onPressed!;
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('별도 화면')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      submit();
      await tester.pump();
      expect(support.calls, isEmpty);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      submit();
      submit();
      await tester.pump(const Duration(milliseconds: 300));
      expect(support.calls.length, 1);
      await tester.pumpWidget(const SizedBox());
      submit();
      pending.complete();
      await tester.pumpAndSettle();
      expect(support.calls.length, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'successful inquiry cannot pop a newer route or be sent again on return',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(740, 360));
      final support = _Support(), pending = Completer<void>();
      support.pending = pending.future;
      await mount(tester, support);
      await draft(tester);
      final submit = tester
          .widget<FilledButton>(key('support-submit'))
          .onPressed!;
      submit();
      await tester.pump(const Duration(milliseconds: 200));
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('별도 화면')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('별도 화면'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('문의가 접수되었습니다.'), findsOneWidget);
      submit();
      await tester.pumpAndSettle();
      expect(support.calls.length, 1);
      await tap(tester, key('support-submit'));
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'theme modal rotation, cancel and repeated selection do not pop its parent',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, _Support());
      final changes = <ThemeMode>[];
      await theme(tester, ThemeMode.light, changes);
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(key('theme-wide-options'), findsOneWidget);
      final choose = tester.widget<InkWell>(key('theme-option-dark')).onTap!;
      choose();
      choose();
      await tester.pumpAndSettle();
      expect(changes, [ThemeMode.dark]);
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      choose();
      await tester.pumpAndSettle();
      expect(changes.length, 1);
      await theme(tester, ThemeMode.light, changes);
      final close = tester.widget<IconButton>(key('theme-close')).onPressed!;
      close();
      close();
      await tester.pumpAndSettle();
      expect(changes.length, 1);
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('inline theme selector still accepts multiple changes', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(740, 360));
    final changes = <ThemeMode>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ThemeSettingsSheet(
            selected: ThemeMode.light,
            onSelected: changes.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, key('theme-option-dark'));
    await tap(tester, key('theme-option-light'));
    expect(changes, [ThemeMode.dark, ThemeMode.light]);
    expect(tester.takeException(), isNull);
  });
}
