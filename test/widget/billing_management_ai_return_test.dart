import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';
import '../support/point_purchase_fakes.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('AI return section stays compact and safe at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(
        bottom: 24,
        right: size.width > size.height ? 48 : 0,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final captureKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: ProviderScope(
            overrides: [
              pointPurchaseServiceProvider.overrideWith((ref) {
                final service = fakePointPurchaseService();
                ref.onDispose(service.dispose);
                return service;
              }),
              myPointBalanceProvider.overrideWith((_) async => 2500),
              myPointLedgerProvider.overrideWith((_) async => []),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const BillingManagementScreen(returnToAiDraftFlow: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final returnButton = find.byKey(
        const ValueKey('points-ai-return-action'),
      );
      await tester.ensureVisible(returnButton);
      final rect = tester.getRect(returnButton);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(
        rect.right,
        lessThanOrEqualTo(size.width - (size.width > size.height ? 48 : 0)),
      );
      expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
      final style = tester.widget<OutlinedButton>(returnButton).style!;
      expect(style.textStyle?.resolve({})?.fontSize, 14);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('JOURNEY_QA')) {
        await tester.runAsync(() async {
          final boundary =
              captureKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          const directory = 'output/creation-journey-qa';
          Directory(directory).createSync(recursive: true);
          File(
            '$directory/points-${size.width.toInt()}-after.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }

  testWidgets(
    'billing screen launched from AI flow offers return to AI draft',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Object? popResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pointPurchaseServiceProvider.overrideWith((ref) {
              final service = fakePointPurchaseService();
              ref.onDispose(service.dispose);
              return service;
            }),
            myStorageQuotaProvider.overrideWith(
              (_) async => const StorageQuotaStatus(
                userId: 'user-1',
                planCode: 'FREE',
                usedBytes: 0,
                softLimitBytes: 1073741824,
                hardLimitBytes: 1073741824,
                softExceeded: false,
                hardExceeded: false,
                usagePercent: 0,
              ),
            ),
            myPointBalanceProvider.overrideWith((_) async => 2500),
            myPointLedgerProvider.overrideWith(
              (_) async => [
                PointLedgerEntry(
                  id: 11,
                  createdAt: DateTime(2026, 9, 6, 4),
                  amountDelta: 2500,
                  reason: 'POINT_PURCHASE',
                ),
                PointLedgerEntry(
                  id: 10,
                  createdAt: DateTime(2026, 9, 6, 3),
                  amountDelta: -700,
                  reason: 'AI_ALBUM_DRAFT_CHARGE',
                ),
              ],
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, __) => MaterialApp(
              home: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    popResult = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BillingManagementScreen(
                          returnToAiDraftFlow: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('open billing'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open billing'));
      await tester.pumpAndSettle();

      expect(find.text('AI 템플릿으로 돌아가기'), findsOneWidget);
      expect(
        find.textContaining('포인트를 채운 뒤 바로 AI 템플릿 만들기로 돌아갈 수 있어요'),
        findsOneWidget,
      );

      await tester.tap(find.text('AI 템플릿으로 돌아가기'));
      await tester.pumpAndSettle();

      expect(popResult, isTrue);
    },
  );

  testWidgets('billing screen shows recent point history', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pointPurchaseServiceProvider.overrideWith((ref) {
            final service = fakePointPurchaseService();
            ref.onDispose(service.dispose);
            return service;
          }),
          myStorageQuotaProvider.overrideWith(
            (_) async => const StorageQuotaStatus(
              userId: 'user-1',
              planCode: 'FREE',
              usedBytes: 0,
              softLimitBytes: 1073741824,
              hardLimitBytes: 1073741824,
              softExceeded: false,
              hardExceeded: false,
              usagePercent: 0,
            ),
          ),
          myPointBalanceProvider.overrideWith((_) async => 2500),
          myPointLedgerProvider.overrideWith(
            (_) async => [
              PointLedgerEntry(
                id: 11,
                createdAt: DateTime(2026, 9, 6, 4),
                amountDelta: 2500,
                reason: 'POINT_PURCHASE',
              ),
              PointLedgerEntry(
                id: 10,
                createdAt: DateTime(2026, 9, 6, 3),
                amountDelta: -700,
                reason: 'AI_ALBUM_DRAFT_CHARGE',
              ),
            ],
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          builder: (_, __) =>
              const MaterialApp(home: BillingManagementScreen()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('이용 내역'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이용 내역'));
    await tester.pumpAndSettle();

    expect(find.text('최근 이용'), findsOneWidget);
    expect(find.text('포인트 충전'), findsWidgets);
    expect(find.textContaining('구독'), findsNothing);
    expect(find.textContaining('SnapFit Pro'), findsNothing);
    expect(find.text('+2500P'), findsOneWidget);
    expect(find.text('AI 템플릿 사용'), findsOneWidget);
    expect(find.text('-700P'), findsOneWidget);
  });
}
