import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../data/print_order_request_repository.dart';
import '../../domain/order_visibility_owner.dart';
import '../../data/order_repository.dart';
import '../../data/print_payment_service.dart';
import '../../domain/print_order_request.dart';
import '../widgets/customer_web_page.dart';
import '../widgets/order_request_workspace.dart';
import '../widgets/inquiry_exit_guard.dart';
import '../../../../shared/web/web_design.dart';
import 'support_inquiry_screen.dart';

Future<String?> openPrintOrderRequest(
  BuildContext context, {
  required String orderId,
  int? albumId,
  String? albumTitle,
  String initialType = 'GENERAL',
}) async {
  if (isPrintOrderRequestOrderId(orderId))
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PrintOrderRequestScreen(
          target: PrintOrderRequestTarget.order(orderId),
          albumId: albumId,
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
    this.albumId,
    this.albumTitle,
    this.initialType = 'GENERAL',
    this.initialReason,
    this.returnToAlbumEditing = false,
  });
  final PrintOrderRequestTarget target;
  final int? albumId;
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
  final _contentScroll = ScrollController();
  final _exitGuardKey = GlobalKey<InquiryExitGuardState>();
  late final _initialReason = widget.initialReason ?? '';
  late final _initialType = widget.initialType;
  late String _type = _initialType;
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
  bool get _hasDraftChanges =>
      _ownerCurrent &&
      _attemptReason == null &&
      !_attempted &&
      (_reason.text != _initialReason || _type != _initialType);

  void _close() {
    _exitGuardKey.currentState?.requestClose();
  }

  @override
  void initState() {
    super.initState();
    _reason.text = _initialReason;
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
    _contentScroll.dispose();
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
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent == false ||
        !_ownerCurrent ||
        _loading ||
        _sending ||
        _attempted ||
        _reason.text.trim().isEmpty)
      return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _sending = true;
      _error = null;
      _attempted = true;
      _result = null;
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
    if (mounted && _contentScroll.hasClients) {
      unawaited(
        _contentScroll.animateTo(
          0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
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
          title: '주문 문의',
          eyebrow: 'ORDER SUPPORT',
          showNavigation: false,
          child: Center(
            child: Text(
              '로그인 계정을 확인해주세요. 계정이 변경됐다면 이 화면을 닫고 주문 문의를 다시 열어주세요.',
              textAlign: TextAlign.center,
            ),
          ),
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
    return InquiryExitGuard(
      key: _exitGuardKey,
      edits: _reason,
      hasUnsavedChanges: () => _hasDraftChanges,
      busy: _sending,
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: ExperienceHeader(
          title: '주문 문의',
          onBack: _close,
          showNotifications: false,
          actions: [
            IconButton(
              key: const ValueKey('print-order-request-refresh'),
              tooltip: '요청 상태 다시 확인',
              onPressed: _loading || _sending ? null : _read,
              icon: const ExperienceIcon('RefreshCw'),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: OrderRequestWorkspace(
            albumId: widget.albumId,
            albumTitle: widget.albumTitle,
            orderId: widget.target.orderId,
            controller: _contentScroll,
            child: _nativeRequest(result, canAsk: canAsk),
          ),
        ),
      ),
    );
  }

  Widget _nativeRequest(
    PrintOrderRequestResult? result, {
    required bool canAsk,
  }) {
    final openFinancial = result?.unresolvedFinancial == true;
    final waitingForResult = _attempted && result == null;
    final compactInput =
        MediaQuery.orientationOf(context) == Orientation.landscape &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading || _sending) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
        ],
        if (result != null || waitingForResult) ...[
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _typeLabel(result?.type ?? _attemptType ?? _type),
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
                const SizedBox(height: 8),
                Text(
                  result?.label ?? '접수 결과 확인 중',
                  key: const ValueKey('print-order-request-status'),
                  style: ExperienceFormStyle.text(
                    context,
                    20,
                    weight: FontWeight.w600,
                  ),
                ),
                if (result != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    result.message,
                    style: ExperienceFormStyle.text(context, 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '접수 ${_timestamp(result.createdAt)}\n최근 변경 ${_timestamp(result.updatedAt)}',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (openFinancial) ...[
            const SizedBox(height: 12),
            Text(
              '기존 주문을 유지하며 확인 중입니다. 결과가 확정되기 전에는 새 결제를 진행하지 않습니다.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(_error!, style: ExperienceFormStyle.text(context, 14)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading || _sending ? null : _read,
              icon: const ExperienceIcon('RefreshCw', size: 18),
              label: const Text('요청 상태 다시 확인'),
            ),
          ),
        ],
        if (_attemptReason != null && (_attempted || result != null)) ...[
          const SizedBox(height: 24),
          Divider(height: 1, color: ExperienceFormStyle.line(context)),
          const SizedBox(height: 20),
          Text(
            '보낸 내용',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            _attemptReason!,
            key: const ValueKey('print-order-request-submitted-reason'),
            style: ExperienceFormStyle.text(context, 14),
          ),
        ],
        if (result?.canReplace == true) ...[
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _sending || _loading ? null : _returnAfterResolution,
            style: ExperienceFormStyle.primary(context),
            child: Text(
              widget.returnToAlbumEditing && result!.preSdkAbortVerified
                  ? '앨범 다시 편집하기'
                  : '확인하고 돌아가기',
            ),
          ),
        ] else if (!openFinancial && !_attempted) ...[
          if (result != null) ...[
            const SizedBox(height: 24),
            Divider(height: 1, color: ExperienceFormStyle.line(context)),
            const SizedBox(height: 24),
          ],
          Text(
            '요청 유형',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in const ['GENERAL', 'CANCEL', 'REFUND'])
                ChoiceChip(
                  key: ValueKey('print-order-request-type-$type'),
                  label: Text(_typeLabel(type)),
                  selected: _type == type,
                  onSelected: canAsk && _attemptReason == null
                      ? (_) => setState(() => _type = type)
                      : null,
                  showCheckmark: false,
                  backgroundColor: SnapFitColors.backgroundOf(context),
                  selectedColor: ExperienceFormStyle.selection(context),
                  labelStyle: ExperienceFormStyle.text(
                    context,
                    13,
                    weight: _type == type ? FontWeight.w600 : FontWeight.w400,
                    color: _type == type
                        ? ExperienceFormStyle.selectionInk(context)
                        : null,
                  ),
                  side: BorderSide(
                    color: _type == type
                        ? ExperienceFormStyle.selectionInk(context)
                        : ExperienceFormStyle.line(context),
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '문의 내용',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('print-order-request-reason'),
            controller: _reason,
            enabled: canAsk && _attemptReason == null,
            minLines: compactInput ? 2 : 4,
            maxLines: compactInput ? 3 : 8,
            maxLength: 1000,
            style: ExperienceFormStyle.text(context, 14),
            decoration:
                ExperienceFormStyle.input(
                  context,
                  hint: '요청 사유 또는 문의 내용을 입력해주세요.',
                ).copyWith(
                  counterStyle: ExperienceFormStyle.text(
                    context,
                    11,
                    secondary: true,
                  ),
                ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            '취소·환불은 접수 후 결제와 제작 상태를 확인해 처리합니다. 요청 접수만으로 주문 취소나 환불이 완료되지는 않습니다.',
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('print-order-request-submit'),
            onPressed: canAsk && _reason.text.trim().isNotEmpty
                ? _submit
                : null,
            style: ExperienceFormStyle.primary(context),
            child: const Text('요청 접수하기'),
          ),
        ],
      ],
    );
  }

  String _typeLabel(String type) => switch (type) {
    'CANCEL' => '취소 요청',
    'REFUND' => '환불 요청',
    _ => '주문 문의',
  };

  String _timestamp(DateTime value) {
    final date = value.toLocal();
    String part(int number) => number.toString().padLeft(2, '0');
    return '${date.year}.${part(date.month)}.${part(date.day)} ${part(date.hour)}:${part(date.minute)}';
  }

  Widget _webRequest(PrintOrderRequestResult? result, {required bool canAsk}) {
    final openFinancial = result?.unresolvedFinancial == true;
    return InquiryExitGuard(
      key: _exitGuardKey,
      edits: _reason,
      hasUnsavedChanges: () => _hasDraftChanges,
      busy: _sending,
      child: CustomerWebPage(
        title: '주문 문의',
        description: '문의·취소·환불 요청과 처리 상태를 확인하세요.',
        showNavigation: false,
        allowBack: !_sending,
        onBack: _close,
        scrollBody: true,
        sidebar: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomerWebNote(
              title: '문의할 주문',
              message: [
                if (widget.albumTitle?.isNotEmpty == true) widget.albumTitle!,
                if (widget.target.orderId != null)
                  '주문 ${widget.target.orderId}',
                if (widget.target.orderId == null) '앨범 주문 준비 건',
              ].join('\n\n'),
            ),
            const SizedBox(height: 20),
            const CustomerWebNote(
              title: '처리 안내',
              message:
                  '취소·환불은 요청 접수 후 결제와 제작 상태를 확인하여 처리합니다. 요청 접수만으로 주문 취소나 환불이 완료되지는 않습니다.',
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('요청 상태', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            if (_loading || _sending) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 20),
            ],
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(
                  color: WebPalette.of(context).ink,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (result != null) ...[
              Text(
                result.label,
                key: const ValueKey('print-order-request-status'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: WebPalette.of(context).brandInk,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                result.message,
                style: TextStyle(
                  height: 1.8,
                  color: WebPalette.of(context).muted,
                ),
              ),
              if (openFinancial) ...[
                const SizedBox(height: 12),
                Text(
                  '기존 주문을 유지하며 확인 중입니다. 결과가 확정되기 전에는 새 결제를 진행하지 않습니다.',
                  style: TextStyle(
                    height: 1.8,
                    color: WebPalette.of(context).muted,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const ValueKey('print-order-request-refresh'),
                onPressed: _loading || _sending ? null : _read,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('요청 상태 다시 확인'),
              ),
            ),
            if (result?.canReplace == true) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _sending || _loading
                      ? null
                      : _returnAfterResolution,
                  child: Text(
                    widget.returnToAlbumEditing && result!.preSdkAbortVerified
                        ? '앨범 다시 편집하기'
                        : '확인하고 돌아가기',
                  ),
                ),
              ),
            ] else if (!openFinancial && !_attempted) ...[
              const SizedBox(height: 32),
              const Divider(height: 1),
              const SizedBox(height: 32),
              Text('요청 작성', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _type,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '요청 유형'),
                items: const [
                  DropdownMenuItem(value: 'GENERAL', child: Text('주문 문의')),
                  DropdownMenuItem(value: 'CANCEL', child: Text('주문 취소 요청')),
                  DropdownMenuItem(value: 'REFUND', child: Text('환불 요청')),
                ],
                onChanged: canAsk && _attemptReason == null
                    ? (value) {
                        if (value != null) setState(() => _type = value);
                      }
                    : null,
              ),
              const SizedBox(height: 24),
              TextField(
                key: const ValueKey('print-order-request-reason'),
                controller: _reason,
                enabled: canAsk && _attemptReason == null,
                minLines: 5,
                maxLines: 10,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: '요청 사유 또는 문의 내용',
                  alignLabelWithHint: true,
                  hintText: '확인이 필요한 내용을 자세히 알려주세요.',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const ValueKey('print-order-request-submit'),
                  onPressed: canAsk && _reason.text.trim().isNotEmpty
                      ? _submit
                      : null,
                  child: const Text('요청 접수하기'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
