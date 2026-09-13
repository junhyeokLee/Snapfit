import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/point_shop/presentation/point_shop_access.dart';
import '../../core/templates/studio_phrase_catalog.dart';
import '../../core/templates/template_catalog_categories.dart';
import 'catalog_favorite_widgets.dart';

class StudioPhrasePicker extends ConsumerStatefulWidget {
  const StudioPhrasePicker({super.key, required this.onSelect});
  final ValueChanged<StudioPhrase> onSelect;

  static Future<StudioPhrase?> show(BuildContext context) =>
      showModalBottomSheet<StudioPhrase>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .85,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    '문구',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  trailing: IconButton(
                    tooltip: '닫기',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: StudioPhrasePicker(
                    onSelect: (value) => Navigator.pop(context, value),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  ConsumerState<StudioPhrasePicker> createState() => _StudioPhrasePickerState();
}

class _StudioPhrasePickerState extends ConsumerState<StudioPhrasePicker> {
  String _category = '전체';
  bool _isApplying = false;

  Future<void> _select(StudioPhrase phrase) async {
    if (_isApplying) return;
    _isApplying = true;
    try {
      if (!await ensurePointShopAccess(
        context,
        ref,
        productKey: 'phrase:${phrase.id}',
        title: phrase.text.replaceAll('\n', ' '),
      ))
        return;
      if (mounted) widget.onSelect(phrase);
    } finally {
      _isApplying = false;
    }
  }

  bool _favoritesOnly = false;
  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final items = favorites.arrange(
      studioPhrases.where((p) => _category == '전체' || p.category == _category),
      (p) => CatalogFavoriteKeys.phrase(p.id),
      onlyFavorites: _favoritesOnly,
    );
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CatalogFavoriteFilter(
                  selected: _favoritesOnly,
                  onChanged: (value) => setState(() {
                    _favoritesOnly = value;
                    _category = '전체';
                  }),
                ),
              ),
              for (final topic in ['전체', ...templateTopicOrder])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(topic),
                    selected: topic == _category,
                    onSelected: (_) => setState(() => _category = topic),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? CatalogFavoritesEmpty(
                  onShowAll: () => setState(() {
                    _favoritesOnly = false;
                    _category = '전체';
                  }),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: math.max(
                        1,
                        (constraints.maxWidth / 340).floor(),
                      ),
                      mainAxisExtent: 166,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final phrase = items[index];
                      return CatalogFavoriteTile(
                        key: ValueKey(phrase.id),
                        itemKey: CatalogFavoriteKeys.phrase(phrase.id),
                        label: phrase.text.replaceAll('\n', ' '),
                        child: Semantics(
                          button: true,
                          label: '${phrase.text.replaceAll('\n', ' ')} 적용',
                          onTap: () => _select(phrase),
                          child: Material(
                            color: colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _select(phrase),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  42,
                                  16,
                                  16,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            phrase.text,
                                            textAlign: phrase.alignment,
                                            style: phrase.lettering.style
                                                .copyWith(
                                                  color: colors.onSurface,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          phrase.lettering.label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        PointShopProductBadge(
                                          productKey: 'phrase:${phrase.id}',
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.add, size: 18),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
