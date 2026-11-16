import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/social_models.dart';
import 'social_widgets.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// A square cover for the month's public records, never a private album preview.
class SocialMomentMonthCover extends StatelessWidget {
  const SocialMomentMonthCover({
    super.key,
    required this.collection,
    required this.onOpen,
    required this.onRetry,
  });
  final SocialMomentMonth collection;
  final VoidCallback onOpen, onRetry;

  @override
  Widget build(BuildContext context) {
    final month = collection.month;
    final title = '${month.year}년 ${month.month}월의 기록';
    return Semantics(
      button: true,
      label: '$title, 공개 기록 ${collection.recordCount}개, 월간 기록 펼치기',
      onTap: onOpen,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('social-moment-month-${socialMomentMonthKey(month)}'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 7),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        left: 6,
                        top: 5,
                        right: -6,
                        bottom: -5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: SocialStyle.background(context),
                            border: Border.all(
                              color: SocialStyle.line(context),
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: SocialStyle.paper(context),
                            border: Border.all(
                              color: SocialStyle.line(context),
                            ),
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(3),
                              right: Radius.circular(10),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, bounds) {
                              final inset = bounds.maxWidth * .065;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: bounds.maxWidth * .024,
                                    child: ColoredBox(
                                      color: SocialStyle.accent(
                                        context,
                                      ).withValues(alpha: .22),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      inset,
                                      inset * .75,
                                      inset * .8,
                                      inset * .8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          '${month.year} / ${month.month.toString().padLeft(2, '0')}',
                                          style: ExperienceFormStyle.text(
                                            context,
                                            12,
                                            secondary: true,
                                          ).copyWith(letterSpacing: 1.2),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${month.month}월의 기록',
                                          maxLines: 1,
                                          style: ExperienceFormStyle.text(
                                            context,
                                            24,
                                            weight: FontWeight.w600,
                                          ).copyWith(letterSpacing: -.8),
                                        ),
                                        const SizedBox(height: 12),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            child:
                                                collection
                                                    .cover
                                                    .imageUrls
                                                    .isEmpty
                                                ? ExperienceIcon('Image', color: SocialStyle.accent(
                                                      context),
                                                    size: 32,
                                                  )
                                                : SocialWorkImage(
                                                    url: collection
                                                        .cover
                                                        .imageUrls
                                                        .first,
                                                    label: '$title 표지 사진',
                                                    fit: BoxFit.contain,
                                                    onRetry: onRetry,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: ExperienceFormStyle.text(
                        context,
                        17,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ExperienceIcon('ChevronRight', size: 18),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '공개 기록 ${collection.recordCount}개',
                style: ExperienceFormStyle.text(context, 13, secondary: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
