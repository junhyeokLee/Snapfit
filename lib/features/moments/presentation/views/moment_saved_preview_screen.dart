import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/fonts/document_fonts.dart';
import '../widgets/moment_document_font_entry.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../album/domain/entities/album.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../../data/moment_engagement_repository.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../providers/moment_publication_providers.dart';
import '../widgets/moments_widgets.dart';
import '../widgets/moment_share_sheet.dart';
import '../widgets/moment_publication_panel.dart';
import 'moment_reminder_settings_screen.dart';
import 'monthly_moment_preview_screen.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// A saved record already exists here. This preview never creates an album;
/// the owner explicitly chooses that action in the monthly preview.
Future<void> showMomentSavedPreview(
  BuildContext context, {
  required MomentRecord record,
  required MomentJournal journal,
  bool hasCompleteJournal = true,
  Future<void> Function(Album)? onAlbumCreated,
}) => Navigator.of(context).push<void>(
  snapFitRoute(
    page: MomentSavedPreviewScreen(
      record: record,
      journal: journal,
      hasCompleteJournal: hasCompleteJournal,
      onAlbumCreated: onAlbumCreated,
    ),
  ),
);

class MomentSavedPreviewScreen extends ConsumerStatefulWidget {
  final bool _fontsPrepared;

  const MomentSavedPreviewScreen({
    super.key,
    required this.record,
    required this.journal,
    this.hasCompleteJournal = true,
    this.onAlbumCreated,
  }) : _fontsPrepared = false;

  final MomentRecord record;
  final MomentJournal journal;
  // First-record and monthly-total copy requires the complete month history.
  final bool hasCompleteJournal;
  final Future<void> Function(Album)? onAlbumCreated;

  MomentSavedPreviewScreen._withFontsReady(MomentSavedPreviewScreen original)
    : _fontsPrepared = true,
      record = original.record,
      journal = original.journal,
      hasCompleteJournal = original.hasCompleteJournal,
      onAlbumCreated = original.onAlbumCreated;

  @override
  ConsumerState<MomentSavedPreviewScreen> createState() =>
      // ignore: no_logic_in_create_state — intentional: selects a different State subtype for deferred font loading
      DocumentFonts.deferred && !_fontsPrepared
      ? MomentDocumentFontEntryState<MomentSavedPreviewScreen>(
          MomentSavedPreviewScreen._withFontsReady,
        )
      : _MomentSavedPreviewScreenState();
}

class _MomentSavedPreviewScreenState
    extends ConsumerState<MomentSavedPreviewScreen> {
  late final String? _owner;
  late final List<MomentRecord> _records;
  bool _sessionChanged = false, _opening = false, _sharing = false;
  int _identity = 0;
  String? _error;

  bool get _matchingMonth =>
      momentMonth(widget.journal.month) ==
      momentMonth(widget.record.recordDate);

  @override
  void initState() {
    super.initState();
    _owner = ref.read(momentsCurrentUserIdProvider);
    final month = momentMonth(widget.record.recordDate);
    _records = [
      widget.record,
      for (final record in widget.journal.records)
        if (record.id != widget.record.id &&
            momentMonth(record.recordDate) == month)
          record,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _owner == null ||
          _sessionChanged ||
          ref.read(momentsCurrentUserIdProvider) != _owner)
        return;
      try {
        unawaited(
          ref
              .read(momentEngagementRepositoryProvider)
              .recordActivity(MomentActivity.rewardViewed, month: month),
        );
      } catch (_) {
        // A measurement failure must never hide the already saved record.
      }
    });
  }

  Future<void> _preview() async {
    if (_opening ||
        _sharing ||
        _sessionChanged ||
        _owner == null ||
        ref.read(momentsCurrentUserIdProvider) != _owner)
      return;
    final identity = _identity;
    bool current() =>
        mounted &&
        !_sessionChanged &&
        identity == _identity &&
        ref.read(momentsCurrentUserIdProvider) == _owner;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final month = momentMonth(widget.record.recordDate);
      final journal = await ref
          .read(momentsRepositoryProvider)
          .listMonth(month);
      if (!current()) return;
      await Navigator.of(context).push<void>(
        snapFitRoute(
          page: MonthlyMomentPreviewScreen(
            month: month,
            records: journal.records,
            today: journal.today,
            existingAlbumId: journal.monthlyAlbumId,
            importedPhotoIds: journal.monthlyAlbumPhotoIds,
            onAlbumCreated: widget.onAlbumCreated,
          ),
        ),
      );
    } catch (error) {
      if (current())
        setState(
          () => _error = error is MomentException
              ? error.message
              : '기록은 저장됐어요. 앨범을 불러오려면 다시 눌러 주세요.',
        );
    } finally {
      if (current()) setState(() => _opening = false);
    }
  }

  Future<void> _shareRecord() async {
    if (_opening ||
        _sharing ||
        _sessionChanged ||
        _owner == null ||
        ref.read(momentsCurrentUserIdProvider) != _owner)
      return;
    final identity = _identity;
    setState(() => _sharing = true);
    try {
      // 공유는 방금 저장한 기록에 속한 사진만 명시적으로 선택한다.
      await showMomentShareSheet(context, record: widget.record);
    } finally {
      if (mounted && identity == _identity) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = ref.watch(momentsCurrentUserIdProvider);
    ref.listen(momentsCurrentUserIdProvider, (previous, next) {
      if (previous != next) {
        _sessionChanged = true;
        _identity++;
      }
    });
    final locked = _sessionChanged || actor == null || actor != _owner;
    final firstRecord = _records.length == 1;
    final savedPhoto = widget.record.photos.firstOrNull;
    final photoCount = _records.fold<int>(
      0,
      (sum, record) => sum + record.photos.length,
    );
    return SocialWebFrame(
      section: WebSection.moments,
      child: Scaffold(
        backgroundColor: SocialStyle.background(context),
        appBar: ExperienceHeader(
          title: '나의 한 달',
          showNotifications: false,
          onBack: () => Navigator.of(context).pop(),
        ),
        body: locked
            ? const SocialEmpty(
                title: '계정이 변경되었어요',
                message: '나의 기록으로 돌아가 다시 시작해 주세요.',
                icon: ExperienceIcon('Lock', size: 28),
              )
            : SafeArea(
                top: false,
                child: SocialContent(
                  maxWidth: 580,
                  child: ListView(
                    cacheExtent: 800,
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      if (savedPhoto != null)
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 370),
                            // 저장한 지면 자체를 보여 주며 월간 표지나 문구를 다시 합성하지 않는다.
                            child: KeyedSubtree(
                              key: const ValueKey('moment-saved-book-cover'),
                              child: MomentPhotoView(
                                key: const ValueKey('moment-saved-photo'),
                                photo: savedPhoto,
                                aspectRatio: savedPhoto.aspectRatio,
                                label: '방금 저장한 사진',
                                backgroundColor: Colors.transparent,
                                fit: BoxFit.contain,
                                imageDecodeWidth: 1200,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 30),
                      Text(
                        !widget.hasCompleteJournal
                            ? '이 순간을,\n잘 간직했어요.'
                            : !_matchingMonth
                            ? '이 순간이,\n한 달의 책이 될 거예요.'
                            : firstRecord
                            ? '내 한 달의\n첫 장이 생겼어요.'
                            : '나의 한 달에\n한 장이 더 쌓였어요.',
                        key: const ValueKey('moment-saved-heading'),
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          27,
                          weight: FontWeight.w600,
                        ).copyWith(height: 1.35, letterSpacing: -.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        !widget.hasCompleteJournal
                            ? '사진 ${widget.record.photos.length}장을 저장했어요.\n모아둔 사진으로 내 한 달의 책을 만들어보세요.'
                            : _matchingMonth
                            ? '${widget.record.recordDate.month}월에 모은 사진 $photoCount장.\n이 순간들로 내 한 달의 책을 만들어보세요.'
                            : '${widget.record.recordDate.month}월의 순간을 저장했어요.\n모아둔 사진으로 내 한 달의 책을 만들어보세요.',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          14,
                          secondary: true,
                        ).copyWith(height: 1.7),
                      ),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        MomentErrorNotice(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        key: const ValueKey('moment-saved-preview'),
                        onPressed: _opening ? null : _preview,
                        style: SocialStyle.primary(context),
                        child: Text(
                          _opening ? '이달의 앨범을 불러오는 중…' : '월간 앨범 미리보기',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.record.photos.isNotEmpty)
                        OutlinedButton.icon(
                          key: const ValueKey('moment-saved-share'),
                          onPressed: _opening || _sharing ? null : _shareRecord,
                          icon: const ExperienceIcon('Share2', size: 18),
                          label: const Text('방금 남긴 기록 공유'),
                        ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('moment-saved-return'),
                        onPressed: _opening
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('기록으로 돌아가기'),
                      ),
                      const SizedBox(height: 16),
                      _publicationOptions(context),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const ValueKey('moment-saved-reminder'),
                        onPressed: _opening
                            ? null
                            : () => Navigator.of(context).push<void>(
                                snapFitRoute(
                                  page: const MomentReminderSettingsScreen(),
                                ),
                              ),
                        icon: const ExperienceIcon('Bell', size: 17),
                        label: const Text('원하는 날에 주간 알림 받기'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _publicationOptions(BuildContext context) {
    final publication = ref.watch(
      momentPublicationStateProvider(widget.record.id),
    );
    // Keep an opened private panel and its retry message mounted while its
    // status refreshes. Cold-load public/pending results still expand below.
    final state = publication.hasValue ? publication.value : null;
    final active = state?.isPublished == true || state?.isPending == true;
    final title = state?.isPublished == true
        ? '피드에 공개한 기록'
        : state?.isPending == true
        ? '준비 중인 피드 공개'
        : publication.hasError
        ? '피드 공개 상태 확인'
        : '한 장을 피드에도 남겨볼까요?';
    return KeyedSubtree(
      key: const ValueKey('moment-saved-publication-options'),
      child: ExpansionTile(
        key: ValueKey(
          'moment-saved-publication-${state?.status ?? (publication.hasError ? 'error' : 'loading')}',
        ),
        initiallyExpanded: active,
        maintainState: false,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: SocialStyle.line(context)),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: SocialStyle.line(context)),
        ),
        leading: ExperienceIcon(
          state?.isPublished == true ? 'Globe' : 'MessageCircle',
          size: 19,
          color: SocialStyle.accent(context),
        ),
        title: Text(
          title,
          style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
        ),
        subtitle: Text(
          active ? '공개 상태 보기 · 나만 보기로 변경' : '사진 한 장과 글만 나누고 싶을 때',
          style: ExperienceFormStyle.text(
            context,
            12,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
        children: [MomentPublicationPanel(record: widget.record)],
      ),
    );
  }
}
