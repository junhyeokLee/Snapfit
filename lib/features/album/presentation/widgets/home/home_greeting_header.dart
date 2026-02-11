import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../auth/data/dto/auth_response.dart';

/// 홈 화면 인사말 헤더
class HomeGreetingHeader extends StatelessWidget {
  final UserInfo? userInfo;

  const HomeGreetingHeader({super.key, required this.userInfo});

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeGreetingHeader', '홈 인사말 · 사용자명/추억 문구');
    }
    final rawName = userInfo?.name ?? '';
    final email = userInfo?.email ?? '';
    final provider = (userInfo?.provider ?? '').toUpperCase();
    final isPlaceholder = rawName.isEmpty ||
        rawName == provider ||
        rawName.endsWith('_USER') ||
        rawName.contains(provider);
    final emailName = email.contains('@') ? email.split('@').first : email;
    final name = !isPlaceholder && rawName.isNotEmpty
        ? rawName
        : (emailName.isNotEmpty ? emailName : '사용자');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '안녕하세요, $name 님',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '당신의 추억이 기다리고 있어요.',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}
