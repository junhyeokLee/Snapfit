import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../../domain/moment_photo_design.dart';
import 'moment_photo_design_view.dart';
import 'moment_daily_journal_intro.dart';
import 'moment_visual_style.dart';
import '../../../../shared/widgets/experience_icon.dart';

String momentDateLabel(DateTime date) => '${date.month}월 ${date.day}일';

class MomentPhotoView extends StatelessWidget {
  const MomentPhotoView({
    super.key,
    this.photo,
    this.bytes,
    this.design,
    this.aspectRatio = 1,
    this.label = '나의 기록 사진',
    this.fit = BoxFit.contain,
    this.useIntrinsicSize = false,
    this.backgroundColor,
    this.imageDecodeWidth = 1200,
    this.placeholder,
    this.error,
    this.automaticStorageRefresh,
    this.resolveStorageUrlForTesting,
  });

  final MomentPhoto? photo;
  final Uint8List? bytes;
  final MomentPhotoDesign? design;
  final double aspectRatio;
  final String label;
  final BoxFit fit;
  final Color? backgroundColor;
  final int imageDecodeWidth;
  final Widget? placeholder, error;
  final bool? automaticStorageRefresh;
  @visibleForTesting
  final Future<String> Function(String)? resolveStorageUrlForTesting;

  /// Kept for callers restoring older drafts. Unformatted originals now share
  /// the default album frame, with their complete pixels contained inside it.
  final bool useIntrinsicSize;

  @override
  Widget build(BuildContext context) {
    final artwork = design ?? photo?.design;
    if (artwork != null) {
      return Semantics(
        label: label,
        image: true,
        child: MomentPhotoDesignView(
          design: artwork,
          photoSource: photo?.storageUri ?? momentPhotoOriginalSource,
          bytes: bytes,
          fit: fit,
          imageDecodeWidth: imageDecodeWidth,
          placeholder: placeholder,
          error: error,
        ),
      );
    }
    Widget unavailable(BuildContext context, Object error, StackTrace? stack) =>
        this.error ??
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '사진을 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 13, secondary: true),
            ),
          ),
        );
    final content = ColoredBox(
      color: backgroundColor ?? MomentVisualStyle.paper(context),
      child: bytes != null
          ? Image.memory(
              bytes!,
              fit: fit,
              cacheWidth: imageDecodeWidth.clamp(64, 1600).toInt(),
              gaplessPlayback: true,
              semanticLabel: label,
              errorBuilder: unavailable,
            )
          : Semantics(
              label: label,
              image: true,
              child: SnapfitImage(
                urlOrGs: photo?.storageUri ?? '',
                fallbackSources: [
                  if (photo?.url.isNotEmpty == true) photo!.url,
                ],
                fit: fit,
                memCacheWidth: imageDecodeWidth.clamp(64, 1600).toInt(),
                automaticStorageRefresh: automaticStorageRefresh,
                resolveStorageUrlForTesting: resolveStorageUrlForTesting,
                error: unavailable(context, StateError('unavailable'), null),
                placeholder:
                    placeholder ??
                    Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SocialStyle.accent(context),
                        ),
                      ),
                    ),
              ),
            ),
    );
    return AspectRatio(aspectRatio: aspectRatio, child: content);
  }
}

class MomentErrorNotice extends StatelessWidget {
  const MomentErrorNotice({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: ExperienceFormStyle.text(
              context,
              13,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ).copyWith(height: 1.6),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 불러오기')),
        ],
      ),
    ),
  );
}

class MomentPrivateNote extends StatelessWidget {
  const MomentPrivateNote({super.key, this.album = false});
  final bool album;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ExperienceIcon('Lock', size: 16, color: SocialStyle.accent(context),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          album
              ? '앨범은 나만 볼 수 있게 만들어져요. 완성한 뒤 직접 공개할 수 있어요.'
              : '기록은 나만 볼 수 있어요. 사진은 선택한 것만 저장해요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
      ),
    ],
  );
}

/// The daily action and real weekly count leave room for the photographs.
class MomentWeekCard extends StatelessWidget {
  const MomentWeekCard({
    super.key,
    required this.photoCount,
    required this.onRecord,
    this.onRecap,
    this.hasTodayRecord = false,
  });
  final int photoCount;
  final VoidCallback onRecord;
  final VoidCallback? onRecap;
  final bool hasTodayRecord;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    decoration: BoxDecoration(
      color: MomentVisualStyle.paper(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: MomentVisualStyle.line(context)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final progress = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '사진과 한 줄, 하루씩',
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '이번 주 사진 $photoCount장',
              style: ExperienceFormStyle.text(
                context,
                11,
                secondary: true,
              ).copyWith(height: 1.5),
            ),
          ],
        );
        final record = FilledButton.icon(
          key: const ValueKey('moments-add'),
          onPressed: onRecord,
          style: SocialStyle.primary(context).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          icon: const ExperienceIcon('Plus', size: 18),
          label: Text(hasTodayRecord ? '오늘 한 장 더' : '오늘 기록하기'),
        );
        if (constraints.maxWidth < 290 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.5) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [progress, const SizedBox(height: 12), record],
          );
        }
        return Row(
          children: [
            Expanded(child: progress),
            const SizedBox(width: 10),
            record,
          ],
        );
      },
    ),
  );
}

/// Kept as the existing entry API; the first experience is now a dated note,
/// while the real monthly book appears only once photographs have been saved.
class MomentEmptyBook extends StatelessWidget {
  const MomentEmptyBook({
    super.key,
    required this.month,
    required this.onRecord,
    this.today,
  });
  final DateTime month;
  final DateTime? today;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => MomentDailyJournalIntro(
    today: today ?? momentToday(),
    onRecord: onRecord,
  );
}

class MomentRecordCard extends StatefulWidget {
  const MomentRecordCard({
    super.key,
    required this.record,
    required this.onEdit,
    this.maxPhotoHeight,
    this.onShare,
    this.initiallyExpanded = false,
    this.expandRequest,
  });
  final MomentRecord record;
  final VoidCallback onEdit;
  final double? maxPhotoHeight;
  final ValueChanged<MomentPhoto>? onShare;
  final bool initiallyExpanded;
  final int? expandRequest;

  @override
  State<MomentRecordCard> createState() => _MomentRecordCardState();
}

class _MomentRecordCardState extends State<MomentRecordCard> {
  final PageController _pages = PageController();
  int _index = 0;
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(covariant MomentRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id) {
      _expanded = widget.initiallyExpanded;
    } else if ((!oldWidget.initiallyExpanded && widget.initiallyExpanded) ||
        (widget.expandRequest != null &&
            oldWidget.expandRequest != widget.expandRequest)) {
      // 날짜로 찾아온 기록만 펼치며, 일반 새로고침은 직접 닫은 상태를 보존한다.
      _expanded = true;
    }
    if (oldWidget.record.id != widget.record.id ||
        _index >= widget.record.photos.length) {
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _toggle() {
    // 다시 펼친 첫 사진과 공유 대상이 다른 인덱스를 가리키지 않게 함께 맞춘다.
    if (_expanded && _index != 0) {
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    if (record.photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label:
                '${momentDateLabel(record.recordDate)} 기록, 사진 ${record.photos.length}장',
            onTap: _toggle,
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('moment-record-toggle-${record.id}'),
              onTap: _toggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Text(
                      record.recordDate.day.toString().padLeft(2, '0'),
                      style: ExperienceFormStyle.text(
                        context,
                        26,
                        weight: FontWeight.w600,
                      ).copyWith(letterSpacing: -1),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            momentDateLabel(record.recordDate),
                            style: ExperienceFormStyle.text(
                              context,
                              12,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${const ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'][record.recordDate.weekday - 1]} · 사진 ${record.photos.length}장',
                            style: ExperienceFormStyle.text(
                              context,
                              11,
                              secondary: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ExperienceFormStyle.muted(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    key: ValueKey('moment-record-content-${record.id}'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: LayoutBuilder(
                          builder: (context, bounds) => AspectRatio(
                            key: ValueKey('moment-photo-frame-${record.id}'),
                            aspectRatio: widget.maxPhotoHeight == null
                                ? momentPhotoAspect(record.photos[_index])
                                : (bounds.maxWidth / widget.maxPhotoHeight!)
                                      .clamp(
                                        momentPhotoAspect(
                                          record.photos[_index],
                                        ),
                                        double.infinity,
                                      ),
                            child: PageView.builder(
                              key: ValueKey('moment-photos-${record.id}'),
                              controller: _pages,
                              itemCount: record.photos.length,
                              onPageChanged: (index) =>
                                  setState(() => _index = index),
                              itemBuilder: (context, index) => MomentPhotoView(
                                photo: record.photos[index],
                                label:
                                    '${momentDateLabel(record.recordDate)} 기록 사진 ${index + 1}',
                                aspectRatio: momentPhotoAspect(
                                  record.photos[index],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (record.photos.length > 1)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (
                              var index = 0;
                              index < record.photos.length;
                              index++
                            )
                              Container(
                                width: index == _index ? 14 : 5,
                                height: 5,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: index == _index
                                      ? SocialStyle.accent(context)
                                      : MomentVisualStyle.line(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            const Spacer(),
                            Text(
                              '${_index + 1} / ${record.photos.length}',
                              style: ExperienceFormStyle.text(
                                context,
                                11,
                                secondary: true,
                              ),
                            ),
                            IconButton(
                              tooltip: '이전 기록 사진',
                              onPressed: _index == 0
                                  ? null
                                  : () => _pages.previousPage(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                              icon: const ExperienceIcon('ChevronLeft', size: 20),
                            ),
                            IconButton(
                              tooltip: '다음 기록 사진',
                              onPressed: _index == record.photos.length - 1
                                  ? null
                                  : () => _pages.nextPage(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      curve: Curves.easeOut,
                                    ),
                              icon: const ExperienceIcon('ChevronRight', size: 20),
                            ),
                          ],
                        ),
                      if (record.caption.trim().isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          record.caption,
                          style: ExperienceFormStyle.text(
                            context,
                            15,
                          ).copyWith(height: 1.7),
                        ),
                      ],

                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (widget.onShare != null)
                            IconButton(
                              key: ValueKey('moment-share-${record.id}'),
                              tooltip: '${_index + 1}번째 사진 공유',
                              onPressed: () =>
                                  widget.onShare!(record.photos[_index]),
                              icon: const ExperienceIcon('Share2'),
                            ),
                          TextButton.icon(
                            key: ValueKey('moment-edit-${record.id}'),
                            onPressed: widget.onEdit,
                            icon: const ExperienceIcon('PenLine', size: 17),
                            label: const Text('기록 다듬기'),
                          ),
                        ],
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: MomentVisualStyle.line(context)),
        ],
      ),
    );
  }
}

/// Artwork owns its aspect. Older originals use a complete, uncropped photo in
/// the same default frame as a new album, without changing their saved data.
double momentPhotoAspect(MomentPhoto photo) =>
    photo.design?.aspectRatio ?? defaultCoverSize.ratio;
