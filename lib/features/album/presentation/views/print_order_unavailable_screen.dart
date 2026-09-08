import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import 'print_order_preview_screen.dart';

class PrintOrderUnavailableScreen extends StatelessWidget {
  const PrintOrderUnavailableScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.pageCount,
  });

  final String albumTitle;
  final int albumId;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        title: const Text('인화 주문 안내'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 24.h),
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 56.sp,
              color: SnapFitColors.accent,
            ),
            SizedBox(height: 24.h),
            Text(
              '인화 주문 결제 준비 중',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              '현재는 인화 주문을 접수할 수 없습니다.\n완성한 앨범은 보관하고 계속 수정할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 14.sp,
                height: 1.6,
              ),
            ),
            SizedBox(height: 28.h),
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumTitle,
                    style: TextStyle(
                      color: SnapFitColors.textPrimaryOf(context),
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    '$pageCount페이지',
                    style: TextStyle(
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 28.h),
            const ElevatedButton(onPressed: null, child: Text('결제 준비 중')),
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrintOrderPreviewScreen(
                    albumId: albumId,
                    albumTitle: albumTitle,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('인쇄 미리보기 · PDF 만들기'),
            ),
            SizedBox(height: 12.h),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('앨범으로 돌아가기'),
            ),
            TextButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              ),
              child: const Text('기존 주문 내역 보기'),
            ),
          ],
        ),
      ),
    );
  }
}
