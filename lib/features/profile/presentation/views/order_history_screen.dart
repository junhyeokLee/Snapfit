import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order_history_item.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(myOrderHistoryProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: SnapFitColors.backgroundOf(context),
        elevation: 0,
        leading: const SnapFitAppBarBackButton(),
        title: Text(
          '나의 주문 내역',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(myOrderHistoryProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelPadding: EdgeInsets.symmetric(horizontal: 10.w),
          indicatorColor: SnapFitColors.accent,
          labelColor: SnapFitColors.textPrimaryOf(context),
          unselectedLabelColor: SnapFitColors.textSecondaryOf(context),
          labelStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
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
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '주문 내역을 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 12.sp,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
        data: (orders) => TabBarView(
          controller: _tabController,
          children: [
            _buildList(context, orders),
            _buildList(
              context,
              orders
                  .where(
                    (o) =>
                        o.status == 'PAYMENT_PENDING' ||
                        o.status == 'PAYMENT_COMPLETED',
                  )
                  .toList(),
            ),
            _buildList(
              context,
              orders.where((o) => o.status == 'IN_PRODUCTION').toList(),
            ),
            _buildList(
              context,
              orders.where((o) => o.status == 'SHIPPING').toList(),
            ),
            _buildList(
              context,
              orders
                  .where(
                    (o) => o.status == 'DELIVERED' || o.status == 'CANCELED',
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<OrderHistoryItem> items) {
    if (items.isEmpty) {
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

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 20.h),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (context, index) => _orderCard(context, items[index]),
    );
  }

  Widget _orderCard(BuildContext context, OrderHistoryItem order) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    final amount = _formatAmount(order.amount);
    final orderedAt = _formatDate(order.orderedAt);

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14.r),
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
                  color: subColor,
                  fontWeight: FontWeight.w500,
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
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$orderedAt  ·  $amount원',
            style: TextStyle(
              fontSize: 11.sp,
              color: subColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              minHeight: 6.h,
              value: order.progress,
              backgroundColor: SnapFitColors.overlayLightOf(context),
              valueColor: AlwaysStoppedAnimation<Color>(SnapFitColors.accent),
            ),
          ),
          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String statusLabel) {
    final isDone = statusLabel == '배송완료';
    final isWarning = statusLabel == '취소';
    final color = isDone
        ? const Color(0xFF00A77E)
        : isWarning
        ? const Color(0xFFE45C5C)
        : SnapFitColors.accent;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
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
}
