import 'package:flutter/material.dart';

import 'experience_form_style.dart';

/// Explain an empty result and offer a direct route back to the full catalog.
class CatalogEmptyResult extends StatelessWidget {
  const CatalogEmptyResult({
    super.key,
    required this.title,
    required this.description,
    this.query = '',
    this.icon = Icons.search_off_rounded,
    this.onReset,
  });

  final String title;
  final String description;
  final String query;
  final IconData icon;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ExperienceFormStyle.surface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ExperienceFormStyle.line(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Icon(
                  icon,
                  size: 32,
                  color: ExperienceFormStyle.muted(context),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(
                context,
                18,
                weight: FontWeight.w700,
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '“$query”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: ExperienceFormStyle.text(context, 14, secondary: true),
            ),
            if (onReset != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                key: const ValueKey('catalog-empty-reset'),
                onPressed: onReset,
                style: FilledButton.styleFrom(
                  backgroundColor: ExperienceFormStyle.selection(context),
                  foregroundColor: ExperienceFormStyle.ink(context),
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: ExperienceFormStyle.text(
                    context,
                    14,
                    weight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('검색·필터 초기화'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
