import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/point_shop/data/point_shop_provider.dart';
import '../../features/point_shop/domain/point_shop_product.dart';
import 'catalog_filter_bar.dart';
import 'experience_form_style.dart';

bool matchesEditorMaterial({
  required String query,
  required String price,
  required String label,
  required String? productKey,
  required Map<String, PointShopProduct> products,
  required Set<String> owned,
}) {
  if (!label.toLowerCase().contains(query.trim().toLowerCase())) return false;
  if (price == '전체') return true;
  if (price == '보유') return productKey != null && owned.contains(productKey);
  if (productKey == null) return price == '무료';
  final product = products[productKey];
  if (product == null) return false;
  if (!product.isActive || product.pointPrice == null) return false;
  return price == '무료' ? product.pointPrice == 0 : product.pointPrice! > 0;
}

class EditorMaterialFilterBar extends ConsumerStatefulWidget {
  const EditorMaterialFilterBar({
    super.key,
    required this.price,
    required this.onPriceChanged,
    required this.favoritesOnly,
    required this.onFavoritesChanged,
    required this.onQueryChanged,
    required this.query,
  });
  final String price;
  final String query;
  final ValueChanged<String> onPriceChanged, onQueryChanged;
  final bool favoritesOnly;
  final VoidCallback onFavoritesChanged;
  @override
  ConsumerState<EditorMaterialFilterBar> createState() =>
      _EditorMaterialFilterBarState();
}

class _EditorMaterialFilterBarState
    extends ConsumerState<EditorMaterialFilterBar> {
  final _controller = TextEditingController();
  bool _searching = false;
  @override
  void didUpdateWidget(covariant EditorMaterialFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) _controller.text = widget.query;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned = ref.watch(ownedPointShopKeysProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          CatalogFilterBar(
            price: widget.price,
            showOwned: true,
            enabled:
                catalog.hasValue && !catalog.hasError && !catalog.isLoading,
            onPriceChanged: widget.onPriceChanged,
            favoritesOnly: widget.favoritesOnly,
            onFavoritesChanged: widget.onFavoritesChanged,
            trailing: IconButton(
              tooltip: _searching ? '소재 검색 접기' : '소재 검색',
              isSelected: _controller.text.isNotEmpty,
              onPressed: () => setState(() => _searching = !_searching),
              icon: Icon(_searching ? Icons.close : Icons.search, size: 20),
            ),
          ),
          if (_searching)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: const ValueKey('editor-material-search'),
                controller: _controller,
                style: ExperienceFormStyle.text(context, 14),
                decoration: ExperienceFormStyle.input(context, hint: '소재 이름 검색')
                    .copyWith(
                      suffixIcon: IconButton(
                        tooltip: '검색 지우기',
                        onPressed: () {
                          _controller.clear();
                          widget.onQueryChanged('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ),
                onChanged: (value) {
                  widget.onQueryChanged(value);
                  setState(() {});
                },
              ),
            ),
          if (catalog.hasError || (widget.price == '보유' && owned.hasError))
            TextButton.icon(
              onPressed: () {
                ref.invalidate(pointShopCatalogProvider);
                ref.invalidate(ownedPointShopKeysProvider);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(catalog.hasError ? '가격 정보 다시 확인' : '보유 소재 다시 확인'),
            ),
          if (widget.price == '보유' && owned.isLoading)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}

class EditorMaterialEmpty extends StatelessWidget {
  const EditorMaterialEmpty({super.key, required this.onReset});
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '조건에 맞는 소재가 없어요',
          style: ExperienceFormStyle.text(context, 14, secondary: true),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onReset, child: const Text('전체 보기')),
      ],
    ),
  );
}
