import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/attendance_status.dart';
import '../providers/attendance_providers.dart';
import '../widgets/attendance_widgets.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with WidgetsBindingObserver {
  AttendanceStatus? _confirmedStatus;
  AttendanceStatus? _scheduledStatus;
  Timer? _midnight;
  bool _claiming = false, _refreshing = false, _checkingDate = false;
  String? _error;
  int _identityRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _identityRevision++;
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  bool _current(String owner, int revision) =>
      mounted &&
      revision == _identityRevision &&
      ref.read(attendanceCurrentUserIdProvider) == owner;

  void _scheduleReset(AttendanceStatus status) {
    if (identical(_scheduledStatus, status)) return;
    _scheduledStatus = status;
    _midnight?.cancel();
    // Use the server's remaining day, so a device clock or timezone cannot
    // decide eligibility. The server rechecks the day when claiming as well.
    final remaining = status.nextResetAt.difference(status.serverTime);
    if (remaining <= Duration.zero) return;
    _midnight = Timer(remaining, () {
      if (!mounted) return;
      setState(() => _checkingDate = true);
      if (!_claiming) unawaited(_refresh(checkDate: true));
    });
  }

  Future<void> _refresh({bool checkDate = false}) async {
    final owner = ref.read(attendanceCurrentUserIdProvider);
    if (owner == null || _claiming || _refreshing) return;
    final revision = _identityRevision;
    setState(() {
      _refreshing = true;
      _checkingDate = _checkingDate || checkDate;
      _error = null;
    });
    try {
      final fresh = await ref.refresh(attendanceStatusProvider.future);
      if (!_current(owner, revision)) return;
      setState(() {
        _confirmedStatus = fresh;
        _checkingDate = false;
      });
    } catch (_) {
      if (_current(owner, revision)) {
        setState(
          () => _error = _checkingDate
              ? '오늘의 출석 날짜를 확인하지 못했어요. 새로고침한 뒤 다시 시도해 주세요.'
              : '출석 기록을 새로 불러오지 못했어요. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (_current(owner, revision)) setState(() => _refreshing = false);
    }
  }

  Future<void> _claim() async {
    final owner = ref.read(attendanceCurrentUserIdProvider);
    if (owner == null || _claiming || _refreshing || _checkingDate) return;
    final status = _confirmedStatus ?? ref.read(attendanceStatusProvider).value;
    if (status == null || status.checkedInToday) return;
    final revision = _identityRevision;
    setState(() {
      _claiming = true;
      _error = null;
    });
    try {
      final confirmed = await ref.read(attendanceRepositoryProvider).claim();
      if (!_current(owner, revision)) return;
      setState(() => _confirmedStatus = confirmed);
      // The claim response is authoritative. Wallet or ledger refresh failures
      // remain separate and cannot turn a completed check-in into an error.
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirmed.claimed && confirmed.awardedPoints > 0
                ? '${attendancePoints(confirmed.awardedPoints)}P를 받았어요. 오늘의 기록이 쌓였어요.'
                : '오늘 출석은 이미 완료했어요.',
          ),
        ),
      );
    } catch (_) {
      if (_current(owner, revision)) {
        setState(() => _error = '출석 결과를 확인하지 못했어요. 다시 눌러 확인해 주세요.');
      }
    } finally {
      if (_current(owner, revision)) {
        setState(() => _claiming = false);
        if (_checkingDate) unawaited(_refresh(checkDate: true));
      }
    }
  }

  void _login() {
    final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigate != null) {
      navigate(WebAppLocation.login);
      return;
    }
    Navigator.of(context).push<void>(
      snapFitRoute(
        page: const LoginScreen(),
        settings: kIsWeb
            ? const WebAppRouteSettings(WebAppLocation.login)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(attendanceCurrentUserIdProvider);
    ref.listen(attendanceCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _identityRevision++;
      _midnight?.cancel();
      _scheduledStatus = null;
      _confirmedStatus = null;
      _claiming = false;
      _refreshing = false;
      _checkingDate = false;
      _error = null;
    });
    final result = owner == null ? null : ref.watch(attendanceStatusProvider);
    final status = result?.isReloading == true
        ? null
        : _confirmedStatus ?? result?.value;
    if (status != null) _scheduleReset(status);
    return SocialWebFrame(
      section: WebSection.myProfile,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: ExperienceHeader(
          title: '출석체크',
          showNotifications: false,
          actions: [
            if (owner != null)
              IconButton(
                key: const ValueKey('attendance-refresh'),
                tooltip: '출석 기록 새로고침',
                onPressed: _claiming || _refreshing ? null : () => _refresh(),
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
                      ? SocialEmpty(
                          title: '매일의 기록으로 포인트를 모아요',
                          message: '로그인하고 오늘의 출석 도장을 찍어보세요.',
                          icon: Icons.event_available_outlined,
                          action: FilledButton(
                            style: SocialStyle.primary(context),
                            onPressed: _login,
                            child: const Text('로그인'),
                          ),
                        )
                      : status == null
                      ? result?.hasError == true
                            ? SocialEmpty(
                                title: '출석 기록을 불러오지 못했어요',
                                message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                                icon: Icons.cloud_off_outlined,
                                action: OutlinedButton(
                                  key: const ValueKey('attendance-retry'),
                                  onPressed: _refreshing
                                      ? null
                                      : () => _refresh(),
                                  child: const Text('다시 시도'),
                                ),
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 80),
                                child: SocialLoading(
                                  message: '오늘의 출석 기록을 불러오고 있어요.',
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

  Widget _content(AttendanceStatus status) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '오늘의 작은 기록',
        style: ExperienceFormStyle.text(
          context,
          14,
          weight: FontWeight.w500,
          color: SocialStyle.accent(context),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '다시 만나는 하루,\n쌓여가는 포인트',
        style: ExperienceFormStyle.text(
          context,
          31,
          weight: FontWeight.w600,
        ).copyWith(height: 1.3, letterSpacing: -.6),
      ),
      const SizedBox(height: 14),
      Text(
        '보유 포인트 ${attendancePoints(status.balance)}P',
        style: ExperienceFormStyle.text(context, 14, secondary: true),
      ),
      const SizedBox(height: 26),
      if (_error != null) ...[
        Semantics(
          liveRegion: true,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: SocialStyle.paper(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SocialStyle.line(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                    ).copyWith(height: 1.6),
                  ),
                  TextButton(
                    onPressed: _claiming || _refreshing
                        ? null
                        : () => _refresh(),
                    child: const Text('출석 기록 다시 확인'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
      LayoutBuilder(
        builder: (context, bounds) {
          final today = AttendanceTodayCard(
            status: status,
            busy: _claiming,
            checkingDate: _checkingDate || _refreshing,
            onCheckIn: _claim,
          );
          final weekly = AttendanceRewardStrip(status: status);
          if (bounds.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: today),
                const SizedBox(width: 24),
                Expanded(flex: 7, child: weekly),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [today, const SizedBox(height: 20), weekly],
          );
        },
      ),
      const SizedBox(height: 24),
      AttendanceCalendarCard(status: status),
    ],
  );
}
