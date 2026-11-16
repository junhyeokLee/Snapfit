import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../moments/data/moments_repository.dart';
import '../../../moments/domain/moment_record.dart';
import '../../../moments/domain/private_moment_archive.dart';
import '../../../moments/presentation/moments_navigation.dart';
import '../../../moments/presentation/providers/moments_providers.dart';
import '../../../moments/presentation/widgets/moments_widgets.dart';
import '../../../moments/presentation/providers/private_moment_archive_providers.dart'
    show
        privateMomentArchiveRepositoryProvider,
        privateMomentArchiveSessionProvider,
        privateMomentMonthsProvider;
import '../../../profile/domain/order_visibility_owner.dart';
import '../providers/social_providers.dart';
import '../../../../shared/widgets/experience_icon.dart';

@visibleForTesting
final myMomentArchivePhotoResolverProvider =
    Provider<Future<String> Function(String)?>((ref) => null);

/// A private, owner-scoped archive. Public profiles never mount this widget.
/// Only month summaries and one original photo per month are requested here;
/// opening a month continues through the existing complete journal screen.
class MyMomentArchive extends ConsumerStatefulWidget {
  const MyMomentArchive({
    super.key,
    required this.ownerId,
    this.today,
    this.onOpenMonth,
    this.onCreateRecord,
    this.resolvePhotoForTesting,
  });

  final String ownerId;
  final DateTime? today;
  final Future<void> Function(DateTime month)? onOpenMonth;
  final VoidCallback? onCreateRecord;
  @visibleForTesting
  final Future<String> Function(String)? resolvePhotoForTesting;

  @override
  ConsumerState<MyMomentArchive> createState() => _MyMomentArchiveState();
}

class _MyMomentArchiveState extends ConsumerState<MyMomentArchive>
    with WidgetsBindingObserver {
  final _queries = <PrivateMomentMonthsQuery>[];
  StreamSubscription<String?>? _auth;
  MomentsRepository? _repository;
  bool _sessionInvalidated = false;
  bool _active = false;
  bool _trimScheduled = false;
  bool _reloadScheduled = false;
  int _revision = 0;
  DateTime? _openingMonth;

  String get _owner => widget.ownerId.trim();
  DateTime get _month => momentMonth(widget.today ?? momentToday());
  PrivateMomentMonthsQuery get _first => PrivateMomentMonthsQuery(_owner);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _queries.add(_first);
    _bindRepository();
  }

  void _bindRepository() {
    try {
      final repository = ref.read(momentsRepositoryProvider);
      if (identical(repository, _repository)) return;
      unawaited(_auth?.cancel());
      _repository = repository;
      _auth = repository.authChanges.listen((next) {
        if (next != _owner) _invalidateSession();
      }, onError: (Object _, StackTrace __) => _invalidateSession());
    } catch (_) {
      // A missing SDK session can never become permission to display a cache.
      _repository = null;
    }
  }

  bool get _ownerMatches {
    try {
      return _owner.isNotEmpty &&
          ref.read(socialCurrentUserIdProvider) == _owner &&
          ref.read(authViewModelProvider).asData?.value?.id == _owner &&
          ref.read(visibleOrderOwnerProvider) == _owner &&
          ref.read(momentsRepositoryProvider).currentUserId == _owner &&
          ref.read(privateMomentArchiveRepositoryProvider).currentUserId ==
              _owner;
    } catch (_) {
      return false;
    }
  }

  bool _current(int revision) =>
      mounted && revision == _revision && !_sessionInvalidated && _ownerMatches;

  void _invalidateSession() {
    if (!mounted || _sessionInvalidated) return;
    setState(() {
      _sessionInvalidated = true;
      _revision++;
      _openingMonth = null;
      _trimScheduled = false;
    });
    for (final query in _queries)
      ref.invalidate(privateMomentMonthsProvider(query));
  }

  void _reload() {
    if (!mounted || !_ownerMatches) return;
    final resetPages = _sessionInvalidated;
    for (final query in _queries)
      ref.invalidate(privateMomentMonthsProvider(query));
    setState(() {
      _revision++;
      _sessionInvalidated = false;
      if (resetPages) {
        _queries
          ..clear()
          ..add(_first);
      }
      _trimScheduled = false;
      _openingMonth = null;
    });
    _bindRepository();
  }

  void _scheduleReload() {
    if (_reloadScheduled) return;
    _reloadScheduled = true;
    final revision = _revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadScheduled = false;
      if (_current(revision) && _active) _reload();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (active && !_active && _activeWasSeen) {
      _scheduleReload();
    }
    _active = active;
    _activeWasSeen = true;
  }

  bool _activeWasSeen = false;

  @override
  void didUpdateWidget(covariant MyMomentArchive oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      final previous = List<PrivateMomentMonthsQuery>.of(_queries);
      _revision++;
      _sessionInvalidated = false;
      _openingMonth = null;
      _trimScheduled = false;
      _queries
        ..clear()
        ..add(_first);
      for (final query in previous)
        ref.invalidate(privateMomentMonthsProvider(query));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _active &&
        !_sessionInvalidated &&
        ModalRoute.of(context)?.isCurrent != false)
      _scheduleReload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    super.dispose();
  }

  Future<void> _open(DateTime month) async {
    if (!_current(_revision) || _openingMonth != null) return;
    final revision = _revision;
    setState(() => _openingMonth = month);
    try {
      if (widget.onOpenMonth case final open?) {
        await open(month);
      } else {
        await openMoments(context, initialMonth: month);
      }
      if (_current(revision)) _scheduleReload();
    } catch (_) {
      if (_current(revision)) {
        context.showSnack('기록을 열지 못했어요. 다시 눌러 주세요.');
      }
    } finally {
      if (_current(revision)) setState(() => _openingMonth = null);
    }
  }

  void _create() {
    if (!_current(_revision)) return;
    if (widget.onCreateRecord case final create?) {
      create();
    } else {
      unawaited(openMomentCompose(context, ref));
    }
  }

  DateTime? _oldest(List<MomentMonthSummary> months) => months.isEmpty
      ? null
      : months
            .map((month) => momentMonth(month.month))
            .reduce((a, b) => a.isBefore(b) ? a : b);

  @override
  Widget build(BuildContext context) {
    ref.watch(socialCurrentUserIdProvider);
    ref.watch(authViewModelProvider.select((value) => value.asData?.value?.id));
    ref.watch(visibleOrderOwnerProvider);
    // Subscribe to session changes, while the explicit SDK owner remains the
    // final local check. Auth events also have the direct A → B → A fence above.
    ref.watch(momentsSessionProvider);
    ref.listen<AsyncValue<int>>(privateMomentArchiveSessionProvider, (
      previous,
      next,
    ) {
      if (previous?.hasValue == true &&
          next.hasValue &&
          previous!.value != next.value) {
        _invalidateSession();
      }
    });
    ref.watch(privateMomentArchiveSessionProvider);
    if (!_ownerMatches) return const SizedBox.shrink();
    if (_sessionInvalidated) {
      return _status('기록을 다시 확인해 주세요.', action: _reload);
    }
    final pages = [
      for (final query in _queries)
        ref.watch(privateMomentMonthsProvider(query)),
    ];
    final first = pages.first;
    if (first.isLoading) return _status('나의 한 달을 불러오고 있어요.', loading: true);
    if (first.hasError || !first.hasValue) {
      return _status('기록을 불러오지 못했어요.', action: _reload);
    }
    var visiblePages = pages.length;
    for (var index = 0; index + 1 < pages.length; index++) {
      final result = pages[index];
      if (result.isLoading || result.hasError || !result.hasValue) {
        visiblePages = index + 1;
        break;
      }
      final oldest = _oldest(result.value!);
      if (oldest != _queries[index + 1].beforeMonth) {
        visiblePages = index + 1;
        if (!_trimScheduled) {
          _trimScheduled = true;
          final revision = _revision;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_current(revision)) return;
            setState(() {
              _queries.removeRange(visiblePages, _queries.length);
              _trimScheduled = false;
            });
          });
        }
        break;
      }
    }
    final byMonth = <DateTime, MomentMonthSummary>{};
    for (final page in pages.take(visiblePages)) {
      if (page.isLoading || page.hasError || !page.hasValue) continue;
      for (final month in page.value!) {
        final key = momentMonth(month.month);
        if (!key.isAfter(_month)) byMonth.putIfAbsent(key, () => month);
      }
    }
    final current = byMonth.remove(_month);
    final past = byMonth.values.toList()
      ..sort((a, b) => b.month.compareTo(a.month));
    final featured = current ?? past.firstOrNull;
    final earlier = current == null ? past.skip(1).toList() : past;
    final last = pages[visiblePages - 1];
    final lastQuery = _queries[visiblePages - 1];
    final oldest = last.isLoading || last.hasError || !last.hasValue
        ? null
        : _oldest(last.value!);
    final more =
        last.hasValue &&
        !last.isLoading &&
        !last.hasError &&
        last.value!.length == lastQuery.limit &&
        oldest != null &&
        (lastQuery.beforeMonth == null ||
            oldest.isBefore(lastQuery.beforeMonth!));
    return Column(
      key: ValueKey('my-moment-archive-$_owner'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '나의 한 달',
                style: ExperienceFormStyle.text(
                  context,
                  21,
                  weight: FontWeight.w600,
                ).copyWith(letterSpacing: -.6),
              ),
            ),
            TextButton(
              key: const ValueKey('my-moments-all'),
              onPressed: () => _open(featured?.month ?? _month),
              child: const Text('전체 기록'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (featured == null)
          _emptyCurrent()
        else
          _monthCard(featured, hero: true),
        if (current == null && featured != null) ...[
          const SizedBox(height: 16),
          _currentMonthPrompt(),
        ],
        if (earlier.isNotEmpty) ...[
          const SizedBox(height: 30),
          Text(
            '지난 한 달',
            style: ExperienceFormStyle.text(
              context,
              15,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns =
                  bounds.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? 1
                  : 2;
              const gap = 18.0;
              final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: 24,
                children: [
                  for (final month in earlier)
                    SizedBox(width: width, child: _monthCard(month)),
                ],
              );
            },
          ),
        ],
        if (last.hasError && visiblePages > 1)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _status(
              '이전 기록을 불러오지 못했어요.',
              action: () =>
                  ref.invalidate(privateMomentMonthsProvider(lastQuery)),
            ),
          )
        else if (last.isLoading && visiblePages > 1)
          const Padding(
            padding: EdgeInsets.all(20),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (more)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OutlinedButton(
              key: const ValueKey('my-moment-months-more'),
              onPressed: () {
                if (!_current(_revision)) return;
                final next = PrivateMomentMonthsQuery(
                  _owner,
                  beforeMonth: oldest,
                );
                if (!_queries.contains(next))
                  setState(() => _queries.add(next));
              },
              child: const Text('이전 기록 더 보기'),
            ),
          ),
      ],
    );
  }

  Widget _status(String title, {VoidCallback? action, bool loading = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 14),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (action != null)
              TextButton(onPressed: action, child: const Text('다시 확인')),
          ],
        ),
      );

  Widget _currentMonthPrompt() => Padding(
    key: const ValueKey('my-current-month-prompt'),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_month.month}월의 첫 장면도 남겨볼까요?',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.5),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          key: const ValueKey('my-current-month-first-record'),
          onPressed: _create,
          icon: const ExperienceIcon('ImagePlus', size: 18),
          label: const Text('남기기'),
        ),
      ],
    ),
  );

  Widget _emptyCurrent() => Material(
    key: const ValueKey('my-current-month-empty'),
    color: ExperienceFormStyle.selection(context),
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_month.month}월의 첫 장면',
            style: ExperienceFormStyle.text(
              context,
              23,
              weight: FontWeight.w600,
            ).copyWith(letterSpacing: -.7),
          ),
          const SizedBox(height: 10),
          Text(
            '사진 한 장과 한 줄로 남기는 나의 한 달.',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.6),
          ),
          const SizedBox(height: 30),
          FilledButton.icon(
            key: const ValueKey('my-first-moment'),
            onPressed: _create,
            style: FilledButton.styleFrom(
              backgroundColor: SnapFitColors.actionAccent,
              foregroundColor: SnapFitColors.onAccent,
            ),
            icon: const ExperienceIcon('ImagePlus', size: 19),
            label: const Text('한 장 남기기'),
          ),
        ],
      ),
    ),
  );

  Widget _monthCard(MomentMonthSummary summary, {bool hero = false}) {
    final month = momentMonth(summary.month);
    final rawPhoto = summary.coverPhoto;
    final photo =
        rawPhoto != null &&
            rawPhoto.path.startsWith('$_owner/moments/') &&
            !rawPhoto.path
                .split('/')
                .any((part) => part.isEmpty || part == '.' || part == '..')
        ? rawPhoto
        : null;
    return Semantics(
      button: true,
      label:
          '${month.year}년 ${month.month}월, 기록 ${summary.recordCount}개, 사진 ${summary.photoCount}장 열기',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('my-moment-month-${momentDateKey(month)}'),
          onTap: _openingMonth == null ? () => _open(month) : null,
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, bounds) {
                  final sourceRatio = photo == null
                      ? 1.0
                      : momentPhotoAspect(photo);
                  final ratio = hero
                      ? math.max(sourceRatio, bounds.maxWidth / 540)
                      : 1.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(hero ? 20 : 16),
                    child: AspectRatio(
                      key: ValueKey(
                        hero
                            ? month == _month
                                  ? 'my-current-month-photo'
                                  : 'my-featured-month-photo-${momentDateKey(month)}'
                            : 'my-past-month-photo-${momentDateKey(month)}',
                      ),
                      aspectRatio: ratio,
                      child: ColoredBox(
                        color: ExperienceFormStyle.selection(context),
                        child: photo == null
                            ? Center(
                                child: ExperienceIcon('Image', size: hero ? 40 : 28, color: ExperienceFormStyle.muted(context),
                                ),
                              )
                            : Semantics(
                                image: true,
                                label:
                                    '${month.year}년 ${month.month}월 내 기록 대표 사진',
                                child: MomentPhotoView(
                                  key: ValueKey((
                                    _owner,
                                    _revision,
                                    photo.storageUri,
                                  )),
                                  // Month summaries can carry an expired signed
                                  // URL. The private archive resolves its stable,
                                  // owner-scoped storage source instead.
                                  photo: photo.withUrl(''),
                                  automaticStorageRefresh: true,
                                  aspectRatio: momentPhotoAspect(photo),
                                  imageDecodeWidth:
                                      (bounds.maxWidth *
                                              MediaQuery.devicePixelRatioOf(
                                                context,
                                              ))
                                          .ceil()
                                          .clamp(
                                            hero ? 640 : 384,
                                            hero ? 2048 : 1200,
                                          )
                                          .toInt(),
                                  resolveStorageUrlForTesting:
                                      widget.resolvePhotoForTesting ??
                                      ref.read(
                                        myMomentArchivePhotoResolverProvider,
                                      ),
                                  placeholder: const SizedBox.expand(),
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: hero ? 14 : 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${month.year}년 ${month.month}월',
                          style: ExperienceFormStyle.text(
                            context,
                            hero ? 23 : 17,
                            weight: FontWeight.w600,
                          ).copyWith(letterSpacing: -.5),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '기록 ${summary.recordCount}개 · 사진 ${summary.photoCount}장',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ).copyWith(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExperienceIcon('ArrowRight', size: hero ? 23 : 20, color: ExperienceFormStyle.selectionInk(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
