import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/snapfit_app_bar_back_button.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  );

  final List<_OrderItem> _orders = const [
    _OrderItem(
      id: 'SF-240319-001',
      title: '성수동 카페 투어 포토북',
      orderedAt: '2026.03.18',
      amount: '34,900원',
      status: '배송중',
      progress: 0.82,
    ),
    _OrderItem(
      id: 'SF-240318-184',
      title: '한강 공원 피크닉 하드커버',
      orderedAt: '2026.03.17',
      amount: '29,000원',
      status: '제작중',
      progress: 0.56,
    ),
    _OrderItem(
      id: 'SF-240316-072',
      title: '여름 휴가 기록 포토북',
      orderedAt: '2026.03.14',
      amount: '41,500원',
      status: '완료',
      progress: 1,
    ),
    _OrderItem(
      id: 'SF-240311-009',
      title: '드라이브 코스 미니북',
      orderedAt: '2026.03.10',
      amount: '19,500원',
      status: '취소',
      progress: 0.12,
    ),
  ];

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(context, _orders),
          _buildList(
            context,
            _orders
                .where(
                  (o) =>
                      o.status == '결제대기' ||
                      o.status == '결제완료' ||
                      o.status == '제작준비',
                )
                .toList(),
          ),
          _buildList(context, _orders.where((o) => o.status == '제작중').toList()),
          _buildList(context, _orders.where((o) => o.status == '배송중').toList()),
          _buildList(
            context,
            _orders.where((o) => o.status == '완료' || o.status == '취소').toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<_OrderItem> items) {
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

  Widget _orderCard(BuildContext context, _OrderItem order) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
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
              _statusChip(context, order.status),
              const Spacer(),
              Text(
                order.id,
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
            '${order.orderedAt}  ·  ${order.amount}',
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
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) {
    final isDone = status == '완료';
    final isWarning = status == '취소';
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
        status,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _OrderItem {
  final String id;
  final String title;
  final String orderedAt;
  final String amount;
  final String status;
  final double progress;

  const _OrderItem({
    required this.id,
    required this.title,
    required this.orderedAt,
    required this.amount,
    required this.status,
    required this.progress,
  });
}
