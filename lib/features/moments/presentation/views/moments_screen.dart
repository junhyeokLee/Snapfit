import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/web/web_design.dart'
    show WebPageHeading, WebPageLayout;
import '../../../../shared/widgets/experience_style.dart';
import '../../../album/domain/entities/album.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../../domain/moment_draft.dart';
import '../../data/moment_engagement_repository.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';
import '../widgets/web_moments_journal_layout.dart';
import '../widgets/moment_draft_recovery_card.dart';
import '../widgets/moment_book_cover.dart';
import 'moment_compose_screen.dart';
import 'monthly_moment_preview_screen.dart';
import 'weekly_moment_recap_screen.dart';
import 'moment_saved_preview_screen.dart';
import '../widgets/moment_visual_style.dart';

class MomentsScreen extends ConsumerStatefulWidget {
  const MomentsScreen({
    super.key,
    this.onBack,
    this.onAlbumCreated,
    this.onReminderSettings,
    this.initialDraftRecordId,
  });
  final VoidCallback? onBack;
  final VoidCallback? onReminderSettings;
  final Future<void> Function(Album)? onAlbumCreated;
  final String? initialDraftRecordId;

  @override
  ConsumerState<MomentsScreen> createState() => _MomentsScreenState();
}

class _MomentsScreenState extends ConsumerState<MomentsScreen>
    with WidgetsBindingObserver {
  DateTime _month = momentMonth(momentToday());
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
  }

  @override
  void dispose() {
    _identity++;
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    bool? editingDraft,
  }) async {
    if (_openingCompose || ref.read(momentsCurrentUserIdProvider) == null)
      return;
    _openingCompose = true;
    final identity = _identity;
    final owner = ref.read(momentsCurrentUserIdProvider)!;
    var isEditing = record != null || editingDraft == true;
    Object? result;
    try {
      if (draftRecordId != null && editingDraft == null) {
        // Deep entry can happen before the recovery list has loaded. Read only
        // its small metadata; the composer alone loads the selected originals.
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
        MaterialPageRoute(
          builder: (_) => MomentComposeScreen(
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
      MaterialPageRoute(
        builder: (_) => MonthlyMomentPreviewScreen(
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
      MaterialPageRoute(
        builder: (_) => WeeklyMomentRecapScreen(
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(momentsCurrentUserIdProvider);
    final drafts = owner == null
        ? null
        : ref.watch(momentDraftSummariesForOwnerProvider(owner));
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
      if (previous == next) return;
      _identity++;
      _month = momentMonth(momentToday());
      _midnight?.cancel();
      _scheduledToday = null;
      _error = null;
    });
    final result = owner == null
        ? null
        : ref.watch(momentsMonthProvider(_month));
    final journal = result?.isReloading == true ? null : result?.value;
    if (journal != null) _scheduleDateRefresh(journal.today);
    final headerActions = <Widget>[
      if (owner != null && widget.onReminderSettings != null)
        if (kIsWeb)
          TextButton.icon(
            key: const ValueKey('moments-reminder-settings'),
            onPressed: widget.onReminderSettings,
            icon: const Icon(Icons.notifications_none_rounded, size: 18),
            label: const Text('기록 알림'),
          )
        else
          IconButton(
            key: const ValueKey('moments-reminder-settings'),
            tooltip: '기록 알림 설정',
            onPressed: widget.onReminderSettings,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
      if (owner != null)
        IconButton(
          key: const ValueKey('moments-refresh'),
          tooltip: '나의 기록 새로고침',
          onPressed: result?.isLoading == true ? null : () => _refresh(),
          icon: const Icon(Icons.refresh_rounded),
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
                icon: Icons.lock_outline_rounded,
              )
            : SafeArea(
                top: false,
                child: SocialContent(
                  maxWidth: kIsWeb ? WebPageLayout.maxWidth : 720,
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: kIsWeb
                        ? _webJournal(result, journal, headerActions, drafts)
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            children: [
                              ..._draftRecovery(drafts, journal),
                              if (journal != null &&
                                  journal.records.isNotEmpty) ...[
                                MomentWeekCard(
                                  photoCount: journal.weekPhotoCount,
                                  onRecord: () => _compose(journal),
                                ),
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
                                    onRecord: () => _compose(journal),
                                  )
                                else
                                  MomentRecordCard(
                                    key: ValueKey(
                                      'moment-record-${journal.records.first.id}',
                                    ),
                                    record: journal.records.first,
                                    onEdit: () => _compose(
                                      journal,
                                      record: journal.records.first,
                                    ),
                                  ),
                                if (journal.currentWeekRecords.isNotEmpty) ...[
                                  _recapCard(journal),
                                  const SizedBox(height: 16),
                                ],
                                if (journal.records.isNotEmpty ||
                                    journal.monthlyAlbumId != null) ...[
                                  _albumCard(journal),
                                  const SizedBox(height: 28),
                                ],
                                if (journal.records.length > 1)
                                  for (final record in journal.records.skip(1))
                                    MomentRecordCard(
                                      key: ValueKey(
                                        'moment-record-${record.id}',
                                      ),
                                      record: record,
                                      onEdit: () =>
                                          _compose(journal, record: record),
                                    ),
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

  Widget _monthNavigation(MomentJournal? journal) => Row(
    children: [
      Expanded(
        child: Text(
          '${_month.year}년 ${_month.month}월',
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
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      IconButton(
        key: const ValueKey('moments-next-month'),
        tooltip: '다음 달',
        onPressed: _month.isBefore(momentMonth(journal?.today ?? momentToday()))
            ? () => _changeMonth(1)
            : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );

  Widget _webJournal(
    AsyncValue<MomentJournal>? result,
    MomentJournal? journal,
    List<Widget> headerActions,
    AsyncValue<List<MomentDraftSummary>>? drafts,
  ) => ListView(
    key: const PageStorageKey('moments-web-scroll'),
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
        description: '오늘의 사진 한 장부터, 나만의 한 달 앨범까지.',
        trailing: Wrap(spacing: 4, children: headerActions),
      ),
      const SizedBox(height: 28),
      ..._draftRecovery(drafts, journal),
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
                onRecord: () => _compose(journal),
              )
            else
              for (final record in journal.records)
                MomentRecordCard(
                  key: ValueKey('moment-record-${record.id}'),
                  record: record,
                  maxPhotoHeight: 560,
                  onEdit: () => _compose(journal, record: record),
                ),
          ],
          weekly: journal.records.isEmpty
              ? const SizedBox.shrink()
              : MomentWeekCard(
                  photoCount: journal.weekPhotoCount,
                  onRecord: () => _compose(journal),
                ),
          recap: journal.currentWeekRecords.isEmpty
              ? null
              : _recapCard(journal),
          album: journal.records.isEmpty && journal.monthlyAlbumId == null
              ? null
              : _albumCard(journal),
        ),
    ],
  );

  List<Widget> _draftRecovery(
    AsyncValue<List<MomentDraftSummary>>? state,
    MomentJournal? journal,
  ) {
    if (state?.hasError == true) {
      return [
        MomentErrorNotice(
          message: '이 기기의 임시 기록을 불러오지 못했어요.',
          onRetry: () async {
            final owner = ref.read(momentsCurrentUserIdProvider);
            if (owner != null)
              ref.invalidate(momentDraftSummariesForOwnerProvider(owner));
            ref.invalidate(momentDraftsProvider);
          },
        ),
        const SizedBox(height: 16),
      ];
    }
    final drafts = state?.asData?.value ?? const <MomentDraftSummary>[];
    if (drafts.isEmpty) return const [];
    return [
      MomentDraftRecoveryCard(
        drafts: drafts,
        onResume: (draft) => _compose(
          journal,
          draftRecordId: draft.recordId,
          editingDraft: draft.isEditing,
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _recapCard(MomentJournal journal) => Material(
    color: MomentVisualStyle.paper(context),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const ValueKey('moments-week-recap'),
      borderRadius: BorderRadius.circular(18),
      onTap: () => _recap(journal),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              color: SocialStyle.accent(context),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 주 돌아보기',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '남겨둔 ${journal.weekPhotoCount}장의 순간을 천천히',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: SocialStyle.accent(context),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _albumCard(MomentJournal journal) {
    final count = journal.records.fold<int>(
      0,
      (total, record) => total + record.photos.length,
    );
    final pending = journal.records
        .expand((record) => record.photos)
        .where((photo) => !journal.monthlyAlbumPhotoIds.contains(photo.id))
        .length;
    final first = journal.records.expand((record) => record.photos).firstOrNull;
    return Material(
      color: MomentVisualStyle.paper(context),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: MomentVisualStyle.line(context)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: InkWell(
        key: const ValueKey('moments-monthly-album'),
        onTap: () => _album(journal),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, bounds) {
              final compact =
                  bounds.maxWidth < 240 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.5;
              final book = SizedBox(
                key: const ValueKey('moments-monthly-book-cover'),
                width: bounds.maxWidth >= 330 ? 104 : 88,
                child: MomentBookCover(month: journal.month, photo: first),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journal.monthlyAlbumId == null
                        ? '나의 ${journal.month.month}월, 한 권으로'
                        : '${journal.month.month}월의 앨범 이어 만들기',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ).copyWith(height: 1.5, letterSpacing: -.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    journal.monthlyAlbumId == null
                        ? '사진 $count장으로 만드는 나만의 월간 앨범'
                        : pending > 0
                        ? '새 사진 $pending장을 골라서 추가할 수 있어요.'
                        : '저장한 앨범에서 사진과 이야기를 다듬어요.',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ).copyWith(height: 1.6),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    journal.monthlyAlbumId == null
                        ? '월간 앨범 미리보기  →'
                        : pending > 0
                        ? '새 사진 골라 추가하기  →'
                        : '월간 앨범 이어보기  →',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      weight: FontWeight.w600,
                      color: SocialStyle.accent(context),
                    ),
                  ),
                ],
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [book, const SizedBox(height: 18), copy],
                    )
                  : Row(
                      children: [
                        book,
                        const SizedBox(width: 16),
                        Expanded(child: copy),
                      ],
                    );
            },
          ),
        ),
      ),
    );
  }
}
