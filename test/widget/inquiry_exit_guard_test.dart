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
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/profile/data/order_repository.dart';
import 'package:snap_fit/features/profile/data/print_order_request_repository.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/domain/print_order_request.dart';
import 'package:snap_fit/features/profile/presentation/views/print_order_request_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';

import '../unit/print_order_request_contract_test.dart' as fixture;
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Orders extends Mock implements OrderRepository {}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => const UserInfo(
    id: 'fixture-owner',
    name: '지현',
    email: 'inquiry-exit@example.com',
    provider: 'EMAIL',
  );
}

const _albumTitle = '우리의 여름, 오래 간직할 장면들';
const _subject = '사진을 앨범에 추가할 때 문의드려요';
const _message = '가족 앨범을 꾸미고 있어요. 사진을 선택한 뒤 프레임에 넣으려는데 적용되지 않아요.\n확인 부탁드려요.';
const _reason = '인쇄할 사진을 다시 확인하고 싶어요. 제작 전 취소 가능 여부를 알려주세요.';

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => [
    Album(
      id: 7,
      userId: 'fixture-owner',
      title: _albumTitle,
      ratio: '1',
      totalPages: 24,
      targetPages: 24,
      createdAt: '2026-10-14T10:00:00',
      coverLayersJson: jsonEncode({
        'pages': [
          {
            'index': 0,
            'isCover': true,
            'backgroundColor': 0xFFF4F3ED,
            'layers': [
              {
                'id': 'inquiry-exit-cover',
                'type': 'image',
                'x': 0.0,
                'y': 0.0,
                'width': 1.0,
                'height': 1.0,
                'rotation': 0.0,
                'payload': {
                  'originalUrl': 'asset:assets/frame_preview/ocean_shore.jpg',
                },
                'zIndex': 0,
              },
            ],
          },
        ],
      }),
    ),
  ];
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
    if (reject) throw StateError('fixture connection unavailable');
  }
}

class _Requests extends PrintOrderRequestRepository {
  _Requests(super.orders);

  final attempts = <({String id, String reason, String type})>[];
  PrintOrderRequestResult? current;
  Completer<PrintOrderRequestResult>? pending;
  bool loseCreate = false;

  @override
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    if (current == null) {
      throw const PrintOrderRequestException(
        'print_order_request_not_found',
        404,
      );
    }
    return current!;
  }

  @override
  Future<PrintOrderRequestResult> create({
    required PrintOrderRequestTarget target,
    required String requestId,
    required String type,
    required String reason,
  }) async {
    attempts.add((id: requestId, reason: reason, type: type));
    if (pending != null) return pending!.future;
    if (loseCreate) throw StateError('fixture response lost');
    return current = PrintOrderRequestResult.fromJson({
      ...fixture.requestJson(),
      'requestId': requestId,
      'type': type,
    });
  }
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  late _Orders orders;
  late _Requests requests;
  late _Support support;

  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await loadCreationFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    requests = _Requests(orders);
    support = _Support();
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'fixture-owner');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    verifyNever(() => orders.confirmPrintPayment(any()));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String value) => find.byKey(ValueKey(value));
  Finder dialog() => key('inquiry-exit-dialog');
  Finder keep() => key('inquiry-exit-continue');
  Finder discard() => key('inquiry-exit-discard');
  Finder editable(String value) =>
      find.descendant(of: key(value), matching: find.byType(EditableText));
  EditableTextState input(WidgetTester tester, String value) =>
      tester.state<EditableTextState>(editable(value));
  VoidCallback closeCallback(WidgetTester tester) => tester
      .widget<IconButton>(
        find.ancestor(
          of: find.byTooltip('뒤로가기'),
          matching: find.byType(IconButton),
        ),
      )
      .onPressed!;

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard > 0 ? 0 : 24)
        : FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
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

  Future<void> enter(WidgetTester tester, String field, String value) async {
    await tester.ensureVisible(key(field));
    await tester.pumpAndSettle();
    await tester.enterText(key(field), value);
    await tester.pumpAndSettle();
  }

  Future<void> category(WidgetTester tester, String label) async {
    await tap(tester, key('support-category'));
    await tap(tester, find.text(label).last);
  }

  Future<void> supportDraft(WidgetTester tester) async {
    await category(tester, '앨범 편집 · 오류');
    await enter(tester, 'support-subject', _subject);
    await enter(tester, 'support-message', _message);
  }

  Future<void> orderDraft(WidgetTester tester) async {
    await tap(tester, key('print-order-request-type-CANCEL'));
    await enter(tester, 'print-order-request-reason', _reason);
  }

  Future<void> mount(
    WidgetTester tester, {
    bool order = false,
    bool dark = false,
    double scale = 1.3,
    String initialCategory = 'GENERAL',
    String initialSubject = '',
    String initialType = 'GENERAL',
    String? initialReason,
  }) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          homeViewModelProvider.overrideWith(_Home.new),
          orderRepositoryProvider.overrideWithValue(orders),
          printOrderRequestRepositoryProvider.overrideWithValue(requests),
          supportInquiryRepositoryProvider.overrideWithValue(support),
          printPaymentServiceProvider.overrideWith(
            (ref) => PrintPaymentService(
              repository: orders,
              orderRequests: requests,
            ),
          ),
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
              key: const ValueKey('inquiry-origin'),
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => order
                            ? PrintOrderRequestScreen(
                                target: PrintOrderRequestTarget.order(
                                  fixture.orderId,
                                ),
                                albumId: 7,
                                albumTitle: _albumTitle,
                                initialType: initialType,
                                initialReason: initialReason,
                              )
                            : SupportInquiryScreen(
                                initialCategory: initialCategory,
                                initialSubject: initialSubject,
                              ),
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
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  void safeAction(WidgetTester tester, Finder finder, Size size) {
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(rect.top, greaterThanOrEqualTo(wide ? 0 : 24));
    expect(rect.bottom, lessThanOrEqualTo(size.height - (wide ? 24 : 34)));
    expect(finder.hitTestable(), findsOneWidget);
  }

  void supportPreserved(WidgetTester tester) {
    expect(input(tester, 'support-subject').widget.controller.text, _subject);
    expect(input(tester, 'support-message').widget.controller.text, _message);
    expect(find.text('앨범 편집 · 오류'), findsOneWidget);
    expect(support.calls, isEmpty);
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('INQUIRY_EXIT_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'output/all-screens-qa/inquiry-exit-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('inquiry exit layouts $size dark=$dark', (tester) async {
        reset(tester);
        metrics(tester, size);
        await mount(tester, dark: dark);
        await supportDraft(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('뒤로가기'));
        expect(dialog(), findsOneWidget);
        expect(find.text('작성 중인 문의를 나갈까요?'), findsOneWidget);
        await tester.ensureVisible(keep());
        await tester.pumpAndSettle();
        safeAction(tester, keep(), size);
        await capture(tester, 'support-dialog', size, dark);
        await tap(tester, keep());
        expect(dialog(), findsNothing);
        supportPreserved(tester);
        await capture(tester, 'support-continued', size, dark);

        await mount(tester, order: true, dark: dark);
        await orderDraft(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await back(tester);
        expect(dialog(), findsOneWidget);
        await tester.ensureVisible(discard());
        await tester.pumpAndSettle();
        safeAction(tester, discard(), size);
        await capture(tester, 'order-dialog', size, dark);
        await tap(tester, discard());
        expect(find.byType(PrintOrderRequestScreen), findsNothing);
        expect(key('inquiry-origin'), findsOneWidget);
        expect(requests.attempts, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(648, 320)]) {
    for (final dark in [false, true]) {
      testWidgets('large text exit actions remain reachable $size dark=$dark', (
        tester,
      ) async {
        reset(tester);
        metrics(tester, size);
        await mount(tester, dark: dark, scale: 1.8);
        await supportDraft(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await back(tester);
        expect(dialog(), findsOneWidget);
        await tester.ensureVisible(keep());
        await tester.pumpAndSettle();
        safeAction(tester, keep(), size);
        await capture(tester, 'support-dialog-large', size, dark);
        await tap(tester, keep());
        supportPreserved(tester);
        await mount(tester, order: true, dark: dark, scale: 1.8);
        await orderDraft(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tap(tester, find.byTooltip('뒤로가기'));
        await tester.ensureVisible(discard());
        await tester.pumpAndSettle();
        safeAction(tester, discard(), size);
        await capture(tester, 'order-dialog-large', size, dark);
        await tap(tester, discard());
        expect(find.byType(PrintOrderRequestScreen), findsNothing);
        expect(support.calls, isEmpty);
        expect(requests.attempts, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('unchanged empty and prefilled inquiries close immediately', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    await mount(tester);
    await back(tester);
    expect(dialog(), findsNothing);
    expect(find.byType(SupportInquiryScreen), findsNothing);
    await mount(
      tester,
      initialCategory: 'ORDER',
      initialSubject: '주문 SF-LEGACY-001 문의',
    );
    await tap(tester, find.byTooltip('뒤로가기'));
    expect(dialog(), findsNothing);
    expect(find.byType(SupportInquiryScreen), findsNothing);
    await mount(
      tester,
      order: true,
      initialType: 'REFUND',
      initialReason: '처음 전달받은 주문 내용',
    );
    unawaited(navigator.currentState!.maybePop());
    await tester.pumpAndSettle();
    expect(dialog(), findsNothing);
    expect(find.byType(PrintOrderRequestScreen), findsNothing);
    expect(support.calls, isEmpty);
    expect(requests.attempts, isEmpty);
  });

  testWidgets(
    'returning all support fields to their baseline removes warning',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, initialCategory: 'ORDER', initialSubject: '주문 문의');
      await category(tester, '앨범 편집 · 오류');
      await enter(tester, 'support-subject', '수정한 제목');
      await enter(tester, 'support-message', '작성 중인 내용');
      await category(tester, '주문');
      await enter(tester, 'support-subject', '주문 문의');
      await enter(tester, 'support-message', '');
      await back(tester);
      expect(dialog(), findsNothing);
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(support.calls, isEmpty);
    },
  );

  testWidgets(
    'a category-only change and whitespace edits are unsaved changes',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await category(tester, '인쇄 · 배송');
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      expect(find.text('인쇄 · 배송'), findsOneWidget);
      await category(tester, '계정 · 기타');
      await enter(tester, 'support-message', ' ');
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      expect(input(tester, 'support-message').widget.controller.text, ' ');
      await enter(tester, 'support-message', '');
      await enter(tester, 'support-subject', ' ');
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, discard());
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(support.calls, isEmpty);
    },
  );

  testWidgets(
    'order type-only edits warn and exact initial values can be restored',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(
        tester,
        order: true,
        initialType: 'CANCEL',
        initialReason: '처음 전달받은 내용 ',
      );
      await tap(tester, key('print-order-request-type-REFUND'));
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      expect(
        tester
            .widget<ChoiceChip>(key('print-order-request-type-REFUND'))
            .selected,
        true,
      );
      await tap(tester, key('print-order-request-type-CANCEL'));
      await enter(tester, 'print-order-request-reason', '처음 전달받은 내용');
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      await enter(tester, 'print-order-request-reason', '처음 전달받은 내용 ');
      await back(tester);
      expect(dialog(), findsNothing);
      expect(find.byType(PrintOrderRequestScreen), findsNothing);
      expect(requests.attempts, isEmpty);
    },
  );

  testWidgets('dismissing the prompt preserves focused input and selection', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    await mount(tester);
    await supportDraft(tester);
    final message = input(tester, 'support-message');
    message.widget.controller.selection = const TextSelection(
      baseOffset: 3,
      extentOffset: 10,
    );
    await back(tester);
    expect(dialog(), findsOneWidget);
    await back(tester);
    expect(dialog(), findsNothing);
    expect(input(tester, 'support-message'), same(message));
    expect(message.widget.focusNode.hasFocus, true);
    expect(
      message.widget.controller.selection,
      const TextSelection(baseOffset: 3, extentOffset: 10),
    );
    supportPreserved(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await back(tester);
    await tester.tapAt(const Offset(8, 40));
    await tester.pumpAndSettle();
    expect(dialog(), findsNothing);
    expect(message.widget.focusNode.hasFocus, false);
    supportPreserved(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'queued close and cached submit cannot duplicate or bypass a prompt',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(844, 390));
      await mount(tester);
      await supportDraft(tester);
      final close = closeCallback(tester);
      final submit = tester
          .widget<FilledButton>(key('support-submit'))
          .onPressed!;
      close();
      close();
      close();
      await tester.pumpAndSettle();
      expect(dialog(), findsOneWidget);
      submit();
      await tester.pumpAndSettle();
      expect(support.calls, isEmpty);
      expect(dialog(), findsOneWidget);
      final leave = tester.widget<TextButton>(discard()).onPressed;
      if (leave != null) {
        leave();
        leave();
        await tester.pumpAndSettle();
      } else {
        await tap(tester, discard());
      }
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(key('inquiry-origin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a newer route cancels a confirmed exit without bypassing the next warning',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await supportDraft(tester);
      await back(tester);
      final leave = tester.widget<TextButton>(discard()).onPressed!;
      leave();
      scheduleMicrotask(() {
        unawaited(
          navigator.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('별도 도움말')),
            ),
          ),
        );
      });
      await tester.pumpAndSettle();
      expect(find.text('별도 도움말'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      supportPreserved(tester);
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      supportPreserved(tester);
      expect(support.calls, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sending remains blocked, failure retains draft and success exits once',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await supportDraft(tester);
      final pending = Completer<void>();
      support.pending = pending.future;
      support.reject = true;
      final close = closeCallback(tester);
      await tap(tester, key('support-submit'), settle: false);
      close();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      expect(dialog(), findsNothing);
      expect(find.byType(SupportInquiryScreen), findsOneWidget);
      expect(support.calls.length, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(key('support-error'), findsOneWidget);
      await back(tester);
      expect(dialog(), findsOneWidget);
      await tap(tester, keep());
      expect(input(tester, 'support-message').widget.controller.text, _message);
      support.pending = null;
      support.reject = false;
      await tap(tester, key('support-submit'));
      expect(support.calls.length, 2);
      expect(dialog(), findsNothing);
      expect(find.byType(SupportInquiryScreen), findsNothing);
      expect(key('inquiry-origin'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('submitted order request results leave without a draft warning', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    await mount(tester, order: true);
    await orderDraft(tester);
    await tap(tester, key('print-order-request-submit'));
    expect(requests.attempts.length, 1);
    expect(find.text('요청 접수됨'), findsOneWidget);
    await back(tester);
    expect(dialog(), findsNothing);
    expect(find.byType(PrintOrderRequestScreen), findsNothing);
    expect(key('inquiry-origin'), findsOneWidget);
  });

  testWidgets(
    'lost order response keeps recovery identity and permits safe closing',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      requests.loseCreate = true;
      await mount(tester, order: true);
      await orderDraft(tester);
      await tap(tester, key('print-order-request-submit'));
      expect(requests.attempts.length, 1);
      expect(find.textContaining('새 요청을 보내기 전에 같은 요청의 결과'), findsOneWidget);
      await tap(tester, key('print-order-request-refresh'));
      expect(
        tester.widget<TextField>(key('print-order-request-reason')).enabled,
        false,
      );
      requests.loseCreate = false;
      await tap(tester, key('print-order-request-submit'));
      expect(requests.attempts.length, 2);
      expect(requests.attempts.first, requests.attempts.last);
      await back(tester);
      expect(dialog(), findsNothing);
      expect(find.byType(PrintOrderRequestScreen), findsNothing);
      requests.current = null;
      requests.loseCreate = true;
      await mount(tester, order: true);
      await orderDraft(tester);
      await tap(tester, key('print-order-request-submit'));
      await back(tester);
      expect(dialog(), findsNothing);
      expect(find.byType(PrintOrderRequestScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'keyboard and rotation retain both inquiry drafts after continuing',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester, dark: true, scale: 1.8);
      await supportDraft(tester);
      final message = input(tester, 'support-message');
      message.widget.controller.selection = const TextSelection(
        baseOffset: 4,
        extentOffset: 12,
      );
      metrics(tester, const Size(390, 844), keyboard: 260);
      await tester.pumpAndSettle();
      await back(tester);
      metrics(tester, const Size(648, 320), keyboard: 140);
      await tester.pumpAndSettle();
      await tap(tester, keep());
      expect(input(tester, 'support-message'), same(message));
      expect(message.widget.focusNode.hasFocus, true);
      expect(
        message.widget.controller.selection,
        const TextSelection(baseOffset: 4, extentOffset: 12),
      );
      supportPreserved(tester);
      await capture(
        tester,
        'support-continued-keyboard-large',
        const Size(648, 320),
        true,
      );

      metrics(tester, const Size(390, 844));
      await mount(tester, order: true, dark: true, scale: 1.8);
      await orderDraft(tester);
      final reason = input(tester, 'print-order-request-reason');
      reason.widget.controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 9,
      );
      metrics(tester, const Size(390, 844), keyboard: 260);
      await tester.pumpAndSettle();
      await back(tester);
      metrics(tester, const Size(844, 390), keyboard: 140);
      await tester.pumpAndSettle();
      await tap(tester, keep());
      expect(input(tester, 'print-order-request-reason'), same(reason));
      expect(reason.widget.controller.text, _reason);
      expect(reason.widget.focusNode.hasFocus, true);
      expect(
        reason.widget.controller.selection,
        const TextSelection(baseOffset: 3, extentOffset: 9),
      );
      expect(
        tester
            .widget<ChoiceChip>(key('print-order-request-type-CANCEL'))
            .selected,
        true,
      );
      await capture(
        tester,
        'order-continued-keyboard-large',
        const Size(844, 390),
        true,
      );
      expect(requests.attempts, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
