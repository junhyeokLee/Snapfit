import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/domain/entities/subscription_status.dart';

class BillingManagementScreen extends ConsumerStatefulWidget {
  const BillingManagementScreen({super.key});

  @override
  ConsumerState<BillingManagementScreen> createState() =>
      _BillingManagementScreenState();
}

class _BillingManagementScreenState
    extends ConsumerState<BillingManagementScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  ProductDetails? _monthlyProduct;
  List<ProductDetails> _pointProducts = const [];
  bool _storeAvailable = false;
  bool _loadingProducts = true;
  bool _purchaseInProgress = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _statusMessage = '구매 업데이트 수신 실패: $error');
      },
    );
    unawaited(_loadStoreProduct());
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStoreProduct() async {
    setState(() {
      _loadingProducts = true;
      _statusMessage = null;
    });
    try {
      final available = await _iap.isAvailable();
      if (!mounted) return;
      if (!available) {
        setState(() {
          _storeAvailable = false;
          _loadingProducts = false;
          _statusMessage = '현재 기기에서 스토어 결제를 사용할 수 없습니다.';
        });
        return;
      }
      final response = await _iap.queryProductDetails({
        Env.iapProMonthlyProductId,
        ...Env.iapPointProductIds,
      });
      if (!mounted) return;
      setState(() {
        _storeAvailable = true;
        _monthlyProduct = response.productDetails
            .where((product) => product.id == Env.iapProMonthlyProductId)
            .cast<ProductDetails?>()
            .firstOrNull;
        _pointProducts = response.productDetails
            .where((product) => Env.iapPointProductIds.contains(product.id))
            .toList(growable: false);
        _loadingProducts = false;
        _statusMessage = response.productDetails.isEmpty
            ? '스토어에 등록된 상품을 찾을 수 없습니다. 상품 ID를 확인해 주세요: ${Env.iapProMonthlyProductId}'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _statusMessage = '스토어 상품 조회 실패: $e';
      });
    }
  }

  Future<void> _buyMonthly() async {
    final product = _monthlyProduct;
    if (!_storeAvailable || product == null || _purchaseInProgress) return;
    setState(() {
      _purchaseInProgress = true;
      _statusMessage = '스토어 결제를 시작합니다.';
    });
    try {
      final sent = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!mounted) return;
      if (!sent) {
        setState(() {
          _purchaseInProgress = false;
          _statusMessage = '스토어 결제 요청을 시작하지 못했습니다.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseInProgress = false;
        _statusMessage = '결제 시작 실패: $e';
      });
    }
  }

  Future<void> _buyPoints(ProductDetails product) async {
    if (!_storeAvailable || _purchaseInProgress) return;
    setState(() {
      _purchaseInProgress = true;
      _statusMessage = '포인트 결제를 시작합니다.';
    });
    try {
      final sent = await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!mounted) return;
      if (!sent) {
        setState(() {
          _purchaseInProgress = false;
          _statusMessage = '포인트 결제 요청을 시작하지 못했습니다.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseInProgress = false;
        _statusMessage = '포인트 결제 시작 실패: $e';
      });
    }
  }

  Future<void> _restorePurchases() async {
    if (_purchaseInProgress) return;
    setState(() {
      _purchaseInProgress = true;
      _statusMessage = '구매 복원을 요청합니다.';
    });
    try {
      await _iap.restorePurchases();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _purchaseInProgress = false;
        _statusMessage = '구매 복원 실패: $e';
      });
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _statusMessage = '결제 승인 대기 중입니다.');
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _purchaseInProgress = false;
            _statusMessage =
                '결제 실패: ${purchase.error?.message ?? purchase.error?.code ?? '알 수 없는 오류'}';
          });
        }
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) {
          setState(() {
            _purchaseInProgress = false;
            _statusMessage = '결제가 취소되었습니다.';
          });
        }
        continue;
      }
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          if (Env.iapPointProductIds.contains(purchase.productID)) {
            final result = await ref
                .read(billingRepositoryProvider)
                .verifyStorePointPurchase(purchase);
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            ref.invalidate(myPointBalanceProvider);
            if (mounted) {
              setState(() {
                _purchaseInProgress = false;
                _statusMessage =
                    '${result.grantedPoints}포인트가 충전되었습니다. 현재 잔액 ${result.remainingBalance}P';
              });
            }
          } else {
            await ref
                .read(billingRepositoryProvider)
                .verifyStorePurchase(purchase);
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            ref.invalidate(mySubscriptionProvider);
            ref.invalidate(myStorageQuotaProvider);
            if (mounted) {
              setState(() {
                _purchaseInProgress = false;
                _statusMessage = '구독 권한이 반영되었습니다.';
              });
            }
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _purchaseInProgress = false;
              _statusMessage = '구매 검증 실패: $e';
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(mySubscriptionProvider);
    final quota = ref.watch(myStorageQuotaProvider);
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        leading: const SnapFitAppBarBackButton(),
        title: const Text('구독 및 결제 관리'),
        backgroundColor: SnapFitColors.backgroundOf(context),
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySubscriptionProvider);
          ref.invalidate(myStorageQuotaProvider);
          await _loadStoreProduct();
        },
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            _SubscriptionCard(subscription: subscription),
            SizedBox(height: 12.h),
            _QuotaCard(quota: quota),
            SizedBox(height: 12.h),
            _PointPackageCard(
              products: _pointProducts,
              loadingProducts: _loadingProducts,
              purchaseInProgress: _purchaseInProgress,
              onBuy: _buyPoints,
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SnapFit Pro 월간 구독',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _monthlyProduct?.price ?? '스토어 상품을 불러오는 중',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: SnapFitColors.accent,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Android는 Google Play Billing, iOS는 App Store / StoreKit 결제로 처리하고, 서버 검증 후 Supabase 구독 권한을 반영합니다.',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: subColor,
                      height: 1.45,
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    SizedBox(height: 12.h),
                    Text(
                      _statusMessage!,
                      style: TextStyle(fontSize: 12.sp, color: subColor),
                    ),
                  ],
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _loadingProducts ||
                              _purchaseInProgress ||
                              _monthlyProduct == null
                          ? null
                          : _buyMonthly,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SnapFitColors.accent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                      ),
                      child: Text(
                        _purchaseInProgress ? '처리 중...' : '스토어에서 구독하기',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _purchaseInProgress ? null : _restorePurchases,
                    child: const Text('구매 복원'),
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

class _PointPackageCard extends StatelessWidget {
  const _PointPackageCard({
    required this.products,
    required this.loadingProducts,
    required this.purchaseInProgress,
    required this.onBuy,
  });

  final List<ProductDetails> products;
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
            'AI 앨범 포인트',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '고급 AI 초안 1회는 ${Env.aiAlbumDraftPointCost}P예요. 초안이 만들어지고 리뷰할 수 있을 때만 차감됩니다.',
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
                        child: Text(
                          product.title,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
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

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final AsyncValue<SubscriptionStatusModel> subscription;

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: subscription.when(
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 구독',
              style: TextStyle(color: subColor, fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              value.isActive ? 'SnapFit Pro 활성' : 'Free 플랜',
              style: TextStyle(
                color: value.isActive ? SnapFitColors.accent : textColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (value.expiresAt != null) ...[
              SizedBox(height: 6.h),
              Text(
                '만료/갱신 예정: ${value.expiresAt}',
                style: TextStyle(color: subColor),
              ),
            ],
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('구독 상태를 불러오지 못했습니다: $e'),
      ),
    );
  }
}

class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.quota});

  final AsyncValue<dynamic> quota;

  @override
  Widget build(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: quota.when(
        data: (value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '저장 공간',
              style: TextStyle(color: subColor, fontSize: 12.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              '${value.usagePercent}% 사용 중',
              style: TextStyle(
                color: textColor,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8.h),
            LinearProgressIndicator(
              value: (value.usagePercent / 100).clamp(0.0, 1.0),
              color: SnapFitColors.accent,
            ),
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('저장 공간 정보를 불러오지 못했습니다: $e'),
      ),
    );
  }
}
