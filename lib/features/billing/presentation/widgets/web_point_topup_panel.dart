import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../config/env.dart';
import '../../../../shared/web/web_design.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../data/web_point_payment_launcher.dart';
import '../../data/billing_provider.dart';
import '../../data/web_point_topup_repository.dart';
import '../../domain/web_point_topup.dart';

String _number(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');

/// Desktop checkout preparation. Production is locked by independent source gates.
/// The production balance/ledger remain in the enclosing account screen.
class WebPointTopupPanel extends ConsumerStatefulWidget {
  const WebPointTopupPanel({super.key, required this.ownerId});
  final String ownerId;
  @override ConsumerState<WebPointTopupPanel> createState() => _WebPointTopupPanelState();
}
class _WebPointTopupPanelState extends ConsumerState<WebPointTopupPanel> with WidgetsBindingObserver {
  late final String _owner;
  WebPointCatalog? _catalog;
  List<WebPointTopup> _history = const [];
  String? _selectedId, _requestId, _message;
  bool _loading = false, _busy = false, _consent = false, _uncertain = false;
  Timer? _timer;
  bool get _sourceEnabled => Env.webPointTopupTestEnabled || webPointTopupLiveCheckoutReleased;
  bool get _live => webPointTopupLiveCheckoutReleased && _catalog?.environment == 'live';
  bool get _current => mounted && ref.read(visibleOrderOwnerProvider) == _owner &&
    ref.read(webPointTopupRepositoryProvider).client.auth.currentUser?.id == _owner;
  WebPointTopup? get _pending {
    for (final row in _history) { if (row.pending && row.environment == (_live ? 'live' : 'test')) return row; }
    return null;
  }
  WebPointProduct? get _selected {
    for (final product in _catalog?.products ?? const <WebPointProduct>[]) {
      if (product.id == _selectedId) return product;
    }
    return null;
  }
  bool get _canCheckout => _current && (_live ? _catalog?.liveAvailable == true :
    Env.webPointTopupTestEnabled && _catalog?.testAvailable == true);
  @override void initState() {
    super.initState(); _owner = widget.ownerId; WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (_current) unawaited(_load()); });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_current && !_busy && !_loading && _pending?.needsRecovery == true) unawaited(_load());
    });
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _current) unawaited(_load());
  }
  @override void dispose() {
    _timer?.cancel(); WidgetsBinding.instance.removeObserver(this); super.dispose();
  }
  String _copy(Object error) => error is WebPointTopupException ? error.message :
    '연결 상태를 확인해주세요. 이미 결제창을 열었다면 다시 결제하지 말고 상태를 확인해주세요.';
  void _put(WebPointTopup row) {
    if (!_current) return;
    setState(() => _history = [row, ..._history.where((item) => item.paymentId != row.paymentId)]);
    if (!row.isTest && row.serverVerified && const {'CREDITED','REFUNDED'}.contains(row.status)) {
      // Refresh the authoritative wallet; never add a client-side credit.
      ref.invalidate(myPointBalanceProvider); ref.invalidate(myPointLedgerProvider);
    }
  }
  Future<void> _load() async {
    if (!_current || _busy || _loading || !_sourceEnabled) return;
    setState(() => _loading = true);
    try {
      final repository = ref.read(webPointTopupRepositoryProvider);
      final catalog = await repository.catalog(_owner);
      final history = await repository.history(_owner);
      if (!_current) return;
      setState(() { _catalog = catalog; _history = history; _uncertain = false; _message = null; });
      final pending = _pending;
      if (pending?.needsRecovery == true) _put(await repository.confirm(_owner, pending!.paymentId));
    } catch (error) { if (_current) setState(() => _message = _copy(error)); }
    finally { if (_current) setState(() => _loading = false); }
  }
  Future<void> _checkout({WebPointTopup? prepared}) async {
    if (!_current || !_canCheckout || _busy || _loading || !_consent || _uncertain ||
        prepared == null && (_selected == null || _pending != null)) return;
    final repository = ref.read(webPointTopupRepositoryProvider);
    setState(() { _busy = true; _message = null; _uncertain = true; });
    try {
      ensureWebPointPaymentSupported();
      _requestId ??= const Uuid().v4();
      final original = prepared ?? await repository.prepare(_owner, _requestId!, _selected!,
        environment: _live ? 'live' : 'test');
      if (!_current) return;
      _put(original);
      await prepareWebPointPaymentSdk();
      if (!_current) return;
      final request = await repository.authorizeLaunch(_owner, original);
      if (!_current) return;
      _put(request.topup);
      try { await launchWebPointPayment(request); }
      finally {
        // Every SDK return/error/cancel observes the original server invoice.
        // It cannot issue points or assert that a canceled window was unpaid.
        if (_current) _put(await repository.confirm(_owner, original.paymentId));
      }
    } catch (error) { if (_current) setState(() => _message = _copy(error)); }
    finally {
      if (_current) {
        try {
          final history = await repository.history(_owner);
          if (_current) setState(() {
            _history = history; _uncertain = false;
            if (_pending == null) _requestId = null;
          });
        } catch (_) { /* Preserve the original pending identity on uncertainty. */ }
        if (_current) setState(() { _busy = false; _consent = false; });
      }
    }
  }
  @override Widget build(BuildContext context) {
    final visibleOwner = ref.watch(visibleOrderOwnerProvider), colors = WebPalette.of(context);
    if (visibleOwner != _owner || !_current) {
      return const Text('로그인 계정이 바뀌었어요. 포인트 화면을 다시 열어주세요.');
    }
    final pending = _pending, selected = _selected;
    final unavailable = !_canCheckout;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
        color: colors.softBrand, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_live ? '포인트 충전' : '웹 포인트 충전 준비 중', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.ink)),
          const SizedBox(height: 8),
          Text(_live ? '결제 금액과 지급 포인트를 확인해주세요. 포인트는 서버에서 결제가 확인된 뒤 반영됩니다.' :
            '실제 결제는 아직 열리지 않았어요. 현재 포인트는 모바일 앱에서 충전할 수 있어요.',
            style: TextStyle(color: colors.muted, height: 1.6)),
          if (!_live && Env.webPointTopupTestEnabled) ...[
            const SizedBox(height: 8),
            Text('개발 검증은 서버가 허용한 계정에서만 진행됩니다. TEST 승인·취소 기록은 실제 포인트 잔액과 이용내역에 반영되지 않아요.',
              style: TextStyle(color: colors.brandInk, height: 1.6)),
          ],
        ])),
      if (_sourceEnabled) ...[
        const SizedBox(height: 24),
        Row(children: [Expanded(child: Text(_live ? '충전 상품' : 'TEST 충전', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: colors.ink))),
          OutlinedButton.icon(onPressed: _busy || _loading ? null : () => unawaited(_load()),
            icon: const Icon(Icons.refresh, size: 18), label: Text(_loading ? '확인 중' : '상태 새로고침'))]),
        if (_loading && _catalog == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: TextStyle(color: colors.warning, height: 1.6)),
        ],
        if (unavailable && !_loading) Padding(padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text('웹 충전은 아직 활성화되지 않았어요. 결제나 포인트 지급은 진행되지 않습니다.',
            style: TextStyle(color: colors.muted))),
        if (!unavailable && pending == null) ...[
          const SizedBox(height: 16),
          if (_catalog!.products.isEmpty) Text('서버에 설정된 충전 상품이 없습니다.', style: TextStyle(color: colors.muted)),
          for (final product in _catalog!.products) Padding(padding: const EdgeInsets.only(bottom: 12),
            child: Material(color: _selectedId == product.id ? colors.softBrand : colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: _selectedId == product.id ? colors.brandInk : colors.line)),
              child: RadioListTile<String>(value: product.id, groupValue: _selectedId,
                onChanged: _busy || _uncertain ? null : (id) => setState(() { _selectedId = id; _consent = false; }),
                title: Text('${_number(product.points)} P', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600)),
                subtitle: Text('${_number(product.amount)}원${_live ? ' · 카드 결제' : ' TEST · 실잔액 미반영'}', style: TextStyle(color: colors.muted))))),
        ],
        if (pending != null) ...[
          const SizedBox(height: 16),
          Text('${pending.statusLabel}\n${_number(pending.points)} P · ${_number(pending.amount)}원${pending.isTest ? ' TEST' : ''}',
            style: TextStyle(color: colors.ink, height: 1.6)),
          const SizedBox(height: 8),
          Text(pending.canLaunch ? '아직 결제창을 열지 않은 기존 건을 이어서 진행할 수 있어요.' :
            '기존 결제를 확인하고 있어요. 새 결제는 시작하지 않습니다. 상태가 계속 바뀌지 않으면 아래 충전 기록의 식별번호로 문의해주세요.',
            style: TextStyle(color: colors.muted, height: 1.6)),
        ],
        if (!unavailable && (pending == null || pending.canLaunch)) ...[
          const SizedBox(height: 16),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: _consent,
            onChanged: _busy || _uncertain ? null : (value) => setState(() => _consent = value == true),
            title: Text(_live ? '결제 금액과 지급 포인트, 서버 확인 후 반영되는 것을 확인했어요.' :
              'TEST 결제이며 실제 포인트가 지급되지 않는 것을 확인했어요.',
              style: TextStyle(fontSize: 14, color: colors.ink))),
          const SizedBox(height: 12),
          FilledButton(onPressed: !_canCheckout || _busy || _loading || !_consent || _uncertain ||
            pending == null && selected == null ? null : () => unawaited(_checkout(prepared: pending)),
            child: Text(_busy ? '결제 확인 중' : pending != null ?
              '${_number(pending.amount)}원${pending.isTest ? ' TEST' : ''} 결제창 열기' : selected == null ?
              '상품을 선택해주세요' : '${_number(selected.amount)}원${_live ? '' : ' TEST'} 결제창 열기')),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(_live ? '충전 기록' : 'TEST 충전 기록', style: TextStyle(color: colors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('TEST 표시가 있는 기록은 실제 잔액·이용내역과 별도로 보관됩니다.', style: TextStyle(color: colors.muted)),
          for (final topup in _history) Container(padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(topup.statusLabel, style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${_number(topup.points)} P · ${_number(topup.amount)}원${topup.isTest ? ' TEST' : ''} · ${topup.paymentId.substring(topup.paymentId.length - 8)}',
                style: TextStyle(color: colors.muted)),
            ])),
        ],
      ],
    ]);
  }
}
