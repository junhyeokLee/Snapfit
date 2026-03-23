import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../data/billing_provider.dart';
import '../../domain/entities/billing_plan.dart';
import '../../domain/entities/payment_prepare_result.dart';
import '../../domain/entities/subscription_status.dart';

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

  String _provider = 'TOSS_NAVERPAY';
  bool _isProcessing = false;
  bool _waitingCallback = false;
  PaymentPrepareResult? _latestPrepared;

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

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(billingPlansProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        title: Text(
          '구독 및 결제 관리',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        children: [
          _heroCard(context, subscriptionAsync),
          const SizedBox(height: 12),
          _paymentMethodCard(context),
          const SizedBox(height: 12),
          _planCard(context, plansAsync),
        ],
      ),
    );
  }

  Widget _heroCard(
    BuildContext context,
    AsyncValue<SubscriptionStatusModel> subscriptionAsync,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2027), Color(0xFF123D49)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: subscriptionAsync.when(
        loading: () => const SizedBox(
          height: 72,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        error: (e, _) => const Text(
          '구독 상태를 가져오지 못했습니다.',
          style: TextStyle(color: Colors.white),
        ),
        data: (sub) {
          final active = sub.isActive;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF23D1A0)
                          : Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      active ? 'ACTIVE' : 'INACTIVE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_waitingCallback)
                    const Text(
                      '결제 승인 대기중...',
                      style: TextStyle(
                        color: Color(0xFFC7E8F1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                active ? 'SnapFit Pro 구독 중' : '구독이 필요합니다',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '플랜: ${sub.planCode ?? '-'}\n만료일: ${_fmt(sub.expiresAt)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.86),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _startSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF09B8DF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('구독하기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _cancelSubscriptionWithConfirm(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.45)),
                      ),
                      child: const Text('구독취소'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _paymentMethodCard(BuildContext context) {
    return _cardShell(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, '결제 수단'),
          const SizedBox(height: 10),
          _paymentOptionTile(
            context,
            provider: 'TOSS_NAVERPAY',
            title: '토스페이먼츠',
            subtitle: '토스 결제창에서 카드/간편결제 선택',
            badge: '권장',
          ),
          const SizedBox(height: 8),
          _paymentOptionTile(
            context,
            provider: 'INICIS_NAVERPAY',
            title: 'KG이니시스',
            subtitle: '이니시스 결제창에서 카드/간편결제 선택',
            badge: '보조',
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SnapFitColors.overlayLightOf(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '네이버페이는 PG 결제창 내부에서 결제수단으로 선택됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: SnapFitColors.textSecondaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentOptionTile(
    BuildContext context, {
    required String provider,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final selected = _provider == provider;
    return InkWell(
      onTap: () => setState(() => _provider = provider),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFDDF6FC)
              : SnapFitColors.backgroundOf(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF08B8DF)
                : SnapFitColors.overlayLightOf(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0A2027),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                provider == 'TOSS_NAVERPAY' ? 'T' : 'K',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF08B8DF)
                    : SnapFitColors.overlayLightOf(context),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : SnapFitColors.textMutedOf(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(
    BuildContext context,
    AsyncValue<List<BillingPlan>> plansAsync,
  ) {
    return _cardShell(
      context,
      child: plansAsync.when(
        loading: () => const SizedBox(
          height: 68,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          '플랜 정보를 불러오지 못했습니다.',
          style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return Text(
              '플랜이 없습니다.',
              style: TextStyle(color: SnapFitColors.textSecondaryOf(context)),
            );
          }
          final plan = plans.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(context, '요금제'),
              const SizedBox(height: 8),
              Text(
                plan.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_comma(plan.amount)}원 / ${plan.periodDays}일 · ${plan.currency}',
                style: TextStyle(
                  fontSize: 12,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
              if (_latestPrepared != null) ...[
                const SizedBox(height: 8),
                Text(
                  '최근 결제 시도: ${_latestPrepared!.orderId}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _cardShell(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: SnapFitColors.textPrimaryOf(context),
      ),
    );
  }

  Future<void> _startSubscribe() async {
    setState(() {
      _isProcessing = true;
      _waitingCallback = false;
    });

    try {
      final repository = ref.read(billingRepositoryProvider);
      final prepared = await repository.preparePayment(provider: _provider);
      _latestPrepared = prepared;

      final uri = Uri.tryParse(prepared.checkoutUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      if (prepared.isMock) {
        await repository.approveOrder(
          orderId: prepared.orderId,
          amount: prepared.amount,
          paymentKey: 'MOCK-PAY-${prepared.orderId}',
          transactionId: 'MOCK-TX-${DateTime.now().millisecondsSinceEpoch}',
        );
        _waitingCallback = false;
      } else {
        _waitingCallback = true;
      }

      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myStorageQuotaProvider);
      _show(prepared.isMock ? '구독 결제가 완료되었습니다.' : '결제 완료 후 앱으로 자동 복귀합니다.');
    } catch (e) {
      _show('구독 결제 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _cancelSubscriptionWithConfirm(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      title: '구독을 취소할까요?',
      body: '현재 구독이 즉시 비활성화되고, 프리미엄 템플릿 사용이 제한됩니다.',
      confirmText: '취소하기',
    );
    if (!ok) return;

    setState(() => _isProcessing = true);
    try {
      await ref.read(billingRepositoryProvider).cancelSubscription();
      ref.invalidate(mySubscriptionProvider);
      ref.invalidate(myStorageQuotaProvider);
      _show('구독이 취소되었습니다.');
    } catch (e) {
      _show('구독 취소 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _initBillingDeepLinkListener() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        await _handleBillingDeepLink(initial);
      }
    } catch (_) {}

    _linkSub = _appLinks.uriLinkStream.listen((uri) async {
      await _handleBillingDeepLink(uri);
    });
  }

  Future<void> _handleBillingDeepLink(Uri uri) async {
    if (uri.scheme != 'snapfit') return;
    if (uri.host != 'billing') return;

    final path = uri.path.toLowerCase();
    final orderId = uri.queryParameters['orderId'];
    if (orderId == null || orderId.isEmpty) return;

    if (path.contains('success')) {
      if (_handledOrderIds.contains(orderId)) return;
      _handledOrderIds.add(orderId);

      final paymentKey = uri.queryParameters['paymentKey'];
      final amountRaw = uri.queryParameters['amount'];
      final amount = amountRaw == null ? null : int.tryParse(amountRaw);

      setState(() {
        _isProcessing = true;
        _waitingCallback = false;
      });

      try {
        await ref
            .read(billingRepositoryProvider)
            .approveOrder(
              orderId: orderId,
              paymentKey: paymentKey,
              amount: amount,
              transactionId: paymentKey,
            );
        ref.invalidate(mySubscriptionProvider);
        ref.invalidate(myStorageQuotaProvider);
        _show('결제가 승인되어 구독이 활성화되었습니다.');
      } catch (e) {
        _show('결제 승인 처리 실패: $e');
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
      return;
    }

    if (path.contains('fail')) {
      setState(() => _waitingCallback = false);
      final message = uri.queryParameters['message'] ?? '결제에 실패했습니다.';
      _show(message);
    }
  }

  Future<bool> _confirmDialog(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmText,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD64B4B),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(confirmText),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  String _fmt(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _comma(int value) {
    final s = value.toString();
    return s.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
