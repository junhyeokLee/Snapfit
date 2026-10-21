import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/data/point_purchase_service.dart';
import '../../../billing/presentation/widgets/web_point_topup_panel.dart';
import '../../../billing/domain/web_point_topup.dart';
import '../widgets/customer_web_page.dart';
import '../../domain/order_visibility_owner.dart';
import '../../../../shared/web/web_design.dart';

enum _LedgerFilter { all, received, spent }

String _formatPoints(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

String _ledgerTimestamp(DateTime value) {
  final date = value.toLocal();
  String part(int n) => n.toString().padLeft(2, '0');
  return '${date.year}.${part(date.month)}.${part(date.day)} ${part(date.hour)}:${part(date.minute)}';
}

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
  final _chargeScroll = ScrollController();
  final _historyScroll = ScrollController();
  bool _history = false;
  bool _webTopup = true;
  _LedgerFilter _filter = _LedgerFilter.all;
  String? _selectedProductId;
  String? _webOwnerId;
  bool get _webOwnerCurrent =>
      _webOwnerId != null && ref.read(visibleOrderOwnerProvider) == _webOwnerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !kIsWeb) ref.read(pointPurchaseServiceProvider).start();
    });
  }

  @override
  void dispose() {
    _chargeScroll.dispose();
    _historyScroll.dispose();
    super.dispose();
  }

  ProductDetails? _selectedProduct(PointPurchaseService purchases) {
    for (final product in purchases.products) {
      if (product.id == _selectedProductId) return product;
    }
    return null;
  }

  Future<void> _refresh(PointPurchaseService purchases) async {
    if (purchases.busy) return;
    ref.invalidate(myPointBalanceProvider);
    ref.invalidate(myPointLedgerProvider);
    if (!kIsWeb) await purchases.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      final owner = ref.watch(visibleOrderOwnerProvider);
      if (owner != null && _webOwnerId == null) _webOwnerId = owner;
      if (owner == null || owner != _webOwnerId) {
        return const CustomerWebPage(
          title: '포인트 이용내역',
          eyebrow: 'POINTS',
          child: Center(child: Text('로그인 계정을 확인하고 포인트 화면을 다시 열어주세요.')),
        );
      }
    }
    final balance = ref.watch(myPointBalanceProvider);
    final ledger = ref.watch(myPointLedgerProvider);
    if (kIsWeb) return _webPoints(balance, ledger);
    final purchases = ref.watch(pointPurchaseServiceProvider);
    return ListenableBuilder(
      listenable: purchases,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: ExperienceHeader(
            title: '포인트',
            showNotifications: false,
            actions: [
              IconButton(
                tooltip: '포인트 새로고침',
                onPressed: purchases.busy
                    ? null
                    : () => unawaited(_refresh(purchases)),
                icon: const ExperienceIcon('RefreshCw'),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, box) {
                final wide =
                    box.maxWidth >= 540 &&
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 1040 : 640),
                    child: wide
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: (box.maxWidth * .33).clamp(180, 280),
                                  child: SingleChildScrollView(
                                    key: const PageStorageKey('points-summary'),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: _balanceSummary(
                                      balance,
                                      purchases,
                                      compact: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                VerticalDivider(
                                  width: 1,
                                  color: ExperienceFormStyle.line(context),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 12,
                                          bottom: 12,
                                        ),
                                        child: _modeSelector(),
                                      ),
                                      Expanded(
                                        child: _content(
                                          purchases,
                                          balance,
                                          ledger,
                                          wide: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  0,
                                ),
                                child: _modeSelector(),
                              ),
                              Expanded(
                                child: _content(
                                  purchases,
                                  balance,
                                  ledger,
                                  wide: false,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: _history
              ? null
              : SafeArea(
                  top: false,
                  child: Align(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: _purchaseButton(purchases),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _webPoints(
    AsyncValue<int> balance,
    AsyncValue<List<PointLedgerEntry>> ledger,
  ) {
    final entries = (ledger.asData?.value ?? const <PointLedgerEntry>[])
        .where(
          (entry) => switch (_filter) {
            _LedgerFilter.all => true,
            _LedgerFilter.received => entry.amountDelta > 0,
            _LedgerFilter.spent => entry.amountDelta < 0,
          },
        )
        .toList(growable: false);
    return CustomerWebPage(
      title: '포인트',
      description: webPointTopupLiveCheckoutReleased
          ? '보유 포인트와 충전·사용 내역을 확인하세요.'
          : '보유 포인트와 이용내역을 확인하세요.',
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            if (!_webOwnerCurrent) return;
            ref.invalidate(myPointBalanceProvider);
            ref.invalidate(myPointLedgerProvider);
          },
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('새로고침'),
        ),
      ],
      sidebar: CustomerWebNote(
        title: '사용 가능한 포인트',
        message: webPointTopupLiveCheckoutReleased
            ? '포인트는 템플릿과 꾸밈 소재를 고를 때 사용합니다. TEST 기록은 실제 잔액과 별도로 보관됩니다.'
            : '포인트는 템플릿과 꾸밈 소재를 고를 때 사용합니다. 웹의 실제 충전은 아직 열려 있지 않으며 TEST 기록은 잔액에 반영되지 않습니다.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            balance.when(
              data: (amount) => Text(
                '${_formatPoints(amount)} P',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: WebPalette.of(context).ink,
                ),
              ),
              loading: () => const Text('잔액 확인 중'),
              error: (_, __) => TextButton(
                onPressed: () => ref.invalidate(myPointBalanceProvider),
                child: const Text('잔액 다시 확인'),
              ),
            ),
            if (widget.returnToAiDraftFlow) ...[
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => Navigator.maybePop(context),
                child: const Text('앨범 만들기로 돌아가기'),
              ),
            ],
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('포인트 충전')),
                ButtonSegment(value: false, label: Text('이용내역')),
              ],
              selected: {_webTopup},
              onSelectionChanged: (value) =>
                  setState(() => _webTopup = value.single),
            ),
          ),
          const SizedBox(height: 24),
          if (_webTopup)
            Expanded(
              child: SingleChildScrollView(
                controller: _chargeScroll,
                child: WebPointTopupPanel(
                  key: ValueKey('web-point-topup-$_webOwnerId'),
                  ownerId: _webOwnerId!,
                ),
              ),
            )
          else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 16,
              children: [
                Text('이용내역', style: Theme.of(context).textTheme.titleLarge),
                SegmentedButton<_LedgerFilter>(
                  key: const ValueKey('points-ledger-filter'),
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: _LedgerFilter.all, label: Text('전체')),
                    ButtonSegment(
                      value: _LedgerFilter.received,
                      label: Text('적립'),
                    ),
                    ButtonSegment(
                      value: _LedgerFilter.spent,
                      label: Text('사용'),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) =>
                      setState(() => _filter = selection.single),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ledger.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: OutlinedButton.icon(
                    onPressed: () => ref.invalidate(myPointLedgerProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('이용내역 다시 확인'),
                  ),
                ),
                data: (_) => entries.isEmpty
                    ? const Center(child: Text('선택한 조건의 포인트 내역이 없습니다.'))
                    : ListView.builder(
                        controller: _historyScroll,
                        itemCount: entries.length,
                        itemBuilder: (_, index) =>
                            _ledgerRow(entries[index], compact: false),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _balanceSummary(
    AsyncValue<int> balance,
    PointPurchaseService purchases, {
    required bool compact,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.returnToAiDraftFlow)
        _AiDraftReturnCard(
          purchaseInProgress: purchases.busy,
          compact: compact,
        ),
      Text(
        '사용 가능한 포인트',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      const SizedBox(height: 8),
      balance.when(
        data: (v) => Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${_formatPoints(v)} '),
              TextSpan(
                text: 'P',
                style: ExperienceFormStyle.text(
                  context,
                  compact ? 16 : 20,
                  weight: compact ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
            ],
          ),
          style: ExperienceFormStyle.text(
            context,
            compact ? 26 : 32,
            weight: FontWeight.w700,
          ),
        ),
        loading: () => Text(
          '확인 중',
          style: ExperienceFormStyle.text(context, 24, weight: FontWeight.w700),
        ),
        error: (_, __) => Text(
          '확인 실패',
          style: ExperienceFormStyle.text(context, 24, weight: FontWeight.w700),
        ),
      ),
      if (balance.hasError)
        TextButton(
          onPressed: () => ref.invalidate(myPointBalanceProvider),
          child: const Text('잔액 다시 확인'),
        ),
      const SizedBox(height: 8),
      Text(
        '템플릿과 꾸밈 소재를 고를 때 사용해요.',
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
      if ((balance.asData?.value ?? 0) < 0) ...[
        const SizedBox(height: 8),
        Text(
          '환불로 차감된 포인트가 남아 있어요. 충전 시 먼저 정산됩니다.',
          style: ExperienceFormStyle.text(context, 12),
        ),
      ],
    ],
  );

  Widget _modeSelector() => SegmentedButton<bool>(
    key: const ValueKey('points-mode'),
    showSelectedIcon: false,
    style: _segmentStyle(),
    segments: const [
      ButtonSegment(
        value: false,
        icon: ExperienceIcon('Plus', size: 16),
        label: Text('충전'),
      ),
      ButtonSegment(
        value: true,
        icon: ExperienceIcon('History', size: 16),
        label: Text('이용 내역'),
      ),
    ],
    selected: {_history},
    onSelectionChanged: (value) => setState(() => _history = value.single),
  );

  ButtonStyle _segmentStyle() => SegmentedButton.styleFrom(
    side: BorderSide.none,
    backgroundColor: ExperienceFormStyle.surface(context),
    foregroundColor: ExperienceFormStyle.ink(context),
    selectedBackgroundColor: ExperienceFormStyle.selection(context),
    selectedForegroundColor: ExperienceFormStyle.selectionInk(context),
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    textStyle: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
    shape: const StadiumBorder(),
  );

  Widget _content(
    PointPurchaseService purchases,
    AsyncValue<int> balance,
    AsyncValue<List<PointLedgerEntry>> ledger, {
    required bool wide,
  }) {
    final charge = _chargeItems(purchases);
    final entries = (ledger.asData?.value ?? [])
        .where(
          (entry) => switch (_filter) {
            _LedgerFilter.all => true,
            _LedgerFilter.received => entry.amountDelta > 0,
            _LedgerFilter.spent => entry.amountDelta < 0,
          },
        )
        .toList(growable: false);
    return RefreshIndicator(
      onRefresh: () => _refresh(purchases),
      child: CustomScrollView(
        key: PageStorageKey(_history ? 'points-history' : 'points-charge'),
        controller: _history ? _historyScroll : _chargeScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: wide
                ? const EdgeInsets.only(bottom: 24)
                : const EdgeInsets.fromLTRB(24, 20, 24, 28),
            sliver: SliverMainAxisGroup(
              slivers: [
                if (!wide)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _balanceSummary(balance, purchases, compact: false),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                if (_history) ...[
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!wide) ...[
                          Text(
                            '최근 이용',
                            style: ExperienceFormStyle.text(
                              context,
                              16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SegmentedButton<_LedgerFilter>(
                          key: const ValueKey('points-ledger-filter'),
                          style: _segmentStyle(),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _LedgerFilter.all,
                              label: Text('전체'),
                            ),
                            ButtonSegment(
                              value: _LedgerFilter.received,
                              label: Text('적립'),
                            ),
                            ButtonSegment(
                              value: _LedgerFilter.spent,
                              label: Text('차감'),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (value) => setState(() {
                            _filter = value.single;
                            if (_historyScroll.hasClients)
                              _historyScroll.jumpTo(0);
                          }),
                        ),
                        const SizedBox(height: 12),
                        if (ledger.isLoading) const LinearProgressIndicator(),
                        if (ledger.hasError) ...[
                          Text(
                            '이용 내역을 불러오지 못했어요.',
                            style: ExperienceFormStyle.text(context, 14),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(myPointLedgerProvider),
                            child: const Text('이용 내역 다시 확인'),
                          ),
                        ] else if (ledger.hasValue && entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              _filter == _LedgerFilter.all
                                  ? '아직 포인트 내역이 없어요.'
                                  : '해당 포인트 내역이 없어요.',
                              style: ExperienceFormStyle.text(
                                context,
                                14,
                                secondary: true,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SliverList.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) =>
                        _ledgerRow(entries[index], compact: wide),
                  ),
                ] else
                  SliverList.builder(
                    itemCount: charge.length,
                    itemBuilder: (context, index) => charge[index],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _chargeItems(PointPurchaseService purchases) => [
    Row(
      children: [
        Expanded(
          child: Text(
            '포인트 충전',
            style: ExperienceFormStyle.text(
              context,
              16,
              weight: FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          key: const ValueKey('points-purchase-recover'),
          onPressed: purchases.busy
              ? null
              : () => unawaited(purchases.recover()),
          icon: const ExperienceIcon('RefreshCw', size: 16),
          label: Text(purchases.busy ? '구매 확인 중' : '구매 복원'),
          style: TextButton.styleFrom(
            textStyle: ExperienceFormStyle.text(context, 13),
            minimumSize: const Size(0, 44),
          ),
        ),
      ],
    ),
    const SizedBox(height: 8),
    if (purchases.loadingProducts)
      const LinearProgressIndicator()
    else if (purchases.products.isEmpty) ...[
      Text('스토어 포인트 상품 준비 중입니다.', style: ExperienceFormStyle.text(context, 14)),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: purchases.busy
              ? null
              : () => unawaited(purchases.loadProducts()),
          child: const Text('상품 다시 확인'),
        ),
      ),
    ] else
      for (final product in purchases.products)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _productOption(product, purchases),
        ),
    if (purchases.message != null)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          purchases.message!,
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
      ),
    const SizedBox(height: 8),
    Text(
      '결제한 포인트가 보이지 않으면 구매 복원으로 미완료 결제를 확인할 수 있어요.',
      style: ExperienceFormStyle.text(context, 12, secondary: true),
    ),
  ];

  Widget _productOption(
    ProductDetails product,
    PointPurchaseService purchases,
  ) {
    final selected = _selectedProductId == product.id;
    return Semantics(
      button: true,
      selected: selected,
      checked: selected,
      enabled: !purchases.busy,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected
            ? ExperienceFormStyle.selection(context)
            : ExperienceFormStyle.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          side: BorderSide(
            color: selected
                ? ExperienceFormStyle.selectionInk(context)
                : ExperienceFormStyle.line(context),
          ),
        ),
        child: InkWell(
          key: ValueKey('points-product-${product.id}'),
          borderRadius: BorderRadius.circular(SnapFitRadius.lg),
          onTap: purchases.busy
              ? null
              : () => setState(() => _selectedProductId = product.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: selected
                        ? ExperienceFormStyle.selectionInk(context)
                        : ExperienceFormStyle.muted(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatPoints(_pointAmountFromProductId(product.id))} P',
                          style: ExperienceFormStyle.text(
                            context,
                            18,
                            weight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.price,
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            secondary: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _purchaseButton(PointPurchaseService purchases) {
    final selected = _selectedProduct(purchases);
    final canBuy =
        selected != null &&
        purchases.available &&
        !purchases.loadingProducts &&
        !purchases.busy;
    return FilledButton(
      key: const ValueKey('points-charge-action'),
      style: ExperienceFormStyle.primary(context),
      onPressed: canBuy
          ? () {
              if (purchases.busy ||
                  purchases.loadingProducts ||
                  !purchases.available)
                return;
              final current = _selectedProduct(purchases);
              if (current != null) unawaited(purchases.buy(current));
            }
          : null,
      child: Text(
        purchases.busy
            ? '구매 확인 중'
            : purchases.loadingProducts
            ? '상품 확인 중'
            : !purchases.available || purchases.products.isEmpty
            ? '충전 상품 확인 필요'
            : selected == null
            ? '충전할 포인트 선택'
            : '${selected.price} · ${_formatPoints(_pointAmountFromProductId(selected.id))} P 충전하기',
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _ledgerRow(
    PointLedgerEntry entry, {
    required bool compact,
  }) => Container(
    key: ValueKey('points-ledger-${entry.id}'),
    padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            entry.amountDelta >= 0 ? Icons.south_west : Icons.north_east,
            size: 20,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    entry.title,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.amountLabel,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                      color: entry.amountDelta > 0
                          ? ExperienceFormStyle.selectionInk(context)
                          : null,
                    ),
                  ),
                ],
              ),
              if (!compact || entry.createdAt == null) ...[
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  style: ExperienceFormStyle.text(context, 12, secondary: true),
                ),
              ],
              if (entry.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _ledgerTimestamp(entry.createdAt!),
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _AiDraftReturnCard extends StatelessWidget {
  const _AiDraftReturnCard({
    required this.purchaseInProgress,
    this.compact = false,
  });
  final bool purchaseInProgress;
  final bool compact;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI 템플릿 준비 중',
          style: ExperienceStyle.text(
            14,
            weight: FontWeight.w600,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '포인트를 채운 뒤 바로 AI 템플릿 만들기로 돌아갈 수 있어요.',
          style: ExperienceStyle.text(
            14,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('points-ai-return-action'),
          onPressed: purchaseInProgress
              ? null
              : () => Navigator.of(context).pop(true),
          style: OutlinedButton.styleFrom(
            foregroundColor: ExperienceFormStyle.selectionInk(context),
            side: BorderSide(color: ExperienceFormStyle.line(context)),
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            textStyle: ExperienceStyle.text(14, weight: FontWeight.w600),
            shape: const StadiumBorder(),
          ),
          icon: ExperienceIcon(
            'ArrowLeft',
            size: 18,
            color: ExperienceFormStyle.selectionInk(context),
          ),
          label: Text(
            compact ? 'AI로 돌아가기' : 'AI 템플릿으로 돌아가기',
            semanticsLabel: 'AI 템플릿으로 돌아가기',
          ),
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
      ],
    ),
  );
}
