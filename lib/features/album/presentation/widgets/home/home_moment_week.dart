import 'package:flutter/material.dart';

import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../moments/domain/moment_record.dart';

/// 홈에는 서버의 오늘이 속한 한 주만 남기고 월 전체는 모아보기에서 보여 준다.
class HomeMomentWeek extends StatelessWidget {
  const HomeMomentWeek({
    super.key,
    required this.journal,
    required this.onRecord,
    required this.onOpenDate,
  });

  final MomentJournal journal;
  final VoidCallback onRecord;
  final ValueChanged<DateTime> onOpenDate;

  @override
  Widget build(BuildContext context) {
    final today = momentDate(journal.today);
    final week = momentWeekStart(today);
    final recordedDays = {
      for (final record in journal.records)
        if (record.photos.isNotEmpty) momentDate(record.recordDate),
    };
    final accent = ExperienceFormStyle.selectionInk(context);
    return Row(
      key: const ValueKey('home-monthly-feed-week'),
      children: [
        for (var index = 0; index < 7; index++)
          Expanded(
            child: Builder(
              builder: (context) {
                final date = week.add(Duration(days: index));
                final current = date == today;
                final recorded = recordedDays.contains(date);
                final future = date.isAfter(today);
                // 이전 달은 이번 달 응답에 없으므로 미기록이라고 단정하지 않는다.
                final outsideMonth = momentMonth(date) != journal.month;
                final canOpen =
                    !future && (current || recorded || outsideMonth);
                void open() =>
                    current && !recorded ? onRecord() : onOpenDate(date);
                return Semantics(
                  label:
                      '${date.month}월 ${date.day}일'
                      '${current ? ', 오늘' : ''}'
                      '${recorded
                          ? ', 기록 있음'
                          : future
                          ? ', 아직 오지 않은 날'
                          : !current && !outsideMonth
                          ? ', 사진 추가 마감'
                          : ''}',
                  button: canOpen,
                  enabled: canOpen,
                  selected: current,
                  excludeSemantics: true,
                  onTap: canOpen ? open : null,
                  child: InkWell(
                    key: ValueKey('home-week-day-${momentDateKey(date)}'),
                    onTap: canOpen ? open : null,
                    borderRadius: BorderRadius.circular(9),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            const ['월', '화', '수', '목', '금', '토', '일'][index],
                            style: ExperienceFormStyle.text(
                              context,
                              10,
                              secondary: true,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: recorded
                                  ? accent
                                  : current
                                  ? ExperienceFormStyle.selection(context)
                                  : future
                                  ? ExperienceFormStyle.surface(context)
                                  : ExperienceFormStyle.surface(context),
                              border: current && !recorded
                                  ? Border.all(color: accent, width: 1.5)
                                  : null,
                            ),
                            child: Text(
                              '${date.day}',
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                color: recorded
                                    ? SnapFitColors.onAccent
                                    : current
                                    ? accent
                                    : future
                                    ? ExperienceFormStyle.muted(context)
                                        .withValues(alpha: 0.4)
                                    : ExperienceFormStyle.muted(context),
                                weight: recorded || current
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
