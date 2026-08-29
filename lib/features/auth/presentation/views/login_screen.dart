import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../profile/presentation/views/terms_policy_screen.dart';
import '../../domain/consent_policy.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.startInPasswordReset = false});

  final bool startInPasswordReset;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginProvider? _loadingProvider;
  late _AuthMode _mode;
  bool _animateIn = false;

  final _signUpFormKey = GlobalKey<FormState>();
  final _emailLoginFormKey = GlobalKey<FormState>();
  final _resetPasswordFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();
  bool _showPassword = false;
  bool _showPasswordConfirm = false;
  bool _showLoginPassword = false;
  bool _showNewPassword = false;
  bool _showNewPasswordConfirm = false;
  String? _pendingConfirmationEmail;
  bool _termsChecked = false;
  bool _privacyChecked = false;
  bool _marketingChecked = false;
  bool _showSignUpConfirmation = false;

  bool get _isLoading => _loadingProvider != null;
  bool get _canCreateEmailAccount => _termsChecked && _privacyChecked;

  @override
  void initState() {
    super.initState();
    _mode = widget.startInPasswordReset
        ? _AuthMode.resetPassword
        : _AuthMode.login;
    ScreenLogger.enter('LoginScreen', '카카오/구글/이메일 로그인 진입 화면');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _resetEmailController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _loginWithKakao() async {
    final canProceed = await _ensureConsentBeforeLogin();
    if (!canProceed) return;
    if (_isLoading) return;
    setState(() => _loadingProvider = _LoginProvider.kakao);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithKakao();
      await ref.read(authViewModelProvider.notifier).syncConsentIfPresent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _loginWithGoogle() async {
    final canProceed = await _ensureConsentBeforeLogin();
    if (!canProceed) return;
    if (_isLoading) return;
    setState(() => _loadingProvider = _LoginProvider.google);
    try {
      await ref.read(authViewModelProvider.notifier).loginWithGoogle();
      await ref.read(authViewModelProvider.notifier).syncConsentIfPresent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.')),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final canAgree = termsChecked && privacyChecked;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                child: _AuthPaperCard(
                  maxWidth: 460,
                  padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: const Color(0xFF141312).withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        '서비스 이용 동의',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w900,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        '동의 이력은 계정에 저장되며, 빠른 확인을 위해 기기에도 보관됩니다.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          height: 1.45,
                          color: SnapFitColors.textSecondaryOf(context),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _TermsCheckTile(
                        value: termsChecked,
                        requiredLabel: true,
                        label: '이용약관 동의',
                        onChanged: (v) => setModalState(() => termsChecked = v),
                        onView: () => _openTerms(TermsPolicyDocType.terms),
                      ),
                      _TermsCheckTile(
                        value: privacyChecked,
                        requiredLabel: true,
                        label: '개인정보처리방침 동의',
                        onChanged: (v) =>
                            setModalState(() => privacyChecked = v),
                        onView: () => _openTerms(TermsPolicyDocType.privacy),
                      ),
                      _TermsCheckTile(
                        value: marketingChecked,
                        label: '마케팅 정보 수신 동의',
                        onChanged: (v) =>
                            setModalState(() => marketingChecked = v),
                      ),
                      SizedBox(height: 10.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: canAgree
                              ? () => Navigator.pop(ctx, true)
                              : null,
                          style: _primaryButtonStyle(context),
                          child: const Text('동의하고 계속'),
                        ),
                      ),
                    ],
                  ),
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

  void _openTerms(TermsPolicyDocType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TermsPolicyScreen(initialDocType: type),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '이메일을 입력해주세요.';
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(text)) return '이메일 형식을 확인해주세요.';
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.length < 8) return '비밀번호는 8자 이상 입력해주세요.';
    if (text.contains(RegExp(r'\s'))) return '비밀번호에는 공백을 사용할 수 없어요.';
    if (!text.contains(RegExp(r'[A-Za-z]')) ||
        !text.contains(RegExp(r'[0-9]'))) {
      return '비밀번호는 영문과 숫자를 함께 사용해주세요.';
    }
    return null;
  }

  String _friendlyEmailAuthError(Object error, {required bool isSignUp}) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('already') || raw.contains('registered')) {
      return '이미 가입된 이메일이에요. 이메일로 로그인을 시도해주세요.';
    }
    if (raw.contains('invalid') || raw.contains('credential')) {
      return isSignUp ? '이메일 또는 비밀번호 형식을 확인해주세요.' : '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (raw.contains('confirm') || raw.contains('verified')) {
      return '이메일 인증을 먼저 완료해주세요.';
    }
    if (raw.contains('weak') || raw.contains('password')) {
      return '비밀번호는 8자 이상, 영문과 숫자를 함께 사용해주세요.';
    }
    return isSignUp
        ? '이메일 가입을 완료하지 못했어요. 잠시 후 다시 시도해주세요.'
        : '이메일 로그인을 완료하지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _loginWithEmail() async {
    FocusScope.of(context).unfocus();
    final valid = _emailLoginFormKey.currentState?.validate() ?? false;
    if (!valid || _isLoading) return;
    setState(() => _loadingProvider = _LoginProvider.email);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .loginWithEmail(
            email: _loginEmailController.text.trim(),
            password: _loginPasswordController.text,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailAuthError(e, isSignUp: false))),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _requestPasswordReset() async {
    FocusScope.of(context).unfocus();
    final emailError = _validateEmail(_resetEmailController.text);
    if (emailError != null || _isLoading) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(emailError ?? '잠시 후 다시 시도해주세요.')));
      return;
    }
    setState(() => _loadingProvider = _LoginProvider.email);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .requestPasswordReset(_resetEmailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정 메일을 보냈어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailAuthError(e, isSignUp: false))),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _resendConfirmationEmail() async {
    final email =
        _pendingConfirmationEmail?.trim() ?? _emailController.text.trim();
    final emailError = _validateEmail(email);
    if (emailError != null || _isLoading) return;
    setState(() => _loadingProvider = _LoginProvider.email);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .resendEmailConfirmation(email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 메일을 다시 보냈어요.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailAuthError(e, isSignUp: true))),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _submitNewPassword() async {
    FocusScope.of(context).unfocus();
    final valid = _resetPasswordFormKey.currentState?.validate() ?? false;
    if (!valid || _isLoading) return;
    setState(() => _loadingProvider = _LoginProvider.email);
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .updatePassword(_newPasswordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었어요.')));
      _switchMode(_AuthMode.login);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailAuthError(e, isSignUp: false))),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _submitEmailSignUp() async {
    FocusScope.of(context).unfocus();
    final valid = _signUpFormKey.currentState?.validate() ?? false;
    if (!valid || !_canCreateEmailAccount || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _loadingProvider = _LoginProvider.email);
    try {
      final storage = ref.read(tokenStorageProvider);
      await storage.saveConsent(
        termsVersion: ConsentPolicy.termsVersion,
        privacyVersion: ConsentPolicy.privacyVersion,
        marketingOptIn: _marketingChecked,
        agreedAtIso: DateTime.now().toIso8601String(),
      );
      await ref
          .read(authViewModelProvider.notifier)
          .signUpWithEmail(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            marketingOptIn: _marketingChecked,
          );
      if (!mounted) return;
      setState(() {
        _pendingConfirmationEmail = _emailController.text.trim();
        _showSignUpConfirmation = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyEmailAuthError(e, isSignUp: true))),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _showSignUpConfirmation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8EFE2),
      body: _AuthResponsiveShell(
        animateIn: _animateIn,
        form: switch (_mode) {
          _AuthMode.login => _buildLoginCard(context),
          _AuthMode.emailLogin => _buildEmailLoginCard(context),
          _AuthMode.signup => _buildSignUpCard(context),
          _AuthMode.resetRequest ||
          _AuthMode.resetPassword => _buildResetPasswordCard(context),
        },
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return _AuthPaperCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CardEyebrow('Snapfit 계정'),
          SizedBox(height: 8.h),
          Text('내 앨범으로 계속하기', style: _titleStyle(context)),
          SizedBox(height: 8.h),
          Text(
            '로그인하면 제작 중인 앨범과 주문 정보를 안전하게 이어볼 수 있어요.',
            style: _bodyStyle(context),
          ),
          SizedBox(height: 22.h),
          _SocialLoginButton.kakao(
            loading: _loadingProvider == _LoginProvider.kakao,
            disabled: _isLoading && _loadingProvider != _LoginProvider.kakao,
            onPressed: _isLoading ? null : _loginWithKakao,
          ),
          SizedBox(height: 10.h),
          _SocialLoginButton.google(
            loading: _loadingProvider == _LoginProvider.google,
            disabled: _isLoading && _loadingProvider != _LoginProvider.google,
            onPressed: _isLoading ? null : _loginWithGoogle,
          ),
          if (_isLoading) ...[
            SizedBox(height: 14.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: const CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 8.w),
                Text(
                  '로그인 중…',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16.h),
          const _DividerWithText('또는'),
          SizedBox(height: 12.h),
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => _switchMode(_AuthMode.emailLogin),
            style: _outlineButtonStyle(context),
            child: const Text('이메일로 로그인'),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: _isLoading ? null : () => _switchMode(_AuthMode.signup),
            child: const Text('이메일로 새 계정 만들기'),
          ),
          SizedBox(height: 12.h),
          _TermsFooter(
            onTerms: () => _openTerms(TermsPolicyDocType.terms),
            onPrivacy: () => _openTerms(TermsPolicyDocType.privacy),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailLoginCard(BuildContext context) {
    return _AuthPaperCard(
      maxWidth: 500,
      child: Form(
        key: _emailLoginFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardEyebrow('이메일 로그인'),
                      SizedBox(height: 8.h),
                      Text('이메일로 계속하기', style: _titleStyle(context)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '소셜 로그인으로 돌아가기',
                  onPressed: () => _switchMode(_AuthMode.login),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _AuthTextField(
              controller: _loginEmailController,
              label: '이메일',
              hint: 'snapfit@example.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            SizedBox(height: 10.h),
            _AuthTextField(
              controller: _loginPasswordController,
              label: '비밀번호',
              hint: '비밀번호 입력',
              obscureText: !_showLoginPassword,
              autofillHints: const [AutofillHints.password],
              validator: (value) =>
                  (value == null || value.isEmpty) ? '비밀번호를 입력해주세요.' : null,
              suffixIcon: IconButton(
                tooltip: _showLoginPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                onPressed: () =>
                    setState(() => _showLoginPassword = !_showLoginPassword),
                icon: Icon(
                  _showLoginPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _resetEmailController.text = _loginEmailController.text
                      .trim();
                  _switchMode(_AuthMode.resetRequest);
                },
                child: const Text('비밀번호를 잊으셨나요?'),
              ),
            ),
            SizedBox(height: 6.h),
            ElevatedButton(
              onPressed: _isLoading ? null : _loginWithEmail,
              style: _primaryButtonStyle(context),
              child: _loadingProvider == _LoginProvider.email
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('이메일로 로그인'),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => _switchMode(_AuthMode.signup),
              child: const Text('새 계정 만들기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetPasswordCard(BuildContext context) {
    final isUpdate = _mode == _AuthMode.resetPassword;
    return _AuthPaperCard(
      maxWidth: 500,
      child: Form(
        key: _resetPasswordFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardEyebrow('계정 복구'),
                      SizedBox(height: 8.h),
                      Text(
                        isUpdate ? '새 비밀번호 설정' : '비밀번호 찾기',
                        style: _titleStyle(context),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '로그인으로 돌아가기',
                  onPressed: () => _switchMode(_AuthMode.emailLogin),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              isUpdate
                  ? '메일 인증 링크가 확인되었어요. 앞으로 사용할 새 비밀번호를 입력해주세요.'
                  : '가입한 이메일을 입력하면 비밀번호 재설정 링크를 보내드릴게요.',
              style: _bodyStyle(context),
            ),
            SizedBox(height: 14.h),
            if (!isUpdate) ...[
              _AuthTextField(
                controller: _resetEmailController,
                label: '이메일',
                hint: 'snapfit@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              SizedBox(height: 14.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _requestPasswordReset,
                style: _primaryButtonStyle(context),
                child: _loadingProvider == _LoginProvider.email
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('재설정 메일 보내기'),
              ),
            ] else ...[
              _AuthTextField(
                controller: _newPasswordController,
                label: '새 비밀번호',
                hint: '8자 이상, 영문+숫자',
                obscureText: !_showNewPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
                suffixIcon: IconButton(
                  tooltip: _showNewPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                  icon: Icon(
                    _showNewPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              _AuthTextField(
                controller: _newPasswordConfirmController,
                label: '새 비밀번호 확인',
                hint: '한 번 더 입력',
                obscureText: !_showNewPasswordConfirm,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => value != _newPasswordController.text
                    ? '비밀번호가 서로 달라요.'
                    : null,
                suffixIcon: IconButton(
                  tooltip: _showNewPasswordConfirm ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () => setState(
                    () => _showNewPasswordConfirm = !_showNewPasswordConfirm,
                  ),
                  icon: Icon(
                    _showNewPasswordConfirm
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitNewPassword,
                style: _primaryButtonStyle(context),
                child: const Text('비밀번호 변경하기'),
              ),
            ],
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => _switchMode(_AuthMode.emailLogin),
              child: const Text('이메일 로그인으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpCard(BuildContext context) {
    if (_showSignUpConfirmation) {
      return _AuthPaperCard(
        maxWidth: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardEyebrow('이메일 가입'),
            SizedBox(height: 8.h),
            Text('확인 메일을 보냈어요', style: _titleStyle(context)),
            SizedBox(height: 8.h),
            Text(
              '메일함에서 인증을 마치면 Snapfit 앨범을 이어서 만들 수 있어요. 기능 연결 전 UI 검증용 상태입니다.',
              style: _bodyStyle(context),
            ),
            SizedBox(height: 18.h),
            OutlinedButton(
              onPressed: _isLoading ? null : _resendConfirmationEmail,
              style: _outlineButtonStyle(context),
              child: const Text('인증 메일 다시 보내기'),
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () => _switchMode(_AuthMode.login),
              style: _primaryButtonStyle(context),
              child: const Text('로그인으로 돌아가기'),
            ),
          ],
        ),
      );
    }

    return _AuthPaperCard(
      maxWidth: 520,
      child: Form(
        key: _signUpFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CardEyebrow('이메일 가입'),
                      SizedBox(height: 8.h),
                      Text('Snapfit 계정 만들기', style: _titleStyle(context)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '로그인으로 돌아가기',
                  onPressed: () => _switchMode(_AuthMode.login),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SizedBox(height: 14.h),
            _AuthTextField(
              controller: _nameController,
              label: '이름',
              hint: '앨범에 표시할 이름',
              autofillHints: const [AutofillHints.name],
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? '이름을 입력해주세요.'
                  : null,
            ),
            SizedBox(height: 10.h),
            _AuthTextField(
              controller: _emailController,
              label: '이메일',
              hint: 'snapfit@example.com',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: _validateEmail,
            ),
            SizedBox(height: 10.h),
            _AuthTextField(
              controller: _passwordController,
              label: '비밀번호',
              hint: '8자 이상',
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.newPassword],
              validator: _validatePassword,
              suffixIcon: IconButton(
                tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            SizedBox(height: 10.h),
            _AuthTextField(
              controller: _passwordConfirmController,
              label: '비밀번호 확인',
              hint: '한 번 더 입력',
              obscureText: !_showPasswordConfirm,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) =>
                  value != _passwordController.text ? '비밀번호가 서로 달라요.' : null,
              suffixIcon: IconButton(
                tooltip: _showPasswordConfirm ? '비밀번호 숨기기' : '비밀번호 보기',
                onPressed: () => setState(
                  () => _showPasswordConfirm = !_showPasswordConfirm,
                ),
                icon: Icon(
                  _showPasswordConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            _TermsCheckTile(
              value: _termsChecked,
              requiredLabel: true,
              label: '이용약관 동의',
              onChanged: (v) => setState(() => _termsChecked = v),
              onView: () => _openTerms(TermsPolicyDocType.terms),
            ),
            _TermsCheckTile(
              value: _privacyChecked,
              requiredLabel: true,
              label: '개인정보처리방침 동의',
              onChanged: (v) => setState(() => _privacyChecked = v),
              onView: () => _openTerms(TermsPolicyDocType.privacy),
            ),
            _TermsCheckTile(
              value: _marketingChecked,
              label: '마케팅 정보 수신 동의',
              onChanged: (v) => setState(() => _marketingChecked = v),
            ),
            SizedBox(height: 14.h),
            ElevatedButton(
              onPressed: _canCreateEmailAccount && !_isLoading
                  ? _submitEmailSignUp
                  : null,
              style: _primaryButtonStyle(context),
              child: _loadingProvider == _LoginProvider.email
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('계정 만들기'),
            ),
            SizedBox(height: 8.h),
            TextButton(
              onPressed: () => _switchMode(_AuthMode.login),
              child: const Text('이미 계정이 있어요'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthResponsiveShell extends StatelessWidget {
  const _AuthResponsiveShell({required this.animateIn, required this.form});

  final bool animateIn;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final isLandscape = size.width > size.height;
        final isTablet = size.width >= 840;
        final compactLandscape = isLandscape && size.height < 430;
        final horizontal = isLandscape || isTablet;
        final maxContentWidth = isTablet ? 1180.0 : double.infinity;

        final content = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: horizontal
              ? Row(
                  children: [
                    Expanded(
                      flex: isTablet ? 56 : 54,
                      child: _AuthHeroPane(compact: compactLandscape),
                    ),
                    SizedBox(width: isTablet ? 26.w : 12.w),
                    Expanded(
                      flex: isTablet ? 44 : 46,
                      child: Align(
                        alignment: isTablet
                            ? Alignment.centerLeft
                            : Alignment.center,
                        child: form,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _AuthHeroPane(compact: size.height < 720),
                    SizedBox(height: 18.h),
                    form,
                  ],
                ),
        );

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEFE2D0), Color(0xFFF8EFE2)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontal ? 28.w : 22.w,
                  vertical: compactLandscape ? 14.h : 22.h,
                ),
                child: AnimatedOpacity(
                  opacity: animateIn ? 1 : 0,
                  duration: const Duration(milliseconds: 360),
                  child: AnimatedSlide(
                    offset: animateIn ? Offset.zero : const Offset(0, 0.035),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuthHeroPane extends StatelessWidget {
  const _AuthHeroPane({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;
    final previewHeight = isLandscape
        ? (compact ? 150.0 : 250.0)
        : (compact ? 150.h : 220.h);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isLandscape
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.62),
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
                fontSize: isLandscape ? 28 : 30.sp,
                letterSpacing: -0.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF141312),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10.h : 16.h),
        Text(
          '추억을 한 권의 앨범으로',
          textAlign: isLandscape ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isLandscape ? 30 : 25.sp,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF141312),
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          '사진을 고르고, 넘기고, 간직하는 가장 쉬운 방법',
          textAlign: isLandscape ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isLandscape ? 14 : 12.5.sp,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4F4941),
          ),
        ),
        SizedBox(height: compact ? 12.h : 20.h),
        SizedBox(height: previewHeight, child: const _AuthAlbumPreview()),
        if (isLandscape && !compact) ...[
          SizedBox(height: 18.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: const [
              _BenefitPill('앨범 제작 이어보기'),
              _BenefitPill('공유 초대와 주문 관리'),
              _BenefitPill('사진과 문구를 안전하게 저장'),
            ],
          ),
        ],
      ],
    );
  }
}

class _AuthAlbumPreview extends StatelessWidget {
  const _AuthAlbumPreview();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth.clamp(210.0, 360.0);
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _PreviewCover(
                  asset: 'assets/snapfit_home_landscape.jpg',
                  width: width * 0.72,
                  height: height * 0.62,
                  angle: -0.13,
                  offset: Offset(-width * 0.14, height * 0.02),
                  opacity: 0.72,
                ),
                _PreviewCover(
                  asset: 'assets/snapfit_home_square.jpg',
                  width: height * 0.62,
                  height: height * 0.62,
                  angle: 0.11,
                  offset: Offset(width * 0.16, -height * 0.01),
                  opacity: 0.82,
                ),
                _PreviewCover(
                  asset: 'assets/snapfit_home_portrait.jpg',
                  width: height * 0.53,
                  height: height * 0.76,
                  angle: -0.02,
                  offset: Offset.zero,
                  opacity: 1,
                  foreground: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewCover extends StatelessWidget {
  const _PreviewCover({
    required this.asset,
    required this.width,
    required this.height,
    required this.angle,
    required this.offset,
    required this.opacity,
    this.foreground = false,
  });

  final String asset;
  final double width;
  final double height;
  final double angle;
  final Offset offset;
  final double opacity;
  final bool foreground;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: Transform.rotate(
        angle: angle,
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.r),
                bottomLeft: Radius.circular(8.r),
                topRight: Radius.circular(22.r),
                bottomRight: Radius.circular(22.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(foreground ? 0.18 : 0.10),
                  blurRadius: foreground ? 28.r : 18.r,
                  offset: Offset(0, foreground ? 14.h : 8.h),
                ),
              ],
              image: DecorationImage(
                image: AssetImage(asset),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPaperCard extends StatelessWidget {
  const _AuthPaperCard({
    required this.child,
    this.maxWidth = 430,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          width: double.infinity,
          padding: padding ?? EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 20.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.86),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: Colors.white.withOpacity(0.68)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.11),
                blurRadius: 30.r,
                offset: Offset(0, 16.h),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardEyebrow extends StatelessWidget {
  const _CardEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        color: SnapFitColors.textMutedOf(context),
      ),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.52),
        borderRadius: BorderRadius.circular(999.r),
        border: Border.all(color: Colors.white.withOpacity(0.58)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF4F4941),
        ),
      ),
    );
  }
}

class _DividerWithText extends StatelessWidget {
  const _DividerWithText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.sp,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
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
    required this.disabled,
    this.borderColor,
  });

  factory _SocialLoginButton.kakao({
    required VoidCallback? onPressed,
    required bool loading,
    required bool disabled,
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
      disabled: disabled,
    );
  }

  factory _SocialLoginButton.google({
    required VoidCallback? onPressed,
    required bool loading,
    required bool disabled,
  }) {
    return _SocialLoginButton(
      label: 'Google로 계속하기',
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      borderColor: const Color(0xFFD1D5DB),
      icon: SvgPicture.asset('assets/social/google.svg', width: 18, height: 18),
      onPressed: onPressed,
      loading: loading,
      disabled: disabled,
    );
  }

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: SizedBox(
        width: double.infinity,
        height: 54.h,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: foregroundColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF141312),
          ),
        ),
        SizedBox(height: 6.h),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white.withOpacity(0.92),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 15.w,
              vertical: 14.h,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15.r),
              borderSide: BorderSide(
                color: SnapFitColors.accent.withOpacity(0.9),
                width: 1.4,
              ),
            ),
            suffixIcon: suffixIcon,
            errorStyle: TextStyle(fontSize: 10.5.sp, height: 1.2),
          ),
        ),
      ],
    );
  }
}

class _TermsCheckTile extends StatelessWidget {
  const _TermsCheckTile({
    required this.value,
    required this.label,
    required this.onChanged,
    this.requiredLabel = false,
    this.onView,
  });

  final bool value;
  final bool requiredLabel;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Text(
                '${requiredLabel ? '[필수] ' : '[선택] '}$label',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: requiredLabel ? FontWeight.w800 : FontWeight.w600,
                  color: requiredLabel
                      ? const Color(0xFF141312)
                      : SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
            if (onView != null)
              TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  minimumSize: Size(44.w, 36.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('보기'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TermsFooter extends StatelessWidget {
  const _TermsFooter({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '최초 로그인 시 이용약관/개인정보처리방침 동의가 필요하며, 동의 이력은 계정과 기기에 안전하게 보관됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.sp,
            height: 1.45,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FooterLink(label: '이용약관', onTap: onTerms),
            Text(
              ' · ',
              style: TextStyle(
                fontSize: 12.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
            _FooterLink(label: '개인정보처리방침', onTap: onPrivacy),
          ],
        ),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 7.h),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.underline,
            color: SnapFitColors.textSecondaryOf(context),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _outlineButtonStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: Size.fromHeight(48.h),
    foregroundColor: const Color(0xFF141312),
    side: BorderSide(color: const Color(0xFF141312).withOpacity(0.18)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
  );
}

ButtonStyle _primaryButtonStyle(BuildContext context) {
  return ElevatedButton.styleFrom(
    minimumSize: Size.fromHeight(52.h),
    backgroundColor: const Color(0xFF141312),
    foregroundColor: Colors.white,
    disabledBackgroundColor: const Color(0xFF141312).withOpacity(0.24),
    disabledForegroundColor: Colors.white.withOpacity(0.72),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
    textStyle: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900),
  );
}

TextStyle _titleStyle(BuildContext context) {
  return TextStyle(
    fontSize: 24.sp,
    height: 1.15,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w900,
    color: SnapFitColors.textPrimaryOf(context),
  );
}

TextStyle _bodyStyle(BuildContext context) {
  return TextStyle(
    fontSize: 12.5.sp,
    height: 1.48,
    fontWeight: FontWeight.w600,
    color: SnapFitColors.textSecondaryOf(context),
  );
}

enum _LoginProvider { kakao, google, email }

enum _AuthMode { login, emailLogin, signup, resetRequest, resetPassword }
