import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/attendance_status.dart';
import '../../../../shared/widgets/experience_icon.dart';

String attendancePoints(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class AttendanceTodayCard extends StatelessWidget {
  const AttendanceTodayCard({
    super.key,
    required this.status,
    required this.busy,
    required this.checkingDate,
    required this.onCheckIn,
  });

  final AttendanceStatus status;
  final bool busy, checkingDate;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) => _AttendancePaper(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${status.serverDate.month}월 ${status.serverDate.day}일의 기록',
                style: ExperienceFormStyle.text(context, 14, secondary: true),
              ),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: ExperienceIcon('BookOpen', color: SocialStyle.accent(context),
                size: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            label: status.checkedInToday ? '오늘 출석 도장 완료' : '오늘의 출석 도장',
            child: ExcludeSemantics(
              child: Container(
                width: 102,
                height: 102,
                decoration: BoxDecoration(
                  color: status.checkedInToday
                      ? SocialStyle.accent(context).withValues(alpha: .12)
                      : SocialStyle.background(context),
                  border: Border.all(
                    color: SocialStyle.accent(context).withValues(alpha: .45),
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Center(
                  child: status.checkedInToday
                      ? ExperienceIcon('Check', size: 50, color: SocialStyle.accent(context),
                        )
                      : Text(
                          '${status.serverDate.day}',
                          textScaler: TextScaler.noScaling,
                          style: ExperienceFormStyle.text(
                            context,
                            42,
                            weight: FontWeight.w600,
                            color: SocialStyle.accent(context),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          status.checkedInToday ? '오늘의 도장을 찍었어요' : '오늘도, 한 칸의 기록',
          style: ExperienceFormStyle.text(
            context,
            25,
            weight: FontWeight.w600,
          ).copyWith(height: 1.35, letterSpacing: -.5),
        ),
        const SizedBox(height: 10),
        Text(
          status.checkedInToday
              ? '내일도 들러 새로운 기록을 이어가세요.'
              : '출석하고 ${attendancePoints(status.todayReward)}P를 받아요.',
          style: ExperienceFormStyle.text(
            context,
            15,
            secondary: true,
          ).copyWith(height: 1.65),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const ValueKey('attendance-check-in'),
          style: SocialStyle.primary(context).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
            textStyle: WidgetStatePropertyAll(
              ExperienceFormStyle.text(context, 15, weight: FontWeight.w600),
            ),
          ),
          onPressed: busy || checkingDate || status.checkedInToday
              ? null
              : onCheckIn,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              busy
                  ? '출석 확인 중…'
                  : checkingDate
                  ? '오늘의 출석 확인 중…'
                  : status.checkedInToday
                  ? '오늘 출석 완료'
                  : '출석하고 ${attendancePoints(status.todayReward)}P 받기',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '한국 시간 오전 0시에 새 도장을 찍을 수 있어요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
      ],
    ),
  );
}

class AttendanceRewardStrip extends StatelessWidget {
  const AttendanceRewardStrip({super.key, required this.status});
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final total = status.weeklyRewards.fold<int>(
      0,
      (sum, points) => sum + points,
    );
    return _AttendancePaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '차곡차곡 이어가는 출석',
            style: ExperienceFormStyle.text(
              context,
              21,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '7일의 기록을 채우면 총 ${attendancePoints(total)}P',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.65),
          ),
          const SizedBox(height: 18),
          Text(
            status.currentStreak == 0
                ? '첫 번째 기록을 시작해 보세요.'
                : '${status.currentStreak}일째 이어가는 중',
            style: ExperienceFormStyle.text(
              context,
              14,
              weight: FontWeight.w600,
              color: SocialStyle.accent(context),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, bounds) {
              final large = MediaQuery.textScalerOf(context).scale(12) > 18;
              final minimum = large ? 88.0 : 58.0;
              final columns = bounds.maxWidth >= minimum * 7 + 48
                  ? 7
                  : bounds.maxWidth >= minimum * 4 + 24
                  ? 4
                  : bounds.maxWidth >= minimum * 3 + 16
                  ? 3
                  : 2;
              final width = (bounds.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final reward in status.weeklyRewards.indexed)
                    SizedBox(
                      width: width,
                      child: _RewardStamp(
                        day: reward.$1 + 1,
                        points: reward.$2,
                        complete: reward.$1 < status.completedCycleDays,
                        today: reward.$1 + 1 == status.cycleDay,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            '연속 출석이 끊기면 1일차부터 다시 시작해요. 7일을 채운 다음 날에는 새 도장판이 열려요.',
            style: ExperienceFormStyle.text(
              context,
              12,
              secondary: true,
            ).copyWith(height: 1.65),
          ),
        ],
      ),
    );
  }
}

class _RewardStamp extends StatelessWidget {
  const _RewardStamp({
    required this.day,
    required this.points,
    required this.complete,
    required this.today,
  });
  final int day, points;
  final bool complete, today;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '$day일차, $points포인트, ${complete
            ? '출석 완료'
            : today
            ? '오늘 받을 보상'
            : '출석 예정'}',
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
        decoration: BoxDecoration(
          color: complete
              ? SocialStyle.accent(context).withValues(alpha: .12)
              : SocialStyle.background(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: today
                ? SocialStyle.accent(context)
                : SocialStyle.line(context),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$day일차',
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 12, secondary: true),
            ),
            const SizedBox(height: 10),
            Icon(
              complete
                  ? Icons.check_circle_outline_rounded
                  : today
                  ? Icons.radio_button_unchecked
                  : Icons.circle_outlined,
              size: 25,
              color: complete || today
                  ? SocialStyle.accent(context)
                  : ExperienceFormStyle.muted(context).withValues(alpha: .55),
            ),
            const SizedBox(height: 9),
            Text(
              '${points}P',
              style: ExperienceFormStyle.text(
                context,
                15,
                weight: FontWeight.w600,
                color: complete || today ? SocialStyle.accent(context) : null,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AttendanceCalendarCard extends StatelessWidget {
  const AttendanceCalendarCard({super.key, required this.status});
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final month =
        DateTime.tryParse('${status.month}-01') ??
        DateTime(status.serverDate.year, status.serverDate.month);
    final first = DateTime(month.year, month.month);
    final length = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final rows = ((leading + length) / 7).ceil();
    final checked = <int, AttendanceRecord>{
      for (final record in status.history)
        if (record.date.year == month.year && record.date.month == month.month)
          record.date.day: record,
    };
    final large = MediaQuery.textScalerOf(context).scale(12) > 18;
    return _AttendancePaper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${month.year}년 ${month.month}월의 기록',
            style: ExperienceFormStyle.text(
              context,
              21,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text(
                '이번 달 ${status.monthAttendanceCount}일 출석',
                style: ExperienceFormStyle.text(context, 14, secondary: true),
              ),
              Text(
                '+${attendancePoints(status.monthPoints)}P 모았어요',
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                  color: SocialStyle.accent(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              for (final day in ['월', '화', '수', '목', '금', '토', '일'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (var row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final day = row * 7 + column - leading + 1;
                            if (day < 1 || day > length)
                              return SizedBox(height: large ? 70 : 56);
                            final date = DateTime(month.year, month.month, day);
                            final record = checked[day];
                            final today =
                                date.year == status.serverDate.year &&
                                date.month == status.serverDate.month &&
                                day == status.serverDate.day;
                            final future = date.isAfter(
                              DateTime(
                                status.serverDate.year,
                                status.serverDate.month,
                                status.serverDate.day,
                              ),
                            );
                            return Semantics(
                              container: true,
                              label:
                                  '${month.month}월 $day일${today ? ', 오늘' : ''}, ${record != null
                                      ? '출석 완료, ${record.points}포인트'
                                      : future
                                      ? '출석 예정'
                                      : '출석 기록 없음'}',
                              child: ExcludeSemantics(
                                child: Container(
                                  constraints: BoxConstraints(
                                    minHeight: large ? 70 : 56,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: record == null
                                        ? Colors.transparent
                                        : SocialStyle.accent(
                                            context,
                                          ).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: today
                                        ? Border.all(
                                            color: SocialStyle.accent(context),
                                          )
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$day',
                                        style: ExperienceFormStyle.text(
                                          context,
                                          12,
                                          weight: today || record != null
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: future
                                              ? ExperienceFormStyle.muted(
                                                  context,
                                                )
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Icon(
                                        record == null
                                            ? Icons.circle
                                            : Icons.check_rounded,
                                        size: record == null ? 4 : 13,
                                        color: record == null
                                            ? (today
                                                  ? SocialStyle.accent(context)
                                                  : Colors.transparent)
                                            : SocialStyle.accent(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '이번 달 출석 기록을 보여드려요.',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
        ],
      ),
    );
  }
}

class _AttendancePaper extends StatelessWidget {
  const _AttendancePaper({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SocialStyle.paper(context),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: SocialStyle.line(context)),
    ),
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
}
