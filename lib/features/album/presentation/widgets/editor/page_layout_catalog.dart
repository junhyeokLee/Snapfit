import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/constants/page_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

/// Shared catalog for the editor panel and the standalone layout picker.
/// The selected arrangement is only returned to the caller; opening a card
/// never changes a document here.
class PageLayoutCatalog extends StatefulWidget {
  const PageLayoutCatalog({
    super.key,
    required this.onSelect,
    this.selectedId,
    this.pageRatio = 1,
  });

  final ValueChanged<PageTemplate> onSelect;
  final String? selectedId;
  final double pageRatio;

  @override
  State<PageLayoutCatalog> createState() => _PageLayoutCatalogState();
}

enum _PhotoCount {
  all('모든 사진 수'),
  one('1장'),
  two('2장'),
  three('3장'),
  four('4장'),
  fiveSix('5–6장'),
  sevenPlus('7장 이상');

  const _PhotoCount(this.label);
  final String label;

  bool matches(int count) => switch (this) {
    all => true,
    one => count == 1,
    two => count == 2,
    three => count == 3,
    four => count == 4,
    fiveSix => count >= 5 && count <= 6,
    sevenPlus => count >= 7,
  };
}

class _PageLayoutCatalogState extends State<PageLayoutCatalog> {
  PageLayoutCategory? _category;
  _PhotoCount _photos = _PhotoCount.all;
  bool _favoritesOnly = false;

  bool get _filtered =>
      _category != null || _photos != _PhotoCount.all || _favoritesOnly;

  void _reset() => setState(() {
    _category = null;
    _photos = _PhotoCount.all;
    _favoritesOnly = false;
  });

  @override
  Widget build(BuildContext context) => CatalogFavoritesBuilder(
    builder: (context, favorites) {
      final templates = favorites.arrange(
        pageTemplates
            .where(
              (template) =>
                  (_category == null || template.category == _category) &&
                  _photos.matches(template.photoCount),
            )
            .toList(),
        (template) => CatalogFavoriteKeys.layout(template.id),
        onlyFavorites: _favoritesOnly,
      );
      final ink = SnapFitColors.textPrimaryOf(context);
      return LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          key: const PageStorageKey('page-layout-catalog-scroll'),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (constraints.maxHeight > 430)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                      child: Text(
                        '사진 수와 담고 싶은 이야기에 맞춰 골라보세요.',
                        style: TextStyle(
                          color: SnapFitColors.textSecondaryOf(context),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  _FilterStrip(
                    stripKey: const ValueKey('layout-categories'),
                    children: [
                      _choice(
                        key: 'layout-category-all',
                        label: '전체',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final category in PageLayoutCategory.values)
                        _choice(
                          key: 'layout-category-${category.name}',
                          label: category.label,
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                  _FilterStrip(
                    stripKey: const ValueKey('layout-photo-counts'),
                    children: [
                      for (final photos in _PhotoCount.values)
                        _choice(
                          key: 'layout-photos-${photos.name}',
                          label: photos.label,
                          selected: _photos == photos,
                          onTap: () => setState(() => _photos = photos),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${templates.length}가지 레이아웃',
                          key: const ValueKey('layout-result-count'),
                          style: TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        CatalogFavoriteFilter(
                          selected: _favoritesOnly,
                          onChanged: (value) =>
                              setState(() => _favoritesOnly = value),
                        ),
                        if (_filtered)
                          TextButton(
                            key: const ValueKey('layout-reset-filters'),
                            onPressed: _reset,
                            child: const Text('초기화'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (templates.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child:
                    _favoritesOnly &&
                        _category == null &&
                        _photos == _PhotoCount.all
                    ? CatalogFavoritesEmpty(onShowAll: _reset)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.dashboard_customize_outlined,
                                color: SnapFitColors.textMutedOf(context),
                                size: 30,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '조건에 맞는 레이아웃이 없어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ink, fontSize: 14),
                              ),
                              TextButton(
                                onPressed: _reset,
                                child: const Text('모든 레이아웃 보기'),
                              ),
                            ],
                          ),
                        ),
                      ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: constraints.maxWidth < 360
                        ? 1
                        : ((constraints.maxWidth - 40) / 180)
                              .floor()
                              .clamp(2, 4)
                              .toInt(),
                    mainAxisExtent:
                        (constraints.maxWidth < 360 ? 210 : 170) +
                        MediaQuery.textScalerOf(context).scale(72),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return CatalogFavoriteTile(
                      key: ValueKey(template.id),
                      itemKey: CatalogFavoriteKeys.layout(template.id),
                      label: template.name,
                      child: _LayoutCard(
                        template: template,
                        selected: widget.selectedId == template.id,
                        pageRatio: widget.pageRatio,
                        onTap: () => widget.onSelect(template),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _choice({
    required String key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) => ChoiceChip(
    key: ValueKey(key),
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: selected,
    showCheckmark: false,
    onSelected: (_) => onTap(),
    visualDensity: VisualDensity.standard,
    labelPadding: const EdgeInsets.symmetric(horizontal: 6),
  );
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.stripKey, required this.children});
  final Key stripKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: stripKey,
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: 7),
          children[index],
        ],
      ],
    ),
  );
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.template,
    required this.selected,
    required this.pageRatio,
    required this.onTap,
  });
  final PageTemplate template;
  final bool selected;
  final double pageRatio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SnapFitPressable(
      semanticLabel: '${template.name} 레이아웃 미리보기',
      selected: selected,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? colors.primary
                : colors.outlineVariant.withValues(alpha: .75),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SnapFitColors.isDark(context)
                      ? const Color(0xFF243338)
                      : const Color(0xFFF1F5F5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: RepaintBoundary(
                    child: AspectRatio(
                      aspectRatio: pageRatio > 0 ? pageRatio : 1,
                      child: PageLayoutPreview(template: template),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 11),
            Text(
              template.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                height: 1.3,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '사진 ${template.photoCount}장${template.textCount > 0 ? ' · 글 ${template.textCount}칸' : ''}',
              maxLines: 2,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.35,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              template.description.isEmpty
                  ? template.category.label
                  : template.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                height: 1.3,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lightweight, honest diagram of the actual page slots. It intentionally
/// contains no remote photos or document font loading while browsing layouts.
class PageLayoutPreview extends StatelessWidget {
  const PageLayoutPreview({super.key, required this.template});
  final PageTemplate template;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: CustomPaint(painter: _LayoutPainter(template), size: Size.infinite),
  );
}

class _LayoutPainter extends CustomPainter {
  const _LayoutPainter(this.template);
  final PageTemplate template;
  static const _photoColors = [
    Color(0xFFACD1D8),
    Color(0xFFC5DDE0),
    Color(0xFF8AB9C4),
    Color(0xFFD8E8E6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = template.backgroundColor,
    );
    var photoIndex = 0;
    for (final slot in template.slots) {
      final rect = Rect.fromLTWH(
        slot.left * size.width,
        slot.top * size.height,
        slot.width * size.width,
        slot.height * size.height,
      );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate(slot.rotation * math.pi / 180);
      final box = Rect.fromCenter(
        center: Offset.zero,
        width: rect.width,
        height: rect.height,
      );
      if (slot.type == 'image') {
        final color = _photoColors[photoIndex++ % _photoColors.length];
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(1.5)),
          Paint()..color = color,
        );
        canvas.save();
        canvas.clipRect(box);
        final hills = Path()
          ..moveTo(box.left, box.bottom)
          ..lineTo(box.left, box.top + box.height * .76)
          ..lineTo(box.left + box.width * .35, box.top + box.height * .42)
          ..lineTo(box.left + box.width * .61, box.top + box.height * .67)
          ..lineTo(box.right, box.top + box.height * .36)
          ..lineTo(box.right, box.bottom)
          ..close();
        canvas.drawPath(
          hills,
          Paint()..color = const Color(0xFF6395A3).withValues(alpha: .32),
        );
        final shortestSide = math.min(box.width, box.height);
        if (shortestSide > 18) {
          canvas.drawCircle(
            Offset(box.left + box.width * .72, box.top + box.height * .24),
            shortestSide * .085,
            Paint()..color = const Color(0xFFF4FBFB).withValues(alpha: .8),
          );
        }
        canvas.restore();
      } else {
        final linePaint = Paint()
          ..color = const Color(0xFF6C8589)
          ..strokeWidth = (size.width * .012).clamp(1.0, 2.0).toDouble()
          ..strokeCap = StrokeCap.round;
        final lineCount = box.height > size.height * .15 ? 4 : 2;
        final gap = math.min(box.height / (lineCount + 1), size.height * .045);
        final start = box.top + math.min(gap, box.height * .2);
        for (var line = 0; line < lineCount; line++) {
          final y = start + line * gap;
          canvas.drawLine(
            Offset(box.left, y),
            Offset(
              box.left + box.width * (line == lineCount - 1 ? .6 : .92),
              y,
            ),
            linePaint,
          );
        }
      }
      canvas.restore();
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..color = const Color(0xFFD3DEDE),
    );
  }

  @override
  bool shouldRepaint(_LayoutPainter oldDelegate) =>
      !identical(oldDelegate.template, template);
}
