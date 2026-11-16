import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../data/social_repository.dart' show socialActionMessage;
import '../../domain/social_models.dart';
import '../providers/social_providers.dart';
import '../social_page_boundaries.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Only already public snapshots can be chosen. A null ID restores automatic
/// selection; the caller remains responsible for the authoritative write.
Future<void> showSocialMomentMonthCoverPicker(
  BuildContext context, {
  required String userId,
  required DateTime month,
  required String? selectedWorkId,
  required Future<void> Function(String? workId) onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 680),
  builder: (_) => SocialMomentMonthCoverPicker(
    userId: userId,
    month: month,
    selectedWorkId: selectedWorkId,
    onSelect: onSelect,
  ),
);

class SocialMomentMonthCoverPicker extends ConsumerStatefulWidget {
  const SocialMomentMonthCoverPicker({
    super.key,
    required this.userId,
    required this.month,
    required this.selectedWorkId,
    required this.onSelect,
  });

  final String userId;
  final DateTime month;
  final String? selectedWorkId;
  final Future<void> Function(String? workId) onSelect;

  @override
  ConsumerState<SocialMomentMonthCoverPicker> createState() =>
      _SocialMomentMonthCoverPickerState();
}

class _SocialMomentMonthCoverPickerState
    extends ConsumerState<SocialMomentMonthCoverPicker> {
  final _queries = <SocialMomentMonthQuery>[];
  String? _selection, _error, _owner;
  final _boundaries = SocialPageBoundaries<SocialMomentMonthQuery>();
  int _revision = 0;
  int _identityRevision = 0;
  Object? _saveOperation;
  bool _busy = false, _sessionChanged = false, _reconciling = false;

  DateTime get _month => DateTime.utc(widget.month.year, widget.month.month);
  SocialMomentMonthQuery get _firstQuery =>
      SocialMomentMonthQuery(widget.userId, _month, limit: 12);

  @override
  void initState() {
    super.initState();
    _owner = ref.read(socialCurrentUserIdProvider);
    _selection = widget.selectedWorkId;
    _queries.add(_firstQuery);
  }

  SocialMomentMonthQuery? _nextQuery(SocialWorkPage? page) {
    if (page?.hasMore != true) return null;
    final cursor = page!.nextCursor;
    final next = cursor != null && cursor.isNotEmpty
        ? SocialMomentMonthQuery(
            widget.userId,
            _month,
            limit: 12,
            cursor: Map.unmodifiable(cursor),
          )
        : page.nextOffset > _queries.last.offset
        ? SocialMomentMonthQuery(
            widget.userId,
            _month,
            limit: 12,
            offset: page.nextOffset,
          )
        : null;
    return next != null && !_queries.contains(next) ? next : null;
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
        if (!_current || revision != _revision) return;
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
  void didUpdateWidget(covariant SocialMomentMonthCoverPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.month.year != _month.year ||
        oldWidget.month.month != _month.month) {
      _revision++;
      _identityRevision++;
      _saveOperation = null;
      _busy = false;
      _boundaries.clear();
      _reconciling = false;
      _selection = widget.selectedWorkId;
      _error = null;
      _queries
        ..clear()
        ..add(_firstQuery);
    }
  }

  bool get _current =>
      mounted &&
      !_sessionChanged &&
      _owner != null &&
      _owner == widget.userId &&
      ref.read(socialCurrentUserIdProvider) == _owner;

  void _close() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      route.navigator?.pop();
    } else {
      route.navigator?.removeRoute(route);
    }
  }

  Future<void> _apply() async {
    if (!_current || _busy || _selection == widget.selectedWorkId) return;
    final revision = _identityRevision;
    final userId = widget.userId, month = _month;
    final operation = Object();
    _saveOperation = operation;
    bool current() =>
        _current &&
        revision == _identityRevision &&
        userId == widget.userId &&
        month == _month &&
        identical(_saveOperation, operation);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSelect(_selection);
      if (current()) _close();
    } catch (error) {
      if (current()) {
        setState(
          () => _error = socialActionMessage(
            error,
            fallback: '표지를 저장하지 못했어요. 선택한 사진으로 다시 시도해 주세요.',
          ),
        );
      }
    } finally {
      if (current()) {
        setState(() {
          _busy = false;
          _saveOperation = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(socialCurrentUserIdProvider, (previous, next) {
      if (previous == next) return;
      _sessionChanged = true;
      _identityRevision++;
      _saveOperation = null;
      _busy = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    });
    ref.watch(socialCurrentUserIdProvider);
    if (!_current) return const SizedBox.shrink();
    final month = _month;
    final revision = _revision;
    final userId = widget.userId;
    final pages = [
      for (final query in _queries)
        ref.watch(socialMomentMonthPageProvider(query)),
    ];
    final first = pages.first, last = pages.last;
    final reconciling = _reconcilePages(pages);
    final seen = <String>{};
    final records = <SocialWork>[
      if (!reconciling && !first.isLoading && !first.hasError)
        for (final page in pages)
          if (!page.isLoading && !page.hasError)
            for (final work in page.asData?.value.items ?? const <SocialWork>[])
              if (work.isPublished &&
                  work.isMoment &&
                  work.author.userId == widget.userId &&
                  work.recordDate?.year == month.year &&
                  work.recordDate?.month == month.month &&
                  seen.add(work.id))
                work,
    ];
    final next = _nextQuery(last.asData?.value);
    final more = !reconciling && next != null;
    final selectedAvailable =
        _selection == null || records.any((work) => work.id == _selection);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .84,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${month.month}월의 대표 사진',
                    style: ExperienceFormStyle.text(
                      context,
                      22,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('month-cover-close'),
                  tooltip: '닫기',
                  onPressed: _close,
                  icon: const ExperienceIcon('X'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '공개한 사진 중 한 장을 표지로 골라요.',
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  Semantics(
                    selected: _selection == null,
                    child: ListTile(
                      key: const ValueKey('month-cover-automatic'),
                      contentPadding: EdgeInsets.zero,
                      leading: const ExperienceIcon('Sparkles'),
                      title: const Text('최신 기록으로 자동 선택'),
                      trailing: Icon(
                        _selection == null
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _selection == null
                            ? SocialStyle.accent(context)
                            : null,
                      ),
                      onTap: _busy
                          ? null
                          : () => setState(() {
                              _selection = null;
                              _error = null;
                            }),
                    ),
                  ),
                  if (first.isLoading || reconciling)
                    const SocialLoading(message: '공개한 사진을 불러오고 있어요.')
                  else if (first.hasError)
                    SocialFailure(
                      onRetry: () =>
                          ref.invalidate(socialMomentMonthPageProvider),
                    )
                  else if (records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('이달에 공개한 사진이 없어요.'),
                    ),
                  LayoutBuilder(
                    builder: (context, bounds) {
                      final columns =
                          MediaQuery.textScalerOf(context).scale(1) > 1.5
                          ? 1
                          : 2;
                      final width =
                          (bounds.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final work in records)
                            SizedBox(width: width, child: _photo(work)),
                        ],
                      );
                    },
                  ),
                  if (!first.isLoading && !first.hasError && !reconciling)
                    for (var index = 1; index < pages.length - 1; index++)
                      if (pages[index].hasError && !pages[index].isLoading)
                        _middleFailure(
                          index,
                          _queries[index],
                          revision,
                          userId,
                          month,
                        ),
                  if (last.isLoading && _queries.length > 1)
                    const SocialLoading(message: '다음 사진을 불러오고 있어요.')
                  else if (last.hasError && _queries.length > 1 || more)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: OutlinedButton(
                        key: const ValueKey('month-cover-more'),
                        onPressed: _busy
                            ? null
                            : () {
                                if (!_current ||
                                    revision != _revision ||
                                    userId != widget.userId ||
                                    month != _month) {
                                  return;
                                }
                                if (last.hasError) {
                                  ref.invalidate(
                                    socialMomentMonthPageProvider(
                                      _queries.last,
                                    ),
                                  );
                                } else if (more) {
                                  setState(() => _queries.add(next!));
                                }
                              },
                        child: Text(last.hasError ? '다시 시도' : '공개 사진 더 보기'),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: ExperienceFormStyle.text(context, 13)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('month-cover-apply'),
              style: SocialStyle.primary(context),
              onPressed:
                  !_busy &&
                      !first.isLoading &&
                      !first.hasError &&
                      selectedAvailable &&
                      _selection != widget.selectedWorkId
                  ? _apply
                  : null,
              child: Text(_busy ? '표지를 저장하고 있어요…' : '표지로 사용'),
            ),
          ],
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
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text('일부 공개 사진을 불러오지 못했어요.')),
        const SizedBox(height: 8),
        OutlinedButton(
          key: ValueKey('month-cover-middle-retry-$index'),
          onPressed: _busy
              ? null
              : () {
                  if (_current &&
                      revision == _revision &&
                      userId == widget.userId &&
                      month == _month &&
                      _queries.contains(query))
                    ref.invalidate(socialMomentMonthPageProvider(query));
                },
          child: const Text('다시 시도'),
        ),
      ],
    ),
  );

  Widget _photo(SocialWork work) {
    final selected = _selection == work.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${socialDate(work.recordDate!)} ${work.title}, 표지로 선택',
      child: InkWell(
        key: ValueKey('month-cover-photo-${work.id}'),
        onTap: _busy
            ? null
            : () => setState(() {
                _selection = work.id;
                _error = null;
              }),
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? SocialStyle.accent(context)
                  : SocialStyle.line(context),
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: work.imageUrls.isEmpty
                        ? const SocialArtworkPlaceholder()
                        : SocialWorkImage(
                            url: work.imageUrls.first,
                            label: work.title,
                            fit: BoxFit.contain,
                            onRetry: () =>
                                ref.invalidate(socialMomentMonthPageProvider),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${work.recordDate!.month}월 ${work.recordDate!.day}일',
                        style: ExperienceFormStyle.text(context, 13),
                      ),
                    ),
                    if (selected)
                      ExperienceIcon(
                        'CheckCircle2',
                        size: 20,
                        color: SocialStyle.accent(context),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
