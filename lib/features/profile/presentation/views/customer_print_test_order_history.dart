import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../data/customer_print_test_checkout.dart';
import '../../data/print_dev_checkout.dart';
import '../../domain/order_visibility_owner.dart';

/// A successful owner-scoped server read grants visibility to the separate TEST
/// history. These records never enter the production order or receipt models.
final customerPrintTestHistoryProvider =
    FutureProvider.autoDispose<List<CustomerPrintTestOrder>>((ref) async {
      final owner = ref.watch(visibleOrderOwnerProvider);
      if (owner == null || !ref.watch(printDevAdminAccessProvider)) {
        throw const PrintDevCheckoutException('admin_required');
      }
      final orders = await ref
          .watch(customerPrintTestCheckoutServiceProvider)
          .history();
      if (ref.read(visibleOrderOwnerProvider) != owner) {
        throw const PrintDevCheckoutException('owner_changed');
      }
      return orders;
    });

class CustomerPrintTestOrderHistory extends ConsumerStatefulWidget {
  const CustomerPrintTestOrderHistory({
    super.key,
    required this.ownerId,
    this.initialRunId,
  });

  final String ownerId;
  final String? initialRunId;

  @override
  ConsumerState<CustomerPrintTestOrderHistory> createState() =>
      _CustomerPrintTestOrderHistoryState();
}

class _CustomerPrintTestOrderHistoryState
    extends ConsumerState<CustomerPrintTestOrderHistory>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _openedInitial = false;
  bool get _ownerCurrent =>
      ref.read(visibleOrderOwnerProvider) == widget.ownerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          _ownerCurrent &&
          ModalRoute.of(context)?.isCurrent != false &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.inactive) {
        _refresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refresh() {
    if (mounted && _ownerCurrent) {
      ref.invalidate(customerPrintTestHistoryProvider);
    }
  }

  void _openDetail(String runId) {
    if (!mounted || !_ownerCurrent) return;
    if (kIsWeb) {
      unawaited(showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: WebPalette.of(dialogContext).surface,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 860,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .88),
            child: _CustomerPrintTestDetail(ownerId: widget.ownerId, runId: runId),
          ),
        ),
      ).then((_) => _refresh()));
      return;
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: SnapFitColors.backgroundOf(context),
        constraints: const BoxConstraints(maxWidth: 760),
        builder: (_) =>
            _CustomerPrintTestDetail(ownerId: widget.ownerId, runId: runId),
      ).then((_) => _refresh()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(visibleOrderOwnerProvider) != widget.ownerId ||
        !ref.watch(printDevAdminAccessProvider)) {
      return const Center(child: Text('로그인 계정을 다시 확인해주세요.'));
    }
    final orders = ref.watch(customerPrintTestHistoryProvider);
    return Column(
      key: const ValueKey('customer-test-order-history'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'TEST 주문 · 실제 청구·제작·배송 없음',
                  style: ExperienceFormStyle.text(context, 14),
                ),
              ),
              IconButton(
                key: const ValueKey('customer-test-history-refresh'),
                tooltip: 'TEST 주문 새로고침',
                onPressed: orders.isLoading ? null : _refresh,
                icon: const Icon(Icons.refresh, size: 21),
              ),
            ],
          ),
        ),
        Expanded(
          child: orders.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'TEST 주문을 확인하지 못했어요. 새 결제를 만들지 말고 다시 확인해주세요.',
                  style: ExperienceFormStyle.text(context, 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (items) {
              final initial = widget.initialRunId?.trim() ?? '';
              if (!_openedInitial && initial.isNotEmpty) {
                _openedInitial = true;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _openDetail(initial),
                );
              }
              if (items.isEmpty) {
                return const Center(child: Text('아직 TEST 주문이 없어요.'));
              }
              return ListView.separated(
                key: const PageStorageKey('customer-test-order-list'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: ExperienceFormStyle.line(context),
                ),
                itemBuilder: (context, index) {
                  final order = items[index];
                  if (kIsWeb && MediaQuery.sizeOf(context).width >= 980) {
                    return InkWell(
                      key: ValueKey('customer-test-order-${order.session.runId}'),
                      onTap: () => _openDetail(order.session.runId),
                      hoverColor: WebPalette.of(context).background,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
                        child: Row(children: [
                          Expanded(flex: 3, child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(order.albumTitle, style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
                              const SizedBox(height: 7),
                              Text('TEST · ${order.session.runId}', maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: WebPalette.of(context).muted)),
                            ])),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: Text('300×300mm 하드커버\n80페이지 · 1권',
                            style: TextStyle(fontSize: 12, height: 1.7, color: WebPalette.of(context).muted))),
                          SizedBox(width: 120, child: Text(_date(order.createdAt),
                            style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted))),
                          SizedBox(width: 140, child: Text('${_amount(order.session.totalAmount)}원',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                              color: WebPalette.of(context).ink))),
                          SizedBox(width: 160, child: Text(_stage(order.session),
                            style: TextStyle(fontSize: 12, height: 1.6, color: WebPalette.of(context).brandInk))),
                          Icon(Icons.chevron_right, size: 18, color: WebPalette.of(context).muted),
                        ]),
                      ),
                    );
                  }
                  return ListTile(
                    key: ValueKey('customer-test-order-${order.session.runId}'),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    title: Text(order.albumTitle),
                    subtitle: Text(
                      '${_date(order.createdAt)} · 300×300mm 하드커버 · 80쪽\n'
                      'TEST ${_amount(order.session.totalAmount)}원\n'
                      '${_stage(order.session)}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(order.session.runId),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CustomerPrintTestDetail extends ConsumerStatefulWidget {
  const _CustomerPrintTestDetail({required this.ownerId, required this.runId});
  final String ownerId;
  final String runId;

  @override
  ConsumerState<_CustomerPrintTestDetail> createState() =>
      _CustomerPrintTestDetailState();
}

class _CustomerPrintTestDetailState
    extends ConsumerState<_CustomerPrintTestDetail>
    with WidgetsBindingObserver {
  CustomerPrintTestOrder? _order;
  bool _loading = false;
  String? _error;
  Timer? _timer;
  bool get _ownerCurrent =>
      ref.read(visibleOrderOwnerProvider) == widget.ownerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          _ownerCurrent &&
          _order?.session.stage != 'FILE_CHECKED' &&
          ModalRoute.of(context)?.isCurrent != false &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.inactive) {
        unawaited(_refresh());
      }
    });
    Future.microtask(_refresh);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || _loading || !_ownerCurrent) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await ref
          .read(customerPrintTestCheckoutServiceProvider)
          .detail(widget.runId);
      if (!mounted || !_ownerCurrent) return;
      if (latest.session.runId != widget.runId) {
        throw const FormatException('customer_print_test_identity_changed');
      }
      if (_order != null) latest.session.match(_order!.session);
      setState(() => _order = latest);
    } catch (error) {
      if (!mounted || !_ownerCurrent) return;
      setState(() {
        if (error is PrintDevCheckoutException &&
            const {
              'admin_required',
              'authentication_required',
              'invalid_session',
              'forbidden',
              'owner_changed',
              'print_dev_checkout_not_found',
            }.contains(error.code)) {
          _order = null;
        }
        _error = '현재 TEST 주문 상태를 읽지 못했어요. 기존 결제와 주문은 그대로 보존됩니다.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(visibleOrderOwnerProvider) != widget.ownerId ||
        !ref.watch(printDevAdminAccessProvider)) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('로그인 계정이 변경되었어요. 주문 내역을 다시 열어주세요.'),
        ),
      );
    }
    final order = _order;
    final session = order?.session;
    final accepted =
        session?.verifiedTest == true &&
        const {'ACCEPTED', 'FILE_CHECKED'}.contains(session?.stage);
    final checked =
        session?.verifiedTest == true && session?.stage == 'FILE_CHECKED';
    final recipient = order?.recipient ?? const <String, dynamic>{};
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          key: const ValueKey('customer-test-order-detail'),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('TEST 주문 상세')),
                  IconButton(
                    key: const ValueKey('customer-test-detail-refresh'),
                    tooltip: 'TEST 주문 상태 새로고침',
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                children: [
                  Text(
                    '실제 카드 청구·책 제작·배송은 진행하지 않습니다.',
                    style: ExperienceFormStyle.text(context, 14),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const ValueKey('customer-test-detail-error'),
                      style: ExperienceFormStyle.text(context, 14),
                    ),
                  ],
                  if (order != null && session != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      order.albumTitle,
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${_date(order.createdAt)} · 하드커버 300×300mm · 80쪽 · 1권',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'TEST ${_amount(session.totalAmount)}원',
                      style: ExperienceFormStyle.text(context, 18),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _stage(session),
                      style: ExperienceFormStyle.text(
                        context,
                        17,
                        weight: FontWeight.w600,
                        color: ExperienceFormStyle.selectionInk(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _step('인쇄 파일 준비', session.filesReady),
                    _step('TEST 결제 확인', session.verifiedTest),
                    _step('업체 개발 접수', accepted),
                    _step('업체 파일 확인', checked),
                    const SizedBox(height: 12),
                    const Text(
                      '결제를 승인한 뒤에는 앱을 닫아도 서버가 결제 결과를 확인하고 개발 주문을 이어갑니다. 이 화면은 저장된 상태만 조회합니다.',
                    ),
                    if (checked && _advisory(session)) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '업체 파일 분석은 완료됐으며 검사 주의 표시가 있습니다. 실제 제작 승인이나 배송 완료를 뜻하지 않습니다.',
                      ),
                    ],
                    if (recipient.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'TEST 배송 정보',
                        style: ExperienceFormStyle.text(
                          context,
                          15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text('${recipient['name'] ?? ''}'),
                      Text('${recipient['phone'] ?? ''}'),
                      Text(
                        '[${recipient['zipCode'] ?? ''}] '
                        '${recipient['addressLine1'] ?? ''} '
                        '${recipient['addressLine2'] ?? ''}',
                      ),
                      if ('${recipient['deliveryMemo'] ?? ''}'.isNotEmpty)
                        Text('${recipient['deliveryMemo']}'),
                    ],
                    const SizedBox(height: 24),
                    SelectableText('TEST 주문번호: ${session.orderId}'),
                    SelectableText('TEST 결제번호: ${session.paymentId}'),
                    if (session.devOrderNum != null)
                      SelectableText('업체 개발 주문번호: ${session.devOrderNum}'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String label, bool complete) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Icon(
          complete ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 20,
          color: complete ? ExperienceFormStyle.selectionInk(context) : null,
        ),
        const SizedBox(width: 10),
        Text('$label · ${complete ? '완료' : '대기'}'),
      ],
    ),
  );
}

String _stage(PrintDevCheckoutSession session) {
  if (session.stage == 'FAILED') return 'TEST 주문 확인 필요';
  if (!session.verifiedTest) {
    if (session.data['sdkIssuedAt'] != null) return 'TEST 결제 확인 중';
    return session.filesReady ? 'TEST 결제 전' : '인쇄 파일 준비 중';
  }
  return switch (session.stage) {
    'FILE_CHECKED' => '업체 파일 확인 완료',
    'ACCEPTED' => '업체 파일 확인 중',
    'SUBMITTING' || 'UNKNOWN' => '업체 접수 확인 중',
    _ => 'TEST 결제 확인 완료 · 자동 발주 대기',
  };
}

bool _advisory(PrintDevCheckoutSession session) {
  final status = session.data['vendorStatus'];
  return status is Map && status['statusCodeOrg'] == 'PGS_05';
}

String _date(DateTime date) {
  final local = date.toLocal();
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _amount(int amount) => amount.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);
