import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../auth/presentation/views/login_screen.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../widgets/social_profile_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_widgets.dart';
import 'social_profile_screen.dart';

enum _RelationAction { follow, removeFollower, block }

class SocialRelationsScreen extends ConsumerStatefulWidget {
  const SocialRelationsScreen({
    super.key,
    required this.userId,
    this.followers = true,
  });

  final String userId;
  final bool followers;

  @override
  ConsumerState<SocialRelationsScreen> createState() =>
      _SocialRelationsScreenState();
}

class _SocialRelationsScreenState extends ConsumerState<SocialRelationsScreen> {
  late bool _followers = widget.followers;
  final Set<String> _busy = {};
  int _identityRevision = 0;
  DialogRoute<bool>? _confirmation;
  final List<int> _offsets = [0];

  bool _isCurrent(String actor, String owner, int revision) =>
      mounted &&
      revision == _identityRevision &&
      ref.read(socialCurrentUserIdProvider) == actor &&
      widget.userId == owner;

  void _resetIdentity() {
    _identityRevision++;
    _busy.clear();
    _offsets
      ..clear()
      ..add(0);
    _dismissConfirmation();
  }

  @override
  void didUpdateWidget(covariant SocialRelationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.followers != widget.followers) {
      _resetIdentity();
      _followers = widget.followers;
    }
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

  SocialRelationsQuery get _query =>
      SocialRelationsQuery(widget.userId, followers: _followers);

  void _openProfile(String id) {
    final own = ref.read(socialCurrentUserIdProvider) == id;
    Navigator.of(context).push<void>(
      snapFitRoute(
        page: SocialProfileScreen(userId: id),
        settings: kIsWeb
            ? WebAppRouteSettings(
                own
                    ? WebAppLocation.myProfile
                    : WebAppLocation(WebAppPage.socialProfile, id),
              )
            : null,
      ),
    );
  }

  void _invalidate() {
    ref.invalidate(socialRelationsProvider);
    ref.invalidate(socialRelationsPageProvider);
    ref.invalidate(socialProfileProvider);
    ref.invalidate(ownSocialProfileProvider);
    ref.invalidate(socialProfileWorksProvider);
    ref.invalidate(socialProfileWorksPageProvider);
    ref.invalidate(socialFeedProvider);
    ref.invalidate(socialBlockedProfilesProvider);
    ref.invalidate(socialSavedWorksProvider);
    ref.invalidate(socialSavedWorksPageProvider);
    ref.invalidate(socialWorkProvider);
    ref.invalidate(socialCommentsProvider);
    ref.invalidate(socialCommentsPageProvider);
  }

  Future<void> _act(SocialProfile person, _RelationAction action) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null) {
      final navigate = WebNavigationScope.maybeOf(context)?.onPublicNavigate;
      if (kIsWeb && navigate != null) {
        navigate(WebAppLocation.login);
        return;
      }
      await Navigator.of(context).push<void>(
        snapFitRoute(
          page: const LoginScreen(),
          settings: kIsWeb
              ? const WebAppRouteSettings(WebAppLocation.login)
              : null,
        ),
      );
      return;
    }
    if (actor == person.userId || _busy.contains(person.userId)) return;
    if (action == _RelationAction.removeFollower &&
        (actor != widget.userId || !_followers))
      return;
    if (_confirmation != null) return;
    final owner = widget.userId;
    final revision = _identityRevision;
    setState(() => _busy.add(person.userId));
    try {
      final needsConfirmation =
          action != _RelationAction.follow || person.isFollowing;
      if (needsConfirmation) {
        final title = switch (action) {
          _RelationAction.follow => '팔로우를 해제할까요?',
          _RelationAction.removeFollower => '팔로워에서 삭제할까요?',
          _RelationAction.block => '사용자를 차단할까요?',
        };
        final copy = switch (action) {
          _RelationAction.follow =>
            '${person.displayName}님의 공개 작품은 계속 볼 수 있어요.',
          _RelationAction.removeFollower =>
            '상대에게 알림을 보내지 않아요. 내가 상대를 팔로우하는 관계는 유지되며, 상대는 다시 팔로우할 수 있어요.',
          _RelationAction.block =>
            '양쪽 팔로우 관계가 해제되고 새 상호작용을 제한해요. 기존에 만든 앨범은 유지돼요.',
        };
        final label = switch (action) {
          _RelationAction.follow => '팔로우 해제',
          _RelationAction.removeFollower => '팔로워 삭제',
          _RelationAction.block => '차단',
        };
        final accepted = await _confirm(
          (context) => AlertDialog(
            title: Text(title),
            content: Text(copy),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: SocialStyle.primary(context),
                onPressed: () => Navigator.pop(context, true),
                child: Text(label),
              ),
            ],
          ),
        );
        if (!_isCurrent(actor, owner, revision) || accepted != true) return;
      }
      final repository = ref.read(socialRepositoryProvider);
      switch (action) {
        case _RelationAction.follow:
          await repository.setFollowing(person.userId, !person.isFollowing);
          break;
        case _RelationAction.removeFollower:
          await repository.removeFollower(person.userId);
          break;
        case _RelationAction.block:
          await repository.setBlocked(person.userId, true);
          break;
      }
      if (!_isCurrent(actor, owner, revision)) return;
      _invalidate();
    } catch (_) {
      if (_isCurrent(actor, owner, revision)) {
        _invalidate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경 결과를 확인하지 못했어요. 최신 상태를 다시 확인해 주세요.')),
        );
      }
    } finally {
      if (_isCurrent(actor, owner, revision)) {
        setState(() => _busy.remove(person.userId));
      }
    }
  }

  Future<String?> _refreshAvatarUrl(String userId) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final owner = widget.userId;
    final revision = _identityRevision;
    final profile = await ref
        .read(socialRepositoryProvider)
        .fetchProfile(userId);
    if (!mounted ||
        revision != _identityRevision ||
        actor != ref.read(socialCurrentUserIdProvider) ||
        owner != widget.userId ||
        profile?.userId != userId)
      return null;
    if (actor != null) {
      final blocked = await ref.read(socialBlockedProfilesProvider.future);
      if (!_isCurrent(actor, owner, revision) ||
          blocked.any(
            (person) => person.userId == owner || person.userId == userId,
          ))
        return null;
    }
    return profile?.avatarUrl;
  }

  void _selectTab(bool followers) {
    if (_followers == followers) return;
    setState(() {
      _followers = followers;
      _offsets
        ..clear()
        ..add(0);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _offsets
        ..clear()
        ..add(0);
    });
    ref.invalidate(socialRelationsPageProvider);
    try {
      await ref.read(socialRelationsPageProvider(_query).future);
    } catch (_) {
      // The list's error state owns retry feedback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(socialCurrentUserIdProvider);
    ref.listen<String?>(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) _resetIdentity();
    });
    final pages = [
      for (final offset in _offsets)
        ref.watch(
          socialRelationsPageProvider(
            SocialRelationsQuery(
              widget.userId,
              followers: _followers,
              offset: offset,
            ),
          ),
        ),
    ];
    final relations = pages.first;
    final last = pages.last;
    final next = last.value?.nextOffset;
    final hasMore =
        last.value?.hasMore == true &&
        next != null &&
        next > _offsets.last &&
        !_offsets.contains(next);
    final blocked = actor == null
        ? const <String>{}
        : ref
                  .watch(socialBlockedProfilesProvider)
                  .asData
                  ?.value
                  .map((person) => person.userId)
                  .toSet() ??
              const <String>{};
    return SocialWebFrame(
      section: actor == widget.userId ? WebSection.myProfile : WebSection.feed,
      child: Scaffold(
        appBar: const ExperienceHeader(
          title: '팔로워·팔로잉',
          showNotifications: false,
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SocialProfileContent(
                maxWidth: 760,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openProfile(widget.userId),
                        icon: const Icon(Icons.person_outline, size: 18),
                        label: const Text('공개 프로필 보기'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('팔로워'),
                          showCheckmark: false,
                          selectedColor: ExperienceFormStyle.selection(context),
                          side: BorderSide.none,
                          labelStyle: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: FontWeight.w500,
                          ),
                          selected: _followers,
                          onSelected: (_) => _selectTab(true),
                        ),
                        ChoiceChip(
                          label: const Text('팔로잉'),
                          showCheckmark: false,
                          selectedColor: ExperienceFormStyle.selection(context),
                          side: BorderSide.none,
                          labelStyle: ExperienceFormStyle.text(
                            context,
                            14,
                            weight: FontWeight.w500,
                          ),
                          selected: !_followers,
                          onSelected: (_) => _selectTab(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '팔로워와 팔로잉은 공개 프로필의 관계 목록이에요.',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    relations.when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () => const SocialProfileStatePanel(
                        title: '관계 목록을 불러오고 있어요.',
                        message: '잠시만 기다려 주세요.',
                        loading: true,
                      ),
                      error: (_, _) => SocialProfileStatePanel(
                        title: '목록을 불러오지 못했어요.',
                        message: '연결 상태를 확인하고 다시 시도해 주세요.',
                        action: OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('다시 시도'),
                        ),
                      ),
                      data: (_) {
                        if (blocked.contains(widget.userId)) {
                          return const SocialProfileStatePanel(
                            title: '관계 목록을 볼 수 없어요.',
                            message: '차단한 사용자의 관계 목록은 표시하지 않아요.',
                          );
                        }
                        final seen = <String>{};
                        final people = <SocialProfile>[
                          for (final page in pages)
                            if (!page.isReloading)
                              for (final person
                                  in page.value?.items ??
                                      const <SocialProfile>[])
                                if (!blocked.contains(person.userId) &&
                                    seen.add(person.userId))
                                  person,
                        ];
                        if (people.isEmpty) {
                          return SocialProfileStatePanel(
                            title: _followers
                                ? '아직 팔로워가 없어요.'
                                : '아직 팔로우한 사람이 없어요.',
                            message: _followers
                                ? '새로운 관계가 생기면 이곳에 표시돼요.'
                                : '마음에 드는 작품의 창작자를 팔로우해 보세요.',
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...people.map((person) {
                              final me = person.userId == actor;
                              final busy = _busy.contains(person.userId);
                              return SocialRelationTile(
                                key: ValueKey(
                                  'social-relation-${person.userId}',
                                ),
                                name: person.displayName,
                                handle: person.handle,
                                avatarUrl: person.avatarUrl,
                                refreshImageUrl: () =>
                                    _refreshAvatarUrl(person.userId),
                                isMe: me,
                                onOpenProfile: () =>
                                    _openProfile(person.userId),
                                actions: me
                                    ? const []
                                    : [
                                        OutlinedButton(
                                          onPressed: busy
                                              ? null
                                              : () => _act(
                                                  person,
                                                  _RelationAction.follow,
                                                ),
                                          child: Text(
                                            busy
                                                ? '변경 중…'
                                                : person.isFollowing
                                                ? '팔로잉'
                                                : '팔로우',
                                          ),
                                        ),
                                        if (actor != null)
                                          PopupMenuButton<_RelationAction>(
                                            tooltip:
                                                '${person.displayName} 관계 관리',
                                            enabled: !busy,
                                            onSelected: (action) =>
                                                _act(person, action),
                                            itemBuilder: (_) => [
                                              if (actor == widget.userId &&
                                                  _followers)
                                                const PopupMenuItem(
                                                  value: _RelationAction
                                                      .removeFollower,
                                                  child: Text('팔로워 삭제'),
                                                ),
                                              const PopupMenuItem(
                                                value: _RelationAction.block,
                                                child: Text('사용자 차단'),
                                              ),
                                            ],
                                          ),
                                      ],
                              );
                            }),
                            if (last.isLoading || last.hasError || hasMore) ...[
                              const SizedBox(height: 20),
                              if (last.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '관계 목록을 더 불러오지 못했어요. 다시 시도해 주세요.',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      13,
                                      secondary: true,
                                    ),
                                  ),
                                ),
                              OutlinedButton(
                                key: const ValueKey('social-relations-more'),
                                onPressed: last.isLoading
                                    ? null
                                    : () {
                                        if (last.hasError) {
                                          ref.invalidate(
                                            socialRelationsPageProvider(
                                              SocialRelationsQuery(
                                                widget.userId,
                                                followers: _followers,
                                                offset: _offsets.last,
                                              ),
                                            ),
                                          );
                                        } else if (hasMore) {
                                          setState(() => _offsets.add(next!));
                                        }
                                      },
                                child: Text(
                                  last.isLoading
                                      ? '불러오는 중…'
                                      : last.hasError
                                      ? '다시 시도'
                                      : '더 보기',
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
