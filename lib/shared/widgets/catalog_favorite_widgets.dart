import 'package:flutter/material.dart';
import '../../core/templates/catalog_favorites.dart';
export '../../core/templates/catalog_favorites.dart';
export '../../core/templates/catalog_favorite_keys.dart';

class CatalogFavoritesBuilder extends StatefulWidget {
  const CatalogFavoritesBuilder({super.key, required this.builder});
  final Widget Function(BuildContext, CatalogFavorites) builder;
  @override
  State<CatalogFavoritesBuilder> createState() =>
      _CatalogFavoritesBuilderState();
}

class _CatalogFavoritesBuilderState extends State<CatalogFavoritesBuilder> {
  late final CatalogFavorites favorites = CatalogFavorites.instance;
  @override
  void initState() {
    super.initState();
    favorites.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: favorites,
    builder: (context, _) => widget.builder(context, favorites),
  );
}

class CatalogFavoriteButton extends StatelessWidget {
  const CatalogFavoriteButton({
    super.key,
    required this.itemKey,
    required this.label,
  });
  final String itemKey, label;
  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final selected = favorites.contains(itemKey);
      final tooltip = '$label 즐겨찾기 ${selected ? '해제' : '추가'}';
      Future<void> toggle() async {
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (!await favorites.toggle(itemKey) &&
            messenger != null &&
            messenger.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('즐겨찾기를 저장하지 못했어요. 다시 시도해 주세요.')),
          );
        }
      }

      return Semantics(
        button: true,
        toggled: selected,
        label: tooltip,
        excludeSemantics: true,
        onTap: toggle,
        child: IconButton.filledTonal(
          key: ValueKey('favorite-$itemKey'),
          tooltip: tooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            maximumSize: const Size(44, 44),
            padding: EdgeInsets.zero,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Icon(
              selected ? Icons.star_rounded : Icons.star_outline_rounded,
              key: ValueKey(selected),
              size: 22,
            ),
          ),
          onPressed: toggle,
        ),
      );
    },
  );
}

/// Sibling hit targets keep bookmarking separate from applying/opening an item.
class CatalogFavoriteTile extends StatelessWidget {
  const CatalogFavoriteTile({
    super.key,
    required this.itemKey,
    required this.label,
    required this.child,
  });
  final String itemKey, label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned(
        top: 4,
        right: 4,
        child: CatalogFavoriteButton(itemKey: itemKey, label: label),
      ),
    ],
  );
}

class CatalogFavoriteFilter extends StatelessWidget {
  const CatalogFavoriteFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final bool selected;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => FilterChip(
    avatar: Icon(
      selected ? Icons.star_rounded : Icons.star_outline_rounded,
      size: 18,
    ),
    label: const Text('즐겨찾기', style: TextStyle(fontSize: 12)),
    selected: selected,
    showCheckmark: false,
    onSelected: onChanged,
  );
}

class CatalogFavoritesEmpty extends StatelessWidget {
  const CatalogFavoritesEmpty({super.key, required this.onShowAll});
  final VoidCallback onShowAll;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 30,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          const Text(
            '즐겨찾기한 항목이 없어요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          TextButton(onPressed: onShowAll, child: const Text('전체 보기')),
        ],
      ),
    ),
  );
}

class CatalogFavoriteGrid<T> extends StatefulWidget {
  const CatalogFavoriteGrid({
    super.key,
    required this.items,
    required this.keyOf,
    required this.labelOf,
    required this.itemBuilder,
    this.mainAxisExtent = 180,
    this.maxCrossAxisExtent = 190,
  });
  final List<T> items;
  final String Function(T) keyOf, labelOf;
  final Widget Function(BuildContext, T) itemBuilder;
  final double mainAxisExtent, maxCrossAxisExtent;
  @override
  State<CatalogFavoriteGrid<T>> createState() => _CatalogFavoriteGridState<T>();
}

class _CatalogFavoriteGridState<T> extends State<CatalogFavoriteGrid<T>> {
  bool _onlyFavorites = false;
  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final items = favorites.arrange(
        widget.items,
        widget.keyOf,
        onlyFavorites: _onlyFavorites,
      );
      return Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: CatalogFavoriteFilter(
                selected: _onlyFavorites,
                onChanged: (value) => setState(() => _onlyFavorites = value),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? CatalogFavoritesEmpty(
                    onShowAll: () => setState(() => _onlyFavorites = false),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: widget.maxCrossAxisExtent,
                      mainAxisExtent: widget.mainAxisExtent,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return CatalogFavoriteTile(
                        key: ValueKey(widget.keyOf(item)),
                        itemKey: widget.keyOf(item),
                        label: widget.labelOf(item),
                        child: widget.itemBuilder(context, item),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}
