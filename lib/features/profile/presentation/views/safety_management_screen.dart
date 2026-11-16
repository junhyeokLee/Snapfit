import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/context_extensions.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/navigation/web_app_router.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../social/data/social_repository.dart' show socialActionMessage;
import '../../../social/domain/social_models.dart';
import '../../../social/presentation/providers/social_providers.dart';
import '../../../social/presentation/widgets/social_profile_widgets.dart';
import '../../../social/presentation/widgets/social_report_sheet.dart';
import '../providers/safety_management_providers.dart';
import '../widgets/customer_web_page.dart';
import '../../../../shared/widgets/experience_icon.dart';

Future<void> openSafetyManagement(
  NavigatorState navigator, {
  bool reports = false,
}) async {
  final location = reports
      ? WebAppLocation.safetyReports
      : WebAppLocation.safety;
  final controller = WebAppRouteController(
    location,
    pages: const {WebAppPage.safety, WebAppPage.safetyReports},
  );
  final page = SafetyManagementScreen(
    initialReports: reports,
    routeController: controller,
  );
  final settings = WebAppRouteSettings(location, controller: controller);
  try {
    await navigator.push<void>(
      kIsWeb
          ? WebAppPageRoute<void>(settings: settings, builder: (_) => page)
          : snapFitRoute<void>(page: page, settings: settings),
    );
  } finally {
    controller.dispose();
  }
}

class SafetyManagementScreen extends ConsumerStatefulWidget {
  const SafetyManagementScreen({
    super.key,
    this.initialReports = false,
    this.routeController,
  });
  final bool initialReports;
  final WebAppRouteController? routeController;

  @override
  ConsumerState<SafetyManagementScreen> createState() =>
      _SafetyManagementScreenState();
}

class _SafetyManagementScreenState extends ConsumerState<SafetyManagementScreen>
    with WidgetsBindingObserver {
  late bool _reports;
  final _reportOffsets = <int>[0];
  int _revision = 0;
  String? _busyTarget, _error;
  DialogRoute<bool>? _decision;
  PageRoute<void>? _loginRoute;

  @override
  void initState() {
    super.initState();
    _reports = widget.initialReports;
    widget.routeController?.addListener(_routeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _revision++;
    _dismissDecision();
    _dismissLogin();
    widget.routeController?.removeListener(_routeChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  void _routeChanged() {
    final reports =
        widget.routeController?.value.page == WebAppPage.safetyReports;
    if (mounted && reports != _reports) {
      _revision++;
      _dismissDecision();
      setState(() {
        _reports = reports;
        _busyTarget = null;
        _error = null;
      });
    }
  }

  void _select(bool reports) {
    if (_busyTarget != null || _reports == reports) return;
    setState(() {
      _reports = reports;
      _revision++;
      _error = null;
    });
    widget.routeController?.update(
      reports ? WebAppLocation.safetyReports : WebAppLocation.safety,
    );
  }

  bool _current(SafetyManagementSession session, int revision) =>
      mounted &&
      revision == _revision &&
      session.ownerId != null &&
      identical(ref.read(safetyManagementSessionProvider), session) &&
      safetySessionMatchesSdk(session, ref.read(socialRepositoryProvider));

  void _dismissDecision() {
    final route = _decision;
    _decision = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  void _dismissLogin() {
    final route = _loginRoute;
    _loginRoute = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route.isActive) route.navigator?.removeRoute(route);
    });
  }

  void _sessionChanged(SafetyManagementSession next) {
    _revision++;
    if (next.ownerId != null) _dismissLogin();
    _dismissDecision();
    setState(() {
      _busyTarget = null;
      _error = null;
      _reportOffsets
        ..clear()
        ..add(0);
    });
  }

  Future<void> _refresh() async {
    final session = ref.read(safetyManagementSessionProvider);
    final owner = session.ownerId;
    if (owner == null || _busyTarget != null || !_current(session, _revision))
      return;
    final revision = ++_revision;
    setState(() {
      _error = null;
      _reportOffsets
        ..clear()
        ..add(0);
    });
    ref.invalidate(safetyBlockedProfilesProvider(owner));
    ref.invalidate(safetyOwnReportsProvider);
    try {
      await (_reports
          ? ref.read(
              safetyOwnReportsProvider(SocialPageQuery(ownerId: owner)).future,
            )
          : ref.read(safetyBlockedProfilesProvider(owner).future));
    } catch (_) {
      if (!_current(session, revision)) return;
      // Each list supplies its own retry without replacing the destination.
    }
  }

  Future<void> _login() async {
    final web = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && web != null) {
      // Requesting this private destination lets the shared router remember it.
      web(_reports ? WebAppLocation.safetyReports : WebAppLocation.safety);
      return;
    }
    if (_loginRoute != null) return;
    final route = snapFitRoute<void>(page: const LoginScreen());
    _loginRoute = route;
    try {
      await Navigator.of(context).push<void>(route);
    } finally {
      if (identical(_loginRoute, route)) _loginRoute = null;
    }
  }

  Future<void> _unblock(SocialProfile profile) async {
    final session = ref.read(safetyManagementSessionProvider);
    final owner = session.ownerId;
    if (owner == null || _busyTarget != null || !_current(session, _revision))
      return;
    final revision = _revision;
    final container = ProviderScope.containerOf(context, listen: false);
    bool current() =>
        _current(session, revision) && _busyTarget == profile.userId;
    setState(() {
      _busyTarget = profile.userId;
      _error = null;
    });
    try {
      late final DialogRoute<bool> route;
      var decided = false;
      void decide(bool confirmed) {
        if (!current() || decided || !route.isCurrent) return;
        decided = true;
        route.navigator?.pop(confirmed);
      }

      route = DialogRoute<bool>(
        context: context,
        builder: (context) => Consumer(
          builder: (context, ref, _) {
            ref.watch(safetyManagementSessionProvider);
            if (!current()) return const SizedBox.shrink();
            return AlertDialog(
              title: const Text('차단을 해제할까요?'),
              content: Text(
                '${profile.displayName.trim().isEmpty ? '이 사용자' : '${profile.displayName}님'}의 차단을 해제해요. 팔로우 관계는 자동으로 복원되지 않아요.',
              ),
              actions: [
                TextButton(
                  onPressed: () => decide(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  key: const ValueKey('safety-unblock-confirm'),
                  style: ExperienceFormStyle.primary(context),
                  onPressed: () => decide(true),
                  child: const Text('차단 해제'),
                ),
              ],
            );
          },
        ),
      );
      _decision = route;
      final confirmed = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (identical(_decision, route)) _decision = null;
      if (confirmed != true || !current()) return;
      await ref
          .read(socialRepositoryProvider)
          .setBlocked(profile.userId, false)
          .timeout(const Duration(seconds: 15));
      invalidateSafetyManagementDomain(container, session);
      if (!current()) return;
      context.showSnack('차단을 해제했어요. 팔로우는 자동으로 복원되지 않아요.');
    } catch (error) {
      invalidateSafetyManagementDomain(container, session);
      if (!current()) return;
      setState(
        () => _error = socialActionMessage(
          error,
          fallback: '차단 해제 결과를 확인하지 못했어요. 목록을 새로 확인해 주세요.',
        ),
      );
    } finally {
      if (current()) setState(() => _busyTarget = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(safetyManagementSessionProvider, (previous, next) {
      if (!identical(previous, next) && mounted) _sessionChanged(next);
    });
    final session = ref.watch(safetyManagementSessionProvider);
    final owner =
        safetySessionMatchesSdk(session, ref.read(socialRepositoryProvider))
        ? session.ownerId
        : null;
    final blocked = owner == null || _reports
        ? null
        : ref.watch(safetyBlockedProfilesProvider(owner));
    final reportPages = [
      if (owner != null && _reports)
        for (final offset in _reportOffsets)
          ref.watch(
            safetyOwnReportsProvider(
              SocialPageQuery(ownerId: owner, offset: offset),
            ),
          ),
    ];
    final content = owner == null
        ? _accessNotice()
        : RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              key: ValueKey(
                'safety-list-$owner-${_reports ? 'reports' : 'blocked'}',
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                kIsWeb ? 0 : 20,
                8,
                kIsWeb ? 0 : 20,
                32,
              ),
              children: [
                _tabs(),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      key: const ValueKey('safety-action-error'),
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_reports)
                  ..._reportList(reportPages, session)
                else
                  ..._blockedList(blocked!, session),
              ],
            ),
          );
    if (kIsWeb) {
      return CustomerWebPage(
        title: '안전 관리',
        description: '차단한 사용자와 내가 접수한 신고를 확인해요.',
        section: WebSection.account,
        actions: [_refreshAction(owner)],
        child: content,
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '안전 관리',
        showNotifications: false,
        actions: [_refreshAction(owner)],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _refreshAction(String? owner) => IconButton(
    key: const ValueKey('safety-refresh'),
    tooltip: '안전 관리 새로고침',
    onPressed: owner == null || _busyTarget != null
        ? null
        : () => unawaited(_refresh()),
    icon: const ExperienceIcon('RefreshCw'),
  );

  Widget _accessNotice() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExperienceIcon('Shield', color: ExperienceFormStyle.selectionInk(context),
          size: 32,
        ),
        const SizedBox(height: 20),
        Text(
          '로그인하고 안전 관리를 확인하세요.',
          style: ExperienceFormStyle.text(context, 21, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '차단 목록과 신고 내역은 내 계정에서만 확인할 수 있어요.',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: ExperienceFormStyle.primary(context),
          onPressed: _login,
          child: const Text('로그인'),
        ),
      ],
    ),
  );

  Widget _tabs() => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final tab in [
        (false, '차단한 사용자', 'blocked'),
        (true, '내 신고 내역', 'reports'),
      ])
        ChoiceChip(
          key: ValueKey('safety-tab-${tab.$3}'),
          label: Text(tab.$2),
          selected: _reports == tab.$1,
          showCheckmark: false,
          selectedColor: ExperienceFormStyle.selection(context),
          labelStyle: ExperienceFormStyle.text(
            context,
            14,
            weight: _reports == tab.$1 ? FontWeight.w700 : FontWeight.w400,
            color: _reports == tab.$1
                ? ExperienceFormStyle.selectionInk(context)
                : null,
          ),
          onSelected: _busyTarget != null ? null : (_) => _select(tab.$1),
        ),
    ],
  );

  List<Widget> _blockedList(
    AsyncValue<List<SocialProfile>> data,
    SafetyManagementSession session,
  ) {
    final revision = _revision;
    if (data.isLoading) return [_loading('차단 목록을 확인하고 있어요.')];
    if (data.hasError)
      return [
        _failure('차단 목록을 불러오지 못했어요.', () {
          if (_current(session, revision))
            ref.invalidate(safetyBlockedProfilesProvider(session.ownerId!));
        }),
      ];
    final profiles = data.value ?? const [];
    if (profiles.isEmpty)
      return [
        _empty(
          Icons.verified_user_outlined,
          '차단한 사용자가 없어요.',
          '필요할 때 상대 프로필의 더보기에서 차단할 수 있어요.',
        ),
      ];
    return [
      Text(
        '해제해도 팔로우 관계는 자동으로 복원되지 않아요.',
        style: ExperienceFormStyle.text(context, 13, secondary: true),
      ),
      const SizedBox(height: 12),
      for (final profile in profiles) _blockedCard(profile),
    ];
  }

  Widget _blockedCard(SocialProfile profile) => Container(
    key: ValueKey('safety-blocked-${profile.userId}'),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(),
    child: LayoutBuilder(
      builder: (context, bounds) {
        final stacked =
            bounds.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final identity = Row(
          children: [
            SocialProfileAvatar(
              name: profile.displayName.trim().isEmpty
                  ? '사용자'
                  : profile.displayName,
              imageUrl: profile.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName.trim().isEmpty
                        ? '프로필 정보가 없는 사용자'
                        : profile.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (profile.handle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '@${profile.handle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        final action = OutlinedButton(
          key: ValueKey('safety-unblock-${profile.userId}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(68, 44),
            foregroundColor: ExperienceFormStyle.selectionInk(context),
          ),
          onPressed: _busyTarget != null ? null : () => _unblock(profile),
          child: Text(_busyTarget == profile.userId ? '해제 중…' : '해제'),
        );
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              )
            : Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 20),
                  action,
                ],
              );
      },
    ),
  );

  List<Widget> _reportList(
    List<AsyncValue<SocialReportsPage>> pages,
    SafetyManagementSession session,
  ) {
    if (pages.first.isLoading) return [_loading('내 신고 내역을 확인하고 있어요.')];
    final revision = _revision;
    final seen = <String>{};
    final cards = <Widget>[];
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index];
      final query = SocialPageQuery(
        ownerId: session.ownerId,
        offset: _reportOffsets[index],
      );
      if (page.hasError) {
        cards.add(
          _failure('신고 내역을 불러오지 못했어요.', () {
            if (_current(session, revision) &&
                _reportOffsets.contains(query.offset)) {
              ref.invalidate(safetyOwnReportsProvider(query));
            }
          }),
        );
      } else if (page.isLoading)
        cards.add(_loading('이전 신고를 확인하고 있어요.'));
      else
        for (final report in page.value?.items ?? const <SocialReport>[]) {
          if (seen.add(report.id)) cards.add(_reportCard(report));
        }
    }
    if (seen.isEmpty && !pages.any((page) => page.isLoading || page.hasError)) {
      return [
        _empty(
          Icons.fact_check_outlined,
          '접수한 신고가 없어요.',
          '신고한 내용의 처리 상태를 이곳에서 확인할 수 있어요.',
        ),
      ];
    }
    final last = pages.last;
    final next = last.value?.nextOffset;
    final more =
        !pages.any((page) => page.isLoading || page.hasError) &&
        last.value?.hasMore == true &&
        next != null &&
        next > _reportOffsets.last &&
        !_reportOffsets.contains(next);
    final lastOffset = _reportOffsets.last;
    final lastQuery = SocialPageQuery(
      ownerId: session.ownerId,
      offset: lastOffset,
    );
    if (more)
      cards.add(
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OutlinedButton(
            key: const ValueKey('safety-reports-more'),
            onPressed: () {
              if (!_current(session, revision) ||
                  _reportOffsets.last != lastOffset)
                return;
              final latest = ref.read(safetyOwnReportsProvider(lastQuery));
              if (latest.isLoading ||
                  latest.hasError ||
                  latest.value?.hasMore != true ||
                  latest.value?.nextOffset != next)
                return;
              if (next! > _reportOffsets.last && !_reportOffsets.contains(next))
                setState(() => _reportOffsets.add(next));
            },
            child: const Text('이전 신고 더 보기'),
          ),
        ),
      );
    return cards;
  }

  Widget _reportCard(SocialReport report) {
    final (label, explanation) = switch (report.status) {
      'open' => ('접수됨', '운영자가 신고 내용을 확인하고 있어요.'),
      'hidden' => ('조치 완료', '신고 대상의 공개가 제한됐어요.'),
      'dismissed' => ('확인 완료', '검토를 마쳤으며 별도 조치는 하지 않았어요.'),
      _ => ('상태 확인 중', '새로고침하면 최신 상태를 확인할 수 있어요.'),
    };
    final kind = switch (report.targetKind) {
      'comment' => '댓글 신고',
      'user' => '사용자 신고',
      _ => '기록·앨범 신고',
    };
    final date = report.createdAt.toLocal();
    final submitted =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('safety-report-${report.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                kind,
                style: ExperienceFormStyle.text(
                  context,
                  15,
                  weight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: ExperienceFormStyle.selection(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    color: ExperienceFormStyle.selectionInk(context),
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            socialReportReasonLabels[report.reason] ?? '기타',
            style: ExperienceFormStyle.text(context, 14),
          ),
          const SizedBox(height: 6),
          Text(
            '접수 $submitted',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            style: ExperienceFormStyle.text(context, 13, secondary: true),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: ExperienceFormStyle.surface(context),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ExperienceFormStyle.line(context)),
  );

  Widget _loading(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const CircularProgressIndicator(strokeWidth: 2),
        const SizedBox(height: 16),
        Text(
          message,
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
      ],
    ),
  );

  Widget _failure(String message, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(message, style: ExperienceFormStyle.text(context, 14)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: retry,
          icon: const ExperienceIcon('RefreshCw', size: 18),
          label: const Text('다시 확인'),
        ),
      ],
    ),
  );

  Widget _empty(IconData icon, String title, String description) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: ExperienceFormStyle.selectionInk(context)),
        const SizedBox(height: 20),
        Text(
          title,
          style: ExperienceFormStyle.text(context, 19, weight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          description,
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
      ],
    ),
  );
}
