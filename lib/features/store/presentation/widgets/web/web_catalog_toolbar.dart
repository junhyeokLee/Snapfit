import 'package:flutter/material.dart';

import '../../../../../shared/web/web_design.dart';
import '../../../../../shared/widgets/catalog_result_status.dart';

/// Desktop catalogs share the same visible search and wrapping filter order.
class WebCatalogToolbar extends StatelessWidget {
  const WebCatalogToolbar({
    super.key,
    required this.controller,
    required this.searchHint,
    required this.onSearchChanged,
    required this.categories,
    required this.category,
    required this.onCategoryChanged,
    required this.price,
    required this.onPriceChanged,
    required this.favoritesOnly,
    required this.onFavoritesChanged,
    required this.resultLabel,
    required this.onReset,
    this.showOwned = true,
    this.sort,
    this.onSortChanged,
    this.leading,
    this.filtersActive = false,
  });

  final TextEditingController controller;
  final String searchHint, category, price, resultLabel;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged, onCategoryChanged, onPriceChanged;
  final bool favoritesOnly, filtersActive, showOwned;
  final VoidCallback onFavoritesChanged, onReset;
  final String? sort;
  final ValueChanged<String>? onSortChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final controls = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 144,
          child: DropdownButtonFormField<String>(
            key: const ValueKey('web-catalog-price-filter'),
            initialValue: price,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '이용 구분',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              for (final value in ['전체', '무료', '유료', if (showOwned) '보유'])
                DropdownMenuItem(
                  value: value,
                  child: Text(value == '유료' ? '포인트' : value),
                ),
            ],
            onChanged: (value) {
              if (value != null) onPriceChanged(value);
            },
          ),
        ),
        FilterChip(
          avatar: Icon(
            favoritesOnly ? Icons.bookmark : Icons.bookmark_outline,
            size: 17,
          ),
          label: const Text('즐겨찾기'),
          selected: favoritesOnly,
          selectedColor: palette.softBrand,
          showCheckmark: false,
          onSelected: (_) => onFavoritesChanged(),
        ),
        if (sort != null)
          SizedBox(
            width: 144,
            child: DropdownButtonFormField<String>(
              key: const ValueKey('web-catalog-sort'),
              initialValue: sort,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '정렬',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '추천순', child: Text('추천순')),
                DropdownMenuItem(value: '이름순', child: Text('이름순')),
              ],
              onChanged: (value) {
                if (value != null) onSortChanged?.call(value);
              },
            ),
          ),
      ],
    );
    final categoriesRow = Wrap(
      key: const ValueKey('web-catalog-categories'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in categories)
          ChoiceChip(
            label: Text(value),
            selected: category == value,
            onSelected: (_) => onCategoryChanged(value),
            selectedColor: palette.softBrand,
            labelStyle: TextStyle(
              color: category == value ? palette.brandInk : palette.ink,
            ),
            showCheckmark: false,
          ),
      ],
    );
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxWidth < 600;
        return WebSurface(
          key: const ValueKey('web-catalog-toolbar'),
          padding: EdgeInsets.all(compact ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null) ...[leading!, const SizedBox(height: 12)],
              TextField(
                key: const ValueKey('web-catalog-search'),
                controller: controller,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: searchHint,
                  prefixIcon: const Icon(Icons.search, size: 21),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '검색 지우기',
                          onPressed: () {
                            controller.clear();
                            onSearchChanged('');
                          },
                          icon: const Icon(Icons.close, size: 19),
                        ),
                  filled: true,
                  fillColor: palette.canvas,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: palette.line),
                  ),
                ),
              ),

              const SizedBox(height: 8),
              categoriesRow,
              const SizedBox(height: 8),
              if (compact)
                ExpansionTile(
                  key: const ValueKey('web-catalog-advanced-filters'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: const Text('필터·정렬'),
                  subtitle: filtersActive
                      ? Text(
                          [
                            if (price != '전체') price,
                            if (favoritesOnly) '즐겨찾기',
                            if (sort != null && sort != '추천순') sort!,
                          ].join(' · '),
                        )
                      : null,
                  children: [
                    Align(alignment: Alignment.centerLeft, child: controls),
                  ],
                )
              else ...[
                Divider(height: 1, color: palette.line),
                const SizedBox(height: 12),
                controls,
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CatalogResultStatus(
                    label: resultLabel,
                    debounceToken: (
                      controller.text,
                      category,
                      price,
                      favoritesOnly,
                      sort,
                    ),
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                  if (filtersActive)
                    TextButton.icon(
                      key: const ValueKey('web-catalog-reset'),
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('초기화'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
