import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/domain/entities/storage_quota.dart';
import 'package:snap_fit/features/billing/domain/entities/subscription_status.dart';
import 'package:snap_fit/features/profile/presentation/views/billing_management_screen.dart';

void main() {
  testWidgets(
    'billing screen launched from AI flow offers return to AI draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Object? popResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mySubscriptionProvider.overrideWith(
              (_) async => const SubscriptionStatusModel(
                userId: 'user-1',
                planCode: null,
                status: 'INACTIVE',
                isActive: false,
              ),
            ),
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

      expect(find.text('AI 초안으로 돌아가기'), findsOneWidget);
      expect(
        find.textContaining('포인트를 채운 뒤 바로 초안 만들기로 돌아갈 수 있어요'),
        findsOneWidget,
      );

      await tester.tap(find.text('AI 초안으로 돌아가기'));
      await tester.pumpAndSettle();

      expect(popResult, isTrue);
    },
  );
}
