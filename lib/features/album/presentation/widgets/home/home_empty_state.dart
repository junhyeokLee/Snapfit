import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_icon.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.onCreate, this.onResumeDraft});
  final VoidCallback onCreate;
  final VoidCallback? onResumeDraft;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 640;
      final preview = _FirstAlbumPreview(
        height: onResumeDraft != null && constraints.maxHeight < 520
            ? 180
            : 246,
      );
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
            icon: const ExperienceIcon('BookOpen', size: 20, color: Colors.white),
            label: const Text('앨범 만들기'),
          ),
          if (onResumeDraft != null)
            TextButton.icon(
              onPressed: onResumeDraft,
              icon: const Icon(Icons.history_rounded, size: 20),
              label: const Text('이어 만들기'),
              style: TextButton.styleFrom(
                foregroundColor: ExperienceFormStyle.ink(context),
                minimumSize: const Size(0, 44),
              ),
            ),
        ],
      );
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 48),
          ),
          child: Center(
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
                        children: [
                          preview,
                          const SizedBox(height: 28),
                          content,
                        ],
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FirstAlbumPreview extends StatelessWidget {
  const _FirstAlbumPreview({this.height = 246});
  final double height;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 328,
              height: 246,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(-70, 8),
                    child: Transform.rotate(
                      angle: -.12,
                      child: const _PreviewCover(id: -9302, size: 148),
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(70, 8),
                    child: Transform.rotate(
                      angle: .12,
                      child: const _PreviewCover(id: -9303, size: 148),
                    ),
                  ),
                  const _PreviewCover(id: -9301, size: 184),
                ],
              ),
            ),
          ),
        ),
      ),
      Text(
        '템플릿 미리보기',
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
    ],
  );
}

class _PreviewCover extends StatelessWidget {
  const _PreviewCover({required this.id, required this.size});
  final int id;
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .12),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Image.asset(
      'assets/catalog_thumbnails/template_$id.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: 480,
    ),
  );
}
