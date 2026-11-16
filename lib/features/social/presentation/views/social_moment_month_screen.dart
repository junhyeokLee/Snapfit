import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/web/web_design.dart' show WebPageLayout;
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_page_boundaries.dart';
import '../social_navigation.dart';
import '../widgets/social_page_header.dart';
import '../widgets/social_profile_widgets.dart';
import '../widgets/social_web_frame.dart';
import '../widgets/social_widgets.dart';
import 'social_feed_screen.dart';

/// A public monthly collection. It never reads the owner's private journal.
class SocialMomentMonthScreen extends ConsumerStatefulWidget {
  const SocialMomentMonthScreen({
    super.key,
    required this.userId,
    required this.month,
  });

  final String userId;
  final DateTime month;

  @override
  ConsumerState<SocialMomentMonthScreen> createState() =>
      _SocialMomentMonthScreenState();
}

class _SocialMomentMonthScreenState
    extends ConsumerState<SocialMomentMonthScreen> {
  final _queries = <SocialMomentMonthQuery>[];
  int _revision = 0;
  final _boundaries = SocialPageBoundaries<SocialMomentMonthQuery>();
  bool _reconciling = false;

  String get _userId => widget.userId.trim();
  DateTime get _month => DateTime.utc(widget.month.year, widget.month.month);
  String get _title => '${_month.year}년 ${_month.month}월';

  SocialMomentMonthQuery get _firstQuery =>
      SocialMomentMonthQuery(_userId, _month, limit: 12);

  @override
  void initState() {
    super.initState();
    _queries.add(_firstQuery);
  }

  SocialMomentMonthQuery? _nextQuery(SocialWorkPage? page) {
    if (page?.hasMore != true) return null;
    final cursor = page!.nextCursor;
    final next = cursor != null && cursor.isNotEmpty
        ? SocialMomentMonthQuery(
            _userId,
            _month,
            limit: 12,
            cursor: Map.unmodifiable(cursor),
          )
        : page.nextOffset > _queries.last.offset
        ? SocialMomentMonthQuery(
            _userId,
            _month,
            limit: 12,
            offset: page.nextOffset,
          )
        : null;
    return next != null && !_queries.contains(next) ? next : null;
  }

  void _resetPages() {
    _revision++;
    _boundaries.clear();
    _reconciling = false;
    _queries
      ..clear()
      ..add(_firstQuery);
  }

  bool _reconcilePages(List<AsyncValue<SocialWorkPage>> pages) {
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
          _queries.removeRange(keep, _queries.length);
          _reconciling = false;
        });
      });
    }
    return _reconciling;
  }

  String _pageBoundary(SocialWorkPage page) => socialPageBoundary(
    nextCursor: page.nextCursor,
    nextOffset: page.nextOffset,
    hasMore: page.hasMore,
    itemKeys: page.items.map((work) => work.id),
  );

  @override
  void didUpdateWidget(covariant SocialMomentMonthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId.trim() != _userId ||
        oldWidget.month.year != _month.year ||
        oldWidget.month.month != _month.month) {
      _resetPages();
    }
  }

  bool _current(int revision, String userId, DateTime month, String? viewer) =>
      mounted &&
      revision == _revision &&
      userId == _userId &&
      month == _month &&
      ref.read(socialCurrentUserIdProvider) == viewer;

  Future<void> _refresh() async {
    if (_userId.isEmpty) return;
    final queries = List<SocialMomentMonthQuery>.of(_queries);
    setState(_resetPages);
    for (final query in queries) {
      ref.invalidate(socialMomentMonthPageProvider(query));
    }
    ref.invalidate(socialProfileProvider(_userId));
    try {
      await ref.read(socialMomentMonthPageProvider(_firstQuery).future);
    } catch (_) {
      // Keep the month and route in place; the first-page panel offers retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(socialCurrentUserIdProvider);
    ref.listen<String?>(socialCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      final queries = List<SocialMomentMonthQuery>.of(_queries);
      setState(_resetPages);
      for (final query in queries) {
        ref.invalidate(socialMomentMonthPageProvider(query));
      }
      ref.invalidate(socialProfileProvider(_userId));
    });
    ref.listen(socialAuthStateProvider, (previous, next) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous?.asData?.value != next.asData?.value) {
        final queries = List<SocialMomentMonthQuery>.of(_queries);
        setState(_resetPages);
        for (final query in queries)
          ref.invalidate(socialMomentMonthPageProvider(query));
      }
    });
    final profile = _userId.isEmpty
        ? null
        : ref.watch(socialProfileProvider(_userId));
    final pages = [
      if (_userId.isNotEmpty)
        for (final query in _queries)
          ref.watch(socialMomentMonthPageProvider(query)),
    ];
    final revision = _revision, userId = _userId;
    final month = _month;
    final first = pages.firstOrNull;
    final reconciling = pages.isNotEmpty && _reconcilePages(pages);
    final records = <({SocialWork work, SocialMomentMonthQuery query})>[];
    final seen = <String>{};
    if (!reconciling &&
        first?.isLoading == false &&
        first?.hasValue == true &&
        !first!.hasError) {
      for (var index = 0; index < pages.length; index++) {
        final page = pages[index];
        // Reloading old offsets must not reintroduce withdrawn snapshots.
        if (page.isLoading || page.hasError) continue;
        for (final work in page.asData?.value.items ?? const <SocialWork>[]) {
          final date = work.recordDate;
          if (work.isPublished &&
              work.isMoment &&
              work.author.userId == userId &&
              date?.year == month.year &&
              date?.month == month.month &&
              seen.add(work.id)) {
            records.add((work: work, query: _queries[index]));
          }
        }
      }
    }
    final last = pages.lastOrNull;
    final next = _nextQuery(last?.asData?.value);
    final more = next != null;
    final author = profile?.isLoading == false ? profile?.asData?.value : null;
    final inset = WebPageLayout.horizontalInset(
      MediaQuery.sizeOf(context).width,
    );
    return SocialWebFrame(
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: SocialPageHeader(title: _title),
        body: SafeArea(
          top: false,
          child: SocialContent(
            maxWidth: 820,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                cacheExtent: 800,
                key: ValueKey((
                  'social-moment-month',
                  userId,
                  month,
                  viewer,
                  revision,
                )),
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(inset, 8, inset, 16),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (author != null && author.userId == userId)
                            TextButton(
                              key: const ValueKey('social-month-author'),
                              onPressed: () {
                                if (_current(revision, userId, month, viewer)) {
                                  openSocialProfile(context, userId);
                                }
                              },
                              style: TextButton.styleFrom(
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 44),
                              ),
                              child: Text('${author.displayName}님의 기록'),
                            ),
                          Text(
                            '공개 기록만 보여요.',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (first == null)
                    const SliverToBoxAdapter(
                      child: SocialEmpty(
                        title: '이 월간 기록을 볼 수 없어요.',
                        message: '프로필에서 다시 선택해 주세요.',
                      ),
                    )
                  else if (first.isLoading || reconciling)
                    const SliverToBoxAdapter(
                      child: SocialLoading(message: '한 달의 공개 기록을 불러오고 있어요.'),
                    )
                  else if (first.hasError || !first.hasValue)
                    SliverToBoxAdapter(
                      child: SocialProfileStatePanel(
                        title: '기록을 불러오지 못했어요.',
                        message: '연결을 확인한 뒤 다시 시도해 주세요.',
                        action: OutlinedButton(
                          key: const ValueKey('social-month-first-retry'),
                          onPressed: () {
                            if (_current(revision, userId, month, viewer)) {
                              ref.invalidate(socialMomentMonthPageProvider);
                            }
                          },
                          child: const Text('기록 다시 불러오기'),
                        ),
                      ),
                    )
                  else ...[
                    if (records.isEmpty && last?.isLoading != true)
                      const SliverToBoxAdapter(
                        child: SocialEmpty(
                          title: '이달에 공개한 기록이 없어요.',
                          message: '공개가 종료된 기록은 표시되지 않아요.',
                        ),
                      ),
                    SliverList.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final entry = records[index],
                            date = records[index].work.recordDate!;
                        final previous = index == 0
                            ? null
                            : records[index - 1].work.recordDate;
                        final showDate =
                            previous == null || previous.day != date.day;
                        return Column(
                          key: ValueKey('social-month-record-${entry.work.id}'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (showDate)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: inset,
                                  vertical: 8,
                                ),
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    '${date.month}월 ${date.day}일',
                                    style: ExperienceFormStyle.text(
                                      context,
                                      16,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            Padding(
                              padding: kIsWeb
                                  ? EdgeInsets.symmetric(horizontal: inset)
                                  : EdgeInsets.zero,
                              child: SocialFeedCard(
                                key: ValueKey((entry.work.id, viewer)),
                                work: entry.work,
                                onRetry: () {
                                  if (_current(
                                    revision,
                                    userId,
                                    month,
                                    viewer,
                                  )) {
                                    ref.invalidate(
                                      socialMomentMonthPageProvider,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    for (var index = 1; index < pages.length - 1; index++)
                      if (pages[index].hasError && !pages[index].isLoading)
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(inset, 12, inset, 12),
                          sliver: SliverToBoxAdapter(
                            child: _middleFailure(
                              index,
                              _queries[index],
                              revision,
                              userId,
                              month,
                              viewer,
                            ),
                          ),
                        ),
                    if (last?.isLoading == true)
                      const SliverToBoxAdapter(
                        child: SocialLoading(message: '다음 기록을 불러오고 있어요.'),
                      )
                    else if (last?.hasError == true || more)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(inset, 12, inset, 32),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (last?.hasError == true) ...[
                                const Text('다음 기록을 불러오지 못했어요.'),
                                const SizedBox(height: 8),
                              ],
                              OutlinedButton(
                                key: const ValueKey('social-month-more'),
                                onPressed: () {
                                  if (!_current(
                                    revision,
                                    userId,
                                    month,
                                    viewer,
                                  ))
                                    return;
                                  if (last?.hasError == true) {
                                    ref.invalidate(
                                      socialMomentMonthPageProvider,
                                    );
                                  } else if (next != null &&
                                      !_queries.contains(next)) {
                                    setState(() => _queries.add(next));
                                  }
                                },
                                child: Text(
                                  last?.hasError == true ? '다시 시도' : '기록 더 보기',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _middleFailure(
    int index,
    SocialMomentMonthQuery query,
    int revision,
    String userId,
    DateTime month,
    String? viewer,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(liveRegion: true, child: Text('일부 기록을 불러오지 못했어요.')),
      const SizedBox(height: 8),
      OutlinedButton(
        key: ValueKey('social-month-middle-retry-$index'),
        onPressed: () {
          if (_current(revision, userId, month, viewer) &&
              _queries.contains(query))
            ref.invalidate(socialMomentMonthPageProvider(query));
        },
        child: const Text('다시 시도'),
      ),
    ],
  );
}
