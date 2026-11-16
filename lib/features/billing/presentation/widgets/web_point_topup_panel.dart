import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/env.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../commerce/presentation/public_commerce_screen.dart';
import '../../data/web_point_payment_launcher.dart';
import '../../data/billing_provider.dart';
import '../../data/web_point_topup_repository.dart';
import '../../domain/web_point_topup.dart';
import 'point_purchase_visuals.dart';
import '../../../../shared/widgets/experience_icon.dart';

String _number(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

/// Keeps the SDK boundary injectable without changing checkout release gates.
abstract interface class WebPointPaymentClient {
  bool get hasUnresolvedWindow;
  void confirmTerminal(WebPointTopup row);
  void ensureSupported();
  Future<void> prepare();
  Future<void> launch(WebPointSdkRequest request);
}

class _BrowserPointPaymentClient implements WebPointPaymentClient {
  const _BrowserPointPaymentClient();
  @override
  bool get hasUnresolvedWindow => hasUnresolvedWebPointPaymentWindow;
  @override
  void confirmTerminal(WebPointTopup row) =>
      acknowledgeConfirmedWebPointPayment(row);
  @override
  void ensureSupported() => ensureWebPointPaymentSupported();
  @override
  Future<void> prepare() => prepareWebPointPaymentSdk();
  @override
  Future<void> launch(WebPointSdkRequest request) =>
      launchWebPointPayment(request);
}

/// Desktop checkout preparation. Production is locked by independent source gates.
/// The production balance/ledger remain in the enclosing account screen.
class WebPointTopupPanel extends ConsumerStatefulWidget {
  const WebPointTopupPanel({
    super.key,
    required this.ownerId,
    this.paymentClient = const _BrowserPointPaymentClient(),
  });
  final String ownerId;
  final WebPointPaymentClient paymentClient;
  @override
  ConsumerState<WebPointTopupPanel> createState() => _WebPointTopupPanelState();
}

class _WebPointTopupPanelState extends ConsumerState<WebPointTopupPanel>
    with WidgetsBindingObserver {
  late final String _owner;
  WebPointCatalog? _catalog;
  List<WebPointTopup> _history = const [];
  String? _selectedId, _requestId, _message;
  bool _loading = false, _busy = false, _consent = false, _uncertain = false;
  bool _checkingPending = false;
  int _loadEpoch = 0, _recoveryEpoch = 0, _checkoutEpoch = 0;
  int _historyRevision = 0;
  String? _activePaymentId;
  Timer? _timer;
  bool get _sourceEnabled =>
      Env.webPointTopupTestEnabled || webPointTopupLiveCheckoutReleased;
  bool get _live =>
      webPointTopupLiveCheckoutReleased && _catalog?.environment == 'live';
  bool get _current =>
      mounted &&
      ref.read(visibleOrderOwnerProvider) == _owner &&
      ref.read(webPointTopupRepositoryProvider).client.auth.currentUser?.id ==
          _owner;
  WebPointTopup? get _pending {
    for (final row in _history) {
      if (row.pending && row.environment == (_live ? 'live' : 'test'))
        return row;
    }
    return null;
  }

  WebPointProduct? get _selected {
    for (final product in _catalog?.products ?? const <WebPointProduct>[]) {
      if (product.id == _selectedId) return product;
    }
    return null;
  }

  bool get _canCheckout =>
      _current &&
      (_live
          ? _catalog?.liveAvailable == true
          : Env.webPointTopupTestEnabled && _catalog?.testAvailable == true);
  @override
  void initState() {
    super.initState();
    _owner = widget.ownerId;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) unawaited(_load());
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_current && !_busy && !_loading && _pending?.needsRecovery == true)
        unawaited(_load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _current) unawaited(_load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _copy(Object error) => error is WebPointTopupException
      ? error.message
      : '연결 상태를 확인해주세요. 이미 결제창을 열었다면 다시 결제하지 말고 상태를 확인해주세요.';

  void _refreshWalletForChanges(Iterable<WebPointTopup> rows) {
    if (!_current) return;
    final previous = {for (final row in _history) row.paymentId: row};
    final changed = rows.any((row) {
      if (row.isTest ||
          !row.serverVerified ||
          !const {'CREDITED', 'REFUNDED'}.contains(row.status))
        return false;
      final before = previous[row.paymentId];
      return before?.status != row.status ||
          before?.verifiedAt != row.verifiedAt ||
          before?.refundedAt != row.refundedAt;
    });
    if (changed) {
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ref.invalidate(pointLedgerHistoryProvider);
    }
  }

  bool _checkoutCurrent(int operation) =>
      _current && operation == _checkoutEpoch;

  void _cancelLoad() {
    _loadEpoch++;
    _loading = false;
  }

  WebPointTopup _preserveTerminal(WebPointTopup incoming) {
    for (final previous in _history) {
      if (previous.paymentId != incoming.paymentId) continue;
      // A stale pending/paid snapshot cannot undo a confirmed terminal state.
      // A later partial cancellation may legitimately move a paid invoice to
      // REVIEW, while a verified full cancellation remains irreversible.
      if (previous.status == 'REFUNDED' || previous.status == 'VOIDED')
        return previous;
      if (!previous.pending &&
          incoming.status != 'REFUNDED' &&
          incoming.status != 'REVIEW')
        return previous;
    }
    return incoming;
  }

  void _finishConfirmedCheckout(WebPointTopup row) {
    if (row.pending || row.paymentId != _activePaymentId) return;
    widget.paymentClient.confirmTerminal(row);
    // The server ended this invoice. Retire its unresolved SDK continuation
    // before another checkout can start, including its catch/finally handlers.
    _checkoutEpoch++;
    _activePaymentId = null;
    _busy = false;
    _uncertain = false;
    _requestId = null;
    _consent = false;
    _cancelLoad();
  }

  void _put(WebPointTopup row) {
    if (!_current) return;
    final merged = _preserveTerminal(row);
    _refreshWalletForChanges([merged]);
    setState(() {
      _historyRevision++;
      _history = [
        merged,
        ..._history.where((item) => item.paymentId != merged.paymentId),
      ];
      _finishConfirmedCheckout(merged);
    });
  }

  void _replaceHistory(List<WebPointTopup> rows) {
    final merged = rows.map(_preserveTerminal).toList();
    _refreshWalletForChanges(merged);
    setState(() {
      _historyRevision++;
      _history = merged;
      for (final row in merged) {
        _finishConfirmedCheckout(row);
      }
    });
  }

  Future<void> _load() async {
    if (!_current || _busy || _loading || _checkingPending || !_sourceEnabled)
      return;
    final operation = ++_loadEpoch;
    final revision = _historyRevision;
    final recovery = _recoveryEpoch;
    final checkout = _checkoutEpoch;
    bool current() =>
        _current &&
        operation == _loadEpoch &&
        revision == _historyRevision &&
        recovery == _recoveryEpoch &&
        checkout == _checkoutEpoch;
    setState(() => _loading = true);
    try {
      final repository = ref.read(webPointTopupRepositoryProvider);
      final catalog = await repository.catalog(_owner);
      if (!current()) return;
      final history = await repository.history(_owner);
      if (!current()) return;
      setState(() {
        _catalog = catalog;
        _uncertain = false;
        _message = null;
      });
      _replaceHistory(history);
      final pending = _pending;
      if (pending?.needsRecovery == true) {
        await _confirmInvoice(pending!.paymentId);
      }
    } catch (error) {
      if (current()) setState(() => _message = _copy(error));
    } finally {
      if (_current && operation == _loadEpoch) setState(() => _loading = false);
    }
  }

  Future<void> _checkExistingPayment() async {
    final pending = _pending;
    if (!_current || _checkingPending || pending == null) return;
    await _confirmInvoice(pending.paymentId, showResult: true);
  }

  Future<void> _confirmInvoice(
    String paymentId, {
    bool showResult = false,
    int? checkoutOperation,
  }) async {
    final operation = ++_recoveryEpoch;
    bool current() =>
        _current &&
        operation == _recoveryEpoch &&
        (checkoutOperation == null || _checkoutCurrent(checkoutOperation));
    setState(() {
      _cancelLoad();
      _checkingPending = true;
    });
    try {
      final row = await ref
          .read(webPointTopupRepositoryProvider)
          .confirm(_owner, paymentId);
      if (!current()) return;
      _put(row);
      if (showResult) {
        setState(
          () => _message = '서버 확인 결과: ${_preserveTerminal(row).statusLabel}',
        );
      }
    } catch (error) {
      if (current()) setState(() => _message = _copy(error));
    } finally {
      if (_current && operation == _recoveryEpoch) {
        setState(() => _checkingPending = false);
      }
    }
  }

  Future<void> _checkout({WebPointTopup? prepared}) async {
    if (!_current ||
        !_canCheckout ||
        _busy ||
        _loading ||
        _checkingPending ||
        widget.paymentClient.hasUnresolvedWindow ||
        !_consent ||
        _uncertain ||
        prepared == null && (_selected == null || _pending != null))
      return;
    final repository = ref.read(webPointTopupRepositoryProvider);
    final operation = ++_checkoutEpoch;
    setState(() {
      _cancelLoad();
      _recoveryEpoch++;
      _busy = true;
      _message = null;
      _uncertain = true;
      _activePaymentId = prepared?.paymentId;
    });
    try {
      widget.paymentClient.ensureSupported();
      _requestId ??= const Uuid().v4();
      final original =
          prepared ??
          await repository.prepare(
            _owner,
            _requestId!,
            _selected!,
            environment: _live ? 'live' : 'test',
          );
      if (!_checkoutCurrent(operation)) return;
      _activePaymentId = original.paymentId;
      _put(original);
      await widget.paymentClient.prepare();
      if (!_checkoutCurrent(operation)) return;
      final request = await repository.authorizeLaunch(_owner, original);
      if (!_checkoutCurrent(operation)) return;
      _put(request.topup);
      try {
        await widget.paymentClient.launch(request);
      } finally {
        if (_checkoutCurrent(operation)) {
          await _confirmInvoice(
            original.paymentId,
            checkoutOperation: operation,
          );
        }
      }
    } catch (error) {
      if (_checkoutCurrent(operation)) setState(() => _message = _copy(error));
    } finally {
      if (_checkoutCurrent(operation)) {
        final revision = _historyRevision;
        final recovery = _recoveryEpoch;
        try {
          final history = await repository.history(_owner);
          if (_checkoutCurrent(operation) &&
              revision == _historyRevision &&
              recovery == _recoveryEpoch) {
            _replaceHistory(history);
            if (_checkoutCurrent(operation)) {
              setState(() {
                _uncertain = false;
                if (_pending == null) _requestId = null;
              });
            }
          }
        } catch (_) {
          /* Preserve the original pending identity on uncertainty. */
        }
        if (_checkoutCurrent(operation)) {
          setState(() {
            _busy = false;
            _consent = false;
          });
        }
      }
      // A retired SDK may settle after authoritative recovery. Rebuild only its
      // physical-window affordance; no old invoice/message/busy state is reused.
      if (_current &&
          !_checkoutCurrent(operation) &&
          !_busy &&
          _activePaymentId == null)
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleOwner = ref.watch(visibleOrderOwnerProvider);
    final colors = WebPalette.of(context);
    if (visibleOwner != _owner || !_current) {
      return const Text('로그인 계정이 바뀌었어요. 포인트 화면을 다시 열어주세요.');
    }
    final pending = _pending, selected = _selected;
    final unavailable = !_canCheckout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WebPointPolicyNotice(),
        const SizedBox(height: 24),
        if (!_sourceEnabled)
          _appChargeNotice(colors)
        else ...[
          if (!_live) ...[_testNotice(colors), const SizedBox(height: 28)],
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                _live ? '충전할 포인트 선택' : 'TEST 충전',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _busy || _loading || _checkingPending
                    ? null
                    : () => unawaited(_load()),
                style: _secondaryAction(colors),
                icon: const ExperienceIcon('RefreshCw', size: 18),
                label: Text(_loading ? '확인 중' : '상태 새로고침'),
              ),
            ],
          ),
          if (_loading && _catalog == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            _statusNote(colors, _message!),
          ],
          if (unavailable && !_loading) ...[
            const SizedBox(height: 20),
            Text(
              '웹 충전은 아직 열리지 않았어요. 결제는 진행되지 않습니다.',
              style: TextStyle(color: colors.muted, height: 1.6, fontSize: 13),
            ),
          ],
          if (!unavailable && pending == null) ...[
            const SizedBox(height: 20),
            if (_catalog!.products.isEmpty)
              Text(
                '선택할 수 있는 충전 상품이 없어요.',
                style: TextStyle(color: colors.muted),
              ),
            for (final product in _catalog!.products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PointPackOption(
                  tapKey: ValueKey('web-topup-product-${product.id}'),
                  points: product.points,
                  price: '${_number(product.amount)}원',
                  selected: _selectedId == product.id,
                  onTap: _busy || _uncertain
                      ? null
                      : () => setState(() {
                          _selectedId = product.id;
                          _consent = false;
                        }),
                ),
              ),
          ],
          if (pending != null) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('web-topup-pending'),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ExperienceIcon(
                          'Clock',
                          size: 20,
                          color: colors.brandInk,
                        ),
                        Text(
                          pending.statusLabel,
                          style: TextStyle(
                            color: colors.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (pending.isTest &&
                            !pending.statusLabel.startsWith('TEST'))
                          _testTag(colors),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _checkoutValue(
                          '충전 포인트',
                          '${_number(pending.points)} P',
                          colors,
                        ),
                        _checkoutValue(
                          '결제 금액',
                          '${_number(pending.amount)}원',
                          colors,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      pending.canLaunch
                          ? '기존 결제를 이어서 진행할 수 있어요.'
                          : '기존 결제의 상태를 확인해요. 새 결제는 시작하지 않아요.',
                      style: TextStyle(
                        color: colors.muted,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (pending != null &&
              (_busy || _uncertain || !pending.canLaunch)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('web-topup-check-existing'),
              onPressed: _checkingPending
                  ? null
                  : () => unawaited(_checkExistingPayment()),
              style: _secondaryAction(colors),
              icon: _checkingPending
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.brandInk,
                      ),
                    )
                  : const ExperienceIcon('RefreshCw', size: 18),
              label: Text(_checkingPending ? '기존 결제 확인 중' : '기존 결제 상태 확인'),
            ),
          ],
          if (!_busy && widget.paymentClient.hasUnresolvedWindow) ...[
            const SizedBox(height: 16),
            _statusNote(
              colors,
              '이전 결제창을 닫고 페이지를 새로고침한 뒤 새 충전을 시작해 주세요. 확인된 결제 내역과 포인트는 그대로 유지돼요.',
              textKey: const ValueKey('web-topup-previous-window-unresolved'),
            ),
          ],
          if (!unavailable && (pending == null || pending.canLaunch)) ...[
            const SizedBox(height: 16),
            if (pending == null && selected != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _checkoutValue(
                      '충전 포인트',
                      '${_number(selected.points)} P',
                      colors,
                    ),
                    _checkoutValue(
                      '결제 금액',
                      '${_number(selected.amount)}원',
                      colors,
                    ),
                  ],
                ),
              ),
            ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: colors.brand,
              checkColor: colors.onBrand,
              value: _consent,
              onChanged: _busy || _uncertain
                  ? null
                  : (value) => setState(() => _consent = value == true),
              title: Text(
                _live
                    ? '결제 금액과 포인트, 결제 확인 후 반영되는 것을 확인했어요.'
                    : 'TEST 결제이며 실제 포인트가 지급되지 않는 것을 확인했어요.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: colors.muted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('web-topup-charge-action'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.brand,
                foregroundColor: colors.onBrand,
                minimumSize: const Size(0, 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed:
                  !_canCheckout ||
                      _busy ||
                      widget.paymentClient.hasUnresolvedWindow ||
                      _loading ||
                      !_consent ||
                      _uncertain ||
                      pending == null && selected == null
                  ? null
                  : () => unawaited(_checkout(prepared: pending)),
              child: Text(
                _busy
                    ? '결제 확인 중'
                    : pending != null
                    ? '${_number(pending.amount)}원${pending.isTest ? ' TEST' : ''} 결제창 열기'
                    : selected == null
                    ? '상품을 선택해주세요'
                    : '${_number(selected.amount)}원${_live ? '' : ' TEST'} 결제창 열기',
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 36),
            Text(
              _live ? '충전 기록' : 'TEST 충전 기록',
              style: TextStyle(
                color: colors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_history.any((row) => row.isTest)) ...[
              const SizedBox(height: 8),
              Text(
                'TEST 기록은 실제 잔액에 반영되지 않아요.',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final topup in _history) _historyRow(topup, colors),
          ],
        ],
      ],
    );
  }

  Widget _appChargeNotice(WebPalette colors) => Container(
    key: const ValueKey('web-topup-app-notice'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: colors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.softBrand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExperienceIcon('Coins', color: colors.brandInk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '포인트 충전 준비 중',
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '정식 제공 시 같은 계정의 앱과 웹에서 포인트를 함께 사용할 수 있어요. 현재 실제 결제는 진행되지 않습니다.',
          style: TextStyle(color: colors.muted, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExperienceIcon('Smartphone', size: 18, color: colors.brandInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '스냅핏 앱 · 마이 → 포인트',
                style: TextStyle(
                  color: colors.brandInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _testNotice(WebPalette colors) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: colors.softBrand,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _testTag(colors),
        const SizedBox(height: 12),
        Text(
          '실제 포인트가 지급되지 않아요',
          style: TextStyle(
            color: colors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '서버에서 허용한 계정의 결제 흐름을 확인하는 화면이에요.',
          style: TextStyle(color: colors.muted, fontSize: 13, height: 1.6),
        ),
      ],
    ),
  );

  Widget _testTag(WebPalette colors) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      'TEST',
      style: TextStyle(
        color: colors.brandInk,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    ),
  );

  Widget _statusNote(WebPalette colors, String message, {Key? textKey}) =>
      Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.softBrand,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExperienceIcon('Info', size: 18, color: colors.brandInk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  key: textKey,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  ButtonStyle _secondaryAction(WebPalette colors) => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    foregroundColor: colors.brandInk,
    side: BorderSide(color: colors.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  Widget _historyRow(WebPointTopup topup, WebPalette colors) => Container(
    key: ValueKey('web-topup-history-${topup.paymentId}'),
    padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: colors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          topup.pending ? Icons.schedule_rounded : Icons.receipt_long_outlined,
          size: 20,
          color: colors.muted,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topup.statusLabel,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    '${_number(topup.points)} P',
                    style: TextStyle(color: colors.ink, fontSize: 13),
                  ),
                  Text(
                    '${_number(topup.amount)}원${topup.isTest ? ' · TEST' : ''}',
                    style: TextStyle(color: colors.muted, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '결제 번호 · ${topup.paymentId.substring(topup.paymentId.length - 8)}',
                style: TextStyle(
                  color: colors.muted,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _checkoutValue(String label, String value, WebPalette colors) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}
