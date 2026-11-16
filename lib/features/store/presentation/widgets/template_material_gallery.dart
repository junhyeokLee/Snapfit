import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';

/// Every included material is visible in the detail's normal scroll flow.
class TemplateMaterialGallery extends StatelessWidget {
  const TemplateMaterialGallery({
    super.key,
    required this.materialKeys,
    required this.name,
    required this.kind,
    required this.artwork,
    required this.usage,
    this.onOpen,
  });

  final Iterable<String> materialKeys;
  final String Function(String) name, kind;
  final Widget Function(String) artwork, usage;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final keys = materialKeys.toList(growable: false);
    if (keys.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            '함께 사용한 꾸밈 소재 ${keys.length}종',
            style: ExperienceFormStyle.text(
              context,
              17,
              weight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '디자인에 배치된 모든 소재예요. 다른 앨범에서 사용할 때의 이용 범위도 함께 확인하세요.',
          style: ExperienceFormStyle.text(
            context,
            12,
            secondary: true,
          ).copyWith(height: 1.6),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, bounds) {
            final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
            final columns = largeText || bounds.maxWidth < 280
                ? 1
                : bounds.maxWidth >= 600
                ? 3
                : 2;
            const gap = 14.0;
            final width = (bounds.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: 22,
              children: [
                for (final key in keys)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      button: onOpen != null,
                      label: '${name(key)} ${kind(key)}',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('template-material-preview-$key'),
                          onTap: onOpen == null ? null : () => onOpen!(key),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.2,
                                  child: artwork(key),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  kind(key),
                                  style: ExperienceFormStyle.text(
                                    context,
                                    11,
                                    secondary: true,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  name(key),
                                  style: ExperienceFormStyle.text(
                                    context,
                                    13,
                                    weight: FontWeight.w600,
                                  ).copyWith(height: 1.45),
                                ),
                                const SizedBox(height: 6),
                                usage(key),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
