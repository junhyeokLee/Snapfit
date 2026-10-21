import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart' show SnapFitRadius;
import '../../../../core/utils/app_error_mapper.dart';
import '../../domain/order_visibility_owner.dart';
import '../../data/order_repository.dart';
import '../../data/print_payment_service.dart';
import '../../data/print_dev_checkout.dart';
import '../../domain/print_checkout.dart';
import '../../../album/presentation/views/print_order_preview_screen.dart';
import '../../../album/presentation/views/print_order_complete_screen.dart';
import '../../domain/entities/order_history_item.dart';
import 'print_order_request_screen.dart';
import '../widgets/order_album_artwork.dart';
import '../widgets/order_journey_progress.dart';
import '../widgets/web_order_history_row.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/web/web_design.dart';
import 'customer_print_test_order_history.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({
    super.key,
    this.initialOrderId,
    this.initialTestRunId,
  });

  final String? initialOrderId;
  final String? initialTestRunId;

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );
  int _refreshSeed = 0;
  bool _openedInitialOrder = false;
  Timer? _autoRefreshTimer;
  final _pagesKey = GlobalKey();
  int _selectedTab = 0;
  bool _showTestHistory = false;
  bool _openedInitialTest = false;
  String? _ownerId;
  bool get _ownerCurrent =>
      _ownerId != null && ref.read(visibleOrderOwnerProvider) == _ownerId;

  void _tabChanged() {
    if (_selectedTab != _tabController.index && mounted) {
      setState(() => _selectedTab = _tabController.index);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_tabChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialOrderIfNeeded();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted ||
          !_ownerCurrent ||
          _showTestHistory ||
          ModalRoute.of(context)?.isCurrent == false ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.inactive)
        return;
      _refreshOrders();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  void _refreshOrders() {
    if (mounted && _ownerCurrent) {
      if (ref.read(printDevAdminAccessProvider)) {
        ref.invalidate(customerPrintTestHistoryProvider);
      }
      setState(() => _refreshSeed++);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_showTestHistory) {
      _refreshOrders();
    }
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _openInitialOrderIfNeeded() async {
    if (_openedInitialOrder || !_ownerCurrent) return;
    final orderId = widget.initialOrderId?.trim() ?? '';
    if (orderId.isEmpty) return;
    _openedInitialOrder = true;
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .fetchMyPrintOrder(orderId);
      if (!mounted) return;
      _showOrderDetailSheet(context, order, initialOrderIsFresh: true);
    } catch (e) {
      if (!mounted) return;
      _showToast('주문 상세를 불러오지 못했습니다: ${AppErrorMapper.toUserMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOwner = ref.watch(visibleOrderOwnerProvider);
    if (currentOwner != null && _ownerId == null) _ownerId = currentOwner;
    if (currentOwner == null || currentOwner != _ownerId) {
      if (kIsWeb) {
        return SnapFitWebShell(
          showNavigation: false,
          child: WebSurface(
            child: _orderAccessNotice(
              context,
              currentOwner == null
                  ? '로그인한 계정을 확인한 뒤 주문 내역을 볼 수 있어요.'
                  : '로그인 계정이 변경되었어요. 주문 내역을 다시 열어주세요.',
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: const ExperienceHeader(title: '주문 내역', themeAware: true),
        body: _orderAccessNotice(
          context,
          currentOwner == null
              ? '로그인한 계정을 확인한 뒤 주문 내역을 볼 수 있어요.'
              : '로그인 계정이 변경되었어요. 이 화면을 닫고 주문 내역을 다시 열어주세요.',
        ),
      );
    }
    if (!_openedInitialOrder &&
        widget.initialOrderId?.trim().isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openInitialOrderIfNeeded(),
      );
    }
    // The client role only avoids an unnecessary request. A successful server
    // history read is required before a TEST tab or initial TEST detail opens.
    final testAccess = ref.watch(printDevAdminAccessProvider);
    final testOrders = testAccess
        ? ref.watch(customerPrintTestHistoryProvider)
        : null;
    final canViewTest =
        testOrders != null && testOrders.hasValue && !testOrders.hasError;
    if (!_openedInitialTest &&
        canViewTest &&
        widget.initialTestRunId?.trim().isNotEmpty == true) {
      _openedInitialTest = true;
      _showTestHistory = true;
    }
    final pages = KeyedSubtree(
      key: _pagesKey,
      child: TabBarView(
        controller: _tabController,
        children: [
          _OrderPagedTab(
            key: const ValueKey('all'),
            refreshSeed: _refreshSeed,
            statuses: const [],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: const ValueKey('prep'),
            refreshSeed: _refreshSeed,
            statuses: const ['PAYMENT_PENDING', 'PAYMENT_COMPLETED'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: const ValueKey('prod'),
            refreshSeed: _refreshSeed,
            statuses: const ['IN_PRODUCTION', 'PRINTING'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: const ValueKey('ship'),
            refreshSeed: _refreshSeed,
            statuses: const ['SHIPPING'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: const ValueKey('done'),
            refreshSeed: _refreshSeed,
            statuses: const [
              'DELIVERED',
              'CANCELED',
              'CANCELLED',
              'PREPARATION_CANCELED',
            ],
            itemBuilder: _orderCard,
          ),
        ],
      ),
    );
    const labels = ['전체', '결제/준비', '제작중', '배송중', '완료/취소'];
    if (kIsWeb) return _webHistory(pages, labels, canViewTest);
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '주문 내역',
        themeAware: true,
        showDivider: false,
        showNotifications: false,
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _refreshOrders,
            icon: const ExperienceIcon('RefreshCw', size: 21),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (canViewTest)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                child: SegmentedButton<bool>(
                  key: const ValueKey('order-history-mode'),
                  segments: const [
                    ButtonSegment(value: false, label: Text('일반 주문')),
                    ButtonSegment(value: true, label: Text('TEST 주문')),
                  ],
                  selected: {_showTestHistory},
                  onSelectionChanged: (value) =>
                      setState(() => _showTestHistory = value.single),
                ),
              ),
            Expanded(
              child: _showTestHistory && canViewTest
                  ? CustomerPrintTestOrderHistory(
                      ownerId: _ownerId!,
                      initialRunId: widget.initialTestRunId,
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final wide =
                            box.maxWidth >= 560 &&
                            MediaQuery.orientationOf(context) ==
                                Orientation.landscape;
                        if (wide)
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 164,
                                child: SingleChildScrollView(
                                  key: const PageStorageKey(
                                    'personal-order-filters',
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    12,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        '진행 상태',
                                        style: ExperienceFormStyle.text(
                                          context,
                                          13,
                                          secondary: true,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      for (var i = 0; i < labels.length; i++)
                                        Semantics(
                                          selected: _selectedTab == i,
                                          button: true,
                                          child: InkWell(
                                            key: ValueKey(
                                              'personal-order-filter-$i',
                                            ),
                                            onTap: () =>
                                                _tabController.animateTo(i),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 48,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: _selectedTab == i
                                                    ? ExperienceFormStyle.selection(
                                                        context,
                                                      )
                                                    : null,
                                                border: Border(
                                                  left: BorderSide(
                                                    width: 2,
                                                    color: _selectedTab == i
                                                        ? ExperienceFormStyle.selectionInk(
                                                            context,
                                                          )
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                labels[i],
                                                style: ExperienceFormStyle.text(
                                                  context,
                                                  13,
                                                  weight: _selectedTab == i
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                color: ExperienceFormStyle.line(context),
                              ),
                              Expanded(child: pages),
                            ],
                          );
                        return Column(
                          children: [
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              indicatorColor: ExperienceFormStyle.selectionInk(context),
                              indicatorSize: TabBarIndicatorSize.label,
                              dividerColor: Colors.transparent,
                              labelColor: ExperienceFormStyle.selectionInk(context),
                              unselectedLabelColor: ExperienceFormStyle.muted(
                                context,
                              ),
                              labelStyle: ExperienceFormStyle.text(
                                context,
                                14,
                                weight: FontWeight.w700,
                              ),
                              tabs: [
                                for (final label in labels) Tab(text: label),
                              ],
                            ),
                            Expanded(child: pages),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _webHistory(Widget pages, List<String> labels, bool canViewTest) {
    final summary = ref.watch(myOrderSummaryProvider);
    final orderSummary = summary.asData?.value;
    final counts = orderSummary == null
        ? null
        : [
            orderSummary.paymentPending + orderSummary.paymentCompleted,
            orderSummary.inProduction,
            orderSummary.shipping,
            orderSummary.delivered,
          ];
    final showTest = _showTestHistory && canViewTest;
    final compactWindow = MediaQuery.sizeOf(context).height < 760;
    final palette = WebPalette.of(context);
    return SnapFitWebShell(
      section: WebSection.orders,
      child: NestedScrollView(
        key: const ValueKey('web-order-history-scroll'),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WebPageHeading(
                  title: '주문내역',
                  description: '앨범 제작과 배송 진행 상황을 확인하세요.',
                  trailing: OutlinedButton.icon(
                    onPressed: _refreshOrders,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('새로고침'),
                  ),
                ),
                const SizedBox(height: 24),
                if (!showTest && !compactWindow) ...[
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final columns = bounds.maxWidth >= 760
                          ? 4
                          : bounds.maxWidth >= 440
                          ? 2
                          : 1;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          for (var index = 0; index < 4; index++)
                            SizedBox(
                              width:
                                  (bounds.maxWidth - (columns - 1) * 16) /
                                  columns,
                              child: WebSurface(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      const [
                                        '결제·준비',
                                        '제작 중',
                                        '배송 중',
                                        '배송 완료',
                                      ][index],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.muted,
                                      ),
                                    ),
                                    Text(
                                      counts == null ? '—' : '${counts[index]}',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: palette.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
                if (canViewTest) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<bool>(
                      key: const ValueKey('order-history-mode'),
                      segments: const [
                        ButtonSegment(value: false, label: Text('일반 주문')),
                        ButtonSegment(value: true, label: Text('TEST 주문')),
                      ],
                      selected: {_showTestHistory},
                      onSelectionChanged: (value) =>
                          setState(() => _showTestHistory = value.single),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (!showTest) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var index = 0; index < labels.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Semantics(
                              selected: _selectedTab == index,
                              child: TextButton(
                                key: ValueKey('personal-order-filter-$index'),
                                onPressed: () =>
                                    _tabController.animateTo(index),
                                style: TextButton.styleFrom(
                                  backgroundColor: _selectedTab == index
                                      ? palette.brand
                                      : Colors.transparent,
                                  foregroundColor: _selectedTab == index
                                      ? palette.onBrand
                                      : palette.muted,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 14,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(labels[index]),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
        body: WebSurface(
          padding: EdgeInsets.zero,
          child: showTest
              ? CustomerPrintTestOrderHistory(
                  ownerId: _ownerId!,
                  initialRunId: widget.initialTestRunId,
                )
              : Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, bounds) =>
                          WebOrderHistoryRow.useTable(context, bounds.maxWidth)
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 17,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: palette.line),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      '주문 앨범',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '제작 구성',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      '주문일',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      '금액',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 190,
                                    child: Text(
                                      '진행 상태 · 배송',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(child: pages),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderHistoryItem order) {
    if (kIsWeb) {
      return WebOrderHistoryRow(
        key: ValueKey('personal-order-${order.orderId}'),
        order: order,
        amountLabel: '${_formatAmount(order.amount)}원',
        dateLabel: _formatDate(order.orderedAt),
        artwork: OrderAlbumArtwork(albumId: order.albumId),
        onTap: () => _showOrderDetailSheet(context, order),
      );
    }
    return _compactOrderCard(context, order);
  }

  Widget _compactOrderCard(BuildContext context, OrderHistoryItem order) {
    return InkWell(
      key: ValueKey('personal-order-${order.orderId}'),
      onTap: () => _showOrderDetailSheet(context, order),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: ExperienceFormStyle.line(context)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 360 ? 92 : 112,
              height: 136,
              child: OrderAlbumArtwork(albumId: order.albumId),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerStatusLabel,
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      weight: FontWeight.w600,
                      color: ExperienceFormStyle.selectionInk(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    order.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.pageCount ?? '-'}쪽 · ${order.printProductLabel}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(order.orderedAt),
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatAmount(order.amount)}원',
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ExperienceIcon('ChevronRight', size: 20),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailSheet(
    BuildContext context,
    OrderHistoryItem order, {
    bool initialOrderIsFresh = false,
  }) {
    if (!_ownerCurrent) return;
    if (kIsWeb) {
      unawaited(
        showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            backgroundColor: WebPalette.of(dialogContext).surface,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 1080,
              height: MediaQuery.sizeOf(dialogContext).height * .88,
              child: _LiveOrderDetail(
                initialOrder: order,
                ownerId: _ownerId!,
                initialOrderIsFresh: initialOrderIsFresh,
                navigationContext: context,
                onChanged: () {
                  if (!mounted || !_ownerCurrent) return;
                  ref.invalidate(myOrderHistoryProvider);
                  ref.invalidate(myOrderSummaryProvider);
                  _refreshOrders();
                },
              ),
            ),
          ),
        ).then((_) {
          if (mounted && _ownerCurrent) _refreshOrders();
        }),
      );
      return;
    }
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: SnapFitColors.backgroundOf(context),
        constraints: const BoxConstraints(maxWidth: 920),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SnapFitRadius.lg),
          ),
        ),
        builder: (_) => _LiveOrderDetail(
          initialOrder: order,
          ownerId: _ownerId!,
          initialOrderIsFresh: initialOrderIsFresh,
          navigationContext: context,
          onChanged: () {
            if (!mounted) return;
            ref.invalidate(myOrderHistoryProvider);
            ref.invalidate(myOrderSummaryProvider);
            _refreshOrders();
          },
        ),
      ).then((_) {
        if (mounted) _refreshOrders();
      }),
    );
  }
}

class _LiveOrderDetail extends ConsumerStatefulWidget {
  const _LiveOrderDetail({
    required this.initialOrder,
    required this.ownerId,
    required this.initialOrderIsFresh,
    required this.navigationContext,
    required this.onChanged,
  });
  final OrderHistoryItem initialOrder;
  final String ownerId;
  final bool initialOrderIsFresh;
  final BuildContext navigationContext;
  final VoidCallback onChanged;
  @override
  ConsumerState<_LiveOrderDetail> createState() => _LiveOrderDetailState();
}

class _LiveOrderDetailState extends ConsumerState<_LiveOrderDetail>
    with WidgetsBindingObserver {
  late OrderHistoryItem _order = widget.initialOrder;
  PrintOrderProgress? _progress;
  Timer? _timer;
  bool _loading = false;
  bool _recoveringPayment = false;
  String? _refreshError;
  bool get _ownerCurrent =>
      ref.read(visibleOrderOwnerProvider) == widget.ownerId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _ownerCurrent &&
          !(_order.isFinal) &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
          WidgetsBinding.instance.lifecycleState !=
              AppLifecycleState.inactive &&
          ModalRoute.of(context)?.isCurrent != false) {
        unawaited(_refresh());
      }
    });
    Future.microtask(() => _refresh(fetchOrder: !widget.initialOrderIsFresh));
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

  Future<void> _refresh({bool fetchOrder = true}) async {
    if (_loading || !mounted || !_ownerCurrent) return;
    setState(() => _loading = true);
    final repository = ref.read(orderRepositoryProvider);
    OrderHistoryItem? nextOrder = fetchOrder ? null : _order;
    PrintOrderProgress? nextProgress;
    var progressFailed = false;
    await Future.wait([
      () async {
        if (!fetchOrder) return;
        try {
          nextOrder = await repository.fetchMyPrintOrder(_order.orderId);
        } catch (_) {
          /* Keep the last confirmed order visible during retries. */
        }
      }(),
      () async {
        if (_order.status == 'PREPARATION_CANCELED') return;
        try {
          nextProgress = await repository.fetchMyPrintOrderProgress(
            _order.orderId,
          );
        } catch (_) {
          progressFailed = true;
        }
      }(),
    ]);
    if (!mounted) return;
    if (!_ownerCurrent) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      if (nextOrder != null) _order = nextOrder!;
      if (nextProgress != null) _progress = nextProgress;
      if (_order.status == 'PREPARATION_CANCELED') _progress = null;
      _refreshError = nextOrder == null || progressFailed
          ? '최신 상태를 확인하지 못했어요. 마지막으로 확인한 주문을 보여드리고 있어요. 다시 새로고침해주세요.'
          : null;
      _loading = false;
    });
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String value, String label) async {
    if (!_ownerCurrent) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showToast('$label 복사됨');
  }

  Future<void> _openTracking() async {
    if (!_ownerCurrent) return;
    final tracking = _order.trackingNumber?.trim() ?? '';
    if (tracking.isEmpty) return;
    try {
      final opened = await launchUrl(
        _buildTrackingUri(_order.courier, tracking),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) _showToast('배송 조회를 열지 못했어요. 송장번호를 복사해 확인해주세요.');
    } catch (_) {
      _showToast('배송 조회를 열지 못했어요. 송장번호를 복사해 확인해주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOwner = ref.watch(visibleOrderOwnerProvider);
    if (currentOwner != widget.ownerId) {
      return FractionallySizedBox(
        heightFactor: .5,
        child: _orderAccessNotice(
          context,
          '로그인 계정이 변경되었어요. 이 창을 닫고 주문 내역을 다시 열어주세요.',
        ),
      );
    }
    final order = _order;
    final ctx = context;
    final navigationContext = widget.navigationContext;

    Widget field(String label, String? value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              style: ExperienceFormStyle.text(ctx, 13, secondary: true),
            ),
          ),
          Expanded(
            child: Text(
              value?.trim().isNotEmpty == true ? value! : '-',
              style: ExperienceFormStyle.text(ctx, 14),
            ),
          ),
        ],
      ),
    );
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(height: 1, color: ExperienceFormStyle.line(ctx)),
          const SizedBox(height: 18),
          Text(
            title,
            style: ExperienceFormStyle.text(ctx, 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
    return FractionallySizedBox(
      heightFactor: kIsWeb ? 1 : .92,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '주문 상세',
                      style: ExperienceFormStyle.text(
                        ctx,
                        18,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('order-detail-refresh'),
                    tooltip: '주문 상태 새로고침',
                    onPressed: _loading ? null : _refresh,
                    icon: const ExperienceIcon('RefreshCw', size: 21),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 22),
                  ),
                ],
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(
                key: ValueKey('order-detail-refreshing'),
              )
            else
              Divider(height: 1, color: ExperienceFormStyle.line(ctx)),
            Expanded(
              child: OrderDetailWorkspace(
                albumId: order.albumId,
                children: [
                  _statusChip(
                    ctx,
                    order.status == 'PAYMENT_COMPLETED' &&
                            order.paymentConfirmedAt != null
                        ? (_progress?.label ?? order.customerStatusLabel)
                        : order.customerStatusLabel,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _progress?.requiresAction == true
                        ? '제작 준비 상태를 확인하고 있어요. 주문 문의에서 필요한 안내를 확인할 수 있어요.'
                        : order.customerStatusDescription,
                    key: const ValueKey('order-status-description'),
                    style: ExperienceFormStyle.text(ctx, 13, secondary: true),
                  ),
                  OrderJourneyProgress(order: order),
                  if (_refreshError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _refreshError!,
                      key: const ValueKey('order-detail-refresh-error'),
                      style: ExperienceFormStyle.text(ctx, 12, secondary: true),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    order.title,
                    style: ExperienceFormStyle.text(
                      ctx,
                      20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.pageCount ?? '-'}페이지 · ${order.printProductLabel}',
                    key: const ValueKey('order-physical-product'),
                    style: ExperienceFormStyle.text(ctx, 13, secondary: true),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${const ['PAYMENT_PENDING', 'PREPARATION_CANCELED'].contains(order.status) ? '예정 금액' : '결제금액'} ${_formatAmount(order.amount)}원',
                    style: ExperienceFormStyle.text(
                      ctx,
                      20,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    order.orderId,
                    style: ExperienceFormStyle.text(ctx, 12, secondary: true),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copy(order.orderId, '주문번호'),
                        icon: const ExperienceIcon('Copy', size: 17),
                        label: const Text('주문번호 복사'),
                      ),
                      if (order.trackingNumber?.trim().isNotEmpty == true)
                        OutlinedButton.icon(
                          onPressed: () =>
                              _copy(order.trackingNumber!.trim(), '송장번호'),
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 17,
                          ),
                          label: const Text('송장 복사'),
                        ),
                    ],
                  ),
                  if (order.status == 'PREPARATION_CANCELED')
                    section('주문 준비', [
                      field(
                        '준비 취소',
                        _formatDateTime(order.preparationAbortedAt),
                      ),
                      Text(
                        '앨범을 수정해 새 주문을 준비할 수 있어요.',
                        style: ExperienceFormStyle.text(
                          ctx,
                          13,
                          secondary: true,
                        ),
                      ),
                    ])
                  else
                    section('결제 정보', [
                      field('결제수단', order.paymentMethod),
                      field('결제완료', _formatDateTime(order.paymentConfirmedAt)),
                    ]),
                  section('받는 곳', [
                    field('수령인', order.recipientName),
                    field('연락처', order.recipientPhone),
                    field('우편번호', order.zipCode),
                    field(
                      '주소',
                      [order.addressLine1, order.addressLine2]
                          .whereType<String>()
                          .where((v) => v.trim().isNotEmpty)
                          .join(' '),
                    ),
                    field('배송메모', order.deliveryMemo),
                  ]),
                  if (order.status != 'PREPARATION_CANCELED')
                    section('제작과 배송', [
                      FutureBuilder<PrintOrderProgress?>(
                        future: Future<PrintOrderProgress?>.value(_progress),
                        builder: (ctx, snapshot) {
                          final progress = snapshot.data;
                          if (progress == null)
                            return Text(
                              _refreshError != null
                                  ? '진행 상황을 다시 확인해주세요.'
                                  : '제작 진행 상황을 확인하고 있어요.',
                              style: ExperienceFormStyle.text(
                                ctx,
                                13,
                                secondary: true,
                              ),
                            );
                          return Column(
                            children: [
                              field('진행 상태', progress.label),
                              field(
                                '인쇄 파일 생성',
                                _formatDateTime(progress.filesReadyAt),
                              ),
                              field(
                                '인쇄 규격 검사',
                                progress.preflightPassed ? '통과' : '대기',
                              ),
                              field(
                                '제작사 파일 확인',
                                _formatDateTime(progress.fileCheckedAt),
                              ),
                              field(
                                '제작 시작',
                                _formatDateTime(progress.productionStartedAt),
                              ),
                            ],
                          );
                        },
                      ),
                      field(
                        '제작사 접수',
                        _formatDateTime(
                          _progress?.vendorAcceptedAt ?? order.printSubmittedAt,
                        ),
                      ),
                      if (order.status == 'PAYMENT_COMPLETED')
                        Text(
                          '결제 확인 후 제작사 접수까지 자동으로 진행돼요. 앱을 닫아도 주문은 계속 처리돼요.',
                          style: ExperienceFormStyle.text(
                            ctx,
                            13,
                            secondary: true,
                          ),
                        ),
                      field('택배사', order.courier),
                      field('송장번호', order.trackingNumber),
                      field('배송시작', _formatDateTime(order.shippedAt)),
                      field('배송완료', _formatDateTime(order.deliveredAt)),
                    ]),
                  if (order.status == 'PAYMENT_PENDING')
                    OutlinedButton(
                      onPressed: _recoveringPayment
                          ? null
                          : () async {
                              if (_recoveringPayment || !_ownerCurrent) return;
                              setState(() => _recoveringPayment = true);
                              try {
                                final service = ref.read(
                                  printPaymentServiceProvider,
                                );
                                final pending = await service.pending();
                                if (!context.mounted || !_ownerCurrent) return;
                                if (pending == null ||
                                    pending.albumId != order.albumId ||
                                    pending.orderId != null &&
                                        pending.orderId != order.orderId) {
                                  final repository = ref.read(
                                    orderRepositoryProvider,
                                  );
                                  final invoice = await repository
                                      .fetchPrintPaymentStatus(
                                        orderId: order.orderId,
                                      );
                                  if (invoice.orderId != order.orderId ||
                                      invoice.albumId != order.albumId ||
                                      invoice.totalAmount != order.amount) {
                                    throw const FormatException(
                                      'print_payment_order_mismatch',
                                    );
                                  }
                                  if (!mounted || !_ownerCurrent) return;
                                  if (invoice.verifiedPaid) {
                                    final receipt = await repository
                                        .fetchPrintPaidReceipt(
                                          orderId: order.orderId,
                                          albumId: invoice.albumId,
                                          expectedAmount: order.amount,
                                          expectedPaymentId: invoice.paymentId,
                                        );
                                    if (!mounted ||
                                        !_ownerCurrent ||
                                        !navigationContext.mounted)
                                      return;
                                    Navigator.pop(ctx);
                                    unawaited(
                                      Navigator.push(
                                        navigationContext,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PrintOrderCompleteScreen(
                                                receipt: receipt,
                                              ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    _showToast(
                                      invoice.verifiedUnpaid
                                          ? '결제되지 않은 주문으로 확인됐어요. 새로고침 후 주문 준비를 확인해주세요.'
                                          : '기존 주문의 결제 상태를 확인하고 있어요. 준비를 시작한 기기에서 이어가거나 주문 문의를 이용해주세요.',
                                    );
                                  }
                                  return;
                                }
                                if (!pending.sdkStarted) {
                                  final invoice = await service
                                      .pendingInvoice();
                                  if (invoice?.orderId != order.orderId) {
                                    _showToast('이 주문의 결제 정보를 확인하지 못했어요.');
                                    return;
                                  }
                                  if (!context.mounted ||
                                      !_ownerCurrent ||
                                      invoice?.reviewedRevision == null)
                                    return;
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  unawaited(
                                    Navigator.push(
                                      navigationContext,
                                      MaterialPageRoute(
                                        builder: (_) => PrintOrderPreviewScreen(
                                          albumId: pending.albumId,
                                          albumTitle: order.title,
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  final result = await service.recover();
                                  if (!context.mounted || !_ownerCurrent)
                                    return;
                                  if (result.receipt != null) {
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    unawaited(
                                      Navigator.push(
                                        navigationContext,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PrintOrderCompleteScreen(
                                                receipt: result.receipt!,
                                              ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    _showToast(
                                      result.noCharge
                                          ? '결제가 취소됐습니다. 주문 내역을 새로고침해주세요.'
                                          : '같은 주문의 결제 결과를 확인하고 있어요. 새 결제를 진행하지 않습니다.',
                                    );
                                  }
                                }
                              } catch (_) {
                                if (mounted)
                                  _showToast('결제 상태를 불러오지 못했어요. 다시 확인해주세요.');
                              } finally {
                                if (mounted)
                                  setState(() => _recoveringPayment = false);
                                widget.onChanged();
                                if (mounted) await _refresh();
                              }
                            },
                      child: Text(
                        _recoveringPayment ? '결제 결과 확인 중…' : '결제 상태 확인 · 이어하기',
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (!_ownerCurrent) return;
                      await openPrintOrderRequest(
                        navigationContext,
                        orderId: order.orderId,
                        albumTitle: order.title,
                        albumId: order.albumId,
                      );
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('주문 문의 · 취소 · 환불 요청'),
                  ),
                  if (order.trackingNumber?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _openTracking,
                      style: ExperienceFormStyle.primary(ctx),
                      icon: const Icon(Icons.local_shipping_outlined, size: 19),
                      label: const Text('배송 조회'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _orderAccessNotice(BuildContext context, String message) => SafeArea(
  child: Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: ExperienceFormStyle.text(context, 14),
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

String _formatDateTime(DateTime? date) {
  if (date == null) return '-';
  final local = date.toLocal();
  return '${_formatDate(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

Widget _statusChip(BuildContext context, String label) => Align(
  alignment: Alignment.centerLeft,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: ExperienceFormStyle.selection(context),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: ExperienceStyle.text(
        12,
        weight: FontWeight.w600,
        color: ExperienceFormStyle.selectionInk(context),
      ),
    ),
  ),
);

String _formatAmount(int amount) {
  final s = amount.toString();
  return s.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
}

String _formatDate(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

Uri _buildTrackingUri(String? courier, String tracking) {
  final c = (courier ?? '').toLowerCase();
  if (c.contains('cj')) {
    return Uri.parse(
      'https://www.cjlogistics.com/ko/tool/parcel/tracking?gnbInvcNo=$tracking',
    );
  }
  if (c.contains('한진')) {
    return Uri.parse(
      'https://www.hanjin.com/kor/CMS/DeliveryMgr/WaybillResult.do?mCode=MN038&schWaybillNum=$tracking',
    );
  }
  if (c.contains('롯데')) {
    return Uri.parse(
      'https://www.lotteglogis.com/home/reservation/tracking/linkView?InvNo=$tracking',
    );
  }
  if (c.contains('로젠')) {
    return Uri.parse('https://www.ilogen.com/web/personal/trace/$tracking');
  }
  if (c.contains('우체국')) {
    return Uri.parse(
      'https://service.epost.go.kr/trace.RetrieveDomRigiTraceList.comm?sid1=$tracking',
    );
  }
  return Uri.parse(
    'https://search.naver.com/search.naver?query=${Uri.encodeComponent('택배조회 $tracking')}',
  );
}

class _OrderPagedTab extends ConsumerStatefulWidget {
  const _OrderPagedTab({
    super.key,
    required this.statuses,
    required this.itemBuilder,
    required this.refreshSeed,
  });

  final List<String> statuses;
  final int refreshSeed;
  final Widget Function(BuildContext context, OrderHistoryItem item)
  itemBuilder;

  @override
  ConsumerState<_OrderPagedTab> createState() => _OrderPagedTabState();
}

class _OrderPagedTabState extends ConsumerState<_OrderPagedTab> {
  static const int _pageSize = 20;
  late final ScrollController _scrollController;
  int _page = 0;
  bool _hasNext = true;
  bool _loadingMore = false;
  bool _initialLoading = true;
  bool _refreshing = false;
  int _loadVersion = 0;
  bool _failedRefresh = false;
  String? _loadError;
  final List<OrderHistoryItem> _items = <OrderHistoryItem>[];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    Future.microtask(_loadFirst);
  }

  @override
  void didUpdateWidget(covariant _OrderPagedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statuses.join(',') != widget.statuses.join(',')) {
      Future.microtask(_loadFirst);
    } else if (oldWidget.refreshSeed != widget.refreshSeed) {
      Future.microtask(() => _loadFirst(preserveItems: true));
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasNext) return;
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadFirst({bool preserveItems = false}) async {
    if (!mounted || _refreshing) return;
    final refreshPages = preserveItems && _page > 1 ? _page : 1;
    final version = ++_loadVersion;
    setState(() {
      _refreshing = true;
      _initialLoading = !preserveItems && _items.isEmpty;
      _loadingMore = false;
      _loadError = null;
    });
    try {
      final pageResult = await ref
          .read(orderRepositoryProvider)
          .fetchMyOrdersPage(
            statuses: widget.statuses,
            page: 0,
            size: _pageSize * refreshPages,
          );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _items
          ..clear()
          ..addAll(pageResult.items);
        _page = refreshPages;
        _hasNext = pageResult.hasNext;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loadError = error.toString();
        _failedRefresh = true;
      });
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _refreshing || !_hasNext) return;
    final version = _loadVersion;
    setState(() => _loadingMore = true);
    try {
      final pageResult = await ref
          .read(orderRepositoryProvider)
          .fetchMyOrdersPage(
            statuses: widget.statuses,
            page: _page,
            size: _pageSize,
          );
      if (!mounted || version != _loadVersion) return;
      setState(() {
        final known = _items.map((item) => item.orderId).toSet();
        _items.addAll(
          pageResult.items.where((item) => known.add(item.orderId)),
        );
        _page += 1;
        _hasNext = pageResult.hasNext;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted || version != _loadVersion) return;
      setState(() {
        _loadError = error.toString();
        _failedRefresh = false;
      });
    } finally {
      if (mounted && version == _loadVersion)
        setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      if (_loadError != null) {
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '주문 내역을 불러오지 못했습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: SnapFitColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '네트워크 상태를 확인하고 다시 시도해주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loadFirst,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExperienceIcon(
                  'BookOpen',
                  size: 32,
                  color: ExperienceFormStyle.muted(context),
                ),
                const SizedBox(height: 16),
                Text(
                  '주문 내역이 없습니다.',
                  style: ExperienceFormStyle.text(
                    context,
                    16,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _scrollController,
        padding: kIsWeb
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(20, 14, 20, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + (_hasNext || _loadError != null ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: kIsWeb ? 0 : 10),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            if (_loadError != null) {
              return TextButton.icon(
                onPressed: () => _failedRefresh
                    ? _loadFirst(preserveItems: true)
                    : _loadMore(),
                icon: const Icon(Icons.refresh),
                label: const Text('최신 주문 상태를 다시 확인하기'),
              );
            }
            return Container(
              padding: EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: SizedBox(
                width: 18,
                height: 18,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return widget.itemBuilder(context, _items[index]);
        },
      ),
    );
  }
}
