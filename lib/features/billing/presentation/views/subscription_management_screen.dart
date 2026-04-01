import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../data/billing_provider.dart';
import '../../data/billing_repository.dart';
import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_prepare_result.dart';

class SubscriptionManagementScreen extends ConsumerStatefulWidget {
  const SubscriptionManagementScreen({super.key});

  @override
  ConsumerState<SubscriptionManagementScreen> createState() =>
      _SubscriptionManagementScreenState();
}

class _SubscriptionManagementScreenState
    extends ConsumerState<SubscriptionManagementScreen> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  final Set<String> _handledOrderIds = <String>{};

  bool _isBusy = false;
  PaymentPrepareResult? _prepared;

  @override
  void initState() {
    super.initState();
    _initBillingDeepLinkListener();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initBillingDeepLinkListener() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        unawaited(_handleIncomingUri(initial));
      }
    } catch (_) {
      // no-op: 초기 링크는 실패해도 스트림에서 후속 처리 가능
    }

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleIncomingUri(uri));
    });
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (!mounted) return;
    if (uri.scheme.toLowerCase() != 'snapfit' ||
        uri.host.toLowerCase() != 'billing') {
      return;
    }

    final path = uri.path.toLowerCase();
    final orderId = uri.queryParameters['orderId']?.trim() ?? '';
    if (orderId.isEmpty) return;
    if (_handledOrderIds.contains(orderId)) return;
    _handledOrderIds.add(orderId);

    if (path.contains('success')) {
      final paymentKey = uri.queryParameters['paymentKey']?.trim();
      final amount = _safeInt(uri.queryParameters['amount']);
      await _approveFromCallback(
        orderId: orderId,
        paymentKey: paymentKey,
        amount: amount,
      );
    } else if (path.contains('fail')) {
      final message = uri.queryParameters['message']?.trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message?.isNotEmpty == true ? message! : '결제가 취소되거나 실패했습니다.',
          ),
        ),
      );
    }
  }

  Future<void> _approveFromCallback({
    required String orderId,
    String? paymentKey,
    int? amount,
  }) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      final repo = ref.read(billingRepositoryProvider);
      await repo.approveOrder(
        orderId: orderId,
        paymentKey: paymentKey,
        amount: amount,
      );

      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myStorageQuotaProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('결제가 완료되어 구독 상태가 반영되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('결제 승인 자동 반영 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _prepareAndOpenCheckout(BillingPlan plan) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final repo = ref.read(billingRepositoryProvider);
      final prepared = await repo.preparePayment(
        planCode: plan.planCode,
        provider: plan.provider,
      );

      if (!mounted) return;
      setState(() {
        _prepared = prepared;
      });

      if (prepared.checkoutUrl.isNotEmpty) {
        final uri = Uri.tryParse(prepared.checkoutUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '결제창을 열었습니다. 결제 후 아래 "승인 완료 반영" 버튼을 눌러 상태를 반영하세요. 주문번호: ${prepared.orderId}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('결제 준비 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _approvePreparedOrder() async {
    final prepared = _prepared;
    if (prepared == null || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final repo = ref.read(billingRepositoryProvider);
      await repo.approveOrder(
        orderId: prepared.orderId,
        amount: prepared.amount,
      );

      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myStorageQuotaProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('구독 결제가 반영되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('승인 반영 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _cancelSubscription() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);

    try {
      final repo = ref.read(billingRepositoryProvider);
      await repo.cancelSubscription();

      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myStorageQuotaProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('구독이 취소되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('구독 취소 실패: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(mySubscriptionProvider);
    final plansAsync = ref.watch(billingPlansProvider);
    final quotaAsync = ref.watch(myStorageQuotaProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('구독 및 결제 관리'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        children: [
          _card(
            context,
            child: subscriptionAsync.when(
              loading: () => const _LoadingRow(text: '구독 상태 확인중...'),
              error: (e, _) => Text(
                '구독 상태 조회 실패: $e',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              data: (sub) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.isActive ? '현재 Pro 구독중' : '현재 Free 플랜',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w900,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '상태: ${sub.status} · 플랜: ${sub.planCode ?? '-'}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                    if (sub.nextBillingAt != null) ...[
                      SizedBox(height: 4.h),
                      Text(
                        '다음 결제일: ${_fmtDate(sub.nextBillingAt!)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: SnapFitColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 12.h),
          _card(
            context,
            child: quotaAsync.when(
              loading: () => const _LoadingRow(text: '저장 사용량 확인중...'),
              error: (e, _) => Text(
                '저장 사용량 조회 실패: $e',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              data: (quota) {
                final hard = quota.hardLimitBytes <= 0
                    ? 1
                    : quota.hardLimitBytes;
                final progress = (quota.usedBytes / hard).clamp(0.0, 1.0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '저장 용량',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '${_fmtBytes(quota.usedBytes)} / ${_fmtBytes(quota.hardLimitBytes)}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999.r),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8.h,
                        backgroundColor: const Color(0xFFE9ECEF),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF10BEE2),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'FREE 1GB · PRO 10GB (초과 시 저장 차단)',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: SnapFitColors.textMutedOf(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 12.h),
          _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '구독 상품',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: 8.h),
                plansAsync.when(
                  loading: () => const _LoadingRow(text: '상품 불러오는 중...'),
                  error: (e, _) => Text(
                    '상품 조회 실패: $e',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  data: (plans) {
                    if (plans.isEmpty) {
                      return Text(
                        '등록된 구독 상품이 없습니다.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: SnapFitColors.textSecondaryOf(context),
                        ),
                      );
                    }
                    return Column(
                      children: plans.map((plan) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8.h),
                          child: _planTile(context, plan),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_prepared != null) ...[
            SizedBox(height: 12.h),
            _card(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결제 진행 정보',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '주문번호: ${_prepared!.orderId}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '결제수단: ${_prepared!.provider} · ${_prepared!.amount}원',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isBusy ? null : _approvePreparedOrder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SnapFitColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: const Text('승인 완료 반영'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isBusy ? null : _cancelSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: const Text('구독 취소'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planTile(BuildContext context, BillingPlan plan) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${plan.amount}원 / ${plan.periodDays}일  ·  ${plan.provider}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          ElevatedButton(
            onPressed: _isBusy ? null : () => _prepareAndOpenCheckout(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: SnapFitColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: const Text('구독하기'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: child,
    );
  }

  String _fmtDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '${dt.year}.$m.$d';
  }

  String _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = 1024 * kb;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  int? _safeInt(String? raw) {
    if (raw == null) return null;
    return int.tryParse(raw);
  }
}

class _LoadingRow extends StatelessWidget {
  const _LoadingRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ],
    );
  }
}
