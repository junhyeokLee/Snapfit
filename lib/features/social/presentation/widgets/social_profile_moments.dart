import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../moments/presentation/moments_navigation.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_page_boundaries.dart';
import '../social_actions.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../views/social_moment_month_screen.dart';
import 'social_moment_month_cover.dart';
import 'social_moment_month_cover_picker.dart';
import 'social_profile_widgets.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// Public snapshots only. Private journal data is never loaded on a profile.
class SocialProfileMoments extends ConsumerStatefulWidget {
  const SocialProfileMoments({
    super.key,
    required this.userId,
    required this.own,
  });
  final String userId;
  final bool own;
  @override
  ConsumerState<SocialProfileMoments> createState() =>
      _SocialProfileMomentsState();
}

class _SocialProfileMomentsState extends ConsumerState<SocialProfileMoments> {
  final _queries = <SocialProfileWorksQuery>[];
  final _coverBusy = <String>{};
  int _revision = 0;
  final _boundaries = SocialPageBoundaries<SocialProfileWorksQuery>();
  bool _reconciling = false;
  String get _userId => widget.userId.trim();

  SocialProfileWorksQuery get _firstQuery =>
      SocialProfileWorksQuery(_userId, limit: 6);

  @override
  void initState() {
    super.initState();
    _queries.add(_firstQuery);
  }

  void _resetPages() {
    _revision++;
    _boundaries.clear();
    _reconciling = false;
    _coverBusy.clear();
    _queries
      ..clear()
      ..add(_firstQuery);
  }

  bool _current(int revision, String userId, String? viewer) =>
      mounted &&
      revision == _revision &&
      userId == _userId &&
      ref.read(socialCurrentUserIdProvider) == viewer;

  SocialProfileWorksQuery? _nextQuery(SocialMomentMonthsPage? page) {
    if (page?.hasMore != true) return null;
    final cursor = page!.nextCursor;
    final next = cursor != null && cursor.isNotEmpty
        ? SocialProfileWorksQuery(
            _userId,
            limit: 6,
            cursor: Map.unmodifiable(cursor),
          )
        : page.nextOffset > _queries.last.offset
        ? SocialProfileWorksQuery(_userId, limit: 6, offset: page.nextOffset)
        : null;
    return next != null && !_queries.contains(next) ? next : null;
  }

  void _reload() {
    setState(_resetPages);
    ref.invalidate(socialProfileMomentMonthsPageProvider);
  }

  void _viewerChanged() {
    final previous = List<SocialProfileWorksQuery>.of(_queries);
    setState(_resetPages);
    for (final query in previous)
      ref.invalidate(socialProfileMomentMonthsPageProvider(query));
  }

  bool _reconcilePages(List<AsyncValue<SocialMomentMonthsPage>> pages) {
    if (_reconciling) return true;
    final keep = _boundaries.observe(_queries, [
      for (final result in pages)
        if (!result.isLoading && !result.hasError && result.asData != null)
          _pageBoundary(result.asData!.value)
        else
          null,
    ]);
    if (keep != null) {
      _reconciling = true;
      final revision = ++_revision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        setState(() {
          _coverBusy.clear();
          _queries.removeRange(keep, _queries.length);
          _reconciling = false;
        });
      });
    }
    return _reconciling;
  }

  String _pageBoundary(SocialMomentMonthsPage page) => socialPageBoundary(
    nextCursor: page.nextCursor,
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    itemKeys: page.items.map((month) => socialMomentMonthKey(month.month)),
  );

  Future<void> _chooseCover(SocialMomentMonth collection) async {
    final viewer = ref.read(socialCurrentUserIdProvider), userId = _userId;
    final revision = _revision;
    final key = socialMomentMonthKey(collection.month);
    if (!widget.own ||
        viewer == null ||
        viewer != userId ||
        ModalRoute.of(context)?.isCurrent == false ||
        _coverBusy.contains(key))
      return;
    setState(() => _coverBusy.add(key));
    try {
      await showSocialMomentMonthCoverPicker(
        context,
        userId: userId,
        month: collection.month,
        selectedWorkId: collection.selectedWorkId,
        onSelect: (workId) async {
          if (!_current(revision, userId, viewer) || !widget.own)
            throw StateError('공개 프로필이 변경되었어요.');
          await ref
              .read(socialRepositoryProvider)
              .setMomentMonthCover(collection.month, workId)
              .timeout(const Duration(seconds: 25));
          if (!_current(revision, userId, viewer) || !widget.own)
            throw StateError('공개 프로필이 변경되었어요.');
          invalidateSocial(ref);
        },
      );
    } finally {
      if (_current(revision, userId, viewer))
        setState(() => _coverBusy.remove(key));
    }
  }

  @override
  void didUpdateWidget(covariant SocialProfileMoments oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId.trim() != _userId || oldWidget.own != widget.own)
      _resetPages();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(socialCurrentUserIdProvider);
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous != next) _viewerChanged();
    });
    ref.listen(socialAuthStateProvider, (previous, next) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous?.asData?.value != next.asData?.value)
        _viewerChanged();
    });
    final revision = _revision, userId = _userId;
    final pages = [
      for (final query in _queries)
        ref.watch(socialProfileMomentMonthsPageProvider(query)),
    ];
    final first = pages.first;
    if (first.isLoading) {
      return const SocialLoading(message: '공개한 기록을 불러오고 있어요.');
    }
    if (first.hasError || !first.hasValue) {
      return SocialProfileStatePanel(
        title: '기록을 불러오지 못했어요.',
        message: '연결을 확인한 뒤 다시 불러올 수 있어요.',
        action: OutlinedButton(
          onPressed: _reload,
          child: const Text('기록 다시 불러오기'),
        ),
      );
    }
    if (_reconcilePages(pages)) {
      return const SocialLoading(message: '월간 기록을 새로 확인하고 있어요.');
    }
    final seen = <String>{};
    final months = <SocialMomentMonth>[
      for (final page in pages)
        if (!page.isLoading && !page.hasError)
          for (final month in page.value?.items ?? const <SocialMomentMonth>[])
            if (month.cover.isMoment &&
                month.cover.isPublished &&
                month.cover.author.userId == userId &&
                seen.add(socialMomentMonthKey(month.month)))
              month,
    ];
    final hasMiddleFailure =
        pages.length > 2 &&
        pages.skip(1).take(pages.length - 2).any((page) => page.hasError);
    if (months.isEmpty && !hasMiddleFailure) {
      return SocialProfileStatePanel(
        title: widget.own ? '한 장씩, 나의 한 달을 채워요.' : '아직 공개한 기록이 없어요.',
        message: widget.own
            ? '사진과 짧은 글을 남기고, 나누고 싶은 한 장만 공개해 보세요.'
            : '공개한 사진과 글이 이곳에 모여요.',
        action: widget.own
            ? FilledButton.icon(
                style: SocialStyle.primary(context),
                onPressed: () => openMomentCompose(context, ref),
                icon: const ExperienceIcon('Plus', size: 18),
                label: const Text('월간 기록 남기기'),
              )
            : null,
      );
    }
    final last = pages.last;
    final next = _nextQuery(last.asData?.value);
    final more = next != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Text(
            '공개한 기록을 한 달에 한 권씩 모았어요.',
            style: TextStyle(
              color: SocialStyle.ink(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, bounds) {
            final columns = bounds.maxWidth >= 950
                ? 3
                : bounds.maxWidth >= 650
                ? 2
                : 1;
            const gap = 28.0;
            final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 28,
              children: [
                for (final month in months)
                  SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SocialMomentMonthCover(
                          collection: month,
                          onRetry: _reload,
                          onOpen: () {
                            if (!_current(revision, userId, viewer)) return;
                            Navigator.of(context).push<void>(
                              snapFitRoute(page: SocialMomentMonthScreen(
                                  userId: userId,
                                  month: month.month,
                                ), settings: WebAppRouteSettings(
                                  WebAppLocation.socialMomentMonth(
                                    userId,
                                    month.month,
                                  ),
                                )),
                            );
                          },
                        ),
                        if (widget.own && viewer == userId)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: TextButton.icon(
                              key: ValueKey(
                                'social-moment-month-cover-action-${socialMomentMonthKey(month.month)}',
                              ),
                              onPressed:
                                  _coverBusy.contains(
                                    socialMomentMonthKey(month.month),
                                  )
                                  ? null
                                  : () {
                                      if (_current(revision, userId, viewer))
                                        _chooseCover(month);
                                    },
                              icon: const ExperienceIcon('Image', size: 17),
                              label: const Text('표지 사진 선택'),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        for (var index = 1; index < pages.length - 1; index++)
          if (pages[index].hasError && !pages[index].isLoading)
            _middleFailure(index, _queries[index], revision, userId, viewer),
        if (last.isLoading || last.hasError || more) ...[
          const SizedBox(height: 20),
          OutlinedButton(
            key: const ValueKey('social-profile-more-moments'),
            onPressed: last.isLoading
                ? null
                : () {
                    if (!_current(revision, userId, viewer)) return;
                    if (last.hasError) {
                      ref.invalidate(
                        socialProfileMomentMonthsPageProvider(_queries.last),
                      );
                    } else if (next != null && !_queries.contains(next)) {
                      setState(() => _queries.add(next));
                    }
                  },
            child: Text(
              last.isLoading
                  ? '불러오는 중…'
                  : last.hasError
                  ? '기록 다시 불러오기'
                  : '지난 월간 기록 보기',
            ),
          ),
        ],
      ],
    );
  }

  Widget _middleFailure(
    int index,
    SocialProfileWorksQuery query,
    int revision,
    String userId,
    String? viewer,
  ) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text('일부 월간 기록을 불러오지 못했어요.')),
        const SizedBox(height: 8),
        OutlinedButton(
          key: ValueKey('social-profile-middle-retry-$index'),
          onPressed: () {
            if (_current(revision, userId, viewer) && _queries.contains(query))
              ref.invalidate(socialProfileMomentMonthsPageProvider(query));
          },
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );
}
