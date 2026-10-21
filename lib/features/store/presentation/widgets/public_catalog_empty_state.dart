import 'package:flutter/material.dart';

import '../../../../shared/web/web_design.dart';

/// Recovery actions use only subjects that are present in the public catalog.
class PublicCatalogEmptyState extends StatelessWidget {
  const PublicCatalogEmptyState({
    super.key,
    required this.catalogEmpty,
    required this.suggestedCategories,
    required this.onReset,
    required this.onCategorySelected,
  });

  final bool catalogEmpty;
  final List<String> suggestedCategories;
  final VoidCallback onReset;
  final ValueChanged<String> onCategorySelected;

  @override
  Widget build(BuildContext context) => WebSurface(
    key: ValueKey(
      catalogEmpty ? 'discovery-catalog-empty' : 'discovery-search-empty',
    ),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          catalogEmpty
              ? '둘러볼 디자인을 준비하고 있어요.'
              : '검색 결과가 없어요. 다른 이름이나 주제로 찾아보세요.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        if (catalogEmpty) ...[
          const SizedBox(height: 8),
          const Text('잠시 후 다시 확인해 주세요.'),
        ] else ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('discovery-reset-filters'),
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            label: const Text('검색·주제 초기화'),
          ),
          if (suggestedCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('다른 주제 둘러보기'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in suggestedCategories)
                  ActionChip(
                    key: ValueKey('discovery-suggestion-$category'),
                    label: Text(category),
                    onPressed: () => onCategorySelected(category),
                  ),
              ],
            ),
          ],
        ],
      ],
    ),
  );
}
