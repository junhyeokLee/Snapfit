import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/store_template_recommendations.dart';
import 'catalog_edition_artwork.dart';
import '../../../../shared/widgets/experience_icon.dart';

class StoreTopicShelf extends StatefulWidget {
  const StoreTopicShelf({
    super.key,
    required this.categories,
    required this.templates,
    required this.selected,
    required this.onSelect,
  });
  final List<String> categories;
  final List<PremiumTemplate> templates;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  State<StoreTopicShelf> createState() => _StoreTopicShelfState();
}

class _StoreTopicShelfState extends State<StoreTopicShelf> {
  final _scroll = ScrollController();
  final _chipKeys = <String, GlobalKey>{};
  double? _viewportWidth;
  (
    TextScaler,
    TextDirection,
    VisualDensity,
    MaterialTapTargetSize,
    ChipThemeData,
    bool,
  )?
  _chipMetrics;
  TextStyle? _labelStyle;
  bool _revealPending = true;
  bool _revealScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    final metrics = (
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
      theme.visualDensity,
      theme.materialTapTargetSize,
      theme.chipTheme,
      theme.useMaterial3,
    );
    final labelStyle = DefaultTextStyle.of(context).style.merge(
      ExperienceFormStyle.text(context, 13, weight: FontWeight.w500),
    );
    // Visibility alone must preserve the user's horizontal browsing position.
    // Keep real selection/layout work pending while the store is hidden.
    if (_chipMetrics != metrics ||
        _labelStyle?.compareTo(labelStyle) == RenderComparison.layout) {
      _revealPending = true;
    }
    _chipMetrics = metrics;
    _labelStyle = labelStyle;
    _scheduleSelectedReveal();
  }

  @override
  void didUpdateWidget(StoreTopicShelf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.categories, widget.categories)) {
      _chipKeys.removeWhere(
        (category, _) => !widget.categories.contains(category),
      );
      _requestSelectedReveal();
    } else if (oldWidget.selected != widget.selected) {
      _requestSelectedReveal();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _requestSelectedReveal() {
    _revealPending = true;
    _scheduleSelectedReveal();
  }

  void _scheduleSelectedReveal() {
    if (!_revealPending || _revealScheduled || !TickerMode.of(context)) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted || !TickerMode.of(context) || _scroll.positions.length != 1)
        return;
      final position = _scroll.position;
      final target = _chipKeys[widget.selected]?.currentContext
          ?.findRenderObject();
      if (!position.hasContentDimensions ||
          target is! RenderBox ||
          !target.attached ||
          !target.hasSize)
        return;
      final viewport = RenderAbstractViewport.maybeOf(target);
      if (viewport == null) return;
      final start = viewport.getOffsetToReveal(target, 0).offset;
      final end = viewport.getOffsetToReveal(target, 1).offset;
      if (!start.isFinite || !end.isFinite) return;
      _revealPending = false;
      // Keep fully visible chips still. For programmatic/rapid selections,
      // move only this horizontal position, never the outer catalog. Both
      // alignments define the valid interval in LTR and RTL layouts alike.
      final lower = start < end ? start : end;
      final upper = start < end ? end : start;
      final offset = position.pixels
          .clamp(lower, upper)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if ((offset - position.pixels).abs() > .5) position.jumpTo(offset);
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (_viewportWidth != bounds.maxWidth) {
        _viewportWidth = bounds.maxWidth;
        _requestSelectedReveal();
      }
      return SingleChildScrollView(
        key: const ValueKey('store-topic-filters'),
        controller: _scroll,
        primary: false,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final category in widget.categories)
              Padding(
                key: _chipKeys.putIfAbsent(category, GlobalKey.new),
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey('store-topic-$category'),
                  selected: widget.selected == category,
                  onSelected: (_) {
                    if (widget.selected == category) return;
                    HapticFeedback.selectionClick();
                    widget.onSelect(category);
                  },
                  showCheckmark: false,
                  avatar: category == '전체'
                      ? null
                      : category == storeRecommendedCategory
                      ? ExperienceIcon(
                          'Sparkles',
                          size: 16,
                          color: ExperienceFormStyle.selectionInk(context),
                        )
                      : SizedBox(
                          width: 4,
                          height: 14,
                          child: ColoredBox(
                            color: CatalogEditionPalette.of(category).ink,
                          ),
                        ),
                  label: Text(
                    category,
                    style: ExperienceFormStyle.text(
                      context,
                      13,
                      weight: widget.selected == category
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: widget.selected == category
                          ? ExperienceFormStyle.selectionInk(context)
                          : ExperienceFormStyle.ink(context),
                    ),
                  ),
                  selectedColor: ExperienceFormStyle.selection(context),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  side: BorderSide(
                    color: widget.selected == category
                        ? Colors.transparent
                        : ExperienceFormStyle.line(context),
                  ),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
