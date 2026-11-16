import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/web/web_design.dart'
    show WebPageHeading, WebPageLayout;
import '../../../../shared/widgets/experience_style.dart';
import '../../../album/domain/entities/album.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../../data/moment_engagement_repository.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';
import '../widgets/moment_share_sheet.dart';
import '../widgets/web_moments_journal_layout.dart';
import '../widgets/moment_month_calendar.dart';
import '../widgets/moment_monthly_album_entry.dart';
import '../widgets/moment_monthly_reward_summary.dart';
import 'moment_compose_screen.dart';
import 'monthly_moment_preview_screen.dart';
import 'weekly_moment_recap_screen.dart';
import 'moment_saved_preview_screen.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({
    super.key,
    this.onBack,
    this.onAlbumCreated,
    this.onReminderSettings,
    this.initialDraftRecordId,
    this.initialMonth,
    this.initialDate,
  });
  final VoidCallback? onBack;
  final VoidCallback? onReminderSettings;
  final Future<void> Function(Album)? onAlbumCreated;
  final String? initialDraftRecordId;
  final DateTime? initialMonth, initialDate;

  @override
  ConsumerState<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends ConsumerState<MomentsScreen>
    with WidgetsBindingObserver {
  late DateTime _month;
  DateTime? _selectedDate;
  final ScrollController _scroll = ScrollController();
  final _recordAnchors = <String, GlobalKey>{};
  StreamSubscription<String?>? _authChanges;
  String? _observedOwner;
  bool _sessionSafe = true;
  bool _initialDatePending = false;
  int _jumpGeneration = 0;
  Timer? _midnight;
  DateTime? _scheduledToday;
  String? _error;
  int _identity = 0;
  bool _openedInitialDraft = false;
  bool _openingCompose = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _month = momentMonth(
      widget.initialMonth ?? widget.initialDate ?? momentToday(),
    );
    _selectedDate = widget.initialDate == null
        ? null
        : momentDate(widget.initialDate!);
    _initialDatePending = _selectedDate != null;
    final repository = ref.read(momentsRepositoryProvider);
    _observedOwner = repository.currentUserId;
    _authChanges = repository.authChanges.listen(
      _observeOwner,
      onError: (Object _, StackTrace __) {
        if (!mounted) return;
        setState(() {
          _sessionSafe = false;
          _identity++;
          _jumpGeneration++;
          _recordAnchors.clear();
        });
      },
    );
  }

  @override
  void dispose() {
    _identity++;
    _midnight?.cancel();
    _jumpGeneration++;
    unawaited(_authChanges?.cancel());
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _observeOwner(String? next) {
    if (!mounted || (_sessionSafe && next == _observedOwner)) return;
    _observedOwner = next;
    setState(() {
      _identity++;
      _jumpGeneration++;
      _sessionSafe = true;
      _month = momentMonth(momentToday());
      _selectedDate = null;
      _initialDatePending = false;
      _recordAnchors.clear();
      _midnight?.cancel();
      _scheduledToday = null;
      _error = null;
    });
    ref.invalidate(momentsMonthProvider);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void didUpdateWidget(covariant MomentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMonth != widget.initialMonth ||
        oldWidget.initialDate != widget.initialDate) {
      _month = momentMonth(
        widget.initialMonth ?? widget.initialDate ?? momentToday(),
      );
      _selectedDate = widget.initialDate == null
          ? null
          : momentDate(widget.initialDate!);
      _initialDatePending = _selectedDate != null;
      _recordAnchors.clear();
      _jumpGeneration++;
      if (_scroll.hasClients) _scroll.jumpTo(0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  void _scheduleDateRefresh(DateTime today) {
    if (_scheduledToday == today) return;
    _scheduledToday = today;
    _midnight?.cancel();
    final nextMidnight = DateTime.utc(
      today.year,
      today.month,
      today.day + 1,
    ).subtract(const Duration(hours: 9));
    final remaining = nextMidnight.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) return;
    _midnight = Timer(remaining, () {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    if (ref.read(momentsCurrentUserIdProvider) == null) return;
    final identity = _identity;
    try {
      final refreshed = await ref.refresh(momentsMonthProvider(_month).future);
      if (mounted && identity == _identity) {
        _scheduleDateRefresh(refreshed.today);
        setState(() => _error = null);
      }
    } catch (_) {
      if (mounted && identity == _identity) {
        setState(() => _error = '기록을 새로 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.');
      }
    }
  }

  Future<void> _compose(
    MomentJournal? journal, {
    MomentRecord? record,
    String? draftRecordId,
  }) async {
    if (_openingCompose || ref.read(momentsCurrentUserIdProvider) == null)
      return;
    _openingCompose = true;
    final identity = _identity;
    final owner = ref.read(momentsCurrentUserIdProvider)!;
    var isEditing = record != null;
    Object? result;
    try {
      if (draftRecordId != null) {
        // 명시적으로 받은 초안 ID는 메타데이터로 확인하고 원본은 작성 화면에서 읽는다.
        isEditing = true;
        try {
          final summaries = await ref
              .read(momentDraftStoreProvider)
              .summaries(owner);
          for (final draft in summaries) {
            if (draft.recordId == draftRecordId) isEditing = draft.isEditing;
          }
        } catch (_) {
          // The compose screen provides retry/recovery for a storage failure.
        }
        if (!mounted ||
            identity != _identity ||
            ref.read(momentsCurrentUserIdProvider) != owner)
          return;
      }
      result = await Navigator.of(context).push<Object?>(
        snapFitRoute(
          page: MomentComposeScreen(
            record: record,
            today: journal?.today,
            draftRecordId: draftRecordId,
          ),
        ),
      );
    } finally {
      _openingCompose = false;
    }
    if (!mounted || identity != _identity) return;
    ref.invalidate(momentDraftsProvider);
    ref.invalidate(momentDraftsForOwnerProvider(owner));
    ref.invalidate(momentDraftSummariesForOwnerProvider(owner));
    if (result is! MomentRecord || isEditing) {
      unawaited(_refresh());
      return;
    }
    final saved = result;
    // The completed save is enough to render the book immediately. A fresh
    // monthly journal is requested only when the owner chooses to open it.
    setState(() => _month = momentMonth(saved.recordDate));
    await showMomentSavedPreview(
      context,
      record: saved,
      hasCompleteJournal: journal != null,
      journal:
          journal ??
          MomentJournal(
            today: momentToday(),
            weekStart: momentWeekStart(momentToday()),
            month: momentMonth(saved.recordDate),
            records: [saved],
            weekPhotoCount: saved.photos.length,
          ),
      onAlbumCreated: widget.onAlbumCreated,
    );
    if (mounted && identity == _identity) unawaited(_refresh());
  }

  Future<void> _album(MomentJournal journal) async {
    if (ref.read(momentsCurrentUserIdProvider) == null) return;
    final identity = _identity;
    await Navigator.of(context).push<void>(
      snapFitRoute(
        page: MonthlyMomentPreviewScreen(
          month: journal.month,
          records: journal.records,
          today: journal.today,
          existingAlbumId: journal.monthlyAlbumId,
          importedPhotoIds: journal.monthlyAlbumPhotoIds,
          onAlbumCreated: widget.onAlbumCreated,
        ),
      ),
    );
    if (mounted && identity == _identity) unawaited(_refresh());
  }

  Future<void> _recap(MomentJournal journal) async {
    final owner = ref.read(momentsCurrentUserIdProvider);
    if (owner == null) return;
    unawaited(
      ref
          .read(momentEngagementRepositoryProvider)
          .recordActivity(
            MomentActivity.recapViewed,
            month: momentMonth(journal.today),
          )
          .then<void>((_) {}),
    );
    await Navigator.of(context).push<void>(
      snapFitRoute(
        page: WeeklyMomentRecapScreen(
          today: journal.today,
          weekStart: journal.weekStart,
          records: journal.currentWeekRecords,
          ownerUserId: owner,
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime.utc(_month.year, _month.month + delta);
      _error = null;
      _selectedDate = null;
      _recordAnchors.clear();
      _jumpGeneration++;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final observedOwner = ref.watch(momentsCurrentUserIdProvider);
    final owner = _sessionSafe ? observedOwner : null;
    if (!_openedInitialDraft &&
        owner != null &&
        widget.initialDraftRecordId != null) {
      _openedInitialDraft = true;
      final identity = _identity;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identity == _identity) {
          _compose(null, draftRecordId: widget.initialDraftRecordId);
        }
      });
    }
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) _observeOwner(next);
    });
    final result = owner == null
        ? null
        : ref.watch(momentsMonthProvider(_month));
    final journal = result?.isReloading == true ? null : result?.value;
    if (journal != null) {
      _scheduleDateRefresh(journal.today);
      if (_initialDatePending && _selectedDate != null) {
        _initialDatePending = false;
        final date = _selectedDate!;
        final identity = _identity;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && identity == _identity)
            unawaited(_jumpToDate(journal, date));
        });
      }
    }
    final headerActions = <Widget>[
      if (owner != null && widget.onReminderSettings != null)
        if (kIsWeb)
          TextButton.icon(
            key: const ValueKey('moments-reminder-settings'),
            onPressed: widget.onReminderSettings,
            icon: const ExperienceIcon('Bell', size: 18),
            label: const Text('기록 알림'),
          )
        else
          IconButton(
            key: const ValueKey('moments-reminder-settings'),
            tooltip: '기록 알림 설정',
            onPressed: widget.onReminderSettings,
            icon: const ExperienceIcon('Bell', size: 22),
          ),
      if (owner != null)
        IconButton(
          key: const ValueKey('moments-refresh'),
          tooltip: '나의 기록 새로고침',
          onPressed: result?.isLoading == true ? null : () => _refresh(),
          icon: const ExperienceIcon('RefreshCw'),
        ),
    ];
    return SocialWebFrame(
      section: WebSection.moments,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: kIsWeb
            ? null
            : ExperienceHeader(
                title: '나의 기록',
                showNotifications: false,
                onBack: widget.onBack,
                actions: headerActions,
              ),
        body: owner == null
            ? const SocialEmpty(
                title: '나만의 순간을 모아보세요',
                message: '로그인한 뒤 사진 한 장부터 시작할 수 있어요.',
                icon: ExperienceIcon('Lock', size: 28),
              )
            : SafeArea(
                top: false,
                child: SocialContent(
                  maxWidth: kIsWeb ? WebPageLayout.maxWidth : 720,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: kIsWeb
                        ? _webJournal(result, journal, headerActions)
                        : ListView(
                            controller: _scroll,
                            cacheExtent: 800,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [
                              if (journal != null &&
                                  journal.records.isNotEmpty) ...[
                                _weekCard(journal),
                                const SizedBox(height: 12),
                              ],
                              _monthNavigation(journal),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                MomentErrorNotice(
                                  message: _error!,
                                  onRetry: _refresh,
                                ),
                              ],
                              if (result?.hasError == true &&
                                  journal == null) ...[
                                const SizedBox(height: 24),
                                MomentErrorNotice(
                                  message:
                                      '이달의 기록을 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.',
                                  onRetry: _refresh,
                                ),
                              ] else if (journal == null) ...[
                                const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 10),
                                if (journal.records.isEmpty)
                                  MomentEmptyBook(
                                    month: journal.month,
                                    today: journal.today,
                                    onRecord: () => _compose(journal),
                                  )
                                else
                                  for (final record in journal.records)
                                    _recordCard(journal, record),
                                const SizedBox(height: 20),
                                const MomentPrivateNote(),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _recordCard(
    MomentJournal journal,
    MomentRecord record, {
    bool wide = false,
  }) {
    final owner = ref.read(momentsCurrentUserIdProvider);
    final identity = _identity;
    return KeyedSubtree(
      key: _recordAnchors.putIfAbsent(record.id, () => GlobalKey()),
      child: MomentRecordCard(
        key: ValueKey('moment-record-${record.id}'),
        record: record,
        initiallyExpanded:
            _selectedDate != null &&
            momentDate(record.recordDate) == _selectedDate,
        expandRequest: momentDate(record.recordDate) == _selectedDate
            ? _jumpGeneration
            : null,
        maxPhotoHeight: wide ? 560 : null,
        onEdit: () => _compose(journal, record: record),
        onShare: (photo) {
          if (!mounted ||
              !_sessionSafe ||
              owner == null ||
              identity != _identity ||
              ref.read(momentsCurrentUserIdProvider) != owner)
            return;
          unawaited(
            showMomentShareSheet(
              context,
              record: record,
              initialPhotoId: photo.id,
            ),
          );
        },
      ),
    );
  }

  Future<void> _jumpToDate(MomentJournal journal, DateTime date) async {
    final target = journal.records.indexWhere(
      (record) => momentDate(record.recordDate) == momentDate(date),
    );
    if (target < 0) return;
    final owner = ref.read(momentsCurrentUserIdProvider);
    final identity = _identity;
    final generation = ++_jumpGeneration;
    final month = _month;
    bool current() =>
        mounted &&
        _sessionSafe &&
        identity == _identity &&
        generation == _jumpGeneration &&
        month == _month &&
        owner != null &&
        ref.read(momentsCurrentUserIdProvider) == owner;
    setState(() => _selectedDate = momentDate(date));
    await WidgetsBinding.instance.endOfFrame;
    double low = 0;
    double? high;
    for (var attempt = 0; attempt < 24 && current(); attempt++) {
      final anchor = _recordAnchors[journal.records[target].id]?.currentContext;
      if (anchor != null) {
        await Scrollable.ensureVisible(
          anchor,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 240),
          alignment: .04,
        );
        return;
      }
      if (!_scroll.hasClients) return;
      final visible = <int>[
        for (var index = 0; index < journal.records.length; index++)
          if (_recordAnchors[journal.records[index].id]?.currentContext != null)
            index,
      ];
      final position = _scroll.position;
      if (visible.isNotEmpty && target < visible.first) {
        high = position.pixels;
      } else {
        low = position.pixels;
      }
      low = low.clamp(0, position.maxScrollExtent).toDouble();
      final upper = (high ?? position.maxScrollExtent).clamp(
        low,
        position.maxScrollExtent,
      );
      var next = low + (upper - low) / 2;
      if ((next - position.pixels).abs() < 2) {
        next =
            (position.pixels +
                    (visible.isNotEmpty && target < visible.first ? -1 : 1) *
                        position.viewportDimension *
                        .8)
                .clamp(0, position.maxScrollExtent)
                .toDouble();
      }
      _scroll.jumpTo(next.clamp(0, position.maxScrollExtent).toDouble());
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Widget _monthNavigation(MomentJournal? journal) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '${_month.year}년 ${_month.month}월',
              key: const ValueKey('moments-month-title'),
              style: ExperienceFormStyle.text(
                context,
                23,
                weight: FontWeight.w600,
              ).copyWith(letterSpacing: -.6),
            ),
          ),
          IconButton(
            key: const ValueKey('moments-previous-month'),
            tooltip: '이전 달',
            onPressed: _month.year <= 1900 && _month.month == 1
                ? null
                : () => _changeMonth(-1),
            icon: const ExperienceIcon('ChevronLeft'),
          ),
          IconButton(
            key: const ValueKey('moments-next-month'),
            tooltip: '다음 달',
            onPressed:
                _month.isBefore(momentMonth(journal?.today ?? momentToday()))
                ? () => _changeMonth(1)
                : null,
            icon: const ExperienceIcon('ChevronRight'),
          ),
        ],
      ),
      if (journal != null) ...[
        MomentMonthCalendar(
          month: _month,
          records: journal.records,
          selectedDate: _selectedDate ?? journal.today,
          today: journal.today,
          onDateSelected: (date) {
            final hasPhotos = journal.records.any(
              (record) =>
                  momentDate(record.recordDate) == date &&
                  record.photos.isNotEmpty,
            );
            if (date == journal.today && !hasPhotos) {
              unawaited(_compose(journal));
            } else {
              unawaited(_jumpToDate(journal, date));
            }
          },
        ),
        if (journal.currentWeekRecords.isNotEmpty) _recapCard(journal),
        if (journal.monthlyReward != null)
          MomentMonthlyRewardSummary(reward: journal.monthlyReward!),
        MomentMonthlyAlbumEntry(
          journal: journal,
          onPreview: () => _album(journal),
        ),
      ],
    ],
  );

  Widget _webJournal(
    AsyncValue<MomentJournal>? result,
    MomentJournal? journal,
    List<Widget> headerActions,
  ) => ListView(
    key: const PageStorageKey('moments-web-scroll'),
    cacheExtent: 800,
    controller: _scroll,
    physics: const AlwaysScrollableScrollPhysics(),
    padding: EdgeInsets.fromLTRB(
      WebPageLayout.horizontalInset(MediaQuery.sizeOf(context).width),
      32,
      WebPageLayout.horizontalInset(MediaQuery.sizeOf(context).width),
      48,
    ),
    children: [
      WebPageHeading(
        title: '나의 기록',
        description: '사진 한 장과 짧은 한 줄, 하루씩 쌓이는 나의 기록.',
        trailing: Wrap(spacing: 4, children: headerActions),
      ),
      const SizedBox(height: 28),
      if (_error != null) ...[
        MomentErrorNotice(message: _error!, onRetry: _refresh),
        const SizedBox(height: 20),
      ],
      if (result?.hasError == true && journal == null)
        MomentErrorNotice(
          message: '이달의 기록을 불러오지 못했어요. 연결을 확인한 뒤 다시 시도해 주세요.',
          onRetry: _refresh,
        )
      else if (journal == null)
        const Padding(
          padding: EdgeInsets.all(48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else
        WebMomentsJournalLayout(
          monthNavigation: _monthNavigation(journal),
          records: [
            if (journal.records.isEmpty)
              MomentEmptyBook(
                month: journal.month,
                today: journal.today,
                onRecord: () => _compose(journal),
              )
            else
              for (final record in journal.records)
                _recordCard(journal, record, wide: true),
          ],
          weekly: journal.records.isEmpty
              ? const SizedBox.shrink()
              : _weekCard(journal),
        ),
    ],
  );

  Widget _weekCard(MomentJournal journal) => MomentWeekCard(
    photoCount: journal.weekPhotoCount,
    // 다른 달을 보는 중에도 서버가 돌려준 이번 주 기록에서 오늘 여부를 판단한다.
    hasTodayRecord: journal.currentWeekRecords.any(
      (record) => momentDate(record.recordDate) == momentDate(journal.today),
    ),
    onRecord: () => _compose(journal),
  );

  Widget _recapCard(MomentJournal journal) => TextButton.icon(
    key: const ValueKey('moments-week-recap'),
    style: TextButton.styleFrom(
      minimumSize: const Size(44, 44),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      textStyle: ExperienceFormStyle.text(context, 13, weight: FontWeight.w600),
    ),
    onPressed: () => _recap(journal),
    icon: const Icon(Icons.auto_awesome_motion_outlined, size: 20),
    label: const Text('이번 주 돌아보기'),
  );
}
