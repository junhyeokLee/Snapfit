import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/moment_record.dart';
import '../providers/moment_entry_refresh_provider.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// A daily photograph and a line of writing, with the calendar taking the place
/// of another album cover. Compact entries keep the actual album stage large.
class MomentsEntryCard extends ConsumerWidget {
  const MomentsEntryCard({
    super.key,
    required this.onTap,
    this.compact = false,
    this.inline = false,
  });
  final VoidCallback onTap;
  final bool compact, inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    MomentJournal? journal;
    try {
      final state = ref.watch(momentEntryJournalProvider);
      if (!state.isLoading && !state.hasError) journal = state.asData?.value;
    } catch (_) {
      // The entry is still useful when a personal SDK session is unavailable.
      // No previous account's photograph is retained as a placeholder.
    }
    final today = journal?.today;
    final records = journal?.records ?? const <MomentRecord>[];
    final todayRecord = records
        .where((record) => record.recordDate == today)
        .firstOrNull;
    final todayPhoto = todayRecord?.photos.firstOrNull;
    final photoCount = records.fold<int>(
      0,
      (count, record) => count + record.photos.length,
    );
    final days = records
        .where((record) => record.photos.isNotEmpty)
        .map((record) => record.recordDate)
        .toSet()
        .length;
    final accent = ExperienceFormStyle.selectionInk(context);
    final description = todayRecord != null
        ? '오늘 남긴 순간을 다시 펼쳐보세요.'
        : days > 0
        ? '${journal!.month.month}월에 $days일 · 사진 $photoCount장을 남겼어요.'
        : '사진 한 장과 한 줄로, 하루씩 쌓는 나의 기록';
    final semanticsLabel =
        '${today == null ? '' : '${today.month}월 ${today.day}일, '}오늘의 한 장, 나의 기록. $description';
    if (inline) {
      return Semantics(
        label: semanticsLabel,
        button: true,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('home-daily-record-inline'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Row(
                children: [
                  ExperienceIcon('Calendar', size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      todayRecord == null
                          ? '오늘의 한 장 · 하루씩 남기는 나의 기록'
                          : '오늘의 한 장 · 오늘 남긴 기록 보기',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: accent,
                      ).copyWith(height: 1.45),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ExperienceIcon('ArrowRight', size: 17, color: accent),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Material(
      key: const ValueKey('home-daily-record-card'),
      color: ExperienceFormStyle.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: ExperienceFormStyle.line(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        label: semanticsLabel,
        button: true,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('moments-entry'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 18),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: _DailyStamp(today: today, photo: todayPhoto),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '오늘의 한 장',
                        style: ExperienceFormStyle.text(
                          context,
                          compact ? 15 : 17,
                          weight: FontWeight.w600,
                        ).copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: ExperienceFormStyle.text(
                          context,
                          compact ? 11 : 13,
                          secondary: true,
                        ).copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                ExperienceIcon('ArrowRight', size: 18, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyStamp extends StatelessWidget {
  const _DailyStamp({required this.today, this.photo});
  final DateTime? today;
  final MomentPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final accent = SnapFitColors.actionAccent;
    final date = today == null
        ? const ExperienceIcon('ImagePlus', color: SnapFitColors.onAccent, size: 24)
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${today!.month}월',
                textScaler: TextScaler.noScaling,
                style: ExperienceFormStyle.text(
                  context,
                  10,
                  weight: FontWeight.w600,
                  color: SnapFitColors.onAccent,
                ),
              ),
              Text(
                '${today!.day}',
                textScaler: TextScaler.noScaling,
                style: ExperienceFormStyle.text(
                  context,
                  24,
                  weight: FontWeight.w600,
                  color: SnapFitColors.onAccent,
                ).copyWith(height: 1.05),
              ),
            ],
          );
    return SizedBox(
      key: const ValueKey('home-daily-record-date'),
      width: 48,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: photo == null
            ? ColoredBox(color: accent, child: date)
            : Stack(
                fit: StackFit.expand,
                children: [
                  SnapfitImage(
                    urlOrGs: photo!.url.isEmpty
                        ? photo!.storageUri
                        : photo!.url,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: .18),
                          Colors.black.withValues(alpha: .55),
                        ],
                      ),
                    ),
                  ),
                  date,
                ],
              ),
      ),
    );
  }
}
