import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../../core/data/catalog_preview.dart';
import '../../../../core/templates/catalog_preview_assets.g.dart';
import '../../../../shared/widgets/catalog_artwork_visibility.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/store_template_discovery.dart';
import '../../../../shared/widgets/experience_icon.dart';

/// Mood examples use existing bitmaps, never template documents or font work.
/// [templates] is the eligible catalog for the current conditions, before mood
/// filtering. Counts never use pagination or a previously selected mood.
class StoreStyleGallery extends StatefulWidget {
  const StoreStyleGallery({
    super.key,
    required this.templates,
    required this.styleId,
    required this.onStyleChanged,
    this.resultLimit,
  });

  final List<PremiumTemplate> templates;
  final String? styleId;
  final ValueChanged<String?> onStyleChanged;
  final int? resultLimit;

  @override
  State<StoreStyleGallery> createState() => _StoreStyleGalleryState();
}

class _MoodArtwork {
  const _MoodArtwork(this.id, this.asset, this.styles, this.exactStyles);
  final int id;
  final String asset;
  final Set<String> styles, exactStyles;
}

class _StoreStyleGalleryState extends State<StoreStyleGallery> {
  final _scroll = ScrollController();
  final _tileKeys = <String, GlobalKey>{};
  List<PremiumTemplate>? _source;
  Map<String, String> _assets = const {};
  Map<String, int> _counts = const {};
  double? _width;
  (TextScaler, TextDirection)? _metrics;
  bool _revealPending = true, _revealScheduled = false;

  @override
  void initState() {
    super.initState();
    _prepareArtwork();
  }

  void _prepareArtwork() {
    if (identical(_source, widget.templates)) return;
    _source = widget.templates;
    final seen = <int>{};
    final artwork = <_MoodArtwork>[];
    final counts = <String, int>{};
    for (final template in widget.templates) {
      if (!seen.add(template.id)) continue;
      final styles = storeTemplateStyleIds(template);
      for (final style in styles) {
        counts.update(style, (count) => count + 1, ifAbsent: () => 1);
      }
      final id = canonicalCatalogPreviewId(template);
      if (id == null) continue;
      final asset = catalogPreviewAssets['template:$id'];
      if (asset == null) continue;
      final tags = {
        for (final tag in template.tags ?? const <String>[])
          tag.trim().toLowerCase(),
      };
      artwork.add(
        _MoodArtwork(id, asset, styles, {
          for (final style in storeTemplateStyles)
            if (style.terms.any(tags.contains) ||
                tags.contains(style.label.toLowerCase()))
              style.id,
        }),
      );
    }
    final used = <int>{};
    final result = <String, String>{};
    for (final style in storeTemplateStyles) {
      final candidates = artwork.where(
        (item) => item.styles.contains(style.id),
      );
      _MoodArtwork? first(bool exact, bool distinct) => candidates
          .where(
            (item) =>
                (!exact || item.exactStyles.contains(style.id)) &&
                (!distinct || !used.contains(item.id)),
          )
          .firstOrNull;
      final item =
          first(true, true) ??
          first(false, true) ??
          first(true, false) ??
          first(false, false);
      if (item == null) continue;
      used.add(item.id);
      result[style.id] = item.asset;
    }
    _assets = result;
    _counts = counts;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final metrics = (
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    if (_metrics != metrics) _revealPending = true;
    _metrics = metrics;
    _scheduleReveal();
  }

  @override
  void didUpdateWidget(StoreStyleGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareArtwork();
    if (oldWidget.styleId != widget.styleId) {
      _revealPending = true;
      _scheduleReveal();
    }
  }

  void _scheduleReveal() {
    if (!_revealPending || _revealScheduled || !TickerMode.of(context)) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !TickerMode.of(context) || _scroll.positions.length != 1)
        return;
      final position = _scroll.position;
      if (!position.hasContentDimensions) return;
      if (widget.styleId == null) {
        _revealPending = false;
        if (position.pixels != position.minScrollExtent)
          position.jumpTo(position.minScrollExtent);
        return;
      }
      final target = _tileKeys[widget.styleId]?.currentContext
          ?.findRenderObject();
      if (target is! RenderBox || !target.attached || !target.hasSize) return;
      final viewport = RenderAbstractViewport.maybeOf(target);
      if (viewport == null) return;
      final start = viewport.getOffsetToReveal(target, 0).offset;
      final end = viewport.getOffsetToReveal(target, 1).offset;
      if (!start.isFinite || !end.isFinite) return;
      _revealPending = false;
      final lower = start < end ? start : end;
      final upper = start < end ? end : start;
      final offset = position.pixels
          .clamp(lower, upper)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      // Move this horizontal position only; never scroll the enclosing catalog.
      if ((offset - position.pixels).abs() > .5) position.jumpTo(offset);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              '분위기로 골라보기',
              style: ExperienceFormStyle.text(
                context,
                12,
                weight: FontWeight.w600,
                secondary: true,
              ),
            ),
          ),
          Semantics(
            selected: widget.styleId == null,
            child: TextButton(
              key: const ValueKey('store-style-all'),
              onPressed: () => widget.onStyleChanged(null),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: ExperienceFormStyle.selectionInk(context),
                textStyle: ExperienceFormStyle.text(context, 12),
              ),
              child: const Text('전체'),
            ),
          ),
        ],
      ),
      LayoutBuilder(
        builder: (context, bounds) {
          if (_width != bounds.maxWidth) {
            _width = bounds.maxWidth;
            _revealPending = true;
            _scheduleReveal();
          }
          return SingleChildScrollView(
            key: const ValueKey('store-style-filters'),
            controller: _scroll,
            primary: false,
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final style in storeTemplateStyles)
                  Padding(
                    key: _tileKeys.putIfAbsent(style.id, GlobalKey.new),
                    padding: const EdgeInsets.only(right: 10),
                    child: _MoodTile(
                      style: style,
                      asset: _assets[style.id],
                      count: widget.resultLimit == null
                          ? _counts[style.id] ?? 0
                          : (_counts[style.id] ?? 0).clamp(
                              0,
                              widget.resultLimit!,
                            ),
                      selected: widget.styleId == style.id,
                      onSelect: () {
                        HapticFeedback.selectionClick();
                        widget.onStyleChanged(
                          widget.styleId == style.id ? null : style.id,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.style,
    required this.asset,
    required this.count,
    required this.selected,
    required this.onSelect,
  });
  final StoreTemplateStyle style;
  final String? asset;
  final int count;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = ExperienceFormStyle.selectionInk(context);
    final placeholder = ColoredBox(
      color: ExperienceFormStyle.surface(context),
      child: ExperienceIcon('BookOpen', size: 25, color: ExperienceFormStyle.muted(context),
      ),
    );
    return SizedBox(
      width: (MediaQuery.textScalerOf(context).scale(12) * 7).clamp(
        88.0,
        200.0,
      ),
      child: Semantics(
        key: ValueKey('store-style-semantics-${style.id}'),
        label: '${style.label} 분위기, 디자인 $count개',
        button: true,
        selected: selected,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('store-style-${style.id}'),
            onTap: onSelect,
            borderRadius: BorderRadius.circular(11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ExperienceFormStyle.surface(context),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? accent
                          : ExperienceFormStyle.line(context),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: SizedBox(
                    height: 68,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: ExcludeSemantics(
                              child: asset == null
                                  ? placeholder
                                  : CatalogArtworkVisibility(
                                      child: Image.asset(
                                        asset!,
                                        fit: BoxFit.contain,
                                        cacheWidth: 224,
                                        excludeFromSemantics: true,
                                        errorBuilder: (_, _, _) => placeholder,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        if (selected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: ExperienceIcon('Check', size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: ExperienceFormStyle.surface(context),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Text(
                                '$count개',
                                key: ValueKey('store-style-count-${style.id}'),
                                style: ExperienceFormStyle.text(
                                  context,
                                  10,
                                  secondary: true,
                                ).copyWith(height: 1.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  style.label,
                  textAlign: TextAlign.center,
                  style: ExperienceFormStyle.text(
                    context,
                    12,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? accent : null,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: 5),
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: selected ? accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
