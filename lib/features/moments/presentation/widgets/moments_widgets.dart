import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../../domain/monthly_album_builder.dart';
import 'moment_book_cover.dart';
import 'moment_visual_style.dart';

String momentDateLabel(DateTime date) => '${date.month}월 ${date.day}일';

class MomentPhotoView extends StatelessWidget {
  const MomentPhotoView({
    super.key,
    this.photo,
    this.bytes,
    this.aspectRatio = 4 / 5,
    this.label = '나의 기록 사진',
    this.fit = BoxFit.contain,
    this.useIntrinsicSize = false,
    this.backgroundColor,
  });

  final MomentPhoto? photo;
  final Uint8List? bytes;
  final double aspectRatio;
  final String label;
  final BoxFit fit;
  final Color? backgroundColor;

  /// Local photos already have a decoded intrinsic size. Let that determine
  /// their height instead of adding a portrait-sized canvas around landscape
  /// photos. Bounds keep extreme panoramas/tall photos usable without cropping.
  final bool useIntrinsicSize;

  @override
  Widget build(BuildContext context) {
    Widget error(BuildContext context, Object error, StackTrace? stack) =>
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
              width: useIntrinsicSize ? double.infinity : null,
              fit: fit,
              gaplessPlayback: true,
              semanticLabel: label,
              errorBuilder: error,
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
                memCacheWidth: 1200,
                error: error(context, StateError('unavailable'), null),
                placeholder: Center(
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
    if (useIntrinsicSize && bytes != null) {
      return LayoutBuilder(
        builder: (context, constraints) => ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxWidth / 1.8,
            maxHeight: constraints.maxWidth / .7,
          ),
          child: content,
        ),
      );
    }
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
      Icon(
        Icons.lock_outline_rounded,
        size: 16,
        color: SocialStyle.accent(context),
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

/// A small, optional goal keeps the photographs at the top of the journal.
class MomentWeekCard extends StatelessWidget {
  const MomentWeekCard({
    super.key,
    required this.photoCount,
    required this.onRecord,
    this.onRecap,
  });
  final int photoCount;
  final VoidCallback onRecord;
  final VoidCallback? onRecap;

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
              '오늘, 남겨둘 한 장',
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            Semantics(
              label: '이번 주 기록 사진 $photoCount장, 권장 목표 3장',
              child: ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '이번 주 사진 $photoCount장',
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (var index = 0; index < 3; index++)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: index < photoCount
                              ? SocialStyle.accent(context)
                              : MomentVisualStyle.line(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
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
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('사진 남기기'),
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

/// A book-shaped preview explains the result without showing a fake user photo.
class MomentEmptyBook extends StatelessWidget {
  const MomentEmptyBook({
    super.key,
    required this.month,
    required this.onRecord,
  });
  final DateTime month;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 560 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4;
      final introduction = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 한 장이,\n내 앨범의 시작',
            style: ExperienceFormStyle.text(
              context,
              26,
              weight: FontWeight.w600,
            ).copyWith(height: 1.4, letterSpacing: -.8),
          ),
          const SizedBox(height: 12),
          Text(
            '사진 한 장과 짧은 이야기를 남겨보세요.\n모아둔 순간은 한 달의 앨범으로 만들 수 있어요.',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.8),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            key: const ValueKey('moments-first-photo'),
            onPressed: onRecord,
            style: SocialStyle.primary(context),
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: const Text('첫 사진 남기기'),
          ),
        ],
      );
      final book = Column(
        children: [
          SizedBox(
            key: const ValueKey('moments-empty-book'),
            width: wide ? 224 : bounds.maxWidth.clamp(0, 236).toDouble(),
            child: MomentBookCover(month: month),
          ),
          const SizedBox(height: 18),
          Text(
            '앨범 구성 예시',
            style: ExperienceFormStyle.text(context, 11, secondary: true),
          ),
          const SizedBox(height: 5),
          Text(
            monthlyMomentAlbumCoverSize.displayName,
            style: ExperienceFormStyle.text(context, 11, secondary: true),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: introduction),
                  const SizedBox(width: 32),
                  book,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  introduction,
                  const SizedBox(height: 36),
                  Center(child: book),
                ],
              ),
      );
    },
  );
}

class MomentRecordCard extends StatefulWidget {
  const MomentRecordCard({
    super.key,
    required this.record,
    required this.onEdit,
    this.maxPhotoHeight,
  });
  final MomentRecord record;
  final VoidCallback onEdit;
  final double? maxPhotoHeight;

  @override
  State<MomentRecordCard> createState() => _MomentRecordCardState();
}

class _MomentRecordCardState extends State<MomentRecordCard> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant MomentRecordCard oldWidget) {
    super.didUpdateWidget(oldWidget);
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

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    if (record.photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      const [
                        '월요일',
                        '화요일',
                        '수요일',
                        '목요일',
                        '금요일',
                        '토요일',
                        '일요일',
                      ][record.recordDate.weekday - 1],
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        secondary: true,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('moment-edit-${record.id}'),
                tooltip: '${momentDateLabel(record.recordDate)} 기록 수정',
                onPressed: widget.onEdit,
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: LayoutBuilder(
              builder: (context, bounds) => AspectRatio(
                key: ValueKey('moment-photo-frame-${record.id}'),
                aspectRatio: widget.maxPhotoHeight == null
                    ? momentPhotoAspect(record.photos[_index])
                    : (bounds.maxWidth / widget.maxPhotoHeight!).clamp(
                        momentPhotoAspect(record.photos[_index]),
                        double.infinity,
                      ),
                child: PageView.builder(
                  key: ValueKey('moment-photos-${record.id}'),
                  controller: _pages,
                  itemCount: record.photos.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) => MomentPhotoView(
                    photo: record.photos[index],
                    label:
                        '${momentDateLabel(record.recordDate)} 기록 사진 ${index + 1}',
                    aspectRatio: momentPhotoAspect(record.photos[index]),
                  ),
                ),
              ),
            ),
          ),
          if (record.photos.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (var index = 0; index < record.photos.length; index++)
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
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
                IconButton(
                  tooltip: '이전 기록 사진',
                  onPressed: _index == 0
                      ? null
                      : () => _pages.previousPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
                IconButton(
                  tooltip: '다음 기록 사진',
                  onPressed: _index == record.photos.length - 1
                      ? null
                      : () => _pages.nextPage(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                        ),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
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
          const SizedBox(height: 22),
          Divider(height: 1, color: MomentVisualStyle.line(context)),
        ],
      ),
    );
  }
}

/// Preserve landscape and portrait photographs within usable journal bounds.
double momentPhotoAspect(MomentPhoto photo) {
  if (photo.width <= 0 || photo.height <= 0) return 4 / 5;
  return (photo.width / photo.height).clamp(.7, 1.8);
}
