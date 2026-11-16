import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../profile/domain/order_visibility_owner.dart';
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../profile/data/order_repository.dart';
import '../../../profile/presentation/views/my_page_screen.dart';
import '../../../profile/presentation/views/order_history_screen.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../widgets/social_profile_widgets.dart';
import '../widgets/social_profile_moments.dart';
import '../../../moments/presentation/moments_navigation.dart';
import '../../../moments/presentation/providers/private_moment_archive_providers.dart';
import '../widgets/social_profile_personal_area.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_report_sheet.dart';
import 'social_profile_edit_screen.dart';
import 'social_publish_screen.dart';
import 'social_relations_screen.dart';
import 'social_work_detail_screen.dart';
import 'social_works_manage_screen.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// The public profile is separate from the private account/settings profile.
class SocialProfileScreen extends ConsumerStatefulWidget {
  const SocialProfileScreen({super.key, this.userId});

  /// Null resolves to the current session; it never resolves to a cached owner.
  final String? userId;

  @override
  ConsumerState<SocialProfileScreen> createState() =>
      _SocialProfileScreenState();
}

class _SocialProfileScreenState extends ConsumerState<SocialProfileScreen> {
  bool _busy = false;
  bool _showMoments = true;
  int _identityRevision = 0;
  int? _openingOrdersRevision;
  DialogRoute<bool>? _confirmation;
  final List<int> _workOffsets = [0];

  bool get _personalView => widget.userId?.trim().isEmpty ?? true;

  String? _targetFor(String? actor) {
    final requested = widget.userId?.trim();
    return requested == null || requested.isEmpty ? actor : requested;
  }

  bool _isCurrent(String actor, String target, int revision) =>
      mounted &&
      revision == _identityRevision &&
      ref.read(socialCurrentUserIdProvider) == actor &&
      _targetFor(actor) == target;

  void _resetIdentity() {
    _identityRevision++;
    _busy = false;
    _showMoments = true;
    _workOffsets
      ..clear()
      ..add(0);
    _dismissConfirmation();
  }

  @override
  void didUpdateWidget(covariant SocialProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _resetIdentity();
  }

  @override
  void dispose() {
    _resetIdentity();
    super.dispose();
  }

  Future<bool?> _confirm(WidgetBuilder builder) async {
    final route = DialogRoute<bool>(context: context, builder: builder);
    _confirmation = route;
    try {
      return await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      if (identical(_confirmation, route)) _confirmation = null;
    }
  }

  void _dismissConfirmation() {
    final route = _confirmation;
    _confirmation = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
    });
  }

  void _push(Widget page, [WebAppLocation? location]) {
    Navigator.of(context).push<void>(
      snapFitRoute(
        page: page,
        settings: kIsWeb && location != null
            ? WebAppRouteSettings(location)
            : null,
      ),
    );
  }

  bool _privateCurrent(String actor, String target, int revision) =>
      _isCurrent(actor, target, revision) &&
      target == actor &&
      ref.read(authViewModelProvider).asData?.value?.id == actor &&
      ref.read(visibleOrderOwnerProvider) == actor;

  Future<void> _orders(
    String actor,
    String target,
    int revision,
    AsyncValue<OrderSummaryResult>? summaryState,
  ) async {
    if (!_privateCurrent(actor, target, revision) ||
        _openingOrdersRevision == revision)
      return;
    _openingOrdersRevision = revision;
    try {
      final summary = summaryState?.isLoading == false
          ? summaryState?.asData?.value
          : null;
      if (summary != null) {
        try {
          await ref
              .read(orderRepositoryProvider)
              .markOrderSummarySeen(userId: actor, summary: summary);
        } catch (_) {
          // A local seen marker must not block access to the actual orders.
        }
        if (!_privateCurrent(actor, target, revision)) return;
        ref.invalidate(myOrderStatusBadgesProvider);
      }
      if (_privateCurrent(actor, target, revision)) {
        _push(const OrderHistoryScreen(), WebAppLocation.orders);
      }
    } finally {
      if (_openingOrdersRevision == revision) _openingOrdersRevision = null;
    }
  }

  Widget _toolbarAction({
    required String id,
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: 44,
    height: 44,
    child: IconButton(
      key: ValueKey('profile-header-$id'),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 22),
    ),
  );

  void _login() {
    final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
    if (kIsWeb && navigate != null) {
      navigate(WebAppLocation.login);
      return;
    }
    _push(const LoginScreen(), WebAppLocation.login);
  }

  void _invalidate(String target, String actor) {
    ref.invalidate(socialProfileProvider(target));
    ref.invalidate(socialProfileProvider(actor));
    ref.invalidate(ownSocialProfileProvider);
    ref.invalidate(socialRelationsProvider);
    ref.invalidate(socialRelationsPageProvider);
    ref.invalidate(socialProfileWorksProvider);
    ref.invalidate(socialProfileWorksPageProvider);
    ref.invalidate(socialProfileMomentsPageProvider);
    ref.invalidate(socialProfileMomentMonthsPageProvider);
    ref.invalidate(socialMomentMonthPageProvider);
    ref.invalidate(socialFeedProvider);
    ref.invalidate(socialBlockedProfilesProvider);
    ref.invalidate(socialSavedWorksProvider);
    ref.invalidate(socialSavedWorksPageProvider);
    ref.invalidate(socialWorkProvider);
    ref.invalidate(socialCommentsProvider);
    ref.invalidate(socialCommentsPageProvider);
  }

  Future<void> _follow(SocialProfile profile) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null) return _login();
    if (_busy || actor == profile.userId) return;
    final target = profile.userId;
    final revision = _identityRevision;
    if (!_isCurrent(actor, target, revision)) return;
    setState(() => _busy = true);
    try {
      if (profile.isFollowing) {
        final confirmed = await _confirm(
          (context) => AlertDialog(
            title: const Text('팔로우를 해제할까요?'),
            content: Text('${profile.displayName}님의 공개 기록과 앨범은 계속 볼 수 있어요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: SocialStyle.primary(context),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('팔로우 해제'),
              ),
            ],
          ),
        );
        if (!_isCurrent(actor, target, revision) || confirmed != true) return;
      }
      await ref
          .read(socialRepositoryProvider)
          .setFollowing(target, !profile.isFollowing);
      if (!_isCurrent(actor, target, revision)) return;
      _invalidate(target, actor);
    } catch (_) {
      if (_isCurrent(actor, target, revision)) {
        _invalidate(target, actor);
        _message('변경 결과를 확인하지 못했어요. 최신 상태를 다시 확인해 주세요.');
      }
    } finally {
      if (_isCurrent(actor, target, revision)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reportUser(String target) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = _identityRevision;
    if (actor == null ||
        actor == target ||
        _busy ||
        !_isCurrent(actor, target, revision))
      return;
    setState(() => _busy = true);
    try {
      final sent = await showSocialReportSheet(
        context,
        title: '사용자 신고',
        ownerId: actor,
        onSubmit: (reason, detail, requestId) async {
          if (!_isCurrent(actor, target, revision))
            throw StateError('report_target_changed');
          await ref
              .read(socialRepositoryProvider)
              .reportContent(
                targetKind: 'user',
                targetId: target,
                reason: reason,
                details: detail,
                requestId: requestId,
              );
        },
      );
      if (sent && _isCurrent(actor, target, revision))
        _message('신고를 접수했어요. 운영자가 확인할게요.');
    } finally {
      if (_isCurrent(actor, target, revision)) setState(() => _busy = false);
    }
  }

  Future<void> _setBlocked(String target, bool block) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null) return _login();
    if (_busy || target == actor) return;
    final revision = _identityRevision;
    if (!_isCurrent(actor, target, revision)) return;
    setState(() => _busy = true);
    try {
      if (block) {
        final confirmed = await _confirm(
          (context) => AlertDialog(
            title: const Text('사용자를 차단할까요?'),
            content: const Text(
              '양쪽 팔로우 관계가 해제되고 새 상호작용을 제한해요. 이미 만든 앨범은 유지돼요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: SocialStyle.primary(context),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('차단'),
              ),
            ],
          ),
        );
        if (!_isCurrent(actor, target, revision) || confirmed != true) return;
      }
      await ref.read(socialRepositoryProvider).setBlocked(target, block);
      if (!_isCurrent(actor, target, revision)) return;
      _invalidate(target, actor);
      _message(block ? '사용자를 차단했어요.' : '차단을 해제했어요. 팔로우 관계는 복원하지 않아요.');
    } catch (_) {
      if (_isCurrent(actor, target, revision)) {
        _invalidate(target, actor);
        _message('차단 변경 결과를 확인하지 못했어요. 최신 상태를 다시 확인해 주세요.');
      }
    } finally {
      if (_isCurrent(actor, target, revision)) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String message) => context.showSnack(message);

  Future<void> _refresh(String target, bool own) async {
    if (own) {
      if (_personalView) ref.invalidate(privateMomentMonthsProvider);
      ref.invalidate(homeViewModelProvider);
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ref.invalidate(pointLedgerHistoryProvider);
      ref.invalidate(myStorageQuotaProvider);
      ref.invalidate(myOrderSummaryProvider);
      ref.invalidate(ownedPointShopKeysProvider);
      ref.invalidate(ownSocialProfileProvider);
    } else {
      ref.invalidate(socialProfileProvider(target));
    }
    setState(() {
      _workOffsets
        ..clear()
        ..add(0);
    });
    ref.invalidate(socialProfileWorksPageProvider);
    ref.invalidate(socialBlockedProfilesProvider);
    ref.invalidate(socialProfileMomentsPageProvider);
    ref.invalidate(socialProfileMomentMonthsPageProvider);
    ref.invalidate(socialMomentMonthPageProvider);
    try {
      await (own
          ? ref.read(ownSocialProfileProvider.future)
          : ref.read(socialProfileProvider(target).future));
    } catch (_) {
      // The async panel supplies the retry action without losing the route.
    }
  }

  Future<String?> _refreshAvatarUrl(SocialProfile profile) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final target = profile.userId;
    final revision = _identityRevision;
    final fresh = await ref.read(socialRepositoryProvider).fetchProfile(target);
    if (!mounted ||
        revision != _identityRevision ||
        ref.read(socialCurrentUserIdProvider) != actor)
      return null;
    if (_targetFor(actor) != target || fresh == null || fresh.userId != target)
      return null;
    if (actor != null &&
        actor != target &&
        (ref
                .read(socialBlockedProfilesProvider)
                .asData
                ?.value
                .any((person) => person.userId == target) ??
            false))
      return null;
    return fresh.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(socialCurrentUserIdProvider);
    ref.listen<String?>(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) _resetIdentity();
    });
    final target = _targetFor(actor);
    final own = target != null && target == actor;
    if (own && _personalView) {
      ref.listen<String?>(
        authViewModelProvider.select((auth) => auth.asData?.value?.id),
        (previous, next) {
          if (previous != next) _resetIdentity();
        },
      );
      ref.listen<String?>(visibleOrderOwnerProvider, (previous, next) {
        if (previous != next) _resetIdentity();
      });
    }
    final blocked = actor != null && target != null && !own
        ? ref
                  .watch(socialBlockedProfilesProvider)
                  .asData
                  ?.value
                  .any((profile) => profile.userId == target) ??
              false
        : false;
    final profile = target == null
        ? null
        : own
        ? ref.watch(ownSocialProfileProvider)
        : ref.watch(socialProfileProvider(target));
    final webInset = WebPageLayout.horizontalInset(
      MediaQuery.sizeOf(context).width,
    );
    final privateHeader =
        own &&
        _personalView &&
        ref.watch(authViewModelProvider).asData?.value?.id == actor &&
        ref.watch(visibleOrderOwnerProvider) == actor;
    final orders = privateHeader ? ref.watch(myOrderSummaryProvider) : null;
    final revision = _identityRevision;
    final headerActions = <Widget>[
      if (privateHeader) ...[
        _toolbarAction(
          id: 'orders',
          tooltip: '인쇄 주문 내역',
          icon: Icons.local_shipping_outlined,
          onPressed: () => _orders(actor!, target!, revision, orders),
        ),
        if (!kIsWeb)
          _toolbarAction(
            id: 'notifications',
            tooltip: '알림',
            icon: Icons.notifications_outlined,
            onPressed: () {
              if (_privateCurrent(actor!, target!, revision)) {
                _push(const NotificationScreen(), WebAppLocation.notifications);
              }
            },
          ),
        _toolbarAction(
          id: 'settings',
          tooltip: '설정',
          icon: Icons.settings_outlined,
          onPressed: () {
            if (_privateCurrent(actor!, target!, revision)) {
              _push(const MyPageScreen(), WebAppLocation.account);
            }
          },
        ),
      ] else if (!own && target != null && actor != null && !blocked)
        PopupMenuButton<String>(
          tooltip: '프로필 더보기',
          onSelected: (action) {
            if (action == 'report') {
              _reportUser(target);
            } else {
              _setBlocked(target, true);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'report', child: Text('사용자 신고')),
            PopupMenuItem(value: 'block', child: Text('사용자 차단')),
          ],
        ),
    ];
    return SocialWebFrame(
      section: own ? WebSection.myProfile : WebSection.feed,
      child: Scaffold(
        appBar: kIsWeb
            ? null
            : ExperienceHeader(
                title: _personalView ? '마이' : '프로필',
                back: Navigator.canPop(context),
                showNotifications: false,
                actions: headerActions,
              ),
        body: SafeArea(
          top: false,
          child: target == null
              ? SingleChildScrollView(
                  child: SocialProfileContent(
                    maxWidth: kIsWeb ? WebPageLayout.maxWidth : 1120,
                    padding: kIsWeb
                        ? EdgeInsets.fromLTRB(webInset, 32, webInset, 48)
                        : const EdgeInsets.fromLTRB(20, 32, 20, 40),
                    child: SocialProfileStatePanel(
                      title: '내 프로필을 시작해 보세요.',
                      message: '로그인하면 공개 기록과 앨범, 팔로우 관계를 관리할 수 있어요.',
                      action: FilledButton(
                        style: SocialStyle.primary(context),
                        onPressed: _login,
                        child: const Text('로그인'),
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _refresh(target, own),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SocialProfileContent(
                      maxWidth: kIsWeb ? WebPageLayout.maxWidth : 1120,
                      padding: kIsWeb
                          ? EdgeInsets.fromLTRB(webInset, 32, webInset, 48)
                          : const EdgeInsets.fromLTRB(16, 20, 16, 40),
                      child: blocked
                          ? SocialProfileStatePanel(
                              title: '차단한 사용자예요.',
                              message: '차단을 해제해도 팔로우 관계는 자동 복원되지 않아요.',
                              action: OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _setBlocked(target, false),
                                child: Text(_busy ? '변경 중…' : '차단 해제'),
                              ),
                            )
                          : profile!.when(
                              skipLoadingOnRefresh: false,
                              skipLoadingOnReload: false,
                              loading: () => _profileState(
                                const SocialProfileStatePanel(
                                  title: '프로필을 불러오고 있어요.',
                                  message: '공개된 기록을 확인하고 있어요.',
                                  loading: true,
                                ),
                                own,
                                headerActions,
                              ),
                              error: (_, _) => _profileState(
                                SocialProfileStatePanel(
                                  title: '프로필을 불러오지 못했어요.',
                                  message: '연결 상태를 확인한 뒤 다시 시도해 주세요.',
                                  action: OutlinedButton(
                                    onPressed: () => _refresh(target, own),
                                    child: const Text('다시 시도'),
                                  ),
                                ),
                                own,
                                headerActions,
                              ),
                              data: (value) => value == null
                                  ? _profileState(
                                      _missing(own),
                                      own,
                                      headerActions,
                                    )
                                  : _body(value, own, headerActions),
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _personal(
    Widget header, {
    Widget? gallery,
  }) => SocialProfilePersonalArea(
    key: ValueKey(('personal-profile', ref.watch(socialCurrentUserIdProvider))),
    ownerId: ref.watch(socialCurrentUserIdProvider)!,
    publicHeader: header,
    gallery: gallery,
    onOpenPublicProfile: () {
      final actor = ref.read(socialCurrentUserIdProvider);
      if (actor == null || !_privateCurrent(actor, actor, _identityRevision))
        return;
      _push(
        SocialProfileScreen(userId: actor),
        WebAppLocation(WebAppPage.socialProfile, actor),
      );
    },
  );

  Widget _webProfileHeading(bool personal, List<Widget> actions) =>
      LayoutBuilder(
        builder: (context, bounds) {
          final title = personal ? '내 프로필' : '프로필';
          final tools = Wrap(spacing: 4, children: actions);
          if (personal &&
              bounds.maxWidth < 650 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4) {
            return Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 24, letterSpacing: -.6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                tools,
              ],
            );
          }
          return WebPageHeading(
            title: title,
            description: personal ? null : '사진과 앨범으로 만나는 이 사람의 시선.',
            trailing: tools,
          );
        },
      );

  Widget _profileState(Widget state, bool own, List<Widget> headerActions) {
    if (!own || !_personalView) return state;
    return _personal(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb) ...[
            _webProfileHeading(true, headerActions),
            const SizedBox(height: 16),
          ],
          state,
        ],
      ),
    );
  }

  Widget _missing(bool own) => SocialProfileStatePanel(
    title: own ? '공개 프로필을 만들어 보세요.' : '프로필을 볼 수 없어요.',
    message: own
        ? '공개할 이름과 소개를 정하고 내 기록과 앨범을 모아보세요.'
        : '현재 공개되지 않았거나 접근할 수 없는 프로필이에요.',
    action: own
        ? FilledButton(
            style: SocialStyle.primary(context),
            onPressed: () => _push(const SocialProfileEditScreen()),
            child: const Text('프로필 설정'),
          )
        : null,
  );

  Widget _manageWorks() => Tooltip(
    message: '공개 앨범 관리',
    child: TextButton(
      key: const ValueKey('profile-manage-works'),
      onPressed: () =>
          _push(const SocialWorksManageScreen(), WebAppLocation.socialManage),
      child: const Text('앨범 관리'),
    ),
  );

  Widget _collections(SocialProfile profile, bool own) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Wrap(
            spacing: 22,
            children: [
              for (final tab in [(true, '월간 기록'), (false, '공개 앨범')])
                Semantics(
                  selected: _showMoments == tab.$1,
                  child: TextButton(
                    key: ValueKey(
                      'profile-collection-${tab.$1 ? 'moments' : 'albums'}',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: _showMoments == tab.$1
                          ? SocialStyle.ink(context)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(),
                      textStyle: ExperienceFormStyle.text(
                        context,
                        16,
                        weight: _showMoments == tab.$1
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    onPressed: () => setState(() => _showMoments = tab.$1),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2,
                            color: _showMoments == tab.$1
                                ? SocialStyle.accent(context)
                                : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(tab.$2),
                    ),
                  ),
                ),
            ],
          ),
          if (own && _showMoments)
            TextButton.icon(
              key: const ValueKey('profile-monthly-records'),
              onPressed: () => openMoments(context),
              icon: const ExperienceIcon('Calendar', size: 18),
              label: const Text('나의 기록'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_showMoments)
        SocialProfileMoments(
          key: ValueKey(profile.userId),
          userId: profile.userId,
          own: own,
        )
      else
        _workGallery(profile, own),
    ],
  );

  Widget _workGallery(SocialProfile profile, bool own) {
    Widget statePanel(Widget content) => own
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '공개 앨범',
                      style: ExperienceFormStyle.text(
                        context,
                        21,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _manageWorks(),
                ],
              ),
              const SizedBox(height: 14),
              content,
            ],
          )
        : content;
    final pages = [
      for (final offset in _workOffsets)
        ref.watch(
          socialProfileWorksPageProvider(
            SocialProfileWorksQuery(profile.userId, offset: offset),
          ),
        ),
    ];
    final first = pages.first;
    if (first.isReloading || (!first.hasValue && first.isLoading)) {
      return statePanel(
        const SocialProfileStatePanel(
          title: '앨범을 불러오고 있어요.',
          message: '잠시만 기다려 주세요.',
          loading: true,
        ),
      );
    }
    if (!first.hasValue) {
      return statePanel(
        SocialProfileStatePanel(
          title: '앨범을 불러오지 못했어요.',
          message: '프로필을 유지한 채 다시 불러올 수 있어요.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(
              socialProfileWorksPageProvider(
                SocialProfileWorksQuery(profile.userId),
              ),
            ),
            child: const Text('앨범 다시 불러오기'),
          ),
        ),
      );
    }
    final seen = <String>{};
    final published = <SocialWork>[
      for (final page in pages)
        if (!page.isReloading)
          for (final work in page.value?.items ?? const <SocialWork>[])
            if (work.isPublished && seen.add(work.id)) work,
    ];
    if (published.isEmpty) {
      return statePanel(
        SocialProfileStatePanel(
          title: own ? '첫 앨범을 공개해 보세요.' : '아직 공개한 앨범이 없어요.',
          message: own ? '이미 만든 앨범에서 공개할 페이지만 골라보세요.' : '새로운 기록이 공개되면 이곳에 모여요.',
          action: own
              ? FilledButton(
                  style: SocialStyle.primary(context),
                  onPressed: () => _push(
                    const SocialPublishScreen(),
                    WebAppLocation.socialPublish,
                  ),
                  child: const Text('기존 앨범에서 공개하기'),
                )
              : null,
        ),
      );
    }
    final last = pages.last;
    final next = last.value?.nextOffset;
    final hasMore =
        last.value?.hasMore == true &&
        next != null &&
        next > _workOffsets.last &&
        !_workOffsets.contains(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialProfileGallery(
          title: '공개 앨범',
          key: ValueKey('social-profile-gallery-${profile.userId}'),
          works: published,
          headerAction: own ? _manageWorks() : null,
          onRetry: (work) {
            for (final offset in _workOffsets) {
              final query = SocialProfileWorksQuery(
                profile.userId,
                offset: offset,
              );
              if (ref
                      .read(socialProfileWorksPageProvider(query))
                      .value
                      ?.items
                      .any((item) => item.id == work.id) ==
                  true) {
                ref.invalidate(socialProfileWorksPageProvider(query));
                break;
              }
            }
          },
          onOpenWork: (work) => _push(
            SocialWorkDetailScreen(workId: work.id),
            WebAppLocation(WebAppPage.socialWork, work.id),
          ),
        ),
        if (last.isLoading || last.hasError || hasMore) ...[
          const SizedBox(height: 24),
          if (last.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '앨범을 더 불러오지 못했어요. 다시 시도해 주세요.',
                style: ExperienceFormStyle.text(context, 13, secondary: true),
              ),
            ),
          OutlinedButton(
            key: const ValueKey('social-profile-more-works'),
            onPressed: last.isLoading
                ? null
                : () {
                    if (last.hasError) {
                      ref.invalidate(
                        socialProfileWorksPageProvider(
                          SocialProfileWorksQuery(
                            profile.userId,
                            offset: _workOffsets.last,
                          ),
                        ),
                      );
                    } else if (hasMore) {
                      setState(() => _workOffsets.add(next!));
                    }
                  },
            child: Text(
              last.isLoading
                  ? '앨범을 불러오는 중…'
                  : last.hasError
                  ? '다시 시도'
                  : '앨범 더 보기',
            ),
          ),
        ],
      ],
    );
  }

  Widget _body(SocialProfile profile, bool own, List<Widget> headerActions) {
    final actionStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      textStyle: ExperienceFormStyle.text(context, 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final profileActions = own
        ? LayoutBuilder(
            builder: (context, constraints) {
              final stack = MediaQuery.textScalerOf(context).scale(13) > 20;
              final width = stack
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: OutlinedButton(
                      style: actionStyle,
                      onPressed: () => _push(const SocialProfileEditScreen()),
                      child: const Text('프로필 수정'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: Tooltip(
                      message: '월간 기록 남기기',
                      child: FilledButton.icon(
                        style: SocialStyle.primary(context).copyWith(
                          minimumSize: const WidgetStatePropertyAll(
                            Size(0, 44),
                          ),
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          textStyle: WidgetStatePropertyAll(
                            ExperienceFormStyle.text(context, 13),
                          ),
                        ),
                        onPressed: () => openMomentCompose(context, ref),
                        icon: const ExperienceIcon('Plus', size: 17),
                        label: const Text('기록 남기기'),
                      ),
                    ),
                  ),
                ],
              );
            },
          )
        : Align(
            alignment: Alignment.centerLeft,
            child: profile.isFollowing
                ? OutlinedButton(
                    onPressed: _busy ? null : () => _follow(profile),
                    child: Text(_busy ? '변경 중…' : '팔로잉'),
                  )
                : FilledButton(
                    style: SocialStyle.primary(context),
                    onPressed: _busy ? null : () => _follow(profile),
                    child: Text(_busy ? '변경 중…' : '팔로우'),
                  ),
          );
    final account = own && _personalView
        ? ref.watch(authViewModelProvider).asData?.value
        : null;
    final showLoginId =
        own &&
        _personalView &&
        account?.id == profile.userId &&
        ref.watch(socialCurrentUserIdProvider) == profile.userId &&
        ref.watch(visibleOrderOwnerProvider) == profile.userId;
    final identity = SocialProfileIdentity(
      key: ValueKey((profile.userId, ref.watch(socialCurrentUserIdProvider))),
      name: profile.displayName,
      handle: profile.handle,
      privateLoginId: showLoginId ? account?.email?.trim() : null,
      compact: own && _personalView,
      bio: profile.bio,
      avatarUrl: profile.avatarUrl,
      refreshImageUrl: () => _refreshAvatarUrl(profile),
      worksCount: profile.worksCount,
      momentsCount: profile.momentsCount,
      followersCount: profile.followersCount,
      followingCount: profile.followingCount,
      onFollowers: () => _push(SocialRelationsScreen(userId: profile.userId)),
      onFollowing: () => _push(
        SocialRelationsScreen(userId: profile.userId, followers: false),
      ),
    );
    final publicHeader = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (kIsWeb) ...[
          _webProfileHeading(own && _personalView, headerActions),
          SizedBox(height: own && _personalView ? 16 : 32),
          LayoutBuilder(
            builder: (context, bounds) {
              if (bounds.maxWidth < 840 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    SizedBox(height: own && _personalView ? 12 : 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: profileActions,
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 32),
                  SizedBox(width: own ? 280 : 140, child: profileActions),
                ],
              );
            },
          ),
          SizedBox(height: own && _personalView ? 16 : 28),
          Divider(color: SocialStyle.line(context)),
        ] else
          identity,
        if (!kIsWeb) ...[
          SizedBox(height: own && _personalView ? 12 : 16),
          profileActions,
        ],
      ],
    );
    final gallery = _collections(profile, own);
    if (own && _personalView) return _personal(publicHeader, gallery: gallery);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [publicHeader, const SizedBox(height: 28), gallery],
    );
  }
}
