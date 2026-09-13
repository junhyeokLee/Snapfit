import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';

int _pointAmountFromProductId(String productId) {
  final match = RegExp(r'points_(\d+)').firstMatch(productId);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}

class BillingManagementScreen extends ConsumerStatefulWidget {
  const BillingManagementScreen({super.key, this.returnToAiDraftFlow = false});
  final bool returnToAiDraftFlow;
  @override
  ConsumerState<BillingManagementScreen> createState() =>
      _BillingManagementScreenState();
}

class _BillingManagementScreenState
    extends ConsumerState<BillingManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(pointPurchaseServiceProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(pointPurchaseServiceProvider);
    final balance = ref.watch(myPointBalanceProvider);
    final ledger = ref.watch(myPointLedgerProvider);
    return ListenableBuilder(
      listenable: purchases,
      builder: (context, _) => Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          leading: const SnapFitAppBarBackButton(),
          title: const Text('포인트 충전'),
          backgroundColor: SnapFitColors.backgroundOf(context),
          foregroundColor: SnapFitColors.textPrimaryOf(context),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myPointBalanceProvider);
            ref.invalidate(myPointLedgerProvider);
            await purchases.loadProducts();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(20.w),
            children: [
              if (widget.returnToAiDraftFlow) ...[
                _AiDraftReturnCard(purchaseInProgress: purchases.busy),
                SizedBox(height: 12.h),
              ],
              _PointPackageCard(
                products: purchases.products,
                pointBalance: balance,
                loadingProducts: purchases.loadingProducts,
                purchaseInProgress: purchases.busy,
                onBuy: (product) => unawaited(purchases.buy(product)),
              ),
              SizedBox(height: 12.h),
              if (purchases.message != null) ...[
                Text(
                  purchases.message!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: SnapFitColors.textSecondaryOf(context),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 12.h),
              ],
              TextButton(
                onPressed: purchases.busy
                    ? null
                    : () => unawaited(purchases.recover()),
                child: Text(purchases.busy ? '구매 확인 중...' : '구매 복원'),
              ),
              Text(
                '결제한 포인트가 보이지 않으면 구매 복원을 눌러 주세요. 미완료 결제를 다시 확인합니다.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              SizedBox(height: 16.h),
              _PointLedgerCard(ledger: ledger),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiDraftReturnCard extends StatelessWidget {
  const _AiDraftReturnCard({required this.purchaseInProgress});

  final bool purchaseInProgress;

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: SnapFitColors.accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 템플릿 준비 중',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.accent,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '포인트를 채운 뒤 바로 AI 템플릿 만들기로 돌아갈 수 있어요.',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.25,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '결제가 끝났다면 잔액을 확인하고 이어서 앨범 초안을 만들면 됩니다.',
            style: TextStyle(fontSize: 12.sp, color: subColor, height: 1.45),
          ),
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: purchaseInProgress
                  ? null
                  : () => Navigator.of(context).pop(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: SnapFitColors.accent,
                side: const BorderSide(color: SnapFitColors.accent),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              child: const Text('AI 템플릿으로 돌아가기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointPackageCard extends StatelessWidget {
  const _PointPackageCard({
    required this.products,
    required this.pointBalance,
    required this.loadingProducts,
    required this.purchaseInProgress,
    required this.onBuy,
  });

  final List<ProductDetails> products;
  final AsyncValue<int> pointBalance;
  final bool loadingProducts;
  final bool purchaseInProgress;
  final ValueChanged<ProductDetails> onBuy;

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '보유 포인트와 충전',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '현재 포인트',
            style: TextStyle(fontSize: 12.sp, color: subColor),
          ),
          SizedBox(height: 4.h),
          Text(
            pointBalance.when(
              data: (value) => '${value}P',
              loading: () => '확인 중',
              error: (_, _) => '확인 실패',
            ),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.accent,
            ),
          ),
          SizedBox(height: 8.h),
          if ((pointBalance.asData?.value ?? 0) < 0) ...[
            Text(
              '환불로 차감된 포인트가 남아 있어요. 충전 시 이 금액이 먼저 정산됩니다.',
              style: TextStyle(fontSize: 12.sp, color: subColor, height: 1.45),
            ),
            SizedBox(height: 8.h),
          ],
          Text(
            '템플릿·스티커·문구·프레임 구매와 AI 앨범 제작에 사용할 수 있어요. 고급 AI 템플릿은 1회 ${Env.aiAlbumDraftPointCost}P이며, 초안을 리뷰할 수 있을 때 차감됩니다.',
            style: TextStyle(fontSize: 12.sp, color: subColor, height: 1.45),
          ),
          SizedBox(height: 12.h),
          if (loadingProducts)
            Text('포인트 상품을 불러오는 중', style: TextStyle(color: subColor))
          else if (products.isEmpty)
            Text('스토어 포인트 상품 준비 중입니다.', style: TextStyle(color: subColor))
          else
            ...products.map(
              (product) => Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: OutlinedButton(
                  onPressed: purchaseInProgress ? null : () => onBuy(product),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.title,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              '${_pointAmountFromProductId(product.id)}P 충전',
                              style: TextStyle(
                                color: subColor,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        product.price,
                        style: TextStyle(
                          color: SnapFitColors.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointLedgerCard extends StatelessWidget {
  const _PointLedgerCard({required this.ledger});

  final AsyncValue<List<PointLedgerEntry>> ledger;

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '최근 포인트 내역',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '충전·꾸미기 상품 구매·AI 사용 내역을 최근 순서로 보여드려요.',
            style: TextStyle(fontSize: 12.sp, color: subColor, height: 1.45),
          ),
          SizedBox(height: 12.h),
          ledger.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(
              '포인트 내역을 불러오지 못했어요.',
              style: TextStyle(fontSize: 12.sp, color: subColor),
            ),
            data: (entries) {
              if (entries.isEmpty) {
                return Text(
                  '아직 포인트 내역이 없어요.',
                  style: TextStyle(fontSize: 12.sp, color: subColor),
                );
              }
              return Column(
                children: entries
                    .take(5)
                    .map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    entry.subtitle,
                                    style: TextStyle(
                                      color: subColor,
                                      fontSize: 11.5.sp,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              entry.amountLabel,
                              style: TextStyle(
                                color: entry.amountDelta >= 0
                                    ? SnapFitColors.accent
                                    : subColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
