import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../config/env.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order_history_item.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key, this.initialOrderId});

  final String? initialOrderId;

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );
  int _refreshSeed = 0;
  bool _openedInitialOrder = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInitialOrderIfNeeded();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {
        _refreshSeed++;
      });
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      ),
    );
  }

  Future<void> _openInitialOrderIfNeeded() async {
    if (_openedInitialOrder) return;
    final orderId = widget.initialOrderId?.trim() ?? '';
    if (orderId.isEmpty) return;
    _openedInitialOrder = true;
    try {
      final items = await ref.read(orderRepositoryProvider).fetchMyOrders();
      if (!mounted) return;
      for (final order in items) {
        if (order.orderId == orderId) {
          _showOrderDetailSheet(context, order);
          return;
        }
      }
      _showToast('주문번호 $orderId 를 찾지 못했습니다.');
    } catch (e) {
      if (!mounted) return;
      _showToast('주문 상세를 불러오지 못했습니다: ${AppErrorMapper.toUserMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text('나의 주문 내역', style: context.sfTitle(size: 16.sp)),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _refreshSeed++;
            }),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: EdgeInsets.symmetric(horizontal: 10.w),
          indicatorColor: SnapFitColors.accent,
          indicatorWeight: 2.5,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelColor: SnapFitColors.textPrimaryOf(context),
          unselectedLabelColor: SnapFitColors.textSecondaryOf(context),
          labelStyle: context.sfBody(size: 12.sp, weight: FontWeight.w700),
          unselectedLabelStyle: context.sfSub(
            size: 12.sp,
            weight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: '전체'),
            Tab(text: '결제/준비'),
            Tab(text: '제작중'),
            Tab(text: '배송중'),
            Tab(text: '완료/취소'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OrderPagedTab(
            key: ValueKey('all-$_refreshSeed'),
            statuses: const [],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: ValueKey('prep-$_refreshSeed'),
            statuses: const ['PAYMENT_PENDING', 'PAYMENT_COMPLETED'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: ValueKey('prod-$_refreshSeed'),
            statuses: const ['IN_PRODUCTION'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: ValueKey('ship-$_refreshSeed'),
            statuses: const ['SHIPPING'],
            itemBuilder: _orderCard,
          ),
          _OrderPagedTab(
            key: ValueKey('done-$_refreshSeed'),
            statuses: const ['DELIVERED', 'CANCELED'],
            itemBuilder: _orderCard,
          ),
        ],
      ),
    );
  }

  Widget _orderCard(BuildContext context, OrderHistoryItem order) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    final amount = _formatAmount(order.amount);
    final orderedAt = _formatDate(order.orderedAt);

    return InkWell(
      onTap: () => _showOrderDetailSheet(context, order),
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
        decoration: BoxDecoration(
          color: SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: SnapFitColors.overlayLightOf(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusChip(context, order.statusLabel),
                const Spacer(),
                Text(
                  '주문번호 ${order.orderId}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 9.h),
            Text(
              order.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5.sp,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              '주문일 $orderedAt  ·  결제금액 $amount원',
              style: TextStyle(
                fontSize: 10.8.sp,
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(999.r),
              child: LinearProgressIndicator(
                minHeight: 7.h,
                value: order.progress,
                backgroundColor: SnapFitColors.accent.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(SnapFitColors.accent),
              ),
            ),
            SizedBox(height: 7.h),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '상세보기',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: SnapFitColors.textMutedOf(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetailSheet(BuildContext context, OrderHistoryItem order) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    String line(String label, String? value) {
      if (value == null || value.trim().isEmpty) return '$label: -';
      return '$label: $value';
    }

    String formatDateTime(DateTime? dt) {
      if (dt == null) return '-';
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y.$m.$d $hh:$mm KST';
    }

    Future<void> copy(String value, String label) async {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      _showToast('$label 복사됨');
    }

    Future<void> openTracking() async {
      final tracking = order.trackingNumber?.trim() ?? '';
      if (tracking.isEmpty) return;
      final uri = _buildTrackingUri(order.courier, tracking);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> markShippingForQa() async {
      final courierController = TextEditingController(
        text: (order.courier ?? '').trim().isEmpty ? 'CJ대한통운' : order.courier,
      );
      final trackingController = TextEditingController(
        text: (order.trackingNumber ?? '').trim(),
      );

      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) {
          return AlertDialog(
            title: const Text('배송 시작 처리(QA)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: courierController,
                  decoration: const InputDecoration(labelText: '택배사'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: trackingController,
                  decoration: const InputDecoration(labelText: '송장번호'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dCtx, false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dCtx, true),
                child: const Text('처리'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;
      final courier = courierController.text.trim();
      final tracking = trackingController.text.trim();
      if (courier.isEmpty || tracking.isEmpty) {
        if (!mounted) return;
        _showToast('택배사/송장번호를 입력해주세요.');
        return;
      }

      try {
        await ref
            .read(orderRepositoryProvider)
            .markShipping(
              orderId: order.orderId,
              courier: courier,
              trackingNumber: tracking,
              adminKey: Env.orderAdminKey,
            );
        setState(() {
          _refreshSeed++;
        });
        ref.invalidate(myOrderSummaryProvider);
        if (!mounted) return;
        _showToast('배송중 상태로 변경되었습니다.');
      } catch (e) {
        if (!mounted) return;
        _showToast('배송 시작 처리 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }

    Future<void> markDeliveredForQa() async {
      try {
        await ref
            .read(orderRepositoryProvider)
            .markDelivered(orderId: order.orderId, adminKey: Env.orderAdminKey);
        setState(() {
          _refreshSeed++;
        });
        ref.invalidate(myOrderSummaryProvider);
        if (!mounted) return;
        _showToast('배송완료 상태로 변경되었습니다.');
      } catch (e) {
        if (!mounted) return;
        _showToast('배송 완료 처리 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }

    final canAdminControl = kDebugMode && Env.orderAdminKey.trim().isNotEmpty;
    final canMarkShipping = order.status == 'IN_PRODUCTION';
    final canMarkDelivered = order.status == 'SHIPPING';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 20.h),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '주문 상세',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    order.orderId,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => copy(order.orderId, '주문번호'),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('주문번호 복사'),
                      ),
                      SizedBox(width: 8.w),
                      if ((order.trackingNumber ?? '').trim().isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () =>
                              copy(order.trackingNumber!.trim(), '송장번호'),
                          icon: const Icon(
                            Icons.local_shipping_outlined,
                            size: 16,
                          ),
                          label: const Text('송장 복사'),
                        ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  _statusChip(context, order.statusLabel),
                  SizedBox(height: 12.h),
                  Text(
                    order.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    '결제금액 ${_formatAmount(order.amount)}원',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line('결제수단', order.paymentMethod),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    line('수령인', order.recipientName),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line('연락처', order.recipientPhone),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line('우편번호', order.zipCode),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line(
                      '주소',
                      [order.addressLine1, order.addressLine2]
                          .whereType<String>()
                          .where((e) => e.trim().isNotEmpty)
                          .join(' '),
                    ),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line('배송메모', order.deliveryMemo),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 10.h),
                  Divider(color: SnapFitColors.overlayLightOf(context)),
                  SizedBox(height: 8.h),
                  Text(
                    line('택배사', order.courier),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    line('송장번호', order.trackingNumber),
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  if ((order.trackingNumber ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: openTracking,
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('배송 조회'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SnapFitColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (canAdminControl &&
                      (canMarkShipping || canMarkDelivered)) ...[
                    SizedBox(height: 10.h),
                    Divider(color: SnapFitColors.overlayLightOf(context)),
                    SizedBox(height: 8.h),
                    Text(
                      'QA 상태 전환',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        if (canMarkShipping)
                          Expanded(
                            child: ElevatedButton(
                              onPressed: markShippingForQa,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: SnapFitColors.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text('배송 시작'),
                            ),
                          ),
                        if (canMarkShipping && canMarkDelivered)
                          SizedBox(width: 8.w),
                        if (canMarkDelivered)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: markDeliveredForQa,
                              child: const Text('배송 완료'),
                            ),
                          ),
                      ],
                    ),
                  ],
                  SizedBox(height: 10.h),
                  Divider(color: SnapFitColors.overlayLightOf(context)),
                  SizedBox(height: 8.h),
                  Text(
                    '결제완료: ${formatDateTime(order.paymentConfirmedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '인쇄접수: ${formatDateTime(order.printSubmittedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '배송시작: ${formatDateTime(order.shippedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '배송완료: ${formatDateTime(order.deliveredAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, String statusLabel) {
    final isDone = statusLabel == '배송완료';
    final isWarning = statusLabel == '취소';
    final color = isDone
        ? SnapFitStylePalette.darkGreen
        : isWarning
        ? SnapFitColors.error
        : SnapFitColors.accent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 9.8.sp,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

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
}

class _OrderPagedTab extends ConsumerStatefulWidget {
  const _OrderPagedTab({
    super.key,
    required this.statuses,
    required this.itemBuilder,
  });

  final List<String> statuses;
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

  Future<void> _loadFirst() async {
    setState(() {
      _initialLoading = true;
      _loadingMore = false;
      _loadError = null;
      _page = 0;
      _hasNext = true;
      _items.clear();
    });
    await _loadMore();
    if (!mounted) return;
    setState(() => _initialLoading = false);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasNext) return;
    setState(() => _loadingMore = true);
    try {
      final pageResult = await ref
          .read(orderRepositoryProvider)
          .fetchMyOrdersPage(
            statuses: widget.statuses,
            page: _page,
            size: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(pageResult.items);
        _page += 1;
        _hasNext = pageResult.hasNext;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasNext = false;
        _loadError = e.toString();
      });
    }
    setState(() {
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      if (_loadError != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '주문 내역을 불러오지 못했습니다.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: SnapFitColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '네트워크 상태를 확인하고 다시 시도해주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: SnapFitColors.textSecondaryOf(context),
                  ),
                ),
                SizedBox(height: 10.h),
                OutlinedButton.icon(
                  onPressed: _loadFirst,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        );
      }
      return Center(
        child: Text(
          '주문 내역이 없습니다.',
          style: TextStyle(
            fontSize: 12.sp,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFirst,
      child: ListView.separated(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        itemCount: _items.length + (_hasNext ? 1 : 0),
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              alignment: Alignment.center,
              child: SizedBox(
                width: 18.w,
                height: 18.w,
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
