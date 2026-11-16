import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/config/env.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/data/web_point_topup_repository.dart';
import 'package:snap_fit/features/billing/domain/web_point_topup.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../support/point_ledger_history_fakes.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _catalog = WebPointCatalog(
  testAvailable: true,
  liveAvailable: false,
  environment: 'test',
  products: [
    WebPointProduct(
      id: 'snapfit_points_2500',
      title: '2,500P',
      points: 2500,
      amount: 2200,
    ),
    WebPointProduct(
      id: 'snapfit_points_8000',
      title: '8,000P',
      points: 8000,
      amount: 5900,
    ),
    WebPointProduct(
      id: 'snapfit_points_18000',
      title: '18,000P',
      points: 18000,
      amount: 11900,
    ),
  ],
);
final _ledger = [
  PointLedgerEntry(
    id: 5,
    createdAt: DateTime.utc(2026, 10, 29, 6),
    amountDelta: -450,
    reason: 'DIGITAL_ITEM_PURCHASE',
  ),
  PointLedgerEntry(
    id: 4,
    createdAt: DateTime.utc(2026, 10, 28, 5),
    amountDelta: 2500,
    reason: 'POINT_PURCHASE',
  ),
  PointLedgerEntry(
    id: 3,
    createdAt: DateTime.utc(2026, 10, 27, 6),
    amountDelta: -700,
    reason: 'AI_ALBUM_DRAFT_CHARGE',
  ),
];

class _Auth extends Mock implements GoTrueClient {}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth)
    : super(
        'https://points-design.invalid',
        'fixture',
        httpClient: MockClient(
          (_) async => throw StateError('Unexpected external HTTP'),
        ),
        accessToken: () async => 'fixture',
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

class _Repository extends WebPointTopupRepository {
  _Repository(super.client);
  int catalogReads = 0, historyReads = 0;
  @override
  Future<WebPointCatalog> catalog(String owner) async {
    expect(owner, _owner);
    catalogReads++;
    return _catalog;
  }

  @override
  Future<List<WebPointTopup>> history(String owner) async {
    expect(owner, _owner);
    historyReads++;
    return [];
  }

  @override
  Future<WebPointTopup> prepare(
    String owner,
    String requestId,
    WebPointProduct product, {
    String environment = 'test',
  }) => throw StateError('Design selection must not prepare a payment');
}

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  _PaintBinding();
  final exceptionReporter = reportTestException;
  setUpAll(() {
    reportTestException = (details, description) {
      // The browser reporter otherwise drops the underlying layout/assertion
      // details and only returns "See exception logs above".
      // ignore: avoid_print
      print(details.exceptionAsString());
      if (details.stack != null) {
        // ignore: avoid_print
        print(details.stack.toString().split('\n').take(10).join('\n'));
      }
      exceptionReporter(details, description);
    };
  });
  tearDownAll(() => reportTestException = exceptionReporter);
  final boundary = GlobalKey();
  late _Client client;
  late _Repository repository;

  setUp(() {
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(
      User(
        id: _owner,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-10-29',
      ),
    );
    client = _Client(auth);
    repository = _Repository(client);
  });
  tearDown(() async => client.dispose());

  Future<void> mount(
    WidgetTester tester,
    Size size, {
    bool history = false,
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    // Explicit FontLoader can deadlock in Chrome's widget-test engine. These
    // tests verify state, semantics and layout; actual bundled-font visual QA
    // uses the normal browser entry point tool/point_design_preview.dart.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          visibleOrderOwnerProvider.overrideWithValue(_owner),
          webPointTopupRepositoryProvider.overrideWithValue(repository),
          myPointBalanceProvider.overrideWith((_) async => 12450),
          pointLedgerHistoryProvider.overrideWith2(
            (filter) => FixturePointLedgerHistoryController(
              filter,
              () async => _ledger,
            ),
          ),
          pointPurchaseServiceProvider.overrideWith(
            (_) => throw StateError(
              'The browser must not initialize native billing',
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: SnapFitWebTheme.from(
            dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
          home: WebNavigationScope(
            onNavigate: (_) {},
            onNotifications: () {},
            onPublicNavigate: (_) {},
            child: BillingManagementScreen(
              initialPointsTabIndex: history ? 1 : 0,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(webPointTopupLiveCheckoutReleased, isFalse);
  }

  Future<void> capture(WidgetTester tester, String id) async {
    expect(tester.takeException(), isNull, reason: id);
    if (!const bool.fromEnvironment('WEB_POINTS_QA')) return;
    await tester.pump();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final pixels = await render.toImage(pixelRatio: 1);
      try {
        final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
        debugPrintSynchronously(
          'SNAPFIT_MEMORY_IMAGE_V1:${jsonEncode({'id': id, 'mimeType': 'image/png', 'width': pixels.width, 'height': pixels.height, 'base64': base64Encode(bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))})}',
        );
      } finally {
        pixels.dispose();
      }
    });
  }

  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1440, 1000),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'browser points closed gate stays useful at ${size.width} dark=$dark',
        (tester) async {
          await mount(tester, size, dark: dark);
          expect(find.text('12,450 P'), findsWidgets);
          expect(find.text('포인트는 앱에서 충전해요'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('web-topup-charge-action')),
            findsNothing,
          );
          for (final phrase in [
            'TEST',
            'SDK',
            'codegate',
            'channelKey',
            'web_point_',
          ]) {
            expect(
              find.textContaining(phrase),
              findsNothing,
              reason: 'Production closed UI must not expose $phrase.',
            );
          }
          expect(repository.catalogReads, 0);
          expect(repository.historyReads, 0);
          await capture(
            tester,
            'points-web-closed-${size.width.toInt()}-${dark ? 'dark' : 'light'}',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
        skip: !kIsWeb || Env.webPointTopupTestEnabled,
      );
    }

    testWidgets(
      'browser point history keeps exact balance and server order at ${size.width}',
      (tester) async {
        await mount(tester, size, history: true);
        expect(find.text('12,450 P'), findsWidgets);
        final firstRow = find.byKey(const ValueKey('points-ledger-5'));
        final secondRow = find.byKey(const ValueKey('points-ledger-4'));
        expect(firstRow, findsOneWidget);
        double rowOffset(Finder row) {
          final render = tester.renderObject(row);
          return RenderAbstractViewport.of(
            render,
          ).getOffsetToReveal(render, 0).offset;
        }

        final firstOffset = rowOffset(firstRow);
        if (secondRow.evaluate().isEmpty) {
          // Narrow browsers initially reserve space for the expanded wallet.
          // Read the lazy history by scrolling its actual list, without
          // assuming the second server entry is already in the widget tree.
          await tester.scrollUntilVisible(
            secondRow,
            120,
            scrollable: find.descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            ),
            maxScrolls: 20,
          );
          await tester.pumpAndSettle();
        }
        expect(secondRow, findsOneWidget);
        expect(
          firstOffset,
          lessThan(rowOffset(secondRow)),
          reason: 'The newer server entry must precede the next entry.',
        );
        expect(
          find.byKey(const ValueKey('web-topup-charge-action')),
          findsNothing,
        );
        await capture(tester, 'points-web-history-${size.width.toInt()}-light');
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb || Env.webPointTopupTestEnabled,
    );

    testWidgets(
      'browser test catalog keeps exact KRW prices without preparing a charge at ${size.width}',
      (tester) async {
        await mount(tester, size);
        for (final entry in _catalog.products) {
          expect(
            find.byKey(ValueKey('web-topup-product-${entry.id}')),
            findsOneWidget,
          );
        }
        for (final label in ['2,200원', '5,900원', '11,900원']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(repository.catalogReads, 1);
        expect(repository.historyReads, 1);
        await capture(
          tester,
          'points-web-test-catalog-${size.width.toInt()}-light',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      skip: !kIsWeb || !Env.webPointTopupTestEnabled,
    );
  }

  testWidgets('browser closed gate remains readable with 180 percent text', (
    tester,
  ) async {
    await mount(tester, const Size(320, 740), scale: 1.8);
    expect(find.text('포인트는 앱에서 충전해요'), findsOneWidget);
    expect(find.byKey(const ValueKey('web-topup-charge-action')), findsNothing);
    await capture(tester, 'points-web-closed-320-large');
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !kIsWeb || Env.webPointTopupTestEnabled);
}
