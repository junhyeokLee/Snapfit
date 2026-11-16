import 'package:flutter/material.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../views/attendance_screen.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';

/// A private entry point only; opening a profile never performs a check-in.
class AttendanceEntryCard extends StatelessWidget {
  const AttendanceEntryCard({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: ExperienceFormStyle.selection(context),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const ValueKey('attendance-entry'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).push<void>(
        snapFitRoute<void>(
          page: const AttendanceScreen(),
          settings: const WebAppRouteSettings(WebAppLocation.attendance),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              color: ExperienceFormStyle.selectionInk(context),
              size: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '출석체크 · 무료 포인트',
                    style: ExperienceFormStyle.text(
                      context,
                      15,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '오늘의 도장을 남기고 포인트를 모아보세요.',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ExperienceIcon(
              'ChevronRight',
              color: ExperienceFormStyle.selectionInk(context),
            ),
          ],
        ),
      ),
    ),
  );
}
