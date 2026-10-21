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
import 'package:snap_fit/features/profile/domain/print_order_request.dart';
import 'package:snap_fit/features/profile/presentation/views/print_order_request_screen.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';

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
    email: 'order-support@example.com',
    provider: 'EMAIL',
  );
}

const _title = '우리의 여름, 오래 간직할 장면들';
const _reason = '인쇄할 사진을 다시 확인하고 싶어요. 제작 전 취소 가능 여부를 알려주세요.';

Album _album() => Album(
  id: 7,
  userId: 'fixture-owner',
  title: _title,
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
            'id': 'order-support-cover',
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
);

class _Home extends HomeViewModel {
  @override
  FutureOr<List<Album>> build() => [_album()];
}

PrintOrderRequestResult _result({
  String requestId = fixture.requestId,
  String type = 'REFUND',
  String status = 'REQUESTED',
  String resolution = 'NONE',
  bool replacement = false,
  String updatedAt = '2026-10-19T11:35:00',
}) => PrintOrderRequestResult.fromJson({
  ...fixture.requestJson(
    status: status,
    resolution: resolution,
    replacement: replacement,
  ),
  'requestId': requestId,
  'type': type,
  'updatedAt': updatedAt,
  'message': '담당자가 주문과 제작 진행 상태를 확인하고 있어요.',
});

class _Requests extends PrintOrderRequestRepository {
  _Requests(super.orders);

  final attempts = <({String id, String reason, String type})>[];
  final reads = <({PrintOrderRequestTarget? target, String? id})>[];
  PrintOrderRequestResult? current;
  Object? readError;
  bool loseCreate = false;
  Completer<PrintOrderRequestResult>? pendingCreate;

  @override
  Future<PrintOrderRequestResult> status({
    PrintOrderRequestTarget? target,
    String? requestId,
  }) async {
    reads.add((target: target, id: requestId));
    if (readError != null) throw readError!;
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
    if (pendingCreate != null) return pendingCreate!.future;
    if (loseCreate) throw StateError('private fixture response lost');
    return current = _result(requestId: requestId, type: type);
  }
}

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  late _Orders orders;
  late _Requests requests;

  setUpAll(loadCreationFonts);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orders = _Orders();
    requests = _Requests(orders);
    when(
      () => orders.printPaymentOwnerId(),
    ).thenAnswer((_) async => 'fixture-owner');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Finder reason() => key('print-order-request-reason');
  Finder submit() => key('print-order-request-submit');
  Finder refresh() => key('print-order-request-refresh');
  Finder type(String name) => key('print-order-request-type-$name');
  Finder editable() =>
      find.descendant(of: reason(), matching: find.byType(EditableText));
  Finder contentScroll() =>
      find.ancestor(of: reason(), matching: find.byType(Scrollable)).first;

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

  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1.3,
    String initialType = 'GENERAL',
    String? initialReason,
    bool hasAlbum = true,
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
            debugShowCheckedModeBanner: false,
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: PrintOrderRequestScreen(
              target: PrintOrderRequestTarget.order(fixture.orderId),
              albumId: hasAlbum ? 7 : null,
              albumTitle: _title,
              initialType: initialType,
              initialReason: initialReason,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> visible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await visible(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void safe(
    WidgetTester tester,
    Finder finder,
    Size size, {
    double keyboard = 0,
    bool action = true,
  }) {
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    if (action) expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height - (keyboard > 0 ? keyboard : (wide ? 24 : 34)) + 1,
      ),
    );
  }

  void noPayment() {
    verifyNever(() => orders.confirmPrintPayment(any()));
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark, {
    bool pending = false,
  }) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('PRINT_SUPPORT_QA')) return;
    if (pending) {
      await tester.pump(const Duration(milliseconds: 100));
    } else {
      await tester.pumpAndSettle();
    }
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${directory.path}/order-support-$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
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
      testWidgets(
        'native order support preserves order and request states at $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          await mount(tester, dark: dark);
          expect(
            tester
                .widget<ExperienceHeader>(find.byType(ExperienceHeader))
                .title,
            '주문 문의',
          );
          expect(key('print-order-request-summary'), findsOneWidget);
          expect(find.textContaining(fixture.orderId), findsOneWidget);
          expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
          await capture(tester, 'compose', size, dark);

          await tap(tester, type('REFUND'));
          await tester.enterText(reason(), _reason);
          await tester.pumpAndSettle();
          await visible(tester, submit());
          safe(tester, submit(), size);
          if (size.width > size.height) {
            final summaryScroll = find
                .ancestor(
                  of: key('print-order-request-summary'),
                  matching: find.byType(Scrollable),
                )
                .first;
            expect(
              tester.state<ScrollableState>(summaryScroll),
              isNot(same(tester.state<ScrollableState>(contentScroll()))),
            );
            final before = tester
                .state<ScrollableState>(summaryScroll)
                .position
                .pixels;
            await tester.drag(contentScroll(), const Offset(0, -80));
            await tester.pumpAndSettle();
            expect(
              tester.state<ScrollableState>(summaryScroll).position.pixels,
              before,
            );
            await visible(tester, submit());
          }
          await capture(tester, 'draft', size, dark);
          await tap(tester, submit());
          expect(requests.attempts.single.type, 'REFUND');
          expect(requests.attempts.single.reason, _reason);
          expect(key('print-order-request-status'), findsOneWidget);
          expect(find.text('요청 접수됨'), findsOneWidget);
          expect(find.text('전액 환불 확인됨'), findsNothing);
          expect(submit(), findsNothing);
          expect(
            find.descendant(
              of: key('print-order-request-submitted-reason'),
              matching: find.text(_reason),
              matchRoot: true,
            ),
            findsOneWidget,
          );
          await visible(tester, key('print-order-request-status'));
          await capture(tester, 'submitted', size, dark);

          requests.current = _result(
            requestId: requests.attempts.single.id,
            status: 'WAITING_PROVIDER',
          );
          await tap(tester, refresh());
          expect(find.text('결제·제작사 상태 확인 중'), findsOneWidget);
          expect(find.text('전액 환불 확인됨'), findsNothing);
          expect(requests.attempts, hasLength(1));
          await visible(tester, key('print-order-request-status'));
          await capture(tester, 'waiting', size, dark);
          noPayment();
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large text and keyboard keep order support controls reachable at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        await mount(tester, dark: true, scale: 1.8);
        await tap(tester, type('CANCEL'));
        await tester.enterText(reason(), _reason);
        final keyboard = size.width > size.height ? 110.0 : 240.0;
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        await visible(tester, editable());
        expect(
          tester.widget<EditableText>(editable()).focusNode.hasFocus,
          true,
        );
        safe(tester, editable(), size, keyboard: keyboard, action: false);
        await capture(tester, 'keyboard-large', size, true);
        await visible(tester, submit());
        safe(tester, submit(), size, keyboard: keyboard);
        await tap(tester, submit());
        expect(requests.attempts.single.type, 'CANCEL');
        expect(requests.attempts.single.reason, _reason);
        expect(find.text('요청 접수됨'), findsOneWidget);
        expect(find.text('미결제 주문 취소 확인됨'), findsNothing);
        noPayment();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'rotation preserves the exact reason input, selection, focus and request type',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      await mount(tester);
      await tap(tester, type('REFUND'));
      await tester.enterText(reason(), _reason);
      final input = tester.state<EditableTextState>(editable());
      const selection = TextSelection(baseOffset: 3, extentOffset: 13);
      input.widget.controller.selection = selection;
      metrics(tester, const Size(844, 390), keyboard: 110);
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(editable()), same(input));
      expect(input.widget.controller.text, _reason);
      expect(input.widget.controller.selection, selection);
      expect(input.widget.focusNode.hasFocus, true);
      await visible(tester, editable());
      safe(
        tester,
        editable(),
        const Size(844, 390),
        keyboard: 110,
        action: false,
      );
      await capture(tester, 'rotated-keyboard', const Size(844, 390), false);
      metrics(tester, const Size(390, 844));
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(editable()), same(input));
      expect(input.widget.controller.selection, selection);
      await tap(tester, submit());
      expect(requests.attempts.single.type, 'REFUND');
      expect(requests.attempts.single.reason, _reason);
      noPayment();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a pending request stays single-flight through rotation', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    final pending = Completer<PrintOrderRequestResult>();
    requests.pendingCreate = pending;
    await mount(tester, initialType: 'CANCEL', initialReason: _reason);
    await visible(tester, submit());
    final queued = tester.widget<FilledButton>(submit()).onPressed!;
    queued();
    queued();
    await tester.pump();
    expect(requests.attempts, hasLength(1));
    if (submit().evaluate().isNotEmpty) {
      expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
    }
    metrics(tester, const Size(844, 390));
    await tester.pump(const Duration(milliseconds: 400));
    await capture(
      tester,
      'sending',
      const Size(844, 390),
      false,
      pending: true,
    );
    final result = _result(
      requestId: requests.attempts.single.id,
      type: 'CANCEL',
    );
    requests.current = result;
    pending.complete(result);
    await tester.pumpAndSettle();
    expect(find.text('요청 접수됨'), findsOneWidget);
    expect(requests.attempts, hasLength(1));
    expect(submit(), findsNothing);
    noPayment();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'lost response stays locked until lookup and retries the original UUID and body',
    (tester) async {
      reset(tester);
      const size = Size(390, 844);
      metrics(tester, size);
      requests.loseCreate = true;
      await mount(tester, initialType: 'CANCEL', initialReason: _reason);
      await tap(tester, submit());
      expect(requests.attempts, hasLength(1));
      final first = requests.attempts.single;
      expect(submit(), findsNothing);
      expect(find.textContaining('새 요청을 보내기 전에 같은 요청의 결과'), findsOneWidget);
      await capture(tester, 'response-lost', size, false);

      requests.readError = StateError('private fixture network failure');
      await tap(tester, refresh());
      expect(submit(), findsNothing);
      expect(requests.attempts, hasLength(1));
      expect(requests.reads.last.id, first.id);
      expect(requests.reads.last.target, isNull);
      expect(find.textContaining('private fixture'), findsNothing);
      await capture(tester, 'lookup-error', size, false);

      requests.readError = null;
      await tap(tester, refresh());
      expect(tester.widget<FilledButton>(submit()).onPressed, isNotNull);
      expect(tester.widget<TextField>(reason()).enabled, isFalse);
      requests.loseCreate = false;
      await tap(tester, submit());
      expect(requests.attempts, hasLength(2));
      expect(requests.attempts.last, first);
      expect(find.text('요청 접수됨'), findsOneWidget);
      noPayment();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a new request never inherits an older general inquiry result', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    requests.current = _result(type: 'GENERAL', status: 'COMPLETED');
    await mount(tester);
    expect(find.text('문의 처리 완료'), findsOneWidget);
    await tap(tester, type('CANCEL'));
    await tester.enterText(reason(), _reason);
    requests.loseCreate = true;
    await tap(tester, submit());
    expect(find.text('문의 처리 완료'), findsNothing);
    expect(find.text('접수 결과 확인 중'), findsOneWidget);
    expect(find.text('전액 환불 확인됨'), findsNothing);
    expect(find.textContaining('최근 변경'), findsNothing);
    expect(submit(), findsNothing);
    expect(requests.attempts.single.type, 'CANCEL');
    noPayment();
    await tester.pumpWidget(const SizedBox());
  });

  for (final state in [
    (status: 'REQUESTED', resolution: 'NONE', replacement: false),
    (status: 'WAITING_PROVIDER', resolution: 'NONE', replacement: false),
    (status: 'REVIEW_REQUIRED', resolution: 'NONE', replacement: false),
    (status: 'COMPLETED', resolution: 'REFUNDED_FULL', replacement: true),
  ]) {
    testWidgets(
      'existing ${state.status} uses the server label and updated time',
      (tester) async {
        reset(tester);
        const size = Size(390, 844);
        metrics(tester, size);
        final result = _result(
          status: state.status,
          resolution: state.resolution,
          replacement: state.replacement,
        );
        requests.current = result;
        await mount(tester, dark: true);
        expect(find.text(result.label), findsOneWidget);
        expect(find.text(result.message), findsOneWidget);
        expect(submit(), findsNothing);
        expect(requests.attempts, isEmpty);
        expect(
          find.byWidgetPredicate((widget) {
            if (widget is! Text) return false;
            final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
            return text.contains('2026') &&
                text.contains('19') &&
                text.contains('11:35');
          }),
          findsOneWidget,
        );
        if (state.status != 'COMPLETED') {
          expect(find.text('전액 환불 확인됨'), findsNothing);
          expect(find.text('확인하고 돌아가기'), findsNothing);
        }
        await visible(tester, key('print-order-request-status'));
        await capture(tester, state.status.toLowerCase(), size, true);
        noPayment();
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('an order without an album still permits a general inquiry', (
    tester,
  ) async {
    reset(tester);
    const size = Size(320, 568);
    metrics(tester, size);
    await mount(tester, hasAlbum: false);
    expect(find.textContaining(fixture.orderId), findsOneWidget);
    await tester.enterText(reason(), '배송 전에 주문 내용을 확인하고 싶어요.');
    await tap(tester, submit());
    expect(requests.attempts.single.type, 'GENERAL');
    expect(find.text('요청 접수됨'), findsOneWidget);
    noPayment();
    await tester.pumpWidget(const SizedBox());
  });
}
