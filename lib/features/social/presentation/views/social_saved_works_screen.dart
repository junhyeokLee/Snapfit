import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/web/web_design.dart'
    show WebPageHeading, WebPageLayout;
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_actions.dart';
import '../social_navigation.dart';
import '../widgets/social_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_shimmer.dart';

class SocialSavedWorksScreen extends ConsumerStatefulWidget {
  const SocialSavedWorksScreen({super.key});
  @override
  ConsumerState<SocialSavedWorksScreen> createState() =>
      _SocialSavedWorksScreenState();
}

class _SocialSavedWorksScreenState
    extends ConsumerState<SocialSavedWorksScreen> {
  final _busy = <String>{};
  final _removed = <String>{};
  int _mutationRevision = 0;
  final _offsets = <int>[0];
  GlobalKey? _undoNoticeKey;

  Future<void> _refresh() async {
    final owner = ref.read(socialCurrentUserIdProvider);
    if (owner == null) return;
    ref.invalidate(socialSavedWorksPageProvider);
    setState(
      () => _offsets
        ..clear()
        ..add(0),
    );
    try {
      await ref.read(
        socialSavedWorksPageProvider(SocialPageQuery(ownerId: owner)).future,
      );
    } catch (_) {
      // The provider renders its retry state on failure.
    }
  }

  bool _currentMutation(String actor, int revision) =>
      mounted &&
      revision == _mutationRevision &&
      ref.read(socialCurrentUserIdProvider) == actor;

  void _dismissUndoNotice() {
    final key = _undoNoticeKey;
    _undoNoticeKey = null;
    if (key == null) return;
    // The account listener can run during build; close only our visible notice.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final noticeContext = key.currentContext;
      if (noticeContext != null && noticeContext.mounted) {
        ScaffoldMessenger.maybeOf(noticeContext)?.hideCurrentSnackBar();
      }
    });
  }

  @override
  void dispose() {
    _dismissUndoNotice();
    super.dispose();
  }

  Future<void> _removeSaved(String id) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    if (actor == null) return;
    setState(() => _removed.add(id));
    await _updateSaved(id, false, actor, _mutationRevision);
  }

  Future<void> _updateSaved(
    String id,
    bool saved,
    String actor,
    int revision,
  ) async {
    // Undo retains the account that removed the work, even after the card leaves.
    if (!_currentMutation(actor, revision) || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final confirmed = await ref
          .read(socialRepositoryProvider)
          .setSaved(id, saved);
      if (!_currentMutation(actor, revision)) return;
      if (saved && !confirmed)
        throw StateError('Save restoration not confirmed');
      invalidateSocial(ref, workId: id);
      if (!saved) {
        final key = GlobalKey();
        _undoNoticeKey = key;
        final messenger = ScaffoldMessenger.of(context);
        // Replace immediately so a previous account's undo cannot stay queued.
        messenger.removeCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('저장을 해제했어요', key: key),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action: SnackBarAction(
              label: '되돌리기',
              onPressed: () {
                if (mounted) setState(() => _removed.remove(id));
                _updateSaved(id, true, actor, revision);
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (_currentMutation(actor, revision)) {
        if (!saved) setState(() => _removed.remove(id));
        invalidateSocial(ref, workId: id);
        socialError(context);
      }
    } finally {
      if (_currentMutation(actor, revision)) setState(() => _busy.remove(id));
    }
  }

  Future<void> _openWork(SocialWork work) async {
    final actor = ref.read(socialCurrentUserIdProvider);
    final revision = _mutationRevision;
    await openSocialWork(context, work.id);
    if (mounted &&
        revision == _mutationRevision &&
        ref.read(socialCurrentUserIdProvider) == actor) {
      // Detail can unsave a work, or its creator can withdraw it while read.
      ref.invalidate(socialSavedWorksPageProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous == next || !mounted) return;
      _mutationRevision++;
      _dismissUndoNotice();
      setState(() {
        _busy.clear();
        _removed.clear();
        _offsets
          ..clear()
          ..add(0);
      });
      ref.invalidate(socialSavedWorksPageProvider);
    });
    final user = ref.watch(socialCurrentUserIdProvider);
    final pages = [
      if (user != null)
        for (final offset in _offsets)
          ref.watch(
            socialSavedWorksPageProvider(
              SocialPageQuery(offset: offset, ownerId: user),
            ),
          ),
    ];
    return SocialWebFrame(
      child: Scaffold(
        appBar: kIsWeb ? null : AppBar(title: const Text('저장한 기록·앨범')),
        backgroundColor: SocialStyle.background(context),
        body: SocialContent(
          maxWidth: WebPageLayout.maxWidth,
          child: user == null
              ? SocialEmpty(
                  title: '나만 보는 기록·앨범 보관함',
                  message: '로그인하면 저장한 기록과 앨범을 다시 볼 수 있어요.',
                  action: FilledButton(
                    style: SocialStyle.primary(context),
                    onPressed: () => requireSocialLogin(context, ref),
                    child: const Text('로그인'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final inset = WebPageLayout.horizontalInset(
                        bounds.maxWidth,
                      );
                      final contentWidth = bounds.maxWidth - inset * 2;
                      final columns =
                          contentWidth >= 760 &&
                              MediaQuery.textScalerOf(context).scale(1) <= 1.4
                          ? 2
                          : 1;
                      final seen = <String>{};
                      final works = <({SocialWork work, int offset})>[
                        for (var index = 0; index < pages.length; index++)
                          for (final work
                              in pages[index].value?.items ??
                                  const <SocialWork>[])
                            if (work.isPublished &&
                                seen.add(work.id) &&
                                !_removed.contains(work.id))
                              (work: work, offset: _offsets[index]),
                      ];
                      return CustomScrollView(
                        key: ValueKey('social-saved-scroll-$user'),
                        cacheExtent: 800,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              inset,
                              kIsWeb ? 32 : 16,
                              inset,
                              kIsWeb ? 28 : 20,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: _heading(context),
                            ),
                          ),
                          ...[
                            if (pages.first.hasError)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: inset,
                                  ),
                                  child: SocialFailure(
                                    onRetry: () => ref.invalidate(
                                      socialSavedWorksPageProvider(
                                        SocialPageQuery(ownerId: user),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: EdgeInsets.symmetric(horizontal: inset),
                              sliver: SliverList.builder(
                                itemCount: (works.length / columns).ceil(),
                                itemBuilder: (context, row) => Padding(
                                  padding: const EdgeInsets.only(bottom: 28),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var column = 0;
                                        column < columns;
                                        column++
                                      ) ...[
                                        if (column > 0)
                                          const SizedBox(width: 28),
                                        Expanded(
                                          child:
                                              row * columns + column <
                                                  works.length
                                              ? _card(
                                                  works[row * columns + column],
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            for (var index = 0; index < pages.length; index++)
                              if (pages[index].isLoading ||
                                  (index > 0 && pages[index].hasError))
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: inset,
                                    ),
                                    child: pages[index].hasError
                                        ? SocialFailure(
                                            onRetry: () => ref.invalidate(
                                              socialSavedWorksPageProvider(
                                                SocialPageQuery(
                                                  offset: _offsets[index],
                                                  ownerId: user,
                                                ),
                                              ),
                                            ),
                                          )
                                        : works.isNotEmpty &&
                                              pages[index].hasValue
                                        ? const SizedBox.shrink()
                                        : index == 0
                                        ? const SnapFitShimmerSocialFeed()
                                        : const SocialLoading(
                                            message: '저장한 기록과 앨범을 불러오고 있어요.',
                                          ),
                                  ),
                                ),
                            if (works.isEmpty &&
                                !pages.first.isLoading &&
                                !pages.first.hasError)
                              const SliverToBoxAdapter(
                                child: SocialEmpty(
                                  title: '아직 저장한 기록이나 앨범이 없어요.',
                                  message: '마음에 드는 기록이나 앨범에서 저장 버튼을 눌러보세요.',
                                ),
                              ),
                            if (!pages.last.isLoading &&
                                !pages.last.hasError &&
                                pages.last.value?.hasMore == true &&
                                pages.last.value!.nextOffset > _offsets.last &&
                                !_offsets.contains(
                                  pages.last.value!.nextOffset,
                                ))
                              SliverToBoxAdapter(
                                child: Center(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      final next = pages.last.value!.nextOffset;
                                      if (next <= _offsets.last ||
                                          _offsets.contains(next)) {
                                        return;
                                      }
                                      setState(() => _offsets.add(next));
                                    },
                                    child: const Text('기록·앨범 더 보기'),
                                  ),
                                ),
                              ),
                          ],
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      );
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _heading(BuildContext context) {
    const description = '마음에 든 기록과 앨범을 다시 펼쳐보세요.';
    if (kIsWeb) {
      return const WebPageHeading(
        title: '저장한 기록·앨범',
        eyebrow: 'MY COLLECTION',
        description: description,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExperienceIcon('Lock', size: 15, color: SocialStyle.accent(context)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '나에게만 보여요 · 공개가 종료된 기록과 앨범은 표시하지 않아요.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(({SocialWork work, int offset}) item) {
    final work = item.work;
    return Column(
      key: ValueKey('social-saved-card-${work.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SocialWorkTile(
          work: work,
          preserveArtworkRatio: true,
          onRetry: () => ref.invalidate(
            socialSavedWorksPageProvider(
              SocialPageQuery(
                offset: item.offset,
                ownerId: ref.read(socialCurrentUserIdProvider),
              ),
            ),
          ),
          onTap: () => _openWork(work),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      openSocialProfile(context, work.author.userId),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    foregroundColor: SnapFitColors.textSecondaryOf(context),
                  ),
                  child: Text(
                    work.author.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.45),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              key: ValueKey('social-saved-remove-${work.id}'),
              onPressed: _busy.contains(work.id)
                  ? null
                  : () => _removeSaved(work.id),
              style: TextButton.styleFrom(
                foregroundColor: SocialStyle.accent(context),
                minimumSize: const Size(48, 48),
              ),
              icon: const ExperienceIcon('Bookmark', size: 20),
              label: const Text('저장 해제', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        Divider(height: 12, color: SocialStyle.line(context)),
      ],
    );
  }
}
