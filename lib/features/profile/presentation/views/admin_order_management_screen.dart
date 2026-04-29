import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../data/admin_ops_repository.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order_history_item.dart';

class AdminOrderManagementScreen extends ConsumerStatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  ConsumerState<AdminOrderManagementScreen> createState() =>
      _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState
    extends ConsumerState<AdminOrderManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 5, vsync: this);
  final TextEditingController _searchController = TextEditingController();
  String _keyword = '';
  int _refreshSeed = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      setState(() => _refreshSeed++);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _searchController.dispose();
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

  void _applyKeyword() {
    FocusScope.of(context).unfocus();
    setState(() {
      _keyword = _searchController.text.trim();
      _refreshSeed++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canAdminControl = Env.orderAdminKey.trim().isNotEmpty;
    if (!canAdminControl) {
      return Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        appBar: AppBar(
          backgroundColor: SnapFitColors.backgroundOf(context),
          elevation: 0,
          leading: const SnapFitAppBarBackButton(),
          title: Text('주문 관리', style: context.sfTitle(size: 16.sp)),
        ),
        body: Center(
          child: Text(
            '관리자 키가 설정되지 않았습니다.',
            style: TextStyle(
              fontSize: 13.sp,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text('주문 관리', style: context.sfTitle(size: 16.sp)),
        actions: [
          IconButton(
            onPressed: () => setState(() => _refreshSeed++),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(94.h),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 10.h),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _applyKeyword(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                  decoration: InputDecoration(
                    hintText: '주문번호, 앨범명, 수령인 검색',
                    hintStyle: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      onPressed: _applyKeyword,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                    filled: true,
                    fillColor: SnapFitColors.surfaceOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
              TabBar(
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
                  Tab(text: '결제완료'),
                  Tab(text: '제작중'),
                  Tab(text: '배송중'),
                  Tab(text: '완료/취소'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AdminOrderPagedTab(
            key: ValueKey('admin-all-$_keyword-$_refreshSeed'),
            statuses: const [],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-paid-$_keyword-$_refreshSeed'),
            statuses: const ['PAYMENT_COMPLETED'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-prod-$_keyword-$_refreshSeed'),
            statuses: const ['IN_PRODUCTION'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-ship-$_keyword-$_refreshSeed'),
            statuses: const ['SHIPPING'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
          _AdminOrderPagedTab(
            key: ValueKey('admin-done-$_keyword-$_refreshSeed'),
            statuses: const ['DELIVERED', 'CANCELED'],
            keyword: _keyword,
            onShowDetail: _showOrderDetailSheet,
          ),
        ],
      ),
    );
  }

  void _showOrderDetailSheet(OrderHistoryItem order) {
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
      if (!mounted) return;
      _showToast('$label 복사됨');
    }

    Future<void> openExternal(String raw, String label) async {
      final url = ref.read(orderRepositoryProvider).buildAdminPrintPackageUrl(raw);
      final uri = Uri.tryParse(url);
      if (uri == null) {
        _showToast('$label URL 형식이 올바르지 않습니다.');
        return;
      }
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    Future<void> preparePrintPackage() async {
      try {
        await ref.read(orderRepositoryProvider).preparePrintPackage(
              orderId: order.orderId,
              adminKey: Env.orderAdminKey,
            );
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _refreshSeed++);
        _showToast('인쇄 패키지를 준비했습니다.');
      } catch (e) {
        _showToast('인쇄 패키지 준비 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }

    Future<void> markShipping() async {
      final courierController = TextEditingController(
        text: (order.courier ?? '').trim().isEmpty ? 'CJ대한통운' : order.courier,
      );
      final trackingController = TextEditingController(
        text: (order.trackingNumber ?? '').trim(),
      );
      final ok = await showDialog<bool>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: const Text('배송 시작 처리'),
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
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(adminOpsRepositoryProvider).markShipping(
              adminKey: Env.orderAdminKey,
              orderId: order.orderId,
              courier: courierController.text.trim(),
              trackingNumber: trackingController.text.trim(),
            );
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _refreshSeed++);
        _showToast('배송중 상태로 변경되었습니다.');
      } catch (e) {
        _showToast('배송 시작 처리 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }

    Future<void> markDelivered() async {
      try {
        await ref.read(adminOpsRepositoryProvider).markDelivered(
              adminKey: Env.orderAdminKey,
              orderId: order.orderId,
            );
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _refreshSeed++);
        _showToast('배송완료 상태로 변경되었습니다.');
      } catch (e) {
        _showToast('배송 완료 처리 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }

    Future<void> copyVendorHandOffSet() async {
      final packageUrl = (order.printPackageJsonUrl ?? '').trim();
      final pdfUrl = (order.printFilePdfUrl ?? '').trim();
      final zipUrl = (order.printFileZipUrl ?? '').trim();
      final text = [
        '주문번호: ${order.orderId}',
        '앨범명: ${order.title}',
        '앨범ID: ${order.albumId?.toString() ?? '-'}',
        '페이지 수: ${order.pageCount?.toString() ?? '-'}',
        '수령인: ${order.recipientName ?? '-'}',
        '연락처: ${order.recipientPhone ?? '-'}',
        '우편번호: ${order.zipCode ?? '-'}',
        '주소: ${[order.addressLine1, order.addressLine2].whereType<String>().where((e) => e.trim().isNotEmpty).join(' ')}',
        '배송메모: ${order.deliveryMemo ?? '-'}',
        if (packageUrl.isNotEmpty)
          '인쇄 패키지: ${ref.read(orderRepositoryProvider).buildAdminPrintPackageUrl(packageUrl)}',
        if (pdfUrl.isNotEmpty)
          'PDF: ${ref.read(orderRepositoryProvider).buildAdminPrintPackageUrl(pdfUrl)}',
        if (zipUrl.isNotEmpty)
          'ZIP: ${ref.read(orderRepositoryProvider).buildAdminPrintPackageUrl(zipUrl)}',
      ].join('\n');
      await copy(text, '제작사 전달 정보');
    }

    final hasPrintPackage = (order.printPackageJsonUrl ?? '').trim().isNotEmpty;
    final hasPrintZip = (order.printFileZipUrl ?? '').trim().isNotEmpty;
    final hasPrintPdf = (order.printFilePdfUrl ?? '').trim().isNotEmpty;
    final canMarkShipping = order.status == 'IN_PRODUCTION';
    final canMarkDelivered = order.status == 'SHIPPING';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 20.h),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '운영 주문 상세',
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
                  '${order.orderId} · ${order.statusLabel}',
                  style: TextStyle(fontSize: 11.sp, color: subColor),
                ),
                SizedBox(height: 10.h),
                Text(
                  order.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(line('수령인', order.recipientName),
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 4.h),
                Text(line('연락처', order.recipientPhone),
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
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
                Text(line('배송메모', order.deliveryMemo),
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => copy(order.orderId, '주문번호'),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('주문번호 복사'),
                    ),
                    OutlinedButton.icon(
                      onPressed: copyVendorHandOffSet,
                      icon: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: const Text('제작사 전달 정보 복사'),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Divider(color: SnapFitColors.overlayLightOf(context)),
                SizedBox(height: 8.h),
                Text(
                  '인쇄 패키지 / 제작 전달',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: hasPrintPackage
                            ? () => openExternal(order.printPackageJsonUrl!, '인쇄 패키지')
                            : preparePrintPackage,
                        icon: Icon(
                          hasPrintPackage
                              ? Icons.open_in_new_rounded
                              : Icons.inventory_2_outlined,
                          size: 16,
                        ),
                        label: Text(hasPrintPackage ? '인쇄 패키지 열기' : '인쇄 패키지 생성'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SnapFitColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasPrintPdf || hasPrintZip) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      if (hasPrintPdf)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => openExternal(order.printFilePdfUrl!, 'PDF'),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                            label: const Text('PDF 열기'),
                          ),
                        ),
                      if (hasPrintPdf && hasPrintZip) SizedBox(width: 8.w),
                      if (hasPrintZip)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => openExternal(order.printFileZipUrl!, 'ZIP'),
                            icon: const Icon(Icons.archive_outlined, size: 16),
                            label: const Text('ZIP 열기'),
                          ),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: 10.h),
                Divider(color: SnapFitColors.overlayLightOf(context)),
                SizedBox(height: 8.h),
                Text(
                  '상태 관리',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 8.h),
                if (canMarkShipping || canMarkDelivered)
                  Row(
                    children: [
                      if (canMarkShipping)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: markShipping,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SnapFitColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: const Text('배송 시작'),
                          ),
                        ),
                      if (canMarkShipping && canMarkDelivered) SizedBox(width: 8.w),
                      if (canMarkDelivered)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: markDelivered,
                            child: const Text('배송 완료'),
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    '현재 상태에서 가능한 수동 전환이 없습니다.',
                    style: TextStyle(fontSize: 12.sp, color: subColor),
                  ),
                SizedBox(height: 10.h),
                Text('결제완료: ${formatDateTime(order.paymentConfirmedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 4.h),
                Text('인쇄패키지: ${formatDateTime(order.printPackageGeneratedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 4.h),
                Text('제작사 전송: ${formatDateTime(order.printSubmittedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 4.h),
                Text('배송시작: ${formatDateTime(order.shippedAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
                SizedBox(height: 4.h),
                Text('배송완료: ${formatDateTime(order.deliveredAt)}',
                    style: TextStyle(fontSize: 12.sp, color: textColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminOrderPagedTab extends ConsumerStatefulWidget {
  const _AdminOrderPagedTab({
    super.key,
    required this.statuses,
    required this.keyword,
    required this.onShowDetail,
  });

  final List<String> statuses;
  final String keyword;
  final void Function(OrderHistoryItem order) onShowDetail;

  @override
  ConsumerState<_AdminOrderPagedTab> createState() => _AdminOrderPagedTabState();
}

class _AdminOrderPagedTabState extends ConsumerState<_AdminOrderPagedTab> {
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
  void didUpdateWidget(covariant _AdminOrderPagedTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final statusChanged = oldWidget.statuses.join(',') != widget.statuses.join(',');
    final keywordChanged = oldWidget.keyword != widget.keyword;
    if (statusChanged || keywordChanged) {
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
    if (_loadingMore || !_hasNext || !_scrollController.hasClients) return;
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
      final result = await ref.read(adminOpsRepositoryProvider).fetchAdminOrders(
            adminKey: Env.orderAdminKey,
            statuses: widget.statuses,
            keyword: widget.keyword,
            page: _page,
            size: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page += 1;
        _hasNext = result.hasNext;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasNext = false;
        _loadError = e.toString();
      });
    }
    if (!mounted) return;
    setState(() => _loadingMore = false);
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
                  '주문 목록을 불러오지 못했습니다.',
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
          '조건에 맞는 주문이 없습니다.',
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final order = _items[index];
          return InkWell(
            onTap: () => widget.onShowDetail(order),
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _statusChip(context, order.statusLabel),
                      const Spacer(),
                      Text(
                        order.orderId,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: SnapFitColors.textSecondaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    order.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${order.recipientName ?? '-'} · ${order.recipientPhone ?? '-'}',
                    style: TextStyle(
                      fontSize: 10.8.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '패키지 ${order.printPackageGeneratedAt == null ? '미생성' : '생성됨'}'
                    ' · PDF ${((order.printFilePdfUrl ?? '').trim().isEmpty) ? '없음' : '있음'}'
                    ' · ZIP ${((order.printFileZipUrl ?? '').trim().isEmpty) ? '없음' : '있음'}',
                    style: TextStyle(
                      fontSize: 10.2.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(BuildContext context, String statusLabel) {
    final isDone = statusLabel == '배송완료';
    final isWarning = statusLabel == '취소';
    final color = isDone
        ? SnapFitColors.freezeAccentDark
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
}
