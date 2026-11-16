import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/korean_text_preview.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../moments/domain/moment_record.dart';
import '../../../../moments/presentation/providers/moment_entry_refresh_provider.dart';
import '../../../../moments/presentation/providers/moments_providers.dart';
import '../../../../moments/presentation/widgets/moments_widgets.dart';
import 'home_moment_week.dart';
import 'home_moment_photo.dart';

/// A photograph-led page of the private journal, using its shared server date,
/// auth isolation and midnight/resume refresh rather than another monthly read.
class HomeMomentSummaryCard extends ConsumerWidget {
  const HomeMomentSummaryCard({
    super.key,
    required this.onRecord,
    required this.onOpenMonth,
    required this.onOpenDate,
    required this.onSignIn,
    this.firstUseGuide,
    this.padding = const EdgeInsets.fromLTRB(24, 16, 24, 12),
  });

  final VoidCallback onRecord, onOpenMonth, onSignIn;
  final ValueChanged<DateTime> onOpenDate;
  final Widget? firstUseGuide;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!TickerMode.of(context)) return const SizedBox.shrink();
    final state = ref.watch(momentEntryJournalProvider);
    // Never retain the previous account's photograph while a read changes.
    final journal = !state.isLoading && !state.hasError
        ? state.asData?.value
        : null;
    return Padding(
      padding: padding,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final title = Semantics(
                  header: true,
                  child: Text(
                    journal == null ? '오늘의 기록' : '${journal.month.month}월의 기록',
                    style: ExperienceFormStyle.text(
                      context,
                      20,
                      weight: FontWeight.w700,
                    ),
                  ),
                );
                final open = TextButton(
                  key: const ValueKey('home-monthly-feed-open'),
                  onPressed: onOpenMonth,
                  style: TextButton.styleFrom(
                    foregroundColor: ExperienceFormStyle.selectionInk(context),
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: ExperienceFormStyle.text(
                      context,
                      12,
                      weight: FontWeight.w600,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('모아보기'),
                      SizedBox(width: 5),
                      Icon(Icons.chevron_right_rounded, size: 14),
                    ],
                  ),
                );
                if (MediaQuery.textScalerOf(context).scale(14) / 14 > 1.5 &&
                    box.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, open],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: title),
                    open,
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            // Do not consume the one-time guide during loading, errors or a guest visit.
            if (journal != null && firstUseGuide != null) firstUseGuide!,
            KeyedSubtree(
              key: const ValueKey('home-monthly-feed-summary'),
              child: journal != null
                  ? _JournalSummary(
                      journal: journal,
                      onRecord: onRecord,
                      onOpenDate: onOpenDate,
                    )
                  : _UnavailableSummary(
                      loading: state.isLoading && !state.hasError,
                      failed: state.hasError,
                      onOpen: onSignIn,
                      onRetry: () {
                        ref.invalidate(momentsMonthProvider);
                        ref.invalidate(momentEntryJournalProvider);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalSummary extends StatelessWidget {
  const _JournalSummary({
    required this.journal,
    required this.onRecord,
    required this.onOpenDate,
  });
  final MomentJournal journal;
  final VoidCallback onRecord;
  final ValueChanged<DateTime> onOpenDate;

  @override
  Widget build(BuildContext context) {
    // The journal's server date also anchors the seven visible days.
    final todayRecords = journal.records.where(
      (record) => momentDate(record.recordDate) == momentDate(journal.today),
    );
    // Prefer a saved photograph when several records belong to today.
    final todayRecord =
        todayRecords.where((record) => record.photos.isNotEmpty).firstOrNull ??
        todayRecords.firstOrNull;
    final todayPhoto = todayRecord?.photos.firstOrNull;
    // 특이하게 긴 지면도 홈의 세로 공간을 독점하지 않도록 함께 축소한다.
    final previewSize = todayPhoto == null
        ? null
        : applyBoxFit(
            BoxFit.contain,
            Size(momentPhotoAspect(todayPhoto), 1),
            const Size(104, 120),
          ).destination;
    final preview = todayPhoto == null
        ? null
        : HomeMomentPhoto(
            photo: todayPhoto,
            width: previewSize!.width,
            height: previewSize.height,
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeMomentWeek(
          journal: journal,
          onRecord: onRecord,
          onOpenDate: onOpenDate,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, bounds) {
            final thumbnail = preview != null
                ? Semantics(
                    label: '오늘 기록의 사진 보기',
                    button: true,
                    child: InkWell(
                      key: const ValueKey('home-monthly-feed-today-photo'),
                      onTap: () => onOpenDate(journal.today),
                      borderRadius: BorderRadius.circular(6),
                      child: ExcludeSemantics(child: preview),
                    ),
                  )
                : todayRecord == null
                ? _EmptyPhotoSlot(width: 96, height: 96, onTap: onRecord)
                : null;
            final copyWidth = bounds.maxWidth - (previewSize?.width ?? 96) - 16;
            // 큰 글씨를 사진 옆에 압축하지 않고 날짜와 기록 버튼의 읽을 폭을 확보한다.
            final stacked =
                thumbnail != null &&
                copyWidth < MediaQuery.textScalerOf(context).scale(144);
            final copy = _TodayCopy(
              journal: journal,
              record: todayRecord,
              onRecord: onRecord,
              fullWidth: stacked,
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: thumbnail),
                  const SizedBox(height: 12),
                  copy,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumbnail != null) ...[
                  thumbnail,
                  const SizedBox(width: 16),
                ],
                Expanded(child: copy),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TodayCopy extends StatelessWidget {
  const _TodayCopy({
    required this.journal,
    required this.record,
    required this.onRecord,
    this.fullWidth = false,
  });
  final MomentJournal journal;
  final MomentRecord? record;
  final VoidCallback onRecord;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final caption = record?.caption.trim() ?? '';
    final preview = record == null
        ? '사진 한 장과 한 줄이면 충분해요.'
        : caption.isNotEmpty
        ? caption
        : '사진 ${record!.photos.length}장으로 기억한 하루예요.';
    final accent = ExperienceFormStyle.selectionInk(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: fullWidth
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Text(
          '${journal.today.month}월 ${journal.today.day}일 ${_weekdays[journal.today.weekday - 1]}요일',
          key: const ValueKey('home-monthly-feed-date'),
          style: ExperienceFormStyle.text(
            context,
            12,
            color: accent,
            weight: FontWeight.w600,
          ).copyWith(height: 1.3),
        ),
        const SizedBox(height: 5),
        Semantics(
          key: const ValueKey('home-monthly-feed-today-status'),
          label: record == null ? '오늘의 한 장을 남겨볼까요?' : '오늘의 순간을 남겼어요',
          excludeSemantics: true,
          child: Text(
            record == null ? '오늘의 한 장을 남겨볼까요?' : '기록 완료',
            style: ExperienceFormStyle.text(
              context,
              record == null ? 17 : 11,
              weight: record == null ? FontWeight.w600 : FontWeight.w400,
              secondary: record != null,
            ).copyWith(height: 1.3),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          caption.isEmpty ? preview : keepShortKoreanWords(preview),
          semanticsLabel: preview,
          key: const ValueKey('home-monthly-feed-today-preview'),
          maxLines: MediaQuery.textScalerOf(context).scale(14) / 14 > 1.5
              ? 3
              : 2,
          overflow: TextOverflow.ellipsis,
          style: ExperienceFormStyle.text(
            context,
            record == null ? 12 : 16,
            weight: record == null ? FontWeight.w400 : FontWeight.w500,
            secondary: record == null,
          ).copyWith(height: 1.4),
        ),
        const SizedBox(height: 2),
        TextButton(
          key: const ValueKey('home-monthly-feed-record'),
          onPressed: onRecord,
          style: TextButton.styleFrom(
            foregroundColor: accent,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            textStyle: ExperienceFormStyle.text(
              context,
              12,
              weight: FontWeight.w600,
            ),
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 17),
              const SizedBox(width: 5),
              Flexible(child: Text(record == null ? '오늘 기록하기' : '오늘 한 장 더')),
            ],
          ),
        ),
      ],
    );
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({
    required this.width,
    required this.height,
    required this.onTap,
  });
  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = ExperienceFormStyle.selectionInk(context);
    return Semantics(
      label: '오늘 사진 추가하기',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: ExperienceFormStyle.selection(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 26, color: accent),
              const SizedBox(height: 6),
              Text(
                '사진 추가',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableSummary extends StatelessWidget {
  const _UnavailableSummary({
    required this.loading,
    required this.failed,
    required this.onOpen,
    required this.onRetry,
  });
  final bool loading, failed;
  final VoidCallback onOpen, onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        loading
            ? '이번 달의 기록을 불러오고 있어요'
            : failed
            ? '기록을 불러오지 못했어요'
            : '매일의 순간을 나만의 피드로',
        style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w500),
      ),
      const SizedBox(height: 6),
      Text(
        loading
            ? '오늘의 사진을 확인할게요.'
            : failed
            ? '잠시 뒤 다시 확인해 주세요.'
            : '로그인하면 사진과 한 줄로 하루씩 남길 수 있어요.',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
      if (!loading)
        TextButton(
          key: const ValueKey('home-monthly-feed-recover'),
          onPressed: failed ? onRetry : onOpen,
          style: TextButton.styleFrom(
            foregroundColor: ExperienceFormStyle.selectionInk(context),
            minimumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
          ),
          child: Text(failed ? '기록 다시 불러오기' : '로그인하고 시작하기'),
        ),
    ],
  );
}
