import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../web/web_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/point_shop/presentation/point_shop_access.dart';
import '../../core/templates/studio_phrase_catalog.dart';
import '../../core/templates/template_catalog_categories.dart';
import 'catalog_favorite_widgets.dart';
import 'editor_material_filter_bar.dart';
import 'experience_form_style.dart';
import '../../features/point_shop/data/point_shop_provider.dart';
import '../../features/point_shop/domain/point_shop_product.dart';

class StudioPhrasePicker extends ConsumerStatefulWidget {
  const StudioPhrasePicker({super.key, required this.onSelect});
  final ValueChanged<StudioPhrase> onSelect;

  static Future<StudioPhrase?> show(BuildContext context) =>
      kIsWeb ? showWebAwareDialog<StudioPhrase>(
        context: context,
        maxWidth: 1000,
        maxHeight: 740,
        builder: (_) => const _StudioPhraseSheet(),
      ) : showModalBottomSheet<StudioPhrase>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 960),
        backgroundColor: ExperienceFormStyle.surface(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (_) => const _StudioPhraseSheet(),
      );

  @override
  ConsumerState<StudioPhrasePicker> createState() => _StudioPhrasePickerState();
}

class _StudioPhraseSheet extends StatefulWidget {
  const _StudioPhraseSheet();
  @override
  State<_StudioPhraseSheet> createState() => _StudioPhraseSheetState();
}

class _StudioPhraseSheetState extends State<_StudioPhraseSheet> {
  bool _finishing = false;

  void _finish([StudioPhrase? phrase]) {
    if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent == false)
      return;
    setState(() => _finishing = true);
    Navigator.pop(context, phrase);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: LayoutBuilder(
      builder: (context, box) => SizedBox(
        height: kIsWeb ? box.maxHeight : math.min(
          box.maxHeight,
          MediaQuery.sizeOf(context).height * .94,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  '문구',
                  style: ExperienceFormStyle.text(
                    context,
                    18,
                    weight: FontWeight.w600,
                  ),
                ),
                trailing: IconButton(
                  key: const ValueKey('phrase-sheet-close'),
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: _finishing ? null : () => _finish(),
                ),
              ),
              Expanded(child: StudioPhrasePicker(onSelect: _finish)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StudioPhrasePickerState extends ConsumerState<StudioPhrasePicker> {
  String _category = '전체';
  bool _isApplying = false;
  final _filterKey = GlobalKey();

  Future<void> _select(StudioPhrase phrase) async {
    if (!mounted || _isApplying) return;
    _isApplying = true;
    try {
      if (!await ensurePointShopAccess(
        context,
        ref,
        productKey: 'phrase:${phrase.id}',
        title: phrase.text.replaceAll('\n', ' '),
      ))
        return;
      if (mounted && ModalRoute.of(context)?.isCurrent != false)
        widget.onSelect(phrase);
    } finally {
      _isApplying = false;
    }
  }

  bool _favoritesOnly = false;
  String _price = '전체', _query = '';
  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final products = {
      for (final p
          in ref.watch(pointShopCatalogProvider).asData?.value ??
              <PointShopProduct>[])
        p.productKey: p,
    };
    final owned =
        ref.watch(ownedPointShopKeysProvider).asData?.value ?? <String>{};
    final items = favorites.arrange(
      studioPhrases.where(
        (p) =>
            (_category == '전체' || p.category == _category) &&
            matchesEditorMaterial(
              query: _query,
              price: _price,
              label: '${p.text} ${p.lettering.label}',
              productKey: 'phrase:${p.id}',
              products: products,
              owned: owned,
            ),
      ),
      (p) => CatalogFavoriteKeys.phrase(p.id),
      onlyFavorites: _favoritesOnly,
    );
    final colors = Theme.of(context).colorScheme;
    final filters = EditorMaterialFilterBar(
      key: _filterKey,
      query: _query,
      price: _price,
      onPriceChanged: (value) => setState(() => _price = value),
      onQueryChanged: (value) => setState(() {
        _query = value;
        if (value.isNotEmpty) _category = '전체';
      }),
      favoritesOnly: _favoritesOnly,
      onFavoritesChanged: () => setState(() {
        _favoritesOnly = !_favoritesOnly;
        _category = '전체';
      }),
    );
    final topics = ['전체', ...templateTopicOrder];
    Widget category(String topic) => Tooltip(
      message: topic,
      child: ChoiceChip(
        label: Text(topic, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: topic == _category,
        onSelected: (_) => setState(() => _category = topic),
      ),
    );
    final categoryStrip = SizedBox(
      height: 56,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          for (final topic in topics)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: category(topic),
            ),
        ],
      ),
    );
    final catalog = items.isEmpty
        ? Center(
            child: SingleChildScrollView(
              child: EditorMaterialEmpty(
                onReset: () => setState(() {
                  _favoritesOnly = false;
                  _category = '전체';
                  _price = '전체';
                  _query = '';
                }),
              ),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: math.max(
                  1,
                  (constraints.maxWidth / 340).floor(),
                ),
                mainAxisExtent:
                    166 +
                    (MediaQuery.textScalerOf(context).scale(11) / 11 - 1).clamp(
                          0,
                          2,
                        ) *
                        70,
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
                          padding: const EdgeInsets.fromLTRB(16, 42, 16, 16),
                          child: Column(
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      phrase.text,
                                      textAlign: phrase.alignment,
                                      style: phrase.lettering.style.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      phrase.lettering.label,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: PointShopProductBadge(
                                      productKey: 'phrase:${phrase.id}',
                                    ),
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
          );
    return LayoutBuilder(
      builder: (context, box) {
        final wide =
            box.maxWidth >= 540 &&
            MediaQuery.orientationOf(context) == Orientation.landscape;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: (box.maxWidth * .36).clamp(208, 280),
                child: SingleChildScrollView(
                  key: const PageStorageKey('phrase-filters'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      filters,
                      const SizedBox(height: 8),
                      for (final topic in topics)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: category(topic),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: ExperienceFormStyle.line(context),
              ),
              Expanded(child: catalog),
            ],
          );
        }
        return Column(
          children: [
            filters,
            categoryStrip,
            Expanded(child: catalog),
          ],
        );
      },
    );
  }
}
