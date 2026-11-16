import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/korean_text_preview.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../moments/domain/moment_record.dart';
import '../../../../moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'home_moment_photo.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// A small view of the already loaded personal month, without another request
/// or a document render. The date opens all of that day's actual records.
class HomeMomentArchiveShelf extends ConsumerWidget {
  const HomeMomentArchiveShelf({
    super.key,
    required this.onOpenDate,
    required this.onOpenMonth,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 8),
  });

  final ValueChanged<DateTime> onOpenDate, onOpenMonth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final state = ref.watch(momentEntryJournalProvider);
    final journal = !state.isLoading && !state.hasError
        ? state.asData?.value
        : null;
    if (journal == null) return const SizedBox.shrink();
    final entries = _archiveEntries(journal);
    if (entries.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final large = scaler.scale(14) / 14 > 1.5;
    final width = large ? 196.0 : 148.0;
    final photoHeight = width * (large ? .75 : .65);
    final captionLines = large ? 2 : 1;
    final height =
        photoHeight +
        12 +
        scaler.scale(11) * 1.4 +
        scaler.scale(13) * 1.4 * captionLines;
    return Padding(
      padding: padding,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          key: const ValueKey('home-moment-archive-section'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final title = Semantics(
                  header: true,
                  child: Text(
                    '모아둔 순간',
                    style: ExperienceFormStyle.text(
                      context,
                      20,
                      weight: FontWeight.w700,
                    ),
                  ),
                );
                final more = TextButton(
                  key: const ValueKey('home-moment-archive-month'),
                  onPressed: () => onOpenMonth(journal.month),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: ExperienceFormStyle.selectionInk(context),
                    textStyle: ExperienceFormStyle.text(
                      context,
                      12,
                      weight: FontWeight.w600,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${journal.month.month}월 전체'),
                      const SizedBox(width: 4),
                      const ExperienceIcon('ChevronRight', size: 16),
                    ],
                  ),
                );
                return large && box.maxWidth < 360
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, more],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          more,
                        ],
                      );
              },
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: height,
              child: ListView.separated(
                key: const ValueKey('home-moment-archive-scroll'),
                primary: false,
                scrollDirection: Axis.horizontal,
                cacheExtent: 80,
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) => _ArchiveTile(
                  key: ValueKey(
                    'home-moment-archive-${momentDateKey(entries[index].record.recordDate)}',
                  ),
                  entry: entries[index],
                  width: width,
                  photoHeight: photoHeight,
                  height: height,
                  captionLines: captionLines,
                  onOpen: () => onOpenDate(entries[index].record.recordDate),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveEntry {
  const _ArchiveEntry(
    this.record,
    this.photo, {
    this.anotherTodayPhoto = false,
  });
  final MomentRecord record;
  final MomentPhoto? photo;
  final bool anotherTodayPhoto;
}

List<_ArchiveEntry> _archiveEntries(MomentJournal journal) {
  final byDate = <DateTime, List<MomentRecord>>{};
  MomentRecord? today;
  for (final record in journal.records) {
    if (momentMonth(record.recordDate) != journal.month ||
        record.recordDate.isAfter(journal.today))
      continue;
    if (record.recordDate == journal.today) today ??= record;
    if (record.photos.isEmpty && record.caption.trim().isEmpty) continue;
    byDate.putIfAbsent(record.recordDate, () => []).add(record);
  }
  final dates = byDate.keys.where((date) => date != journal.today).toList()
    ..sort((a, b) => b.compareTo(a));
  if (dates.isNotEmpty) {
    return [
      for (final date in dates.take(4))
        (() {
          final records = byDate[date]!;
          final record =
              records.where((item) => item.photos.isNotEmpty).firstOrNull ??
              records.first;
          return _ArchiveEntry(record, record.photos.firstOrNull);
        })(),
    ];
  }
  // A lone first photograph already has the leading role above. Only show a
  // different actual photo today, never duplicate it or add an empty slot.
  final hero = today?.photos.firstOrNull;
  for (final record in byDate[journal.today] ?? const <MomentRecord>[]) {
    for (final photo in record.photos) {
      if (hero == null || (photo.id != hero.id && photo.path != hero.path)) {
        return [_ArchiveEntry(record, photo, anotherTodayPhoto: true)];
      }
    }
  }
  return const [];
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    super.key,
    required this.entry,
    required this.width,
    required this.photoHeight,
    required this.height,
    required this.captionLines,
    required this.onOpen,
  });
  final _ArchiveEntry entry;
  final double width, photoHeight, height;
  final int captionLines;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final date = entry.record.recordDate;
    final label = '${date.month}월 ${date.day}일';
    final caption = entry.record.caption.trim();
    final photo = entry.photo;
    final ink = ExperienceFormStyle.selectionInk(context);
    return Semantics(
      button: true,
      label: '$label 기록 보기${caption.isEmpty ? '' : ', $caption'}',
      onTap: onOpen,
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: width,
          height: height,
          child: photo == null
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ExperienceFormStyle.surface(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExperienceIcon('FileText', size: 22, color: ink),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Text(
                          keepShortKoreanWords(caption),
                          maxLines:
                              MediaQuery.textScalerOf(context).scale(14) / 14 >
                                  1.5
                              ? 3
                              : 2,
                          overflow: TextOverflow.ellipsis,
                          style: ExperienceFormStyle.text(
                            context,
                            15,
                            weight: FontWeight.w500,
                          ).copyWith(height: 1.4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        style: ExperienceFormStyle.text(
                          context,
                          11,
                          secondary: true,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeMomentPhoto(
                      photo: photo,
                      width: width,
                      height: photoHeight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.anotherTodayPhoto ? '$label · 다른 장면' : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        11,
                        color: ink,
                      ).copyWith(height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caption.isEmpty
                          ? '사진 ${entry.record.photos.length}장'
                          : keepShortKoreanWords(caption),
                      maxLines: captionLines,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        weight: FontWeight.w500,
                      ).copyWith(height: 1.4),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// An honest ending when there is nothing unfinished to resume.
class HomeNextStoryEntry extends StatelessWidget {
  const HomeNextStoryEntry({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('home-next-story-entry'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          keepShortKoreanWords('다음 이야기를 시작해요'),
          semanticsLabel: '다음 이야기를 시작해요',
          style: ExperienceFormStyle.text(context, 20, weight: FontWeight.w600),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '사진을 골라 나만의 한 권을 시작해보세요.',
        style: ExperienceFormStyle.text(
          context,
          12,
          secondary: true,
        ).copyWith(height: 1.5),
      ),
      TextButton(
        key: const ValueKey('home-next-story-create'),
        onPressed: onCreate,
        style: TextButton.styleFrom(
          foregroundColor: ExperienceFormStyle.selectionInk(context),
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(vertical: 8),
          textStyle: ExperienceFormStyle.text(
            context,
            12,
            weight: FontWeight.w600,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExperienceIcon('Plus', size: 17),
            SizedBox(width: 5),
            Text('새 앨범 시작하기'),
          ],
        ),
      ),
    ],
  );
}
