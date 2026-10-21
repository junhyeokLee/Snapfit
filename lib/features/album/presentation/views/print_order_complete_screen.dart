import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/presentation/widgets/customer_web_page.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/domain/print_checkout.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../profile/presentation/views/print_order_request_screen.dart';

/// Print and shipment milestones are distinct facts from the owned order.
class PrintOrderCompleteScreen extends ConsumerStatefulWidget {
  const PrintOrderCompleteScreen({super.key, required this.receipt});
  final PrintPaidReceipt receipt;
  @override
  ConsumerState<PrintOrderCompleteScreen> createState() =>
      _PrintOrderCompleteScreenState();
}

class _PrintOrderCompleteScreenState
    extends ConsumerState<PrintOrderCompleteScreen> {
  PrintOrderProgress? _progress;
  String? _error;
  bool _loading = false;
  Timer? _poll;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading || !mounted) return;
    setState(() => _loading = true);
    try {
      final progress = await ref
          .read(orderRepositoryProvider)
          .fetchMyPrintOrderProgress(widget.receipt.orderId);
      if (progress.orderId != widget.receipt.orderId) {
        throw StateError('order_receipt_mismatch');
      }
      if (mounted)
        setState(() {
          _progress = progress;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(
          () =>
              _error = '진행 상황을 불러오지 못했어요. 결제 영수증은 확인됐으며 주문 내역에서 다시 확인할 수 있어요.',
        );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (!{
          'DELIVERED',
          'CANCELED',
          'CANCELLED',
        }.contains(_progress?.customerStage)) {
          _poll?.cancel();
          _poll = Timer(const Duration(seconds: 20), _refresh);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: kIsWeb
          ? _webProgress()
          : Scaffold(
              backgroundColor: SnapFitColors.backgroundOf(context),
              appBar: ExperienceHeader(
                title: '주문 진행 상황',
                back: false,
                showNotifications: false,
                actions: [
                  IconButton(
                    onPressed: _loading ? null : _refresh,
                    tooltip: '진행 상황 새로고침',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              body: SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final wide =
                        bounds.maxWidth >= 540 &&
                        MediaQuery.orientationOf(context) ==
                            Orientation.landscape;
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: wide ? 1040 : 560,
                        ),
                        child: wide
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  16,
                                  20,
                                  16,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          SizedBox(
                                            width: (bounds.maxWidth * .38)
                                                .clamp(200, 340),
                                            child: SingleChildScrollView(
                                              key: const PageStorageKey(
                                                'print-receipt-summary',
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _confirmation(compact: true),
                                                  const SizedBox(height: 8),
                                                  _receiptDetails(
                                                    compact: true,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          VerticalDivider(
                                            width: 1,
                                            color: ExperienceFormStyle.line(
                                              context,
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          Expanded(
                                            child: ListView(
                                              key: const PageStorageKey(
                                                'print-progress-content',
                                              ),
                                              children: [_progressDetails()],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _actions(wide: true),
                                  ],
                                ),
                              )
                            : ListView(
                                key: const PageStorageKey(
                                  'print-progress-content',
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  28,
                                ),
                                children: [
                                  _confirmation(),
                                  const SizedBox(height: 24),
                                  _progressDetails(),
                                  const SizedBox(height: 24),
                                  Divider(
                                    color: ExperienceFormStyle.line(context),
                                  ),
                                  const SizedBox(height: 16),
                                  _receiptDetails(),
                                  const SizedBox(height: 24),
                                  _actions(),
                                ],
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _webProgress() => SnapFitWebShell(
    title: '주문 진행 상황',
    section: WebSection.orders,
    showNavigation: false,
    actions: [
      IconButton(
        onPressed: _loading ? null : _refresh,
        tooltip: '진행 상황 새로고침',
        icon: const Icon(Icons.refresh, size: 20),
      ),
    ],
    child: ListView(
      key: const PageStorageKey('print-progress-content'),
      children: [
        const WebPageHeading(
          title: '주문 진행 상황',
          description: '결제 확인부터 제작·배송까지 같은 주문내역에서 확인할 수 있습니다.',
        ),
        const SizedBox(height: 24),
        CustomerWebColumns(
          breakpoint: 980,
          summaryWidth: 350,
          primary: WebSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _confirmation(),
                const SizedBox(height: 24),
                Divider(color: WebPalette.of(context).line),
                const SizedBox(height: 24),
                _progressDetails(),
              ],
            ),
          ),
          secondary: WebSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '주문 정보',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: WebPalette.of(context).ink,
                  ),
                ),
                const SizedBox(height: 20),
                _receiptDetails(),
                const SizedBox(height: 24),
                Divider(color: WebPalette.of(context).line),
                const SizedBox(height: 24),
                _actions(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    ),
  );

  Widget _confirmation({bool compact = false}) {
    final canceled = {
      'CANCELED',
      'CANCELLED',
    }.contains(_progress?.customerStage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Icon(
            canceled ? Icons.cancel_outlined : Icons.check_circle_outline,
            size: 36,
            color: ExperienceFormStyle.selectionInk(context),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (compact) ...[
              Icon(
                canceled ? Icons.cancel_outlined : Icons.check_circle_outline,
                size: 20,
                color: ExperienceFormStyle.selectionInk(context),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                compact
                    ? canceled
                          ? '주문 취소'
                          : '결제 확인 완료'
                    : canceled
                    ? '주문이 취소됐어요'
                    : '결제가 확인됐어요',
                style: ExperienceFormStyle.text(
                  context,
                  compact ? 16 : 24,
                  weight: compact ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 8),
          Text(
            canceled
                ? '취소·환불 내역은 주문 내역에서 확인할 수 있어요.'
                : kIsWeb
                ? '창을 닫아도 제작사 주문 접수가 이어집니다. 제작과 배송 상황은 주문 내역에서 확인할 수 있어요.'
                : '앱을 닫아도 제작사 주문 접수가 이어집니다. 제작과 배송 상황은 주문 내역에서 확인할 수 있어요.',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        ],
      ],
    );
  }

  Widget _progressDetails() {
    final progress = _progress;
    final shipped =
        progress?.shippedAt != null &&
        (progress?.trackingNumber?.isNotEmpty ?? false) &&
        (progress?.courier?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          progress?.label ?? '진행 상황 확인 중',
          style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w600),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: LinearProgressIndicator(),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: ExperienceFormStyle.text(context, 13)),
          ),
        const SizedBox(height: 12),
        _stage('결제 확인', true, first: true),
        _stage('인쇄 파일 생성', progress?.filesReadyAt != null),
        _stage('인쇄 규격 검사', progress?.preflightPassed == true),
        _stage('제작사 주문 접수', progress?.vendorAcceptedAt != null),
        _stage('제작사 파일 확인', progress?.fileCheckedAt != null),
        _stage('책 제작', progress?.productionStartedAt != null),
        _stage('택배 출고', shipped),
        _stage('배송 완료', progress?.customerStage == 'DELIVERED', last: true),
        if (progress?.requiresAction == true)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '제작 준비 중 확인이 필요한 부분이 있어 담당자가 확인하고 있습니다. 진행 상황은 주문 내역에서 안내합니다.',
              style: ExperienceFormStyle.text(context, 14),
            ),
          ),
        if (shipped)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '${progress?.courier} · ${progress?.trackingNumber}',
              style: ExperienceFormStyle.text(context, 14),
            ),
          ),
      ],
    );
  }

  Widget _receiptDetails({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.receipt.title,
        style: ExperienceFormStyle.text(
          context,
          compact ? 14 : 18,
          weight: compact ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '결제금액 ${_won(widget.receipt.amount)}원',
        style: ExperienceFormStyle.text(context, 16),
      ),
      const SizedBox(height: 12),
      Text(
        '주문번호',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      SelectableText(
        widget.receipt.orderId,
        style: ExperienceFormStyle.text(context, 13),
      ),
    ],
  );

  Widget _actions({bool wide = false}) {
    final orderHistory = FilledButton(
      style: ExperienceFormStyle.primary(context),
      onPressed: () => Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OrderHistoryScreen(initialOrderId: widget.receipt.orderId),
        ),
      ),
      child: const Text('주문 내역 확인하기'),
    );
    final albums = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        textStyle: ExperienceFormStyle.text(context, 14),
        shape: const StadiumBorder(),
      ),
      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
      child: const Text('내 앨범으로 돌아가기'),
    );
    final navigation = wide
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: orderHistory),
                const SizedBox(width: 12),
                Expanded(child: albums),
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [orderHistory, const SizedBox(height: 8), albums],
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        navigation,
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await openPrintOrderRequest(
              context,
              orderId: widget.receipt.orderId,
              albumTitle: widget.receipt.title,
              albumId: widget.receipt.albumId,
            );
            if (mounted) _refresh();
          },
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('주문 문의 · 취소 · 환불 요청'),
        ),
      ],
    );
  }

  Widget _stage(
    String label,
    bool confirmed, {
    bool first = false,
    bool last = false,
  }) => SizedBox(
    key: ValueKey('print-progress-$label'),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 11.5,
                  top: first ? 24 : 0,
                  bottom: last ? 24 : 0,
                  child: Container(
                    width: 1,
                    color: ExperienceFormStyle.line(context),
                  ),
                ),
                ColoredBox(
                  color: kIsWeb
                      ? WebPalette.of(context).surface
                      : SnapFitColors.backgroundOf(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Icon(
                      confirmed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: confirmed
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.muted(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(label, style: ExperienceFormStyle.text(context, 14)),
            ),
          ),
          const SizedBox(width: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              confirmed ? '확인 완료' : '대기',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ),
        ],
      ),
    ),
  );
}

String _won(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (m) => '${m[1]},',
);
