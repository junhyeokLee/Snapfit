import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../profile/presentation/views/terms_policy_screen.dart';
import '../../domain/consent_policy.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _loading = false;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    ScreenLogger.enter('LoginScreen', '카카오/구글 로그인 진입 화면');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  Future<void> _loginWithKakao() async {
    final canProceed = await _ensureConsentBeforeLogin();
    if (!canProceed) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithKakao();
      await ref.read(authViewModelProvider.notifier).syncConsentIfPresent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('카카오 로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    final canProceed = await _ensureConsentBeforeLogin();
    if (!canProceed) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithGoogle();
      await ref.read(authViewModelProvider.notifier).syncConsentIfPresent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('구글 로그인 실패: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureConsentBeforeLogin() async {
    final storage = ref.read(tokenStorageProvider);
    final alreadyAgreed = await storage.hasRequiredConsent(
      termsVersion: ConsentPolicy.termsVersion,
      privacyVersion: ConsentPolicy.privacyVersion,
    );
    if (alreadyAgreed) return true;
    if (!mounted) return false;

    bool termsChecked = false;
    bool privacyChecked = false;
    bool marketingChecked = false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final canAgree = termsChecked && privacyChecked;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '서비스 이용 동의',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: SnapFitColors.textPrimaryOf(context),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      '최초 1회만 동의하면 다음 로그인부터는 바로 진행됩니다.\n동의 이력은 계정 기준으로 서버에 저장됩니다.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    CheckboxListTile(
                      value: termsChecked,
                      onChanged: (v) => setModalState(() {
                        termsChecked = v ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        '[필수] 이용약관 동의',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      secondary: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsPolicyScreen(
                              initialDocType: TermsPolicyDocType.terms,
                            ),
                          ),
                        ),
                        child: const Text('보기'),
                      ),
                    ),
                    CheckboxListTile(
                      value: privacyChecked,
                      onChanged: (v) => setModalState(() {
                        privacyChecked = v ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        '[필수] 개인정보처리방침 동의',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      secondary: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsPolicyScreen(
                              initialDocType: TermsPolicyDocType.privacy,
                            ),
                          ),
                        ),
                        child: const Text('보기'),
                      ),
                    ),
                    CheckboxListTile(
                      value: marketingChecked,
                      onChanged: (v) => setModalState(() {
                        marketingChecked = v ?? false;
                      }),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        '[선택] 마케팅 정보 수신 동의',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: SnapFitColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canAgree ? () => Navigator.pop(ctx, true) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SnapFitColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: const Text('동의하고 계속'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != true) return false;
    await storage.saveConsent(
      termsVersion: ConsentPolicy.termsVersion,
      privacyVersion: ConsentPolicy.privacyVersion,
      marketingOptIn: marketingChecked,
      agreedAtIso: DateTime.now().toIso8601String(),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = SnapFitColors.textPrimaryOf(context);
    final textSecondary = SnapFitColors.textSecondaryOf(context);
    final isDark = SnapFitColors.isDark(context);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? const [
                          Color(0xFF0C1B1F),
                          Color(0xFF102A31),
                          Color(0xFF132C34),
                        ]
                      : const [
                          Color(0xFFF4FBFF),
                          Color(0xFFEAF6FC),
                          Color(0xFFF5FAFD),
                        ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80.h,
            right: -50.w,
            child: _BackgroundBlob(
              size: 220.w,
              color: SnapFitColors.accent.withOpacity(isDark ? 0.16 : 0.18),
            ),
          ),
          Positioned(
            top: 160.h,
            left: -70.w,
            child: _BackgroundBlob(
              size: 170.w,
              color: const Color(0xFFFEE500).withOpacity(isDark ? 0.10 : 0.18),
            ),
          ),
          Positioned(
            bottom: -60.h,
            right: 24.w,
            child: _BackgroundBlob(
              size: 190.w,
              color: SnapFitColors.accentLight.withOpacity(
                isDark ? 0.12 : 0.28,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: AnimatedOpacity(
                  opacity: _animateIn ? 1 : 0,
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: _animateIn ? Offset.zero : const Offset(0, 0.04),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutCubic,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.96, end: 1),
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 430.w),
                        padding: EdgeInsets.fromLTRB(22.w, 26.h, 22.w, 20.h),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.white.withOpacity(0.86),
                          borderRadius: BorderRadius.circular(22.r),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withOpacity(0.10)
                                : Colors.white.withOpacity(0.75),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.30 : 0.10,
                              ),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 34.w,
                                  height: 34.w,
                                  decoration: BoxDecoration(
                                    color: SnapFitColors.accent.withOpacity(
                                      0.16,
                                    ),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(6.w),
                                    child: Image.asset(
                                      'assets/snapfit_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'SnapFit',
                                  style: TextStyle(
                                    fontFamily: 'Raleway',
                                    fontSize: 29.sp,
                                    letterSpacing: -0.4,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              '소중한 순간을 한 권의 앨범으로',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            _SocialLoginButton.kakao(
                              loading: _loading,
                              onPressed: _loading ? null : _loginWithKakao,
                            ),
                            SizedBox(height: 10.h),
                            _SocialLoginButton.google(
                              loading: _loading,
                              onPressed: _loading ? null : _loginWithGoogle,
                            ),
                            if (_loading) ...[
                              SizedBox(height: 16.h),
                              Center(
                                child: SizedBox(
                                  width: 18.w,
                                  height: 18.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: SnapFitColors.accent,
                                  ),
                                ),
                              ),
                            ],
                            SizedBox(height: 14.h),
                            Text(
                              '최초 로그인 시 이용약관/개인정보처리방침 동의가 필요하며, 이후에는 약관 버전 변경 시에만 다시 동의합니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.sp,
                                height: 1.45,
                                color: SnapFitColors.textMutedOf(context),
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              '동의 이력은 기기에 저장됩니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10.sp,
                                height: 1.35,
                                color: SnapFitColors.textMutedOf(context),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _linkTextButton(
                                  label: '이용약관',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TermsPolicyScreen(
                                        initialDocType:
                                            TermsPolicyDocType.terms,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  ' · ',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: SnapFitColors.textMutedOf(context),
                                  ),
                                ),
                                _linkTextButton(
                                  label: '개인정보처리방침',
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TermsPolicyScreen(
                                        initialDocType:
                                            TermsPolicyDocType.privacy,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTextButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

class _BackgroundBlob extends StatelessWidget {
  const _BackgroundBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.06), Colors.transparent],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  const _SocialLoginButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.onPressed,
    required this.loading,
    this.borderColor,
  });

  factory _SocialLoginButton.kakao({
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return _SocialLoginButton(
      label: '카카오로 계속하기',
      backgroundColor: const Color(0xFFFEE500),
      foregroundColor: const Color(0xFF191919),
      icon: SvgPicture.asset(
        'assets/social/kakaotalk.svg',
        width: 18,
        height: 18,
        colorFilter: const ColorFilter.mode(Color(0xFF191919), BlendMode.srcIn),
      ),
      onPressed: onPressed,
      loading: loading,
    );
  }

  factory _SocialLoginButton.google({
    required VoidCallback? onPressed,
    required bool loading,
  }) {
    return _SocialLoginButton(
      label: 'Google로 계속하기',
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      borderColor: const Color(0xFFD1D5DB),
      icon: SvgPicture.asset('assets/social/google.svg', width: 18, height: 18),
      onPressed: onPressed,
      loading: loading,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54.h,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading) ...[
              SizedBox(
                width: 14.w,
                height: 14.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              ),
              SizedBox(width: 10.w),
            ] else ...[
              icon,
              SizedBox(width: 10.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
