import 'package:flutter/material.dart';
import 'package:snap_fit/features/profile/domain/entities/order_history_item.dart';
import 'package:snap_fit/features/profile/presentation/widgets/customer_web_page.dart';
import 'package:snap_fit/features/profile/presentation/widgets/web_order_history_row.dart';
import 'package:snap_fit/shared/web/web_design.dart';

/// Local design data only: no repositories, auth, payment or fulfillment calls.
class WebCustomerDesignFixture extends StatelessWidget {
  const WebCustomerDesignFixture({super.key});

  @override
  Widget build(BuildContext context) => CustomerWebPage(
    title: '주문내역',
    section: WebSection.orders,
    description: '앨범 제작과 배송 진행 상황을 확인하세요.',
    sidebar: const CustomerWebNote(
      title: '제작과 배송 안내',
      message: '주문별로 제작과 배송 진행 상황을 확인할 수 있습니다. 배송이 시작되면 택배사와 운송장 번호가 표시됩니다.',
    ),
    child: ListView(
      children: [
        for (final row in [
          (
            title: '제주에서 보낸 여름',
            status: 'SHIPPING',
            label: '배송 중',
            amount: '159,900원',
            pages: 80,
            shipment: true,
          ),
          (
            title: '우리 가족의 첫 번째 여행',
            status: 'IN_PRODUCTION',
            label: '제작 중',
            amount: '49,900원',
            pages: 20,
            shipment: false,
          ),
          (
            title: '봄날의 기록',
            status: 'PAYMENT_PENDING',
            label: '결제 대기',
            amount: '49,900원',
            pages: 20,
            shipment: false,
          ),
        ])
          WebOrderHistoryRow(
            order: OrderHistoryItem(
              orderId: 'LOCAL-DESIGN-${row.status}',
              title: row.title,
              amount: row.shipment ? 159900 : 49900,
              pageCount: row.pages,
              status: row.status,
              statusLabel: row.label,
              progress: row.shipment ? .8 : 0,
              orderedAt: DateTime(2026, 10, 18),
              courier: row.shipment ? 'CJ대한통운' : null,
              trackingNumber: row.shipment ? '1234567890' : null,
              printProductSnapshot: const {
                'id': 'REDP_200X150_SOFT',
                'trimWidthMm': 200,
                'trimHeightMm': 150,
              },
            ),
            amountLabel: row.amount,
            dateLabel: '2026.10.18',
            artwork: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE5DBD0), Color(0xFF8DBAB6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(
                Icons.photo_album_outlined,
                color: Colors.white,
              ),
            ),
            onTap: () {},
          ),
      ],
    ),
  );
}
