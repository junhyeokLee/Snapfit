import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../data/pending_referral.dart';
import '../../domain/referral_link.dart';
import '../../domain/referral_status.dart';
import '../providers/referral_providers.dart';
import '../widgets/referral_widgets.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key, this.initialCode});
  final String? initialCode;

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _code;
  ReferralStatus? _confirmedStatus, _scheduledStatus;
  Timer? _expiry;
  bool _redeeming = false, _refreshing = false, _sharing = false;
  bool _loginRequested = false, _openingLogin = false;
  String? _error, _refreshError;
  int _identityRevision = 0;

  @override
  void initState() {
    super.initState();
    _code = TextEditingController(
      text: _normalize(
        widget.initialCode ?? ref.read(pendingReferralProvider)?.code,
      ),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(ReferralScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCode != oldWidget.initialCode) {
      _code.text = _normalize(
        widget.initialCode ?? ref.read(pendingReferralProvider)?.code,
      );
      _error = null;
    }
  }

  @override
  void dispose() {
    _identityRevision++;
    _expiry?.cancel();
    _code.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  String _normalize(String? value) => (value ?? '').trim().toUpperCase();

  bool _current(String owner, int revision) =>
      mounted &&
      revision == _identityRevision &&
      ref.read(referralCurrentUserIdProvider) == owner;

  void _scheduleExpiry(ReferralStatus status) {
    if (identical(status, _scheduledStatus)) return;
    _scheduledStatus = status;
    _expiry?.cancel();
    final remaining = status.eligibleUntil.difference(status.serverTime);
    if (!status.canRedeem || remaining <= Duration.zero) return;
    _expiry = Timer(remaining, () {
      if (mounted && !_redeeming) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final owner = ref.read(referralCurrentUserIdProvider);
    if (owner == null || _redeeming || _refreshing) return;
    final revision = _identityRevision;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final fresh = await ref.refresh(referralStatusProvider.future);
      if (_current(owner, revision)) {
        setState(() => _confirmedStatus = fresh);
      }
    } catch (_) {
      if (_current(owner, revision)) {
        setState(() => _refreshError = '초대 기록을 새로 불러오지 못했어요. 다시 시도해 주세요.');
      }
    } finally {
      if (_current(owner, revision)) setState(() => _refreshing = false);
    }
  }

  Future<void> _redeem() async {
    final owner = ref.read(referralCurrentUserIdProvider);
    final status = _confirmedStatus ?? ref.read(referralStatusProvider).value;
    final code = _normalize(_code.text);
    if (owner == null ||
        status == null ||
        !status.canRedeem ||
        code.isEmpty ||
        _redeeming ||
        _refreshing) {
      return;
    }
    if (code == status.code) {
      setState(() => _error = '내 코드는 등록할 수 없어요. 친구에게 받은 코드를 입력해 주세요.');
      return;
    }
    if (normalizeReferralCode(code) == null) {
      setState(() => _error = '10자리 초대 코드를 확인해 주세요. 영문과 숫자로 입력할 수 있어요.');
      return;
    }
    final revision = _identityRevision;
    final pending = ref.read(pendingReferralProvider);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _redeeming = true;
      _error = null;
      _refreshError = null;
    });
    try {
      final confirmed = await ref.read(referralRepositoryProvider).redeem(code);
      if (!_current(owner, revision)) return;
      setState(() => _confirmedStatus = confirmed);
      if (pending != null && pending.code == code && confirmed.redeemed) {
        ref.read(pendingReferralProvider.notifier).clearIfCurrent(pending);
      }
      // The server response confirms the award. Independent wallet reads must
      // never turn an accepted code into an apparent registration failure.
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed.claimed && confirmed.awardedPoints > 0
                ? '친구와 연결됐어요. ${referralPoints(confirmed.awardedPoints)}P를 받았어요.'
                : '친구 초대 혜택은 이미 받았어요.',
          ),
        ),
      );
    } catch (error) {
      if (_current(owner, revision)) {
        setState(() => _error = _registrationError(error));
      }
    } finally {
      if (_current(owner, revision)) setState(() => _redeeming = false);
    }
  }

  String _registrationError(Object error) {
    final message = error.toString();
    if (message.contains('REFERRAL_INVALID_CODE')) {
      return '코드를 찾지 못했어요. 친구에게 받은 코드를 다시 확인해 주세요.';
    }
    if (message.contains('REFERRAL_SELF_NOT_ALLOWED')) {
      return '내 코드는 등록할 수 없어요. 친구에게 받은 코드를 입력해 주세요.';
    }
    if (message.contains('REFERRAL_RECIPROCAL_NOT_ALLOWED')) {
      return '이미 초대로 연결된 친구예요. 서로의 코드를 다시 등록할 수 없어요.';
    }
    if (message.contains('REFERRAL_WINDOW_EXPIRED')) {
      return '가입 후 코드 등록 기간이 지났어요. 내 코드로 친구를 초대해 보세요.';
    }
    if (message.contains('REFERRAL_LIMIT_REACHED')) {
      return '이 친구의 이번 달 초대 혜택이 모두 사용됐어요. 다른 친구의 코드를 확인해 주세요.';
    }
    if (message.contains('REFERRAL_UNVERIFIED_ACCOUNT')) {
      return '가입한 이메일을 인증한 뒤 다시 등록해 주세요.';
    }
    if (message.contains('REFERRAL_LOGIN_REQUIRED') ||
        message.contains('REFERRAL_ACCOUNT_REQUIRED')) {
      return '로그인 상태를 다시 확인해 주세요.';
    }
    return '등록 결과를 확인하지 못했어요. 같은 코드를 다시 눌러 확인해 주세요.';
  }

  Uri _inviteLink(String code) => referralShareUri(code);

  Future<void> _copy({required String value, required String message}) async {
    final owner = ref.read(referralCurrentUserIdProvider);
    if (owner == null || _sharing) return;
    final revision = _identityRevision;
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (_current(owner, revision)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (_current(owner, revision)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('복사하지 못했어요. 코드를 길게 눌러 복사해 주세요.')),
        );
      }
    }
  }

  Future<void> _share(ReferralStatus status) async {
    final owner = ref.read(referralCurrentUserIdProvider);
    if (owner == null || _sharing) return;
    final revision = _identityRevision;
    final box = context.findRenderObject() as RenderBox?;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'SnapFit 친구 초대',
          text:
              'SnapFit에서 함께 추억을 남겨요. 가입 후 ${status.registrationWindowDays}일 안에 초대 코드 ${status.code}를 등록하면 ${referralPoints(status.inviteePoints)}P를 받을 수 있어요.\n${_inviteLink(status.code)}',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (_current(owner, revision)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공유 창을 열지 못했어요. 링크를 복사해서 보내주세요.')),
        );
      }
    } finally {
      if (_current(owner, revision)) setState(() => _sharing = false);
    }
  }

  Future<void> _login() async {
    if (_openingLogin) return;
    setState(() => _openingLogin = true);
    final code = normalizeReferralCode(_code.text);
    final pending = ref.read(pendingReferralProvider.notifier);
    if (code != null) pending.receive(referralShareUri(code));
    await pending.persisted;
    if (!mounted) return;
    setState(() => _openingLogin = false);
    final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigate != null) {
      navigate(WebAppLocation.login);
      return;
    }
    setState(() => _loginRequested = true);
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(referralCurrentUserIdProvider);
    ref.listen(referralCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _identityRevision++;
      _expiry?.cancel();
      _scheduledStatus = _confirmedStatus = null;
      _redeeming = _refreshing = _sharing = false;
      _error = _refreshError = null;
      _code.text = _normalize(
        widget.initialCode ?? ref.read(pendingReferralProvider)?.code,
      );
    });
    ref.listen(pendingReferralProvider, (_, next) {
      if (next != null && _code.text.isEmpty) {
        setState(() => _code.text = next.code);
      }
    });
    if (_loginRequested) {
      ref.listen(authViewModelProvider, (_, next) {
        if (next.hasValue && next.value != null && !next.isLoading) {
          setState(() => _loginRequested = false);
        }
      });
      final auth = ref.watch(authViewModelProvider);
      if (auth.hasValue && auth.value != null && !auth.isLoading) {
        _loginRequested = false;
      } else {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _loginRequested = false);
          },
          child: Scaffold(
            appBar: ExperienceHeader(
              title: '친구 초대',
              showNotifications: false,
              onBack: () => setState(() => _loginRequested = false),
            ),
            body: const LoginScreen(),
          ),
        );
      }
    }
    final result = owner == null ? null : ref.watch(referralStatusProvider);
    final status = result?.isReloading == true
        ? null
        : _confirmedStatus ?? result?.value;
    if (status != null) _scheduleExpiry(status);
    return SocialWebFrame(
      section: WebSection.myProfile,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: ExperienceHeader(
          title: '친구 초대',
          showNotifications: false,
          actions: [
            if (owner != null)
              IconButton(
                key: const ValueKey('referral-refresh'),
                tooltip: '초대 기록 새로고침',
                onPressed: _redeeming || _refreshing ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SocialContent(
                maxWidth: 1120,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: owner == null
                      ? _guest()
                      : status == null
                      ? result?.hasError == true
                            ? SocialEmpty(
                                title: '초대 기록을 불러오지 못했어요',
                                message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                                icon: Icons.cloud_off_outlined,
                                action: OutlinedButton(
                                  key: const ValueKey('referral-retry'),
                                  onPressed: _refreshing ? null : _refresh,
                                  child: const Text('다시 시도'),
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 80),
                                child: SocialLoading(
                                  message: '친구 초대 기록을 불러오고 있어요.',
                                ),
                              )
                      : _content(status),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _guest() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const ReferralRewardCard(
        inviterPoints: 100,
        inviteePoints: 100,
        registrationWindowDays: 7,
      ),
      const SizedBox(height: 22),
      ReferralPaper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _normalize(_code.text).isEmpty
                  ? '친구와 함께 시작해요'
                  : '친구가 초대장을 보냈어요',
              style: ExperienceFormStyle.text(
                context,
                21,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (_normalize(_code.text).isNotEmpty) ...[
              SelectableText(
                _normalize(_code.text),
                key: const ValueKey('referral-guest-code'),
                style: ExperienceFormStyle.text(
                  context,
                  24,
                  weight: FontWeight.w600,
                  color: SocialStyle.accent(context),
                ).copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '로그인한 뒤 친구 코드를 등록해 주세요. 가입한 지 7일이 지나지 않았다면 초대 혜택을 받을 수 있어요.',
              style: ExperienceFormStyle.text(
                context,
                14,
                secondary: true,
              ).copyWith(height: 1.7),
            ),
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('referral-login'),
              style: SocialStyle.primary(context),
              onPressed: _openingLogin ? null : _login,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('로그인하고 시작하기', textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _content(ReferralStatus status) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '함께 만드는 기록',
        style: ExperienceFormStyle.text(
          context,
          14,
          weight: FontWeight.w500,
          color: SocialStyle.accent(context),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '친구와 함께, SnapFit',
        style: ExperienceFormStyle.text(
          context,
          30,
          weight: FontWeight.w600,
        ).copyWith(height: 1.3, letterSpacing: -.6),
      ),
      const SizedBox(height: 13),
      Text(
        '보유 포인트 ${referralPoints(status.balance)}P',
        style: ExperienceFormStyle.text(context, 14, secondary: true),
      ),
      const SizedBox(height: 26),
      if (_refreshError != null) ...[
        ReferralPaper(
          child: Semantics(
            liveRegion: true,
            child: Text(
              _refreshError!,
              style: ExperienceFormStyle.text(
                context,
                14,
              ).copyWith(height: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
      LayoutBuilder(
        builder: (context, bounds) {
          final reward = ReferralRewardCard(
            inviterPoints: status.inviterPoints,
            inviteePoints: status.inviteePoints,
            registrationWindowDays: status.registrationWindowDays,
          );
          final share = ReferralShareCard(
            code: status.code,
            busy: _sharing,
            onShare: () => _share(status),
            onCopyCode: () =>
                _copy(value: status.code, message: '초대 코드를 복사했어요.'),
            onCopyLink: () => _copy(
              value: _inviteLink(status.code).toString(),
              message: '초대 링크를 복사했어요.',
            ),
          );
          if (bounds.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: reward),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: share),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [reward, const SizedBox(height: 20), share],
          );
        },
      ),
      const SizedBox(height: 22),
      if (status.canRedeem)
        ReferralRedeemCard(
          controller: _code,
          points: status.inviteePoints,
          busy: _redeeming,
          enabled: !_refreshing && _normalize(_code.text).isNotEmpty,
          error: _error,
          eligibleUntil: status.eligibleUntil,
          onChanged: (_) => setState(() => _error = null),
          onRedeem: _redeem,
        )
      else
        ReferralPaper(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                status.redeemed
                    ? Icons.check_circle_outline_rounded
                    : Icons.mail_outline_rounded,
                color: SocialStyle.accent(context),
                size: 29,
              ),
              const SizedBox(height: 14),
              Text(
                status.redeemed
                    ? '친구 초대 혜택을 받았어요'
                    : status.ineligibleReason == 'unverified'
                    ? '이메일 인증이 필요해요'
                    : '이제 친구를 초대해 보세요',
                key: const ValueKey('referral-registration-state'),
                style: ExperienceFormStyle.text(
                  context,
                  19,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                status.redeemed
                    ? '함께할 친구를 내 코드로 초대하고 새로운 추억을 남겨보세요.'
                    : status.ineligibleReason == 'unverified'
                    ? '가입한 이메일을 인증한 뒤 이 화면을 새로고침하면 친구 코드를 등록할 수 있어요.'
                    : '친구 코드 등록은 가입 후 ${status.registrationWindowDays}일 안에 한 번만 가능해요. 내 코드를 보내 친구와 혜택을 나눠보세요.',
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  secondary: true,
                ).copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      const SizedBox(height: 22),
      ReferralSummaryCard(
        monthlyRewardedCount: status.monthlyRewardedCount,
        rewardLimit: status.rewardLimit,
        invitedCount: status.invitedCount,
        totalEarned: status.totalEarned,
      ),
    ],
  );
}
