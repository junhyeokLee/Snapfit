import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/widgets/snapfit_gradient_background.dart';
import '../../../../shared/widgets/snapfit_primary_action_button.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('LoginScreen', '카카오/구글 로그인 진입 화면');
  }

  Future<void> _loginWithKakao() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithKakao();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카카오 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithGoogle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('구글 로그인 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SnapFitGradientBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SnapFit',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    '로그인 후 앨범을 확인하세요',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  SizedBox(height: 28.h),
                  SnapFitPrimaryActionButton(
                    label: '카카오로 시작',
                    onPressed: _loading ? null : _loginWithKakao,
                  ),
                  SizedBox(height: 12.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _loginWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        disabledBackgroundColor: Colors.white.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      child: Text(
                        '구글로 시작',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (_loading) ...[
                    SizedBox(height: 18.h),
                    const CircularProgressIndicator(
                      color: SnapFitColors.accentLight,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
