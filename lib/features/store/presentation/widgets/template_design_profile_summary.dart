import 'package:flutter/material.dart';

import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/template_design_profile.dart';

/// Verified facts from the edition being viewed, without purchase assumptions.
class TemplateDesignProfileSummary extends StatelessWidget {
  const TemplateDesignProfileSummary({
    super.key,
    required this.profile,
    this.heading = '디자인 구성',
  });

  final TemplateDesignProfile profile;
  final String heading;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: ExperienceFormStyle.surface(context),
        border: Border.all(color: ExperienceFormStyle.line(context)),
        borderRadius: BorderRadius.circular(SnapFitRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SnapFitSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heading,
              style: ExperienceFormStyle.text(
                context,
                12,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SnapFitSpace.xs),
            Text(
              profile.hasKnownDocument
                  ? '${profile.pageLabel} · 사진 넣는 ${profile.photoSlotCount}곳'
                  : profile.briefLabel,
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ).copyWith(height: 1.5),
            ),
            const SizedBox(height: SnapFitSpace.xs),
            Text(
              profile.hasKnownDocument
                  ? '글쓰기 ${profile.recordPageCount}쪽 · 본문이 있는 내지 기준'
                  : profile.compositionLabel,
              style: ExperienceFormStyle.text(
                context,
                12,
                secondary: true,
              ).copyWith(height: 1.5),
            ),
            if (profile.hasKnownDocument)
              Text(
                '사진 칸은 표지 포함 · 같은 사진을 여러 번 쓸 수 있어요.',
                style: ExperienceFormStyle.text(
                  context,
                  12,
                  secondary: true,
                ).copyWith(height: 1.5),
              ),
          ],
        ),
      ),
    ),
  );
}
