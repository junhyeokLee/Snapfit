import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';

/// 마이 페이지 (테마 설정 + 로그아웃)
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeControllerProvider);
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          '마이',
          style: TextStyle(color: textColor),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          Text(
            '테마',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: mode,
                  activeColor: SnapFitColors.accent,
                  title: Text(
                    '라이트',
                    style: TextStyle(color: textColor, fontSize: 14.sp),
                  ),
                  subtitle: Text(
                    '밝은 테마',
                    style: TextStyle(color: subColor, fontSize: 12.sp),
                  ),
                  onChanged: (_) =>
                      ref.read(themeModeControllerProvider.notifier).setLight(),
                ),
                Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: mode,
                  activeColor: SnapFitColors.accent,
                  title: Text(
                    '다크',
                    style: TextStyle(color: textColor, fontSize: 14.sp),
                  ),
                  subtitle: Text(
                    '어두운 테마',
                    style: TextStyle(color: subColor, fontSize: 12.sp),
                  ),
                  onChanged: (_) =>
                      ref.read(themeModeControllerProvider.notifier).setDark(),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            '계정',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
            ),
            child: ListTile(
              leading: Icon(Icons.logout, color: SnapFitColors.textPrimaryOf(context)),
              title: Text(
                '로그아웃',
                style: TextStyle(color: textColor, fontSize: 14.sp),
              ),
              subtitle: Text(
                '현재 계정에서 로그아웃합니다',
                style: TextStyle(color: subColor, fontSize: 12.sp),
              ),
              onTap: () async {
                await ref.read(authViewModelProvider.notifier).logout();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('로그아웃되었습니다.')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
