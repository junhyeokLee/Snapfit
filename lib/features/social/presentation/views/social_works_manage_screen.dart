import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../../../../shared/widgets/experience_icon.dart';

class SocialWorksManageScreen extends ConsumerStatefulWidget {
  const SocialWorksManageScreen({super.key});
  @override
  ConsumerState<SocialWorksManageScreen> createState() =>
      _SocialWorksManageScreenState();
}

class _SocialWorksManageScreenState
    extends ConsumerState<SocialWorksManageScreen> {
  String _filter = 'all';
  final _busy = <String>{};
  final _offsets = <int>[0];
  int _identityRevision = 0;
  DialogRoute<bool>? _confirmation;

  bool _current(String owner, int revision) =>
      mounted &&
      revision == _identityRevision &&
      ref.read(socialCurrentUserIdProvider) == owner;

  void _resetPages() => _offsets
    ..clear()
    ..add(0);

  void _dismissConfirmation() {
    final route = _confirmation;
    _confirmation = null;
    if (route == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = route.navigator;
      if (navigator != null && route.isActive) navigator.removeRoute(route);
    });
  }

  @override
  void dispose() {
    _identityRevision++;
    _dismissConfirmation();
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

  void _refreshAfterChange(String workId) {
    setState(_resetPages);
    invalidateSocial(ref, workId: workId);
  }

  bool _restricted(SocialWork work) {
    if (work.isRestricted) return true;
    for (final offset in _offsets) {
      final page = ref
          .read(
            socialOwnWorksPageProvider(
              SocialOwnWorksQuery(status: _filter, offset: offset),
            ),
          )
          .asData
          ?.value;
      for (final current in page?.items ?? const <SocialWork>[]) {
        if (current.id == work.id) return current.isRestricted;
      }
    }
    return false;
  }

  Future<void> _change(SocialWork work, bool delete) async {
    if (_busy.contains(work.id) ||
        _confirmation != null ||
        !delete && _restricted(work))
      return;
    final owner = ref.read(socialCurrentUserIdProvider);
    if (owner == null || owner != work.author.userId) return;
    final revision = _identityRevision;
    // Reserve the action before its confirmation is pushed, including the
    // asynchronous interval where another tap could open a second dialog.
    setState(() => _busy.add(work.id));
    try {
      final confirm = await _confirm(
        (context) => AlertDialog(
          title: Text(
            delete
                ? '공개본을 삭제할까요?'
                : work.isPublished
                ? '공개본을 비공개로 바꿀까요?'
                : '이 공개본을 다시 공개할까요?',
          ),
          content: Text(
            delete
                ? '프로필에서 이 공개 앨범을 삭제해요. 원본 앨범과 인쇄 주문은 그대로 유지돼요.'
                : work.isPublished
                ? '공개 프로필에서 내려가요. 원본 앨범은 그대로 유지돼요.'
                : '처음 확인한 공개 페이지를 그대로 보여줘요. 원본의 최신 변경은 가져오지 않아요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                delete
                    ? '공개본 삭제'
                    : work.isPublished
                    ? '비공개 전환'
                    : '다시 공개',
              ),
            ),
          ],
        ),
      );
      if (!_current(owner, revision) ||
          confirm != true ||
          !delete && _restricted(work))
        return;
      final repo = ref.read(socialRepositoryProvider);
      if (delete) {
        await repo.deleteWork(work.id);
      } else {
        await repo.setWorkVisibility(work.id, !work.isPublished);
      }
      if (_current(owner, revision)) _refreshAfterChange(work.id);
    } catch (_) {
      if (_current(owner, revision)) {
        _refreshAfterChange(work.id);
        socialError(context);
      }
    } finally {
      if (_current(owner, revision)) setState(() => _busy.remove(work.id));
    }
  }

  Future<void> _publish() async {
    final owner = ref.read(socialCurrentUserIdProvider);
    final revision = _identityRevision;
    if (owner == null) return;
    await openSocialPublish(context);
    if (_current(owner, revision)) {
      setState(_resetPages);
      ref.invalidate(socialOwnWorksPageProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next && mounted) {
        _identityRevision++;
        _dismissConfirmation();
        setState(() {
          _busy.clear();
          _filter = 'all';
          _resetPages();
        });
      }
    });
    final user = ref.watch(socialCurrentUserIdProvider);
    final shownIds = <String>{};
    return SocialWebFrame(
      section: WebSection.myProfile,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: AppBar(
          title: const Text('공개 관리'),
          actions: [
            IconButton(
              tooltip: '기존 앨범에서 새 공개본 만들기',
              onPressed: user == null ? null : _publish,
              icon: const ExperienceIcon('Plus'),
            ),
          ],
        ),
        body: SocialContent(
          child: user == null
              ? SocialEmpty(
                  title: '내 공개 기록과 앨범을 관리해요.',
                  message: '로그인하고 공개한 기록과 앨범을 관리해 보세요.',
                  action: FilledButton(
                    onPressed: () => requireSocialLogin(context, ref),
                    child: const Text('로그인'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(socialOwnWorksPageProvider);
                    setState(_resetPages);
                    try {
                      await ref.read(
                        socialOwnWorksPageProvider(
                          SocialOwnWorksQuery(status: _filter),
                        ).future,
                      );
                    } catch (_) {
                      // The provider renders its retry state on failure.
                    }
                  },
                  child: ListView(
                    cacheExtent: 800,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(22),
                    children: [
                      const Text(
                        '하나의 앨범에서 여러 번 공개해도 각 공개본을 따로 관리할 수 있어요.',
                        style: TextStyle(height: 1.8),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in const {
                            'all': '전체',
                            'public': '공개 중',
                            'private': '비공개 보관',
                          }.entries)
                            ChoiceChip(
                              label: Text(entry.value),
                              selected: _filter == entry.key,
                              onSelected: (_) => setState(() {
                                _filter = entry.key;
                                _resetPages();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      for (var index = 0; index < _offsets.length; index++)
                        _page(index, shownIds),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _page(int index, Set<String> shownIds) {
    final query = SocialOwnWorksQuery(status: _filter, offset: _offsets[index]);
    final result = ref.watch(socialOwnWorksPageProvider(query));
    void retry() => ref.invalidate(socialOwnWorksPageProvider(query));
    return result.when(
      // Retain image recovery state until a refreshed signature decodes.
      skipLoadingOnRefresh: true,
      loading: () => const SocialLoading(message: '내 공개 항목을 불러오고 있어요.'),
      error: (_, _) => SocialFailure(onRetry: retry),
      data: (page) => Column(
        children: [
          if (page.items.isEmpty && index == 0)
            SocialEmpty(
              title: '아직 공개한 기록이나 앨범이 없어요.',
              message: '기존 앨범에서 원하는 장면을 공개해 보세요.',
              action: FilledButton(
                style: SocialStyle.primary(context),
                onPressed: _publish,
                child: const Text('내 앨범에서 공개하기'),
              ),
            ),
          for (final work in page.items)
            if (shownIds.add(work.id)) _item(work, onRetry: retry),
          if (index == _offsets.length - 1 &&
              page.hasMore &&
              page.nextOffset > query.offset)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: OutlinedButton(
                onPressed: () {
                  if (_offsets.last != query.offset ||
                      _offsets.contains(page.nextOffset))
                    return;
                  setState(() => _offsets.add(page.nextOffset));
                },
                child: const Text('공개본 더 보기'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(SocialWork work, {required VoidCallback onRetry}) => Padding(
    key: ValueKey(work.id),
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => openSocialWork(context, work.id),
          leading: SizedBox(
            width: 76,
            height: 90,
            child: DecoratedBox(
              decoration: BoxDecoration(color: SocialStyle.paper(context)),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: work.isRestricted || work.imageUrls.isEmpty
                    ? const ExperienceIcon('BookOpen')
                    : SocialWorkImage(
                        key: ValueKey('social-manage-image-${work.id}'),
                        url: work.imageUrls.first,
                        onRetry: onRetry,
                      ),
              ),
            ),
          ),
          title: Text(work.title),
          subtitle: Text(
            work.isRestricted
                ? '공개 제한 · 원본은 그대로 보관돼요.'
                : '${work.isPublished ? '공개 중' : '비공개 보관'} · ${work.imageUrls.length}쪽',
          ),
          trailing: const ExperienceIcon('ChevronRight'),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: ValueKey('social-manage-visibility-${work.id}'),
              onPressed: _busy.contains(work.id) || work.isRestricted
                  ? null
                  : () => _change(work, false),
              child: Text(
                work.isRestricted
                    ? '공개 제한 중'
                    : work.isPublished
                    ? '비공개로 전환'
                    : '같은 공개본으로 다시 공개',
              ),
            ),
            TextButton(
              onPressed: _busy.contains(work.id)
                  ? null
                  : () => _change(work, true),
              child: const Text('공개본 삭제'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(),
      ],
    ),
  );
}
