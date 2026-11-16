import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../onboarding/presentation/widgets/story_album_artwork.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.onCreate,
    this.scrollController,
    this.leadingContent,
    this.footer,
  });
  final VoidCallback onCreate;
  final ScrollController? scrollController;
  final Widget? leadingContent;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      const preview = _FirstAlbumPreview();
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            '아직 만든 앨범이 없어요',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: ExperienceFormStyle.text(
              context,
              22,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '사진을 골라 나만의 앨범을 만들어보세요',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: ExperienceFormStyle.text(context, 14, secondary: true),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('empty-home-create'),
            onPressed: onCreate,
            style: ExperienceFormStyle.primary(context),
            icon: const ExperienceIcon(
              'BookOpen',
              size: 20,
              color: SnapFitColors.onAccent,
            ),
            label: const Text('앨범 만들기'),
          ),
        ],
      );
      final empty = Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 740 : 420),
          child: SnapFitFadeIn(
            child: wide
                ? Row(
                    children: [
                      Expanded(child: preview),
                      const SizedBox(width: 32),
                      Expanded(child: content),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [preview, const SizedBox(height: 28), content],
                  ),
          ),
        ),
      );
      return SingleChildScrollView(
        controller: scrollController,
        primary: false,
        child: Column(
          children: [
            if (leadingContent != null) leadingContent!,
            Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: leadingContent == null && footer == null
                      ? math.max(0, constraints.maxHeight - 48)
                      : 0,
                ),
                child: empty,
              ),
            ),
            if (footer != null) footer!,
          ],
        ),
      );
    },
  );
}

class _FirstAlbumPreview extends StatelessWidget {
  const _FirstAlbumPreview();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: SizedBox(
          height: 246,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 328,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SnapFitFadeIn(
                    duration: const Duration(milliseconds: 200),
                    delay: const Duration(milliseconds: 100),
                    beginOffset: Offset.zero,
                    child: Transform.translate(
                      offset: const Offset(-70, 8),
                      child: Transform.rotate(
                        angle: -.12,
                        child: const SizedBox(
                          width: 148,
                          child: StoryAlbumCover(edition: 1),
                        ),
                      ),
                    ),
                  ),
                  SnapFitFadeIn(
                    duration: const Duration(milliseconds: 200),
                    delay: const Duration(milliseconds: 50),
                    beginOffset: Offset.zero,
                    child: Transform.translate(
                      offset: const Offset(70, 8),
                      child: Transform.rotate(
                        angle: .12,
                        child: const SizedBox(
                          width: 148,
                          child: StoryAlbumCover(edition: 2),
                        ),
                      ),
                    ),
                  ),
                  const SnapFitFadeIn(
                    duration: Duration(milliseconds: 200),
                    beginOffset: Offset.zero,
                    child: SizedBox(width: 184, child: StoryAlbumCover()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Text(
        '이렇게 담아보세요',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
    ],
  );
}
