import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../data/print_order_request_repository.dart';
import '../../domain/order_visibility_owner.dart';
import '../../data/order_repository.dart';
import '../../data/print_payment_service.dart';
import '../../domain/print_order_request.dart';
import '../widgets/customer_web_page.dart';
import '../../../../shared/web/web_design.dart';
import 'support_inquiry_screen.dart';

Future<String?> openPrintOrderRequest(
  BuildContext context, {
  required String orderId,
  String? albumTitle,
  String initialType = 'GENERAL',
}) async {
  if (isPrintOrderRequestOrderId(orderId))
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PrintOrderRequestScreen(
          target: PrintOrderRequestTarget.order(orderId),
          albumTitle: albumTitle,
          initialType: initialType,
        ),
      ),
    );
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => SupportInquiryScreen(
        initialCategory: 'ORDER',
        initialSubject: '주문 $orderId 문의',
      ),
    ),
  );
  return null;
}

class PrintOrderRequestScreen extends ConsumerStatefulWidget {
  const PrintOrderRequestScreen({
    super.key,
    required this.target,
    this.albumTitle,
    this.initialType = 'GENERAL',
    this.initialReason,
    this.returnToAlbumEditing = false,
  });
  final PrintOrderRequestTarget target;
  final String? albumTitle;
  final String initialType;
  final String? initialReason;
  final bool returnToAlbumEditing;
  @override
  ConsumerState<PrintOrderRequestScreen> createState() =>
      _PrintOrderRequestScreenState();
}

class _PrintOrderRequestScreenState
    extends ConsumerState<PrintOrderRequestScreen>
    with WidgetsBindingObserver {
  final _reason = TextEditingController();
  late String _type = widget.initialType;
  String? _requestId, _attemptReason, _attemptType;
  PrintOrderRequestResult? _result;
  bool _loading = true, _sending = false, _attempted = false;
  bool _targetChecked = false;
  bool _readInFlight = false;
  Timer? _statusTimer;
  String? _error;
  String? _ownerId;
  bool get _ownerCurrent =>
      _ownerId != null && ref.read(visibleOrderOwnerProvider) == _ownerId;
  @override
  void initState() {
    super.initState();
    _reason.text = widget.initialReason ?? '';
    WidgetsBinding.instance.addObserver(this);
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted ||
          !_ownerCurrent ||
          ModalRoute.of(context)?.isCurrent == false ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive)
        return;
      if (_result?.status != 'COMPLETED' && (_attempted || _result != null)) {
        unawaited(_read());
      }
    });
    _read();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _reason.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_read());
  }

  Future<void> _read() async {
    if (_sending || _readInFlight || (_ownerId != null && !_ownerCurrent))
      return;
    _readInFlight = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(printOrderRequestRepositoryProvider);
      final result = await repository.status(
        target: _requestId == null ? widget.target : null,
        requestId: _requestId,
      );
      if (!mounted || !_ownerCurrent) return;
      if (!widget.target.matches(result))
        throw const FormatException('request_target_changed');
      setState(() {
        _result = result;
        _requestId = result.requestId;
        _targetChecked = true;
      });
    } on PrintOrderRequestException catch (error) {
      if (!mounted) return;
      if (error.statusCode == 404 &&
          const [
            'request_not_found',
            'print_order_request_not_found',
          ].contains(error.code)) {
        setState(() {
          _result = null;
          _attempted = false;
          _targetChecked = true;
        });
      } else {
        setState(() => _error = '요청 상태를 확인하지 못했어요. 같은 요청의 결과를 다시 확인해주세요.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = '요청 상태를 확인하지 못했어요. 다시 확인해주세요.');
    } finally {
      _readInFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_ownerCurrent ||
        _loading ||
        _sending ||
        _attempted ||
        _reason.text.trim().isEmpty)
      return;
    setState(() {
      _sending = true;
      _error = null;
      _attempted = true;
      if (_attemptReason == null) _requestId = const Uuid().v4();
      _attemptReason ??= _reason.text.trim();
      _attemptType ??= _type;
    });
    try {
      final result = await ref
          .read(printOrderRequestRepositoryProvider)
          .create(
            target: widget.target,
            requestId: _requestId!,
            type: _attemptType!,
            reason: _attemptReason!,
          );
      if (!mounted || !_ownerCurrent) return;
      if (!widget.target.matches(result) || result.requestId != _requestId)
        throw const FormatException('request_target_changed');
      setState(() => _result = result);
    } catch (_) {
      if (mounted)
        setState(
          () => _error = '요청 결과를 받지 못했어요. 새 요청을 보내기 전에 같은 요청의 결과를 확인해주세요.',
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _returnAfterResolution() async {
    if (!_ownerCurrent || _loading || _sending || _result?.canReplace != true)
      return;
    setState(() => _sending = true);
    try {
      final settled = await ref
          .read(printPaymentServiceProvider)
          .applyConfirmedReplacement(_result!.requestId);
      if (!mounted || !_ownerCurrent) return;
      if (!settled) {
        setState(() => _sending = false);
        await _read();
        if (!mounted) return;
        setState(
          () => _error = '기존 결제의 처리 결과를 다시 확인해주세요. 새로운 결제는 아직 진행하지 않습니다.',
        );
        return;
      }
      ref.invalidate(myOrderHistoryProvider);
      ref.invalidate(myOrderSummaryProvider);
      Navigator.pop(
        context,
        widget.returnToAlbumEditing && _result!.preSdkAbortVerified
            ? 'preparation_aborted'
            : 'request_resolved',
      );
    } catch (_) {
      if (mounted)
        setState(() => _error = '처리 결과를 다시 확인하지 못했어요. 준비 주문은 그대로 보관됩니다.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOwner = ref.watch(visibleOrderOwnerProvider);
    if (currentOwner != null && _ownerId == null) {
      _ownerId = currentOwner;
      if (!_targetChecked && !_readInFlight) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_read());
        });
      }
    }
    if (currentOwner == null || currentOwner != _ownerId) {
      if (kIsWeb) {
        return const CustomerWebPage(
          title: '주문 문의', eyebrow: 'ORDER SUPPORT',
          showNavigation: false,
          child: Center(child: Text(
            '로그인 계정을 확인해주세요. 계정이 변경됐다면 이 화면을 닫고 주문 문의를 다시 열어주세요.',
            textAlign: TextAlign.center,
          )),
        );
      }
      return Scaffold(
        appBar: const ExperienceHeader(title: '주문 문의', themeAware: true),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '로그인 계정을 확인해주세요. 계정이 변경됐다면 이 화면을 닫고 주문 문의를 다시 열어주세요.',
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final result = _result;
    final openFinancial = result?.unresolvedFinancial == true;
    final canAsk =
        _targetChecked &&
        !_loading &&
        !_sending &&
        !_attempted &&
        !openFinancial;
    if (kIsWeb) return _webRequest(result, canAsk: canAsk);
    return PopScope(
      canPop: !_sending,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: const ExperienceHeader(
          title: '주문 문의 · 취소 · 환불',
          themeAware: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.albumTitle?.isNotEmpty == true)
                      Text(
                        widget.albumTitle!,
                        style: ExperienceFormStyle.text(
                          context,
                          20,
                          weight: FontWeight.w600,
                        ),
                      ),
                    if (widget.target.orderId != null)
                      Text(
                        '주문 ${widget.target.orderId}',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '취소·환불은 요청을 접수한 뒤 결제와 제작사 상태를 확인합니다. 요청 접수만으로 주문 취소나 환불이 완료되지는 않습니다.',
                      style: ExperienceFormStyle.text(context, 14),
                    ),
                    const SizedBox(height: 16),
                    if (_loading || _sending) const LinearProgressIndicator(),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _error!,
                          style: ExperienceFormStyle.text(context, 14),
                        ),
                      ),
                    if (result != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        result.label,
                        key: const ValueKey('print-order-request-status'),
                        style: ExperienceFormStyle.text(
                          context,
                          18,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.message,
                        style: ExperienceFormStyle.text(context, 14),
                      ),
                      if (result.unresolvedFinancial)
                        Text(
                          '기존 주문을 유지하며 확인 중입니다. 결과가 확정되기 전에는 새 결제를 진행하지 않습니다.',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            secondary: true,
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      key: const ValueKey('print-order-request-refresh'),
                      onPressed: _loading || _sending ? null : _read,
                      icon: const Icon(Icons.refresh),
                      label: const Text('요청 상태 다시 확인'),
                    ),
                    if (result?.canReplace == true) ...[
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _sending || _loading
                            ? null
                            : _returnAfterResolution,
                        child: Text(
                          widget.returnToAlbumEditing &&
                                  result!.preSdkAbortVerified
                              ? '앨범 다시 편집하기'
                              : '확인하고 돌아가기',
                        ),
                      ),
                    ] else if (!openFinancial && !_attempted) ...[
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: _type,
                        decoration: ExperienceFormStyle.input(
                          context,
                          hint: '요청 유형',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'GENERAL',
                            child: Text('주문 문의'),
                          ),
                          DropdownMenuItem(
                            value: 'CANCEL',
                            child: Text('주문 취소 요청'),
                          ),
                          DropdownMenuItem(
                            value: 'REFUND',
                            child: Text('환불 요청'),
                          ),
                        ],
                        onChanged: canAsk && _attemptReason == null
                            ? (value) => setState(() => _type = value!)
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('print-order-request-reason'),
                        controller: _reason,
                        enabled: canAsk && _attemptReason == null,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 1000,
                        decoration: ExperienceFormStyle.input(
                          context,
                          hint: '요청 사유 또는 문의 내용을 입력해주세요.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const ValueKey('print-order-request-submit'),
                        onPressed: canAsk && _reason.text.trim().isNotEmpty
                            ? _submit
                            : null,
                        child: const Text('요청 접수하기'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _webRequest(PrintOrderRequestResult? result, {required bool canAsk}) {
    final openFinancial = result?.unresolvedFinancial == true;
    return PopScope(
      canPop: !_sending,
      child: CustomerWebPage(
        title: '주문 문의 · 취소 · 환불', eyebrow: 'ORDER SUPPORT',
        description: '요청 내용과 현재 처리 상태를 한곳에서 확인하세요.',
        showNavigation: false, allowBack: !_sending, scrollBody: true,
        sidebar: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          CustomerWebNote(
            title: '문의할 주문',
            message: [
              if (widget.albumTitle?.isNotEmpty == true) widget.albumTitle!,
              if (widget.target.orderId != null) '주문 ${widget.target.orderId}',
              if (widget.target.orderId == null) '앨범 주문 준비 건',
            ].join('\n\n'),
          ),
          const SizedBox(height: 20),
          const CustomerWebNote(title: '처리 안내',
            message: '취소·환불은 요청 접수 후 결제와 제작 상태를 확인하여 처리합니다. 요청 접수만으로 주문 취소나 환불이 완료되지는 않습니다.'),
        ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('요청 상태', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          if (_loading || _sending) ...[
            const LinearProgressIndicator(), const SizedBox(height: 20),
          ],
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: WebPalette.of(context).ink, height: 1.7)),
            const SizedBox(height: 20),
          ],
          if (result != null) ...[
            Text(result.label, key: const ValueKey('print-order-request-status'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600,
                color: WebPalette.of(context).brandInk)),
            const SizedBox(height: 12),
            Text(result.message, style: TextStyle(height: 1.8, color: WebPalette.of(context).muted)),
            if (openFinancial) ...[
              const SizedBox(height: 12),
              Text('기존 주문을 유지하며 확인 중입니다. 결과가 확정되기 전에는 새 결제를 진행하지 않습니다.',
                style: TextStyle(height: 1.8, color: WebPalette.of(context).muted)),
            ],
            const SizedBox(height: 24),
          ],
          Align(alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('print-order-request-refresh'),
              onPressed: _loading || _sending ? null : _read,
              icon: const Icon(Icons.refresh, size: 18), label: const Text('요청 상태 다시 확인'),
            )),
          if (result?.canReplace == true) ...[
            const SizedBox(height: 24),
            Align(alignment: Alignment.centerLeft, child: FilledButton(
              onPressed: _sending || _loading ? null : _returnAfterResolution,
              child: Text(widget.returnToAlbumEditing && result!.preSdkAbortVerified
                ? '앨범 다시 편집하기' : '확인하고 돌아가기'),
            )),
          ] else if (!openFinancial && !_attempted) ...[
            const SizedBox(height: 32), const Divider(height: 1),
            const SizedBox(height: 32),
            Text('요청 작성', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _type, isExpanded: true,
              decoration: const InputDecoration(labelText: '요청 유형'),
              items: const [
                DropdownMenuItem(value: 'GENERAL', child: Text('주문 문의')),
                DropdownMenuItem(value: 'CANCEL', child: Text('주문 취소 요청')),
                DropdownMenuItem(value: 'REFUND', child: Text('환불 요청')),
              ],
              onChanged: canAsk && _attemptReason == null
                ? (value) { if (value != null) setState(() => _type = value); } : null,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const ValueKey('print-order-request-reason'), controller: _reason,
              enabled: canAsk && _attemptReason == null,
              minLines: 5, maxLines: 10, maxLength: 1000,
              decoration: const InputDecoration(labelText: '요청 사유 또는 문의 내용',
                alignLabelWithHint: true, hintText: '확인이 필요한 내용을 자세히 알려주세요.'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Align(alignment: Alignment.centerLeft, child: FilledButton(
              key: const ValueKey('print-order-request-submit'),
              onPressed: canAsk && _reason.text.trim().isNotEmpty ? _submit : null,
              child: const Text('요청 접수하기'),
            )),
          ],
        ]),
      ),
    );
  }
}
