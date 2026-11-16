import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/moment_record.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// 화면에서 선택한 월의 기록과 저장된 앨범을 같은 경로로 연다.
class MomentMonthlyAlbumEntry extends StatelessWidget {
  const MomentMonthlyAlbumEntry({
    super.key,
    required this.journal,
    required this.onPreview,
  });

  final MomentJournal journal;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final hasPhotos = journal.records.any(
      (record) =>
          momentMonth(record.recordDate) == journal.month &&
          !record.recordDate.isAfter(journal.today) &&
          record.photos.isNotEmpty,
    );
    if (!hasPhotos && journal.monthlyAlbumId == null)
      return const SizedBox.shrink();

    final accent = ExperienceFormStyle.selectionInk(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: ExperienceFormStyle.line(context)),
          ),
        ),
        child: InkWell(
          key: const ValueKey('home-monthly-album-entry'),
          onTap: onPreview,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExperienceIcon('BookOpen', color: accent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '모은 순간을 한 권의 앨범으로',
                        style: ExperienceFormStyle.text(
                          context,
                          15,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        journal.monthlyAlbumId != null
                            ? '${journal.month.month}월의 앨범을 이어서 살펴보세요.'
                            : '사진을 골라 ${journal.month.month}월의 앨범으로 엮어보세요.',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                    ],
                  ),
                ),
                ExperienceIcon('ChevronRight', color: accent, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
