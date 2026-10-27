import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../../social/presentation/widgets/social_web_frame.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../../store/presentation/widgets/template_page_renderer.dart';
import '../../domain/moment_record.dart';
import '../../domain/monthly_album_builder.dart';
import '../../data/moment_engagement_repository.dart';
import '../providers/moment_engagement_providers.dart';
import '../providers/moments_providers.dart';
import '../widgets/moments_widgets.dart';
import 'moment_reminder_settings_screen.dart';
import 'monthly_moment_preview_screen.dart';

/// A saved record already exists here. This preview never creates an album;
/// the owner explicitly chooses that action in the monthly preview.
Future<void> showMomentSavedPreview(
  BuildContext context, {
  required MomentRecord record,
  required MomentJournal journal,
  Future<void> Function(Album)? onAlbumCreated,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute<void>(
    builder: (_) => MomentSavedPreviewScreen(
      record: record,
      journal: journal,
      onAlbumCreated: onAlbumCreated,
    ),
  ),
);

class MomentSavedPreviewScreen extends ConsumerStatefulWidget {
  const MomentSavedPreviewScreen({
    super.key,
    required this.record,
    required this.journal,
    this.onAlbumCreated,
  });

  final MomentRecord record;
  final MomentJournal journal;
  final Future<void> Function(Album)? onAlbumCreated;

  @override
  ConsumerState<MomentSavedPreviewScreen> createState() =>
      _MomentSavedPreviewScreenState();
}

class _MomentSavedPreviewScreenState
    extends ConsumerState<MomentSavedPreviewScreen> {
  late final String? _owner;
  late final List<MomentRecord> _records;
  late final List<LayerModel> _cover;
  late final Color _coverColor;
  late final Map<String, String> _displaySources;
  bool _sessionChanged = false, _opening = false;
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
    final selected = selectMonthlyMomentPhotoIds(
      month: month,
      records: _records,
    );
    // The latest saved scene becomes this ephemeral preview's cover. The
    // monthly editor still offers its normal explicit cover selection.
    final latest = widget.record.photos.firstOrNull?.id;
    final ids = latest == null
        ? selected
        : <String>[
            latest,
            ...selected.where((id) => id != latest),
          ].take(9).toList();
    final draft = buildMonthlyMomentAlbum(
      month: month,
      records: _records,
      selectedPhotoIds: ids,
    );
    final document = jsonDecode(draft.coverLayersJson) as Map;
    final page = Map<String, dynamic>.from(
      (document['pages'] as List).first as Map,
    );
    _coverColor = Color((page['backgroundColor'] as num).toInt());
    _cover = (page['layers'] as List)
        .map(
          (layer) => LayerExportMapper.fromJson(
            Map<String, dynamic>.from(layer as Map),
            canvasSize: monthlyMomentCanvasSize,
            isCover: true,
          ),
        )
        .toList();
    _displaySources = {
      for (final record in _records)
        for (final photo in record.photos)
          if (photo.url.isNotEmpty) photo.storageUri: photo.url,
    };
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
        MaterialPageRoute<void>(
          builder: (_) => MonthlyMomentPreviewScreen(
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
                icon: Icons.lock_outline_rounded,
              )
            : SafeArea(
                top: false,
                child: SocialContent(
                  maxWidth: 580,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 370),
                          child: Semantics(
                            label:
                                '방금 저장한 사진이 담긴 ${widget.record.recordDate.month}월 앨범 표지 미리보기',
                            image: true,
                            child: Container(
                              key: const ValueKey('moment-saved-book-cover'),
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: _coverColor,
                                borderRadius: BorderRadius.circular(5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .09),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: AspectRatio(
                                aspectRatio: monthlyMomentAlbumCoverSize.ratio,
                                child: LayoutBuilder(
                                  builder: (context, size) =>
                                      TemplatePageRenderer(
                                        layers: _cover,
                                        width: size.maxWidth,
                                        height: size.maxWidth,
                                        designCanvasSize:
                                            monthlyMomentCanvasSize,
                                        preserveTypography: true,
                                        imageDecodeWidth: 1200,
                                        photoBuilder: (layer, width) =>
                                            SnapfitImage(
                                              urlOrGs:
                                                  _displaySources[layer
                                                      .imageUrl] ??
                                                  layer.imageUrl ??
                                                  '',
                                              fit: BoxFit.contain,
                                              memCacheWidth: width,
                                            ),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        !_matchingMonth
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
                        _matchingMonth
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: SocialStyle.accent(context),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '나만 보는 기록에 저장했어요',
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        MomentErrorNotice(message: _error!),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        key: const ValueKey('moment-saved-preview'),
                        onPressed: _opening ? null : _preview,
                        style: SocialStyle.primary(context),
                        child: Text(_opening ? '이달의 앨범을 불러오는 중…' : '내 앨범 미리보기'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        key: const ValueKey('moment-saved-return'),
                        onPressed: _opening
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('기록으로 돌아가기'),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        key: const ValueKey('moment-saved-reminder'),
                        onPressed: _opening
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const MomentReminderSettingsScreen(),
                                ),
                              ),
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          size: 17,
                        ),
                        label: const Text('원하는 날에 주간 알림 받기'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
