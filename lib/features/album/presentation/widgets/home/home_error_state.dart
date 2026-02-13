import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import 'home_empty_state.dart';

/// 에러 상태 빌드
class HomeErrorState extends StatelessWidget {
  final Object error;

  const HomeErrorState({super.key, required this.error});

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeErrorState', '홈 에러 상태 · 연결 실패 등');
    }
    final isTimeout = error is DioException &&
        (error as DioException).type == DioExceptionType.connectionTimeout;
    if (isTimeout) {
      return HomeEmptyState(onCreate: () {}); // Error state return
    }

    final isConnectionRefused =
        error is DioException && (error as DioException).type == DioExceptionType.connectionError;
    final textColor = SnapFitColors.textPrimary.withOpacity(0.9);
    final subColor = SnapFitColors.textSecondary.withOpacity(0.7);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 48.sp, color: subColor),
            SizedBox(height: 16.h),
            Text(
              isConnectionRefused
                  ? '서버에 연결할 수 없습니다\n(Connection refused)'
                  : '에러 발생',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: textColor),
              textAlign: TextAlign.center,
            ),
            if (isConnectionRefused) ...[
              SizedBox(height: 12.h),
              Text(
                '• 백엔드를 0.0.0.0:8080 으로 실행했는지 확인\n'
                '• PC와 폰이 같은 Wi‑Fi인지 확인\n'
                '• dio_provider의 baseUrl을 PC LAN IP로 설정',
                style: TextStyle(fontSize: 13.sp, color: subColor),
                textAlign: TextAlign.center,
              ),
            ] else
              Padding(
                padding: EdgeInsets.only(top: 12.h),
                child: Text('$error', style: TextStyle(fontSize: 13.sp, color: subColor)),
              ),
          ],
        ),
      ),
    );
  }
}
