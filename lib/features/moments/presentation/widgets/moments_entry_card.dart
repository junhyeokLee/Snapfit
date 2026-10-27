import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../social/presentation/widgets/social_widgets.dart';
import '../../domain/moment_record.dart';
import '../providers/moments_providers.dart';
import 'moment_book_cover.dart';
import 'moment_visual_style.dart';

class MomentsEntryCard extends ConsumerWidget {
  const MomentsEntryCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The shared family provider deduplicates home/profile reads. Guests and
    // unavailable sessions keep a useful entry without fetching private data.
    final actor = ref.watch(momentsSessionProvider).asData?.value;
    final journal = actor == null
        ? null
        : ref
              .watch(momentsMonthProvider(momentMonth(momentToday())))
              .asData
              ?.value;
    final photo = journal?.records
        .expand((record) => record.photos)
        .firstOrNull;
    final count =
        journal?.records.fold<int>(
          0,
          (sum, record) => sum + record.photos.length,
        ) ??
        0;
    return Material(
      color: MomentVisualStyle.paper(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const ValueKey('moments-entry'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                child: MomentBookCover(
                  month: journal?.month ?? momentMonth(momentToday()),
                  photo: photo,
                  label: '나의 기록으로 만드는 정사각형 앨범',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '나의 기록',
                      style: ExperienceFormStyle.text(
                        context,
                        17,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      count == 0
                          ? '한 장씩 모아, 한 달의 앨범으로.'
                          : '${journal!.month.month}월의 사진 $count장 · 내 한 달의 책이 자라고 있어요.',
                      style: ExperienceFormStyle.text(
                        context,
                        13,
                        secondary: true,
                      ).copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: SocialStyle.accent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
