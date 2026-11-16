import 'package:flutter/material.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import 'moment_visual_style.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// The first journal entry is a dated photograph and a short note. Blank
/// placeholders explain that experience without inventing saved memories.
class MomentDailyJournalIntro extends StatelessWidget {
  const MomentDailyJournalIntro({
    super.key,
    required this.today,
    required this.onRecord,
  });

  final DateTime today;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide =
          bounds.maxWidth >= 660 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4;
      final introduction = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '사진 한 장 + 짧은 한 줄',
            key: const ValueKey('moments-daily-identity'),
            style: ExperienceFormStyle.text(
              context,
              12,
              weight: FontWeight.w600,
              color: SocialStyle.accent(context),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '하루씩 남기고,\n한 달을 꺼내보세요',
            style: ExperienceFormStyle.text(
              context,
              wide ? 30 : 25,
              weight: FontWeight.w600,
            ).copyWith(height: 1.35, letterSpacing: -.7),
          ),
          const SizedBox(height: 12),
          Text(
            '오늘의 사진과 메모가 날짜별로 쌓여요.\n모인 기록은 나중에 월간 앨범으로 엮어요.',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.7),
          ),
          if (wide) ...[
            const SizedBox(height: 26),
            _recordAction(context),
            const SizedBox(height: 24),
            const _JournalJourney(),
          ],
        ],
      );
      final preview = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: MomentDailyNotePreview(today: today, onRecord: onRecord),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: introduction),
                  const SizedBox(width: 40),
                  SizedBox(width: 300, child: preview),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  introduction,
                  const SizedBox(height: 20),
                  _recordAction(context),
                  const SizedBox(height: 24),
                  Center(child: preview),
                  const SizedBox(height: 18),
                  const _JournalJourney(),
                ],
              ),
      );
    },
  );

  Widget _recordAction(BuildContext context) => FilledButton.icon(
    key: const ValueKey('moments-first-photo'),
    onPressed: onRecord,
    style: SocialStyle.primary(context),
    icon: const ExperienceIcon('ImagePlus', size: 20),
    label: const Text('오늘의 한 장 남기기', textAlign: TextAlign.center),
  );
}

class MomentDailyNotePreview extends StatelessWidget {
  const MomentDailyNotePreview({super.key, required this.today, this.onRecord});

  final DateTime today;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final accent = SocialStyle.accent(context);
    return Container(
      key: const ValueKey('moments-daily-note-preview'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MomentVisualStyle.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                today.day.toString().padLeft(2, '0'),
                style: ExperienceFormStyle.text(
                  context,
                  34,
                  weight: FontWeight.w500,
                ).copyWith(letterSpacing: -1.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${today.year}년 ${today.month}월',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '오늘의 기록',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        weight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            button: onRecord != null,
            label: '오늘 사진과 한 줄 남기기',
            onTap: onRecord,
            excludeSemantics: true,
            child: Material(
              color: ExperienceFormStyle.selection(context),
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const ValueKey('moments-daily-photo-slot'),
                onTap: onRecord,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExperienceIcon('ImagePlus', size: 30, color: accent),
                      const SizedBox(height: 9),
                      Text(
                        '오늘 기억하고 싶은 사진',
                        textAlign: TextAlign.center,
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          color: ExperienceFormStyle.selectionInk(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExperienceIcon(
                'FileText',
                size: 18,
                color: ExperienceFormStyle.muted(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '사진 아래에, 이날의 기분 한 줄',
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    secondary: true,
                  ).copyWith(height: 1.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Divider(height: 1, color: MomentVisualStyle.line(context)),
          const SizedBox(height: 12),
          _WeekDates(today: today),
        ],
      ),
    );
  }
}

class _WeekDates extends StatelessWidget {
  const _WeekDates({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final week = momentWeekStart(today);
    return Semantics(
      label: '날짜별로 모이는 기록, 오늘 ${today.month}월 ${today.day}일',
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Row(
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        const ['월', '화', '수', '목', '금', '토', '일'][index],
                        style: ExperienceFormStyle.text(
                          context,
                          10,
                          secondary: true,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        constraints: const BoxConstraints(minWidth: 26),
                        decoration: BoxDecoration(
                          color: index == today.weekday - 1
                              ? SnapFitColors.actionAccent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${week.add(Duration(days: index)).day}',
                          textAlign: TextAlign.center,
                          style: ExperienceFormStyle.text(
                            context,
                            11,
                            weight: index == today.weekday - 1
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: index == today.weekday - 1
                                ? SnapFitColors.onAccent
                                : ExperienceFormStyle.muted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JournalJourney extends StatelessWidget {
  const _JournalJourney();

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 7,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final (index, label) in const [
        (0, '오늘 한 장'),
        (1, '날짜별 기록'),
        (2, '월간 앨범'),
      ]) ...[
        if (index > 0)
          ExperienceIcon(
            'ChevronRight',
            size: 15,
            color: ExperienceFormStyle.muted(context),
          ),
        Text(
          label,
          style: ExperienceFormStyle.text(
            context,
            11,
            secondary: true,
            weight: FontWeight.w500,
          ),
        ),
      ],
    ],
  );
}
