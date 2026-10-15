import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_theme.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../profile/presentation/views/terms_policy_screen.dart';
import '../../../album/presentation/widgets/home/home_cover_frame.dart';
import '../../../album/presentation/widgets/cover/album_spine_image.dart';
import '../../domain/consent_policy.dart';
import '../../domain/web_oauth.dart';
import '../viewmodels/auth_view_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.startInPasswordReset = false,
    this.authNotice,
  });

  final bool startInPasswordReset;
  final String? authNotice;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _LoginProvider? _loadingProvider;
  bool _confirmingConsent = false;
  bool _webRedirectStarted = false;
  late _AuthMode _mode;
  bool _animateIn = false;
  final _scrollController = ScrollController();
  final _formHostKey = GlobalKey();

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
  bool _resetEmailSent = false;
  bool _confirmationEmailResent = false;
  bool _passwordChangeComplete = false;
  bool _termsChecked = false;
  bool _privacyChecked = false;
  bool _marketingChecked = false;
  bool _showSignUpConfirmation = false;
  String? _emailFormError;
  int _confirmationCooldown = 0;
  int _resetCooldown = 0;
  Timer? _confirmationCooldownTimer;
  Timer? _resetCooldownTimer;

  bool get _isLoading => _loadingProvider != null;
  bool get _canCreateEmailAccount => _termsChecked && _privacyChecked;

  @override
  void initState() {
    super.initState();
    _emailFormError = widget.authNotice;
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
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authNotice != widget.authNotice &&
        widget.authNotice != null) {
      _emailFormError = widget.authNotice;
    }
  }

  @override
  void dispose() {
    _confirmationCooldownTimer?.cancel();
    _resetCooldownTimer?.cancel();
    _scrollController.dispose();
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

  Future<void> _loginWithKakao() => _loginWithSocial(_LoginProvider.kakao);
  Future<void> _loginWithGoogle() => _loginWithSocial(_LoginProvider.google);

  Future<void> _loginWithSocial(_LoginProvider provider) async {
    if (!mounted || _isLoading || ModalRoute.of(context)?.isCurrent == false)
      return;
    setState(() {
      _loadingProvider = provider;
      _confirmingConsent = true;
    });
    try {
      if (!await _ensureConsentBeforeLogin()) return;
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      setState(() => _confirmingConsent = false);
      final auth = ref.read(authViewModelProvider.notifier);
      if (provider == _LoginProvider.kakao) {
        await auth.loginWithKakao();
      } else {
        await auth.loginWithGoogle();
      }
      if (kIsWeb) {
        // Redirect launch is not login success. AuthGate switches only after
        // Supabase returns a verified session on the callback page.
        _webRedirectStarted = true;
      } else {
        await auth.syncConsentIfPresent();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            socialAuthErrorMessage(
              e,
              provider: provider == _LoginProvider.kakao ? '카카오' : 'Google',
            ),
          ),
        ),
      );
    } finally {
      if (mounted && !_webRedirectStarted)
        setState(() {
          _loadingProvider = null;
          _confirmingConsent = false;
        });
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

    FocusScope.of(context).unfocus();
    final result = kIsWeb
        ? await showDialog<_AuthConsentChoice>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: WebPalette.of(dialogContext).surface,
              surfaceTintColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 620,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * .88),
                child: _AuthConsentSheet(onView: _openTerms),
              ),
            ),
          )
        : await showModalBottomSheet<_AuthConsentChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      backgroundColor: Colors.transparent,
      builder: (_) => _AuthConsentSheet(onView: _openTerms),
    );

    if (result == null || !result.terms || !result.privacy || !mounted)
      return false;
    await storage.saveConsent(
      termsVersion: ConsentPolicy.termsVersion,
      privacyVersion: ConsentPolicy.privacyVersion,
      marketingOptIn: result.marketing,
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
    if (raw.contains('rate_limit') ||
        raw.contains('rate limit') ||
        raw.contains('over_email_send_rate') ||
        raw.contains('too many')) {
      return '요청이 잠시 많아졌어요. 조금 뒤에 다시 시도해주세요.';
    }
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
    if (!mounted ||
        _isLoading ||
        _mode != _AuthMode.emailLogin ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    FocusScope.of(context).unfocus();
    final valid = _emailLoginFormKey.currentState?.validate() ?? false;
    if (!valid || _isLoading) return;
    setState(() {
      _emailFormError = null;
      _loadingProvider = _LoginProvider.email;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .loginWithEmail(
            email: _loginEmailController.text.trim(),
            password: _loginPasswordController.text,
          );
      TextInput.finishAutofillContext();
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _emailFormError = _friendlyEmailAuthError(e, isSignUp: false),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _requestPasswordReset() async {
    if (!mounted ||
        _mode != _AuthMode.resetRequest ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    FocusScope.of(context).unfocus();
    if (_isLoading || _resetCooldown > 0) return;
    if (!(_resetPasswordFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _emailFormError = null;
      _loadingProvider = _LoginProvider.email;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .requestPasswordReset(_resetEmailController.text.trim());
      if (!mounted) return;
      setState(() => _resetEmailSent = true);
      _startEmailCooldown(confirmation: false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호 재설정 메일을 보냈어요.')));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _emailFormError = _friendlyEmailAuthError(e, isSignUp: false),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _resendConfirmationEmail() async {
    if (!mounted ||
        _mode != _AuthMode.signup ||
        !_showSignUpConfirmation ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    final email =
        _pendingConfirmationEmail?.trim() ?? _emailController.text.trim();
    final emailError = _validateEmail(email);
    if (emailError != null || _isLoading || _confirmationCooldown > 0) return;
    setState(() {
      _emailFormError = null;
      _loadingProvider = _LoginProvider.email;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .resendEmailConfirmation(email);
      if (!mounted) return;
      setState(() => _confirmationEmailResent = true);
      _startEmailCooldown(confirmation: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('인증 메일을 다시 보냈어요.')));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _emailFormError = _friendlyEmailAuthError(e, isSignUp: true),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!mounted ||
        _isLoading ||
        _mode != _AuthMode.resetPassword ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    FocusScope.of(context).unfocus();
    final valid = _resetPasswordFormKey.currentState?.validate() ?? false;
    if (!valid || _isLoading) return;
    setState(() {
      _emailFormError = null;
      _loadingProvider = _LoginProvider.email;
    });
    try {
      await ref
          .read(authViewModelProvider.notifier)
          .updatePassword(_newPasswordController.text);
      TextInput.finishAutofillContext();
      if (!mounted) return;
      setState(() => _passwordChangeComplete = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었어요.')));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _emailFormError = _friendlyEmailAuthError(e, isSignUp: false),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _submitEmailSignUp() async {
    if (!mounted ||
        _isLoading ||
        _mode != _AuthMode.signup ||
        _showSignUpConfirmation ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    FocusScope.of(context).unfocus();
    final valid = _signUpFormKey.currentState?.validate() ?? false;
    if (!valid || !_canCreateEmailAccount || _isLoading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _emailFormError = null;
      _loadingProvider = _LoginProvider.email;
    });
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
      _startEmailCooldown(confirmation: true);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _emailFormError = _friendlyEmailAuthError(e, isSignUp: true),
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  void _switchMode(_AuthMode mode) {
    if (!mounted || _isLoading || ModalRoute.of(context)?.isCurrent == false)
      return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _mode = mode;
      _emailFormError = null;
      _showSignUpConfirmation = false;
      if (mode != _AuthMode.resetRequest) _resetEmailSent = false;
      if (mode != _AuthMode.resetPassword) _passwordChangeComplete = false;
      if (mode != _AuthMode.signup) _confirmationEmailResent = false;
    });
  }

  // UI pacing only. The authentication server remains the rate-limit authority.
  void _startEmailCooldown({required bool confirmation}) {
    if (confirmation) {
      _confirmationCooldownTimer?.cancel();
    } else {
      _resetCooldownTimer?.cancel();
    }
    setState(() {
      if (confirmation) {
        _confirmationCooldown = 60;
      } else {
        _resetCooldown = 60;
      }
    });
    final cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final remaining = (60 - timer.tick).clamp(0, 60);
      setState(() {
        if (confirmation) {
          _confirmationCooldown = remaining;
        } else {
          _resetCooldown = remaining;
        }
      });
      if (remaining == 0) {
        timer.cancel();
      }
    });
    if (confirmation) {
      _confirmationCooldownTimer = cooldown;
    } else {
      _resetCooldownTimer = cooldown;
    }
  }

  Widget _emailErrorNotice() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _InlineAuthNotice(
      icon: Icons.error_outline,
      text: _emailFormError!,
      error: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Theme(
        data: SnapFitWebTheme.from(Theme.of(context)),
        child: Builder(builder: _buildWebLogin),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SnapFitTheme.systemOverlayStyle(context),
      child: Scaffold(
        backgroundColor: SnapFitColors.backgroundOf(context),
        body: _AuthResponsiveShell(
          controller: _scrollController,
          animateIn: _animateIn,
          mode: _mode,
          keyboardOpen: MediaQuery.viewInsetsOf(context).bottom > 0,
          form: KeyedSubtree(
            key: _formHostKey,
            child: Semantics(
              container: true,
              child: switch (_mode) {
                _AuthMode.login => _buildLoginCard(context),
                _AuthMode.emailLogin => _buildEmailLoginCard(context),
                _AuthMode.signup => _buildSignUpCard(context),
                _AuthMode.resetRequest ||
                _AuthMode.resetPassword => _buildResetPasswordCard(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebLogin(BuildContext context) {
    final form = KeyedSubtree(
      key: _formHostKey,
      child: switch (_mode) {
        _AuthMode.login => _buildLoginCard(context),
        _AuthMode.emailLogin => _buildEmailLoginCard(context),
        _AuthMode.signup => _buildSignUpCard(context),
        _AuthMode.resetRequest || _AuthMode.resetPassword =>
          _buildResetPasswordCard(context),
      },
    );
    return SnapFitWebShell(
      showNavigation: false,
      actions: [
        TextButton(
          onPressed: () => _openTerms(TermsPolicyDocType.terms),
          child: const Text('이용 안내'),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 940;
          final introduction = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('YOUR STORIES, BEAUTIFULLY KEPT',
                style: TextStyle(fontSize: 11, letterSpacing: 1.8,
                  fontWeight: FontWeight.w600, color: WebPalette.of(context).brandInk)),
              const SizedBox(height: 24),
              Text('사진에 담긴 순간을\n나만의 이야기로.',
                style: TextStyle(fontSize: wide ? 46 : 32, height: 1.28,
                  letterSpacing: -1.6, fontWeight: FontWeight.w600,
                  color: WebPalette.of(context).ink)),
              const SizedBox(height: 20),
              Text('일상과 여행, 함께한 시간을 한곳에 모으세요.\n사진을 고르고 이야기를 더하면 나만의 앨범이 됩니다.',
                style: TextStyle(fontSize: 16, height: 1.8,
                  color: WebPalette.of(context).muted)),
              if (wide) ...[
                const SizedBox(height: 40),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.65,
                    child: Image.asset(
                      'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, .25),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Text('A MOMENT WORTH KEEPING',
                    style: TextStyle(fontSize: 10, letterSpacing: 1.4,
                      color: WebPalette.of(context).muted)),
                  const Spacer(),
                  Text('사진에서 시작하는 나의 기록',
                    style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
                ]),
              ],
            ],
          );
          final entry = WebSurface(
            padding: EdgeInsets.all(wide ? 36 : 24),
            child: form,
          );
          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(vertical: wide ? 48 : 20),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Padding(
                        padding: const EdgeInsets.only(right: 72),
                        child: introduction,
                      )),
                      SizedBox(width: 450, child: entry),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [introduction, const SizedBox(height: 32), entry],
                  ),
          );
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
          if (_emailFormError != null) ...[
            _emailErrorNotice(),
            const SizedBox(height: 12),
          ],
          Text('내 앨범으로 계속하기', style: _titleStyle(context)),
          SizedBox(height: 22),
          _SocialLoginButton.kakao(
            loading:
                _loadingProvider == _LoginProvider.kakao && !_confirmingConsent,
            disabled:
                _isLoading &&
                (_loadingProvider != _LoginProvider.kakao ||
                    _confirmingConsent),
            onPressed: _isLoading ? null : _loginWithKakao,
          ),
          SizedBox(height: 10),
          _SocialLoginButton.google(
            loading:
                _loadingProvider == _LoginProvider.google &&
                !_confirmingConsent,
            disabled:
                _isLoading &&
                (_loadingProvider != _LoginProvider.google ||
                    _confirmingConsent),
            onPressed: _isLoading ? null : _loginWithGoogle,
          ),
          if (_isLoading && !_confirmingConsent) ...[
            SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: const CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(width: 8),
                Text(
                  '로그인 중…',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: 16),
          const _DividerWithText('또는'),
          SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoading
                ? null
                : () => _switchMode(_AuthMode.emailLogin),
            style: _outlineButtonStyle(context),
            child: const Text('이메일로 로그인'),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : () => _switchMode(_AuthMode.signup),
            child: const Text('이메일로 새 계정 만들기'),
          ),
          SizedBox(height: 12),
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
        child: _AuthFormLayout(
          header: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardEyebrow('이메일 로그인'),
                    SizedBox(height: 8),
                    Text('이메일로 계속하기', style: _titleStyle(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: '소셜 로그인으로 돌아가기',
                onPressed: _isLoading
                    ? null
                    : () => _switchMode(_AuthMode.login),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          fields: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthTextField(
                enabled: !_isLoading,
                controller: _loginEmailController,
                label: '이메일',
                hint: 'snapfit@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              SizedBox(height: 10),
              _AuthTextField(
                enabled: !_isLoading,
                controller: _loginPasswordController,
                label: '비밀번호',
                hint: '비밀번호 입력',
                obscureText: !_showLoginPassword,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _loginWithEmail(),
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
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_emailFormError != null) _emailErrorNotice(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _resetEmailController.text = _loginEmailController
                              .text
                              .trim();
                          _switchMode(_AuthMode.resetRequest);
                        },
                  child: const Text('비밀번호를 잊으셨나요?'),
                ),
              ),
            ],
          ),
          action: ElevatedButton(
            key: const ValueKey('auth-email-submit'),
            onPressed: _isLoading ? null : _loginWithEmail,
            style: _primaryButtonStyle(context),
            child: _loadingProvider == _LoginProvider.email
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: kIsWeb ? WebPalette.of(context).onBrand : Colors.white,
                    ),
                  )
                : const Text('이메일로 로그인'),
          ),
          secondary: TextButton(
            onPressed: _isLoading ? null : () => _switchMode(_AuthMode.signup),
            child: const Text('새 계정 만들기'),
          ),
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
        child: _AuthFormLayout(
          header: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardEyebrow('계정 복구'),
                    SizedBox(height: 8),
                    Text(
                      isUpdate ? '새 비밀번호 설정' : '비밀번호 찾기',
                      style: _titleStyle(context),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '로그인으로 돌아가기',
                onPressed: _isLoading
                    ? null
                    : () => _switchMode(_AuthMode.emailLogin),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isUpdate
                    ? '메일 인증 링크가 확인되었어요. 앞으로 사용할 새 비밀번호를 입력해주세요.'
                    : '가입한 이메일을 입력하면 비밀번호 재설정 링크를 보내드릴게요.',
                style: _bodyStyle(context),
              ),
              SizedBox(height: 14),
              if (_emailFormError != null) _emailErrorNotice(),
              if (_resetEmailSent)
                const _InlineAuthNotice(
                  icon: Icons.mark_email_read_rounded,
                  text: '입력한 이메일로 재설정 링크를 보냈어요. 메일함을 확인해주세요.',
                ),
              if (_passwordChangeComplete)
                const _InlineAuthNotice(
                  icon: Icons.check_circle_rounded,
                  text: '비밀번호가 변경되었어요. 이제 새 비밀번호로 로그인할 수 있어요.',
                ),
            ],
          ),
          fields: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isUpdate) ...[
                _AuthTextField(
                  enabled: !_isLoading,
                  controller: _resetEmailController,
                  label: '이메일',
                  hint: 'snapfit@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: _validateEmail,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _requestPasswordReset(),
                ),
              ] else ...[
                _AuthTextField(
                  enabled: !_isLoading,
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
                const SizedBox(height: 10),
                _PasswordRequirements(controller: _newPasswordController),
                SizedBox(height: 10),
                _AuthTextField(
                  enabled: !_isLoading,
                  controller: _newPasswordConfirmController,
                  label: '새 비밀번호 확인',
                  hint: '한 번 더 입력',
                  obscureText: !_showNewPasswordConfirm,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitNewPassword(),
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
              ],
            ],
          ),
          action: ElevatedButton(
            key: ValueKey(
              isUpdate ? 'auth-password-submit' : 'auth-reset-submit',
            ),
            onPressed: _isLoading || (!isUpdate && _resetCooldown > 0)
                ? null
                : isUpdate
                ? _submitNewPassword
                : _requestPasswordReset,
            style: _primaryButtonStyle(context),
            child: _loadingProvider == _LoginProvider.email
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: kIsWeb ? WebPalette.of(context).onBrand : Colors.white,
                    ),
                  )
                : Text(
                    isUpdate
                        ? (_passwordChangeComplete ? '다시 변경하기' : '비밀번호 변경하기')
                        : _resetCooldown > 0
                        ? '$_resetCooldown초 후 다시 보내기'
                        : _resetEmailSent
                        ? '재설정 메일 다시 보내기'
                        : '재설정 메일 보내기',
                  ),
          ),
          secondary: TextButton(
            onPressed: _isLoading
                ? null
                : () => _switchMode(_AuthMode.emailLogin),
            child: const Text('이메일 로그인으로 돌아가기'),
          ),
        ),
      ),
    );
  }

  Widget _buildSignUpCard(BuildContext context) {
    if (_showSignUpConfirmation) {
      return _AuthPaperCard(
        maxWidth: 520,
        child: _AuthFormLayout(
          header: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardEyebrow('이메일 가입'),
                    SizedBox(height: 8),
                    Text('가입 메일 확인', style: _titleStyle(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: '이메일 가입으로 돌아가기',
                onPressed: _isLoading
                    ? null
                    : () => _switchMode(_AuthMode.signup),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          fields: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('받는 이메일', style: _bodyStyle(context)),
              const SizedBox(height: 6),
              SelectableText(
                _pendingConfirmationEmail ?? _emailController.text.trim(),
                key: const Key('signup_confirmation_email'),
                style: ExperienceFormStyle.text(
                  context,
                  16,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '메일의 인증 링크를 열면 가입이 완료돼요. 메일이 보이지 않으면 스팸함도 확인해주세요.',
                style: _bodyStyle(context),
              ),
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              if (_emailFormError != null) _emailErrorNotice(),
              if (_confirmationEmailResent) ...[
                SizedBox(height: 12),
                const _InlineAuthNotice(
                  icon: Icons.mark_email_read_rounded,
                  text: '방금 인증 메일을 다시 보냈어요. 가장 최근 메일의 링크를 열어주세요.',
                ),
              ],
              OutlinedButton(
                key: const ValueKey('auth-confirmation-resend'),
                onPressed: _isLoading || _confirmationCooldown > 0
                    ? null
                    : _resendConfirmationEmail,
                style: _outlineButtonStyle(context),
                child: Text(
                  _confirmationCooldown > 0
                      ? '$_confirmationCooldown초 후 다시 보내기'
                      : '인증 메일 다시 보내기',
                ),
              ),
            ],
          ),
          action: ElevatedButton(
            key: const ValueKey('auth-confirmation-login'),
            onPressed: _isLoading
                ? null
                : () {
                    _loginEmailController.text =
                        _pendingConfirmationEmail ?? '';
                    _switchMode(_AuthMode.emailLogin);
                  },
            style: _primaryButtonStyle(context),
            child: const Text('인증 후 이메일로 로그인'),
          ),
          secondary: TextButton(
            onPressed: _isLoading ? null : () => _switchMode(_AuthMode.signup),
            child: const Text('이메일을 잘못 입력했어요'),
          ),
        ),
      );
    }

    return _AuthPaperCard(
      maxWidth: 520,
      child: Form(
        key: _signUpFormKey,
        child: _AuthFormLayout(
          header: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CardEyebrow('이메일 가입'),
                    SizedBox(height: 8),
                    Text('새 계정 만들기', style: _titleStyle(context)),
                  ],
                ),
              ),
              IconButton(
                tooltip: '로그인으로 돌아가기',
                onPressed: _isLoading
                    ? null
                    : () => _switchMode(_AuthMode.login),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          fields: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AuthTextField(
                enabled: !_isLoading,
                controller: _nameController,
                label: '닉네임',
                hint: '앨범에 표시할 이름',
                autofillHints: const [AutofillHints.nickname],
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '앨범에 표시할 닉네임을 입력해주세요.'
                    : null,
              ),
              SizedBox(height: 10),
              _AuthTextField(
                enabled: !_isLoading,
                controller: _emailController,
                label: '이메일',
                hint: 'snapfit@example.com',
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
              ),
              SizedBox(height: 10),
              _AuthTextField(
                enabled: !_isLoading,
                controller: _passwordController,
                label: '비밀번호',
                hint: '8자 이상',
                obscureText: !_showPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: _validatePassword,
                suffixIcon: IconButton(
                  tooltip: _showPassword ? '비밀번호 숨기기' : '비밀번호 보기',
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _PasswordRequirements(controller: _passwordController),
              SizedBox(height: 10),
              _AuthTextField(
                enabled: !_isLoading,
                controller: _passwordConfirmController,
                label: '비밀번호 확인',
                hint: '한 번 더 입력',
                obscureText: !_showPasswordConfirm,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitEmailSignUp(),
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
            ],
          ),
          aside: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_emailFormError != null) _emailErrorNotice(),
              Text(
                '약관 동의',
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              _TermsCheckTile(
                enabled: !_isLoading,
                value: _termsChecked,
                requiredLabel: true,
                label: '이용약관 동의',
                onChanged: (v) => setState(() => _termsChecked = v),
                onView: () => _openTerms(TermsPolicyDocType.terms),
              ),
              _TermsCheckTile(
                enabled: !_isLoading,
                value: _privacyChecked,
                requiredLabel: true,
                label: '개인정보처리방침 동의',
                onChanged: (v) => setState(() => _privacyChecked = v),
                onView: () => _openTerms(TermsPolicyDocType.privacy),
              ),
              _TermsCheckTile(
                enabled: !_isLoading,
                value: _marketingChecked,
                label: '마케팅 정보 수신 동의',
                onChanged: (v) => setState(() => _marketingChecked = v),
              ),
            ],
          ),
          action: ElevatedButton(
            key: const ValueKey('auth-signup-submit'),
            onPressed: _canCreateEmailAccount && !_isLoading
                ? _submitEmailSignUp
                : null,
            style: _primaryButtonStyle(context),
            child: _loadingProvider == _LoginProvider.email
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: kIsWeb ? WebPalette.of(context).onBrand : Colors.white,
                    ),
                  )
                : const Text('계정 만들기'),
          ),
          secondary: TextButton(
            onPressed: _isLoading ? null : () => _switchMode(_AuthMode.login),
            child: const Text('이미 계정이 있어요'),
          ),
        ),
      ),
    );
  }
}

class _AuthConsentChoice {
  const _AuthConsentChoice({
    required this.terms,
    required this.privacy,
    required this.marketing,
  });
  final bool terms, privacy, marketing;
}

class _AuthConsentSheet extends StatefulWidget {
  const _AuthConsentSheet({required this.onView});
  final ValueChanged<TermsPolicyDocType> onView;
  @override
  State<_AuthConsentSheet> createState() => _AuthConsentSheetState();
}

class _AuthConsentSheetState extends State<_AuthConsentSheet> {
  bool _terms = false, _privacy = false, _marketing = false, _finishing = false;
  void _finish({bool apply = false}) {
    if (!mounted ||
        _finishing ||
        ModalRoute.of(context)?.isCurrent == false ||
        (apply && (!_terms || !_privacy)))
      return;
    _finishing = true;
    Navigator.pop(
      context,
      apply
          ? _AuthConsentChoice(
              terms: _terms,
              privacy: _privacy,
              marketing: _marketing,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final action = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          key: const ValueKey('auth-consent-confirm'),
          onPressed: _terms && _privacy && !_finishing
              ? () => _finish(apply: true)
              : null,
          style: _primaryButtonStyle(context),
          child: const Text('동의하고 계속'),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LayoutBuilder(
        builder: (context, box) => ConstrainedBox(
          key: const ValueKey('auth-social-consent'),
          constraints: BoxConstraints(
            maxHeight: math.min(
              box.maxHeight,
              MediaQuery.sizeOf(context).height * .94,
            ),
          ),
          child: Material(
            color: SnapFitColors.backgroundOf(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '서비스 이용 동의',
                            style: ExperienceFormStyle.text(
                              context,
                              18,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('auth-consent-close'),
                          tooltip: '동의 취소',
                          icon: const Icon(Icons.close),
                          onPressed: () => _finish(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      key: const ValueKey('auth-consent-list'),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _TermsCheckTile(
                            value: _terms,
                            requiredLabel: true,
                            label: '이용약관 동의',
                            onChanged: (value) =>
                                setState(() => _terms = value),
                            onView: () =>
                                widget.onView(TermsPolicyDocType.terms),
                          ),
                          _TermsCheckTile(
                            value: _privacy,
                            requiredLabel: true,
                            label: '개인정보처리방침 동의',
                            onChanged: (value) =>
                                setState(() => _privacy = value),
                            onView: () =>
                                widget.onView(TermsPolicyDocType.privacy),
                          ),
                          _TermsCheckTile(
                            value: _marketing,
                            label: '마케팅 정보 수신 동의',
                            onChanged: (value) =>
                                setState(() => _marketing = value),
                          ),
                          if (box.maxHeight < 220) action,
                        ],
                      ),
                    ),
                  ),
                  if (box.maxHeight >= 220) action,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFormLayout extends StatefulWidget {
  const _AuthFormLayout({
    required this.header,
    required this.fields,
    required this.aside,
    required this.action,
    required this.secondary,
  });
  final Widget header, fields, aside, action, secondary;
  @override
  State<_AuthFormLayout> createState() => _AuthFormLayoutState();
}

class _AuthFormLayoutState extends State<_AuthFormLayout> {
  final _fieldsKey = GlobalKey(),
      _asideKey = GlobalKey(),
      _headerKey = GlobalKey();
  final _fieldsScroll = ScrollController(), _asideScroll = ScrollController();
  Size? _lastSize;
  double? _lastInset;
  Size? _lastExtent;
  bool _focusQueued = false;

  void _ensureFocusAfterLayout() {
    if (_focusQueued) return;
    _focusQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusQueued = false;
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final focus = FocusManager.instance.primaryFocus;
      final input = focus?.context;
      if (focus?.hasFocus == true && input != null && input.mounted)
        Scrollable.ensureVisible(input, alignment: .25);
    });
  }

  @override
  void dispose() {
    _fieldsScroll.dispose();
    _asideScroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    if (_lastSize == media.size && _lastInset == media.viewInsets.bottom)
      return;
    _lastSize = media.size;
    _lastInset = media.viewInsets.bottom;
    _ensureFocusAfterLayout();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final extent = Size(box.maxWidth, box.maxHeight);
      if (_lastExtent != extent) {
        _lastExtent = extent;
        _ensureFocusAfterLayout();
      }
      final header = KeyedSubtree(key: _headerKey, child: widget.header);
      final fields = KeyedSubtree(key: _fieldsKey, child: widget.fields);
      final aside = KeyedSubtree(key: _asideKey, child: widget.aside);
      final wide =
          MediaQuery.orientationOf(context) == Orientation.landscape &&
          box.maxWidth >= 480 &&
          box.hasBoundedHeight;
      if (!wide)
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 14),
            fields,
            const SizedBox(height: 16),
            aside,
            const SizedBox(height: 14),
            widget.action,
            const SizedBox(height: 8),
            widget.secondary,
          ],
        );
      final compactHeader = box.maxHeight < 220;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compactHeader) ...[header, const SizedBox(height: 8)],
          Expanded(
            child: LayoutBuilder(
              builder: (context, body) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: PageStorageKey(_fieldsKey),
                      controller: _fieldsScroll,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compactHeader) ...[
                            header,
                            const SizedBox(height: 8),
                          ],
                          fields,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  VerticalDivider(
                    width: 1,
                    color: ExperienceFormStyle.line(context),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: body.maxHeight < 160
                        ? SingleChildScrollView(
                            controller: _asideScroll,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                aside,
                                const SizedBox(height: 8),
                                widget.action,
                                const SizedBox(height: 4),
                                widget.secondary,
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  key: PageStorageKey(_asideKey),
                                  controller: _asideScroll,
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      aside,
                                      const SizedBox(height: 8),
                                      widget.secondary,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              widget.action,
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _AuthResponsiveShell extends StatelessWidget {
  const _AuthResponsiveShell({
    required this.controller,
    required this.animateIn,
    required this.mode,
    required this.form,
    required this.keyboardOpen,
  });

  final bool animateIn;
  final ScrollController controller;
  final _AuthMode mode;
  final Widget form;
  final bool keyboardOpen;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final login = mode == _AuthMode.login;
        final wide =
            constraints.maxWidth >= 540 &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final reducedMotion = MediaQuery.disableAnimationsOf(context);
        final brand = Row(
          key: const ValueKey('auth-brand'),
          children: [
            Image.asset('assets/snapfit_logo.png', width: 30, height: 30),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'SnapFit',
                  style: TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 24,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700,
                    color: ExperienceFormStyle.ink(context),
                  ),
                ),
              ),
            ),
          ],
        );
        if (wide)
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: login
                    ? Row(
                        children: [
                          SizedBox(
                            width: (constraints.maxWidth * .34).clamp(170, 280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                brand,
                                const SizedBox(height: 12),
                                const Expanded(child: _AuthAlbumPreview()),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: controller,
                              child: form,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!keyboardOpen) ...[
                            brand,
                            const SizedBox(height: 12),
                          ],
                          Expanded(child: form),
                        ],
                      ),
              ),
            ),
          );
        return SingleChildScrollView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedOpacity(
                opacity: animateIn ? 1 : 0,
                duration: Duration(milliseconds: reducedMotion ? 0 : 240),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    brand,
                    const SizedBox(height: 24),
                    if (login) ...[
                      const _AuthAlbumPreview(),
                      const SizedBox(height: 28),
                    ],
                    form,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AuthAlbumPreview extends StatelessWidget {
  const _AuthAlbumPreview();

  @override
  Widget build(BuildContext context) {
    const image = ResizeImage(
      AssetImage(
        'assets/templates/jeju_travel/images/approved_stock/beach_people.jpg',
      ),
      width: 720,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final height = math.min(
          box.hasBoundedHeight
              ? box.maxHeight
              : MediaQuery.sizeOf(context).height * .22,
          210.0,
        );
        final width = math.min(box.maxWidth - 12, height * 4 / 3);
        return Center(
          child: HomeCoverFrame(
            width: width,
            height: width * 3 / 4,
            shadowScale: 1,
            showShadow: true,
            showBookDepth: true,
            bindingArtwork: const AlbumSpineImage(image: image),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const AlbumSpineImage(image: image),
                Positioned(
                  left: 20,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    '우리의 여름',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceStyle.text(
                      16,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AuthPaperCard extends StatelessWidget {
  const _AuthPaperCard({required this.child, this.maxWidth = 430});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: !kIsWeb && MediaQuery.orientationOf(context) == Orientation.landscape
            ? 960
            : maxWidth,
      ),
      child: AutofillGroup(child: child),
    ),
  );
}

class _CardEyebrow extends StatelessWidget {
  const _CardEyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape
      ? const SizedBox.shrink()
      : Text(
          text,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        );
}

class _DividerWithText extends StatelessWidget {
  const _DividerWithText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Divider(color: ExperienceFormStyle.line(context))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
      ),
      Expanded(child: Divider(color: ExperienceFormStyle.line(context))),
    ],
  );
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
        height: 52,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
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
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                ),
                SizedBox(width: 10),
              ] else ...[
                icon,
                SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w600,
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
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final Widget? suffixIcon;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ExperienceFormStyle.ink(context),
          ),
        ),
        SizedBox(height: 6),
        TextFormField(
          key: ValueKey('auth-field-$label'),
          enabled: enabled,
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          validator: validator,
          style: ExperienceFormStyle.text(context, 15),
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          autocorrect:
              keyboardType != TextInputType.emailAddress &&
              autofillHints?.contains(AutofillHints.newPassword) != true &&
              autofillHints?.contains(AutofillHints.password) != true,
          enableSuggestions:
              keyboardType != TextInputType.emailAddress &&
              autofillHints?.contains(AutofillHints.newPassword) != true &&
              autofillHints?.contains(AutofillHints.password) != true,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: kIsWeb
              ? InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: WebPalette.of(context).muted, fontSize: 14),
                  filled: true, fillColor: WebPalette.of(context).surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: WebPalette.of(context).line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: WebPalette.of(context).line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: WebPalette.of(context).brandInk, width: 1.5)),
                  suffixIcon: suffixIcon, errorMaxLines: 3,
                )
              : ExperienceFormStyle.input(context, hint: hint)
                  .copyWith(suffixIcon: suffixIcon, errorMaxLines: 3),
        ),
      ],
    );
  }
}

class _InlineAuthNotice extends StatelessWidget {
  const _InlineAuthNotice({
    required this.icon,
    required this.text,
    this.error = false,
  });

  final IconData icon;
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? Theme.of(context).colorScheme.error
        : ExperienceFormStyle.ink(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: ExperienceFormStyle.surface(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.42,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final password = value.text;
          final rules = <(String, bool)>[
            ('8자 이상', password.length >= 8),
            (
              '영문·숫자',
              password.contains(RegExp('[A-Za-z]')) &&
                  password.contains(RegExp('[0-9]')),
            ),
            ('공백 없이', password.isNotEmpty && !password.contains(RegExp(r'\s'))),
          ];
          return Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final rule in rules)
                Semantics(
                  label: '${rule.$1}: ${rule.$2 ? "충족" : "미충족"}',
                  excludeSemantics: true,
                  child: Row(
                    key: ValueKey('password-rule-${rule.$1}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        rule.$2
                            ? Icons.check_circle_outline
                            : Icons.circle_outlined,
                        size: 14,
                        color: rule.$2
                            ? ExperienceFormStyle.selectionInk(context)
                            : ExperienceFormStyle.muted(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rule.$1,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: !rule.$2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
}

class _TermsCheckTile extends StatelessWidget {
  const _TermsCheckTile({
    required this.value,
    required this.label,
    required this.onChanged,
    this.requiredLabel = false,
    this.onView,
    this.enabled = true,
  });
  final bool value, requiredLabel;
  final bool enabled;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
    ),
    child: InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              activeColor: kIsWeb ? WebPalette.of(context).brand : ExperienceStyle.accent,
              checkColor: kIsWeb ? WebPalette.of(context).onBrand : const Color(0xFF063740),
              side: BorderSide(color: ExperienceFormStyle.muted(context)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: requiredLabel ? '필수  ' : '선택  ',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                    TextSpan(text: label),
                  ],
                ),
                style: ExperienceFormStyle.text(context, 13),
              ),
            ),
            if (onView != null)
              IconButton(
                tooltip: '$label 보기',
                onPressed: enabled ? onView : null,
                icon: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: ExperienceFormStyle.muted(context),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _TermsFooter extends StatelessWidget {
  const _TermsFooter({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _FooterLink(label: '이용약관', onTap: onTerms),
            Text(
              ' · ',
              style: TextStyle(
                fontSize: 12,
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
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.underline,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

ButtonStyle _outlineButtonStyle(BuildContext context) =>
    OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      foregroundColor: kIsWeb ? WebPalette.of(context).ink : ExperienceFormStyle.ink(context),
      side: BorderSide(color: kIsWeb ? WebPalette.of(context).line : ExperienceFormStyle.line(context)),
      textStyle: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kIsWeb ? 8 : 6)),
    );

ButtonStyle _primaryButtonStyle(BuildContext context) =>
    kIsWeb ? ElevatedButton.styleFrom(
      backgroundColor: WebPalette.of(context).brand, foregroundColor: WebPalette.of(context).onBrand,
      minimumSize: const Size(0, 48), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ) : ExperienceFormStyle.primary(context);

TextStyle _titleStyle(BuildContext context) => ExperienceFormStyle.text(
  context,
  kIsWeb ? 24 : MediaQuery.orientationOf(context) == Orientation.landscape ? 18 : 22,
  weight: FontWeight.w600,
  color: kIsWeb ? WebPalette.of(context).ink : null,
);

TextStyle _bodyStyle(BuildContext context) =>
    ExperienceFormStyle.text(context, 13, secondary: true);

enum _LoginProvider { kakao, google, email }

enum _AuthMode { login, emailLogin, signup, resetRequest, resetPassword }
