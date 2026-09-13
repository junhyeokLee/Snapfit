import 'package:flutter/material.dart';
import 'catalog_favorite_widgets.dart';
import 'no_glow.dart';

/// 폰트 리스트 (옵션 영역)
class FontPickerList extends StatefulWidget {
  final List<String> families;
  final String current;
  final ValueChanged<String> onPick;
  final ScrollController? controller;
  const FontPickerList({
    super.key,
    required this.families,
    required this.current,
    required this.onPick,
    this.controller,
  });

  @override
  State<FontPickerList> createState() => FontPickerListState();
}

class FontPickerListState extends State<FontPickerList> {
  bool _favoritesOnly = false;
  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final families = favorites.arrange(
        widget.families.toSet(),
        CatalogFavoriteKeys.font,
        onlyFavorites: _favoritesOnly,
      );
      final colors = Theme.of(context).colorScheme;
      return SizedBox(
        height: 68,
        child: Row(
          children: [
            IconButton(
              tooltip: _favoritesOnly ? '전체 폰트 보기' : '즐겨찾는 폰트만 보기',
              isSelected: _favoritesOnly,
              icon: const Icon(Icons.star_outline_rounded),
              selectedIcon: const Icon(Icons.star_rounded),
              onPressed: () => setState(() => _favoritesOnly = !_favoritesOnly),
            ),
            Expanded(
              child: families.isEmpty
                  ? TextButton(
                      onPressed: () => setState(() => _favoritesOnly = false),
                      child: const Text('즐겨찾는 폰트 없음 · 전체 보기'),
                    )
                  : ScrollConfiguration(
                      behavior: const NoGlow(),
                      child: ListView.separated(
                        controller: widget.controller,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        itemCount: families.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (itemContext, index) {
                          final family = families[index];
                          final selected = family == widget.current;
                          return Material(
                            key: ValueKey(family),
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 192,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: selected
                                      ? colors.primary
                                      : colors.outlineVariant,
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        widget.onPick(family);
                                        Scrollable.ensureVisible(
                                          itemContext,
                                          alignment: .5,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeOut,
                                        );
                                      },
                                      child: Semantics(
                                        button: true,
                                        selected: selected,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          child: Center(
                                            child: Text(
                                              family,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontFamily: family,
                                                color: colors.onSurface,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  CatalogFavoriteButton(
                                    itemKey: CatalogFavoriteKeys.font(family),
                                    label: family,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
