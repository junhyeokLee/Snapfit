import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/data/billing_repository.dart';
import '../../../billing/data/point_purchase_service.dart';
import '../../../billing/domain/point_purchase_completion.dart';
import '../../../billing/domain/point_top_up_context.dart';
import '../../../billing/presentation/widgets/web_point_topup_panel.dart';
import '../../../billing/presentation/widgets/point_purchase_visuals.dart';
import '../widgets/customer_web_page.dart';
import 'support_center_screen.dart';
import 'terms_policy_screen.dart';
import '../../domain/order_visibility_owner.dart';
import '../../../../shared/web/web_design.dart' show WebSection;
import '../../../../shared/widgets/snapfit_motion.dart';

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
  const BillingManagementScreen({
    super.key,
    this.returnToAiDraftFlow = false,
    this.initialPointsTabIndex = 0,
    this.purchaseContext,
  }) : assert(initialPointsTabIndex == 0 || initialPointsTabIndex == 1);
  final bool returnToAiDraftFlow;
  final int initialPointsTabIndex;
  final PointTopUpContext? purchaseContext;
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
  PointLedgerFilter _filter = PointLedgerFilter.all;
  String? _selectedProductId;
  String? _webOwnerId;
  PointPurchaseCompletion? _completionAtEntry;
  bool get _webOwnerCurrent =>
      _webOwnerId != null && ref.read(visibleOrderOwnerProvider) == _webOwnerId;

  @override
  void initState() {
    super.initState();
    _history = widget.initialPointsTabIndex == 1;
    _webTopup = !_history;
    // 이 화면을 열기 전에 확인했던 구매를 새로운 충전 완료로 다시 안내하지 않는다.
    if (!kIsWeb) {
      _completionAtEntry = ref.read(pointPurchaseServiceProvider).completion;
    }
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

  PointTopUpContext? _purchasePurpose(String? ownerId) {
    final purpose = widget.purchaseContext;
    return ownerId != null && purpose?.ownerId == ownerId ? purpose : null;
  }

  PointPurchaseCompletion? _visibleCompletion(PointPurchaseService purchases) {
    final result = purchases.completion;
    return result != null &&
            !identical(result, _completionAtEntry) &&
            !purchases.busy &&
            !purchases.verificationDelayed
        ? result
        : null;
  }

  // 짧은 화면에서는 완료 내용을 우선하고 추가 충전은 본문에서 선택한다.
  bool _compactCompletion(PointPurchaseService purchases) =>
      !_history &&
      _visibleCompletion(purchases) != null &&
      MediaQuery.sizeOf(context).height < 420;

  Future<void> _refresh(PointPurchaseService purchases) async {
    if (purchases.busy) return;
    ref.invalidate(myPointBalanceProvider);
    ref.invalidate(myPointLedgerProvider);
    ref.invalidate(pointLedgerHistoryProvider);
    if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
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
    // Detailed history is queried only while its tab is visible.
    final ledger = (kIsWeb ? !_webTopup : _history)
        ? ref.watch(pointLedgerHistoryProvider(_filter))
        : const PointLedgerHistoryState();
    if (kIsWeb) return _webPoints(balance, ledger);
    final purchases = ref.watch(pointPurchaseServiceProvider);
    return ListenableBuilder(
      listenable: purchases,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: AppBar(
            leading: IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
              icon: const ExperienceIcon('ArrowLeft'),
            ),
            title: Text(
              '포인트',
              style: SnapFitType.style(
                20,
                weight: FontWeight.w700,
                color: ExperienceFormStyle.ink(context),
              ),
            ),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: SnapFitColors.backgroundOf(context),
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
                final compactCompletion = _compactCompletion(purchases);
                final wide =
                    !compactCompletion &&
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
                              if (!compactCompletion)
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

  Widget _webPoints(AsyncValue<int> balance, PointLedgerHistoryState ledger) {
    final entries = ledger.entries;
    return CustomerWebPage(
      title: '포인트',
      section: WebSection.myProfile,
      description: '나의 포인트와 이용내역을 한곳에서.',
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            if (!_webOwnerCurrent) return;
            ref.invalidate(myPointBalanceProvider);
            ref.invalidate(myPointLedgerProvider);
            ref.invalidate(pointLedgerHistoryProvider);
            if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
          },
          icon: const ExperienceIcon('RefreshCw', size: 18),
          label: const Text('새로고침'),
        ),
      ],
      collapseSidebarOnNarrow: false,
      sidebar: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_purchasePurpose(_webOwnerId) case final purpose?) ...[
            _purchasePurposeCard(purpose, balance),
            const SizedBox(height: 16),
          ],
          PointWalletCard(
            label: (balance.asData?.value ?? 0) < 0 ? '포인트 잔액' : '사용 가능한 포인트',
            value: balance.when(
              data: (amount) => '${_formatPoints(amount)} P',
              loading: () => '잔액 확인 중',
              error: (_, __) => '확인 실패',
            ),
            onRetry: balance.hasError
                ? () => ref.invalidate(myPointBalanceProvider)
                : null,
            footnote: (balance.asData?.value ?? 0) < 0
                ? '환불로 차감된 포인트가 남아 있어요. 충전 시 먼저 정산됩니다.'
                : '템플릿과 꾸밈 소재를 고를 때 사용해요.',
          ),
          if (widget.returnToAiDraftFlow) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('앨범 만들기로 돌아가기'),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<bool>(
              style: _segmentStyle(),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<PointLedgerFilter>(
                style: _segmentStyle(),
                key: const ValueKey('points-ledger-filter'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PointLedgerFilter.all,
                    label: Text('전체'),
                  ),
                  ButtonSegment(
                    value: PointLedgerFilter.received,
                    label: Text('적립'),
                  ),
                  ButtonSegment(
                    value: PointLedgerFilter.spent,
                    label: Text('차감'),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (selection) =>
                    _selectLedgerFilter(selection.single),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ledger.loading && entries.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ledger.hasError && entries.isEmpty
                  ? Center(
                      child: OutlinedButton.icon(
                        onPressed: _retryHistory,
                        icon: const ExperienceIcon('RefreshCw'),
                        label: const Text('이용내역 다시 확인'),
                      ),
                    )
                  : entries.isEmpty
                  ? const Center(child: Text('선택한 조건의 포인트 내역이 없습니다.'))
                  : ListView.builder(
                      controller: _historyScroll,
                      cacheExtent: 800,
                      itemCount: entries.length + 1,
                      itemBuilder: (_, index) => index == entries.length
                          ? _historyFooter(ledger)
                          : _ledgerRow(entries[index], compact: false),
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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (widget.returnToAiDraftFlow)
        _AiDraftReturnCard(
          purchaseInProgress: purchases.busy,
          compact: compact,
        ),
      if (!_history && _visibleCompletion(purchases) == null)
        if (_purchasePurpose(purchases.currentUserId())
            case final purpose?) ...[
          _purchasePurposeCard(purpose, balance, enabled: !purchases.busy),
          const SizedBox(height: 16),
        ],
      PointWalletCard(
        value: balance.when(
          data: (v) => '${_formatPoints(v)} P',
          loading: () => '확인 중',
          error: (_, __) => '확인 실패',
        ),
        label: (balance.asData?.value ?? 0) < 0 ? '포인트 잔액' : '사용 가능한 포인트',
        compact: compact,
        onRetry: balance.hasError
            ? () => ref.invalidate(myPointBalanceProvider)
            : null,
        footnote: (balance.asData?.value ?? 0) < 0
            ? '정산할 포인트 ${_formatPoints(-balance.requireValue)}P · 충전 시 먼저 정산돼요.'
            : '템플릿과 꾸밈 소재를 고를 때 사용해요.',
      ),
    ],
  );

  Widget _purchasePurposeCard(
    PointTopUpContext purpose,
    AsyncValue<int> balance, {
    bool enabled = true,
  }) {
    final current = balance.asData?.value;
    final deficit = current == null ? null : purpose.requiredPoints - current;
    final missing = deficit == null
        ? null
        : deficit > 0
        ? deficit
        : 0;
    return Container(
      key: const ValueKey('points-purchase-context'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(SnapFitRadius.lg),
        border: Border.all(color: ExperienceFormStyle.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '구매할 상품',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          const SizedBox(height: 6),
          Text(
            purpose.title,
            style: ExperienceFormStyle.text(
              context,
              16,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            missing == null
                ? '잔액을 확인한 뒤 부족분을 안내해요.'
                : missing > 0
                ? '${_formatPoints(missing)} P 더 필요해요.'
                : '필요한 포인트가 준비됐어요.',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
              color: ExperienceFormStyle.selectionInk(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '안내 가격 ${_formatPoints(purpose.requiredPoints)} P · 돌아가서 최신 가격을 다시 확인해요.',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          if (Navigator.canPop(context))
            TextButton.icon(
              key: const ValueKey('points-purpose-return'),
              onPressed: enabled ? () => Navigator.maybePop(context) : null,
              icon: const ExperienceIcon('ArrowLeft', size: 17),
              label: const Text('구매하던 상품으로 돌아가기'),
            ),
        ],
      ),
    );
  }

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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  Widget _content(
    PointPurchaseService purchases,
    AsyncValue<int> balance,
    PointLedgerHistoryState ledger, {
    required bool wide,
  }) {
    final charge = _chargeItems(purchases, balance);
    final entries = ledger.entries;
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
                if (!wide &&
                    (_history || _visibleCompletion(purchases) == null))
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
                            '이용내역',
                            style: ExperienceFormStyle.text(
                              context,
                              16,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        SegmentedButton<PointLedgerFilter>(
                          key: const ValueKey('points-ledger-filter'),
                          style: _segmentStyle(),
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: PointLedgerFilter.all,
                              label: Text('전체'),
                            ),
                            ButtonSegment(
                              value: PointLedgerFilter.received,
                              label: Text('적립'),
                            ),
                            ButtonSegment(
                              value: PointLedgerFilter.spent,
                              label: Text('차감'),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (value) =>
                              _selectLedgerFilter(value.single),
                        ),
                        const SizedBox(height: 12),
                        if (ledger.loading && entries.isEmpty)
                          const LinearProgressIndicator(),
                        if (ledger.hasError && entries.isEmpty) ...[
                          Text(
                            '이용 내역을 불러오지 못했어요.',
                            style: ExperienceFormStyle.text(context, 14),
                          ),
                          TextButton(
                            onPressed: _retryHistory,
                            child: const Text('이용 내역 다시 확인'),
                          ),
                        ] else if (!ledger.loading && entries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              _filter == PointLedgerFilter.all
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
                  SliverToBoxAdapter(child: _historyFooter(ledger)),
                  SliverToBoxAdapter(
                    child: _pointHelp(
                      purchases,
                      refundHistory: entries.any(
                        (e) => e.reason == 'POINT_PURCHASE_REFUND',
                      ),
                    ),
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

  void _selectLedgerFilter(PointLedgerFilter filter) {
    setState(() => _filter = filter);
    if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
  }

  void _retryHistory() => unawaited(
    ref.read(pointLedgerHistoryProvider(_filter).notifier).refresh(),
  );

  Widget _historyFooter(PointLedgerHistoryState ledger) {
    if (ledger.entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ledger.hasError) ...[
            Text(
              '이전 내역을 불러오지 못했어요. 확인한 내역은 그대로 있어요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            const SizedBox(height: 8),
          ],
          if (ledger.hasMore)
            OutlinedButton.icon(
              key: const ValueKey('points-history-more'),
              onPressed: ledger.loading
                  ? null
                  : () => unawaited(
                      ref
                          .read(pointLedgerHistoryProvider(_filter).notifier)
                          .loadMore(),
                    ),
              icon: ledger.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const ExperienceIcon('ChevronDown', size: 20),
              label: Text(
                ledger.loading
                    ? '이전 내역을 불러오는 중…'
                    : ledger.hasError
                    ? '이전 내역 다시 불러오기'
                    : '이전 내역 더 보기',
              ),
            )
          else
            Text(
              '모든 이용내역을 확인했어요.',
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
        ],
      ),
    );
  }

  List<Widget> _chargeItems(
    PointPurchaseService purchases,
    AsyncValue<int> balance,
  ) => [
    if (_visibleCompletion(purchases) case final completed?) ...[
      _completionCard(completed, purchases),
    ] else ...[
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
            label: Text(
              purchases.busy
                  ? '구매 확인 중'
                  : purchases.verificationDelayed
                  ? '결제 상태 확인'
                  : '구매 복원',
            ),
            style: TextButton.styleFrom(
              textStyle: ExperienceFormStyle.text(context, 13),
              minimumSize: const Size(0, 44),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      // 미확정 거래의 다음 행동을 새 상품 선택보다 먼저 안내한다.
      if (purchases.verificationDelayed) _purchaseStatus(purchases),
      if (purchases.loadingProducts)
        const LinearProgressIndicator()
      else if (purchases.products.isEmpty) ...[
        Text(
          purchases.catalogFresh
              ? '지금 구매 가능한 충전 상품이 없어요.'
              : '충전 상품을 확인하지 못했어요.',
          style: ExperienceFormStyle.text(context, 14),
        ),
        if (purchases.catalogFresh || purchases.message == null)
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
      if (_selectedProduct(purchases) case final selected?)
        _expectedBalanceCard(balance, selected),
      if (!purchases.verificationDelayed &&
          (purchases.busy ||
              purchases.message != null && !purchases.messageIsCompletion))
        _purchaseStatus(purchases),
      const SizedBox(height: 8),
      if (!purchases.verificationDelayed)
        Text(
          '포인트가 반영되지 않았다면 구매 복원으로 확인하세요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
    ],
    _pointHelp(purchases),
    if (_compactCompletion(purchases)) _chargeMoreButton(purchases),
  ];

  Widget _completionCard(
    PointPurchaseCompletion result,
    PointPurchaseService purchases,
  ) {
    final purpose = _purchasePurpose(purchases.currentUserId());
    return Container(
      key: const ValueKey('points-completion'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.selection(context),
        borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExperienceIcon(
            'CheckCircle2',
            color: ExperienceFormStyle.selectionInk(context),
            size: 30,
          ),
          const SizedBox(height: 14),
          Text(
            result.alreadyGranted ? '구매 반영을 확인했어요' : '포인트가 충전됐어요',
            style: ExperienceFormStyle.text(
              context,
              20,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (!result.alreadyGranted) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '+${_formatPoints(result.grantedPoints)} P',
                style: ExperienceFormStyle.text(
                  context,
                  30,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              '이미 반영된 구매예요. 이번 확인으로 포인트가 추가 지급되지는 않아요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            const SizedBox(height: 16),
          ],
          _pointSummaryRow(
            '충전 후 확인 잔액',
            '${_formatPoints(result.remainingBalance)} P',
          ),
          if (purpose != null) ...[
            const SizedBox(height: 20),
            Text(
              purpose.title,
              style: ExperienceFormStyle.text(
                context,
                15,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '구매하던 상품으로 돌아가 최신 가격을 확인해주세요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _expectedBalanceCard(AsyncValue<int> balance, ProductDetails product) {
    final current = balance.asData?.value;
    final points = _pointAmountFromProductId(product.id);
    if (current == null || points <= 0) return const SizedBox.shrink();
    final projected = current + points;
    return Container(
      key: const ValueKey('points-expected-balance'),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: ExperienceFormStyle.line(context)),
        borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pointSummaryRow('현재 잔액', '${_formatPoints(current)} P'),
          const SizedBox(height: 10),
          _pointSummaryRow('이번 충전', '+${_formatPoints(points)} P'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: ExperienceFormStyle.line(context)),
          ),
          _pointSummaryRow('충전 후 예상 잔액', '${_formatPoints(projected)} P'),
          if (current < 0) ...[
            const SizedBox(height: 10),
            Text(
              '충전 시 먼저 정산돼요. 정산 후 사용할 수 있는 포인트는 ${_formatPoints(projected < 0 ? 0 : projected)}P예요.',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pointSummaryRow(String label, String amount) => LayoutBuilder(
    builder: (context, bounds) {
      final name = Text(
        label,
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      );
      final value = Text(
        amount,
        style: ExperienceFormStyle.text(context, 15, weight: FontWeight.w600),
      );
      if (bounds.maxWidth < 250 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            name,
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: value,
            ),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: name),
          const SizedBox(width: 12),
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, child: value),
          ),
        ],
      );
    },
  );

  Widget _pointHelp(
    PointPurchaseService purchases, {
    bool refundHistory = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (refundHistory)
          Text(
            '포인트 회수 기록과 현금 환불 처리 내역은 구분돼요. 자세한 기준과 신청 경로를 확인해주세요.',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: const ValueKey('points-policy-help'),
              onPressed: purchases.busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      snapFitRoute(
                        page: const TermsPolicyScreen(
                          initialDocType: TermsPolicyDocType.refund,
                        ),
                      ),
                    ),
              icon: const ExperienceIcon('FileText', size: 17),
              label: const Text('포인트 이용·환불 안내'),
            ),
            TextButton(
              key: const ValueKey('points-support-help'),
              onPressed: purchases.busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      snapFitRoute(page: const SupportCenterScreen()),
                    ),
              child: const Text('포인트 문의'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _purchaseStatus(PointPurchaseService purchases) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('points-purchase-status'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(SnapFitRadius.lg),
        border: Border.all(color: ExperienceFormStyle.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            purchases.verificationDelayed && !purchases.busy
                ? '결제 확인이 지연되고 있어요'
                : purchases.busy
                ? '결제·지급 확인 중'
                : !purchases.catalogFresh
                ? '충전 상품 확인 필요'
                : '결제 안내',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
          ),
          if (purchases.message != null &&
              !purchases.verificationDelayed &&
              !purchases.messageIsCompletion) ...[
            const SizedBox(height: 8),
            Text(
              purchases.message!,
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ],
          if (purchases.verificationDelayed) ...[
            const SizedBox(height: 8),
            Text(
              purchases.busy
                  ? '기존 구매 내역과 스토어 승인 결과를 확인하고 있어요.'
                  : '기존 결제 확인이 끝날 때까지 새 충전은 멈춰둘게요. 위의 결제 상태 확인을 눌러주세요.',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            TextButton(
              key: const ValueKey('points-payment-help'),
              onPressed: purchases.busy
                  ? null
                  : () => Navigator.push<void>(
                      context,
                      snapFitRoute(page: const SupportCenterScreen()),
                    ),
              child: const Text('계속 확인되지 않으면 고객센터로 문의'),
            ),
          ] else if (purchases.busy) ...[
            const SizedBox(height: 8),
            Text(
              '새로 결제하지 말고 진행 중인 결제의 확인을 기다려 주세요.',
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
          ],
          if (!purchases.catalogFresh &&
              !purchases.verificationDelayed &&
              !purchases.busy) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const ValueKey('points-catalog-retry'),
              onPressed: purchases.loadingProducts
                  ? null
                  : () => unawaited(_refresh(purchases)),
              icon: const ExperienceIcon('RefreshCw', size: 18),
              label: const Text('충전 상품 다시 확인'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _productOption(
    ProductDetails product,
    PointPurchaseService purchases,
  ) => PointPackOption(
    tapKey: ValueKey('points-product-${product.id}'),
    points: _pointAmountFromProductId(product.id),
    price: product.price,
    selected: _selectedProductId == product.id,
    onTap:
        purchases.busy ||
            purchases.verificationDelayed ||
            !purchases.catalogFresh
        ? null
        : () => setState(() => _selectedProductId = product.id),
  );

  Widget _purchaseButton(PointPurchaseService purchases) {
    final completed = _visibleCompletion(purchases);
    if (completed != null) return _completionActions(purchases);
    final selected = _selectedProduct(purchases);
    final canBuy = selected != null && purchases.canStartPurchase;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (selected != null &&
            MediaQuery.sizeOf(context).height >= 420 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.4) ...[
          Row(
            children: [
              Text(
                '충전 포인트',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
              const Spacer(),
              Text(
                '${_formatPoints(_pointAmountFromProductId(selected.id))} P',
                style: ExperienceFormStyle.text(
                  context,
                  13,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          key: const ValueKey('points-charge-action'),
          style: ExperienceFormStyle.primary(context).copyWith(
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(0, 54)),
          ),
          onPressed: canBuy
              ? () {
                  if (!purchases.canStartPurchase) return;
                  final current = _selectedProduct(purchases);
                  if (current != null) unawaited(purchases.buy(current));
                }
              : null,
          child: Text(
            purchases.busy
                ? '결제·지급 확인 중'
                : purchases.verificationDelayed
                ? '결제 상태 확인 필요'
                : purchases.loadingProducts
                ? '상품 확인 중'
                : !purchases.catalogFresh ||
                      !purchases.available ||
                      purchases.products.isEmpty
                ? '충전 상품 확인 필요'
                : selected == null
                ? '충전할 포인트 선택'
                : MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? '${_formatPoints(_pointAmountFromProductId(selected.id))} P 충전\n${selected.price} 결제하기'
                : '${selected.price} · ${_formatPoints(_pointAmountFromProductId(selected.id))} P 충전하기',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _completionActions(PointPurchaseService purchases) {
    final returning =
        Navigator.canPop(context) &&
        (_purchasePurpose(purchases.currentUserId()) != null ||
            widget.returnToAiDraftFlow);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(
          key: ValueKey(
            returning
                ? 'points-completion-return'
                : 'points-completion-history',
          ),
          style: ExperienceFormStyle.primary(context),
          onPressed: () {
            if (returning) {
              Navigator.pop(context, true);
            } else {
              setState(() {
                _history = true;
                _selectedProductId = null;
              });
              purchases.dismissCompletion();
            }
          },
          child: Text(
            returning
                ? widget.returnToAiDraftFlow
                      ? 'AI 템플릿으로 돌아가기'
                      : '구매하던 상품으로 돌아가기'
                : '이용 내역 보기',
          ),
        ),
        if (!_compactCompletion(purchases)) _chargeMoreButton(purchases),
      ],
    );
  }

  Widget _chargeMoreButton(PointPurchaseService purchases) => TextButton(
    key: const ValueKey('points-charge-more'),
    onPressed: () {
      setState(() => _selectedProductId = null);
      purchases.dismissCompletion();
    },
    child: const Text('추가 충전하기'),
  );

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
            entry.amountDelta > 0
                ? Icons.add_rounded
                : entry.amountDelta < 0
                ? Icons.remove_rounded
                : Icons.receipt_long_outlined,
            size: 20,
            color: ExperienceFormStyle.muted(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.title,
                      style: ExperienceFormStyle.text(
                        context,
                        14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
              if (entry.hasContextTitle ||
                  !compact ||
                  entry.createdAt == null) ...[
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
          style: ExperienceFormStyle.text(
            context,
            14,
            weight: FontWeight.w600,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '포인트를 채운 뒤 바로 AI 템플릿 만들기로 돌아갈 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
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
            textStyle: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
            ),
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
