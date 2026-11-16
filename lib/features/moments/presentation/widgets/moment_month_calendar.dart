import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import 'moment_visual_style.dart';
import 'moments_widgets.dart';

/// 나의 기록에서 월 전체를 펼쳐 보여 주며 작은 이미지만 디코딩한다.
class MomentMonthCalendar extends StatelessWidget {
  const MomentMonthCalendar({
    super.key,
    required this.month,
    required this.records,
    required this.onDateSelected,
    this.selectedDate,
    this.today,
    this.compact = false,
  });

  final DateTime month;
  final List<MomentRecord> records;
  final DateTime? selectedDate;
  final DateTime? today;
  final bool compact;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final first = momentMonth(month);
    final days = DateTime.utc(first.year, first.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final currentDate = today == null ? null : momentDate(today!);
    final byDay = <int, List<MomentPhoto>>{};
    for (final record in records) {
      if (momentMonth(record.recordDate) != first) continue;
      byDay.putIfAbsent(record.recordDate.day, () => []).addAll(record.photos);
    }
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      key: const ValueKey('moments-photo-calendar'),
      margin: compact
          ? EdgeInsets.zero
          : const EdgeInsets.only(top: 12, bottom: 16),
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(12),
      decoration: compact
          ? null
          : BoxDecoration(
              color: MomentVisualStyle.paper(context),
              border: Border.all(color: MomentVisualStyle.line(context)),
              borderRadius: BorderRadius.circular(18),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final weekday in const ['월', '화', '수', '목', '금', '토', '일'])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: ExperienceFormStyle.text(
                        context,
                        10,
                        secondary: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leading + days,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: compact ? 4 : 6,
              mainAxisExtent: scale > 1.4
                  ? 68
                  : compact
                  ? 44
                  : 52,
            ),
            itemBuilder: (context, index) {
              final day = index - leading + 1;
              if (day < 1) return const SizedBox.shrink();
              final date = DateTime.utc(first.year, first.month, day);
              final future = currentDate != null && date.isAfter(currentDate);
              final current = date == currentDate;
              final photos = future
                  ? const <MomentPhoto>[]
                  : byDay[day] ?? const <MomentPhoto>[];
              final selected =
                  selectedDate != null && momentDate(selectedDate!) == date;
              final photo = photos.firstOrNull;
              final missed =
                  currentDate != null &&
                  date.isBefore(currentDate) &&
                  photo == null;
              final canOpen = !future && (photo != null || current);
              final accent = ExperienceFormStyle.selectionInk(context);
              return Semantics(
                button: canOpen,
                enabled: canOpen,
                selected: selected,
                excludeSemantics: true,
                onTap: canOpen ? () => onDateSelected(date) : null,
                label:
                    '${first.year}년 ${first.month}월 $day일, 사진 ${photos.length}장'
                    '${current ? ', 오늘' : ''}${future
                        ? ', 아직 오지 않은 날'
                        : missed
                        ? ', 사진 추가 마감'
                        : ''}',
                child: Material(
                  color: current && photo == null
                      ? ExperienceFormStyle.selection(context)
                      : compact && missed
                      ? ExperienceFormStyle.line(context).withValues(alpha: .35)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('moments-calendar-${momentDateKey(date)}'),
                    onTap: canOpen ? () => onDateSelected(date) : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (photo != null)
                          MomentPhotoView(
                            key: ValueKey(photo.storageUri),
                            photo: photo,
                            imageDecodeWidth: 112,
                            placeholder: const SizedBox.shrink(),
                            error: const SizedBox.shrink(),
                          ),
                        if (photo != null)
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.black12, Colors.black54],
                              ),
                            ),
                          ),
                        if (missed && !compact && !selected)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: ExperienceFormStyle.line(
                                  context,
                                ).withValues(alpha: .5),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        if (selected)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SocialStyle.accent(context),
                                width: compact ? 2 : 3,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        Align(
                          alignment: photo == null
                              ? Alignment.center
                              : Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ExcludeSemantics(
                              child: Text(
                                '$day',
                                style: ExperienceFormStyle.text(
                                  context,
                                  11,
                                  color: current && photo == null
                                      ? accent
                                      : photo == null
                                      ? ExperienceFormStyle.muted(context)
                                      : Colors.white,
                                  weight: photo == null
                                      ? FontWeight.w400
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (compact && (photo != null || missed || current))
                          Positioned(
                            top: 3,
                            right: 3,
                            child: Icon(
                              photo != null
                                  ? Icons.check_rounded
                                  : missed
                                  ? Icons.lock_outline_rounded
                                  : Icons.add_rounded,
                              size: 11,
                              color: photo != null
                                  ? Colors.white
                                  : missed
                                  ? ExperienceFormStyle.muted(context)
                                  : accent,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
