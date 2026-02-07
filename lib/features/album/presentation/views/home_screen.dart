import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/widgets/circle_action_button.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../domain/entities/album.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home/album_slider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(homeViewModelProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SnapFitGradientBackground(
        child: albumsAsync.when(
          data: (albums) {
            final sorted = List<Album>.from(albums)
              ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));
            return sorted.isEmpty
                ? _buildEmptyState(context, ref)
                : AlbumSlider(albums: sorted);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (err, stack) => _buildErrorState(context, err, ref),
        ),
      ),
    );
  }

  static Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: Text(
            '앨범이 비어있습니다.',
            style: TextStyle(fontSize: 18.sp, color: Colors.white.withOpacity(0.9)),
          ),
        ),
        Positioned(
          bottom: 80.h,
          child: CircleActionButton(
            icon: Icons.add,
            onPressed: () async {
              final created = await Navigator.pushNamed(context, '/add_cover');
              if (created == true && context.mounted) {
                await ref.read(homeViewModelProvider.notifier).refresh();
              }
            },
          ),
        ),
      ],
    );
  }

  static Widget _buildErrorState(BuildContext context, Object err, WidgetRef ref) {
    final isTimeout = err is DioException &&
        err.type == DioExceptionType.connectionTimeout;
    if (isTimeout) {
      return _buildEmptyState(context, ref);
    }

    final isConnectionRefused =
        err is DioException && err.type == DioExceptionType.connectionError;
    final textColor = Colors.white.withOpacity(0.9);
    final subColor = Colors.white.withOpacity(0.7);
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
                child: Text('$err', style: TextStyle(fontSize: 13.sp, color: subColor)),
              ),
          ],
        ),
      ),
    );
  }
}
