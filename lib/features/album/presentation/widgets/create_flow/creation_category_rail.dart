import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../../../../shared/widgets/experience_form_style.dart';

/// 두 행의 카테고리를 같은 가로 위치에서 탐색하는 단일 선택 목록.
class CreationCategoryRail extends StatefulWidget {
  const CreationCategoryRail({
    super.key,
    required this.topCategories,
    required this.bottomCategories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> topCategories;
  final List<String> bottomCategories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<CreationCategoryRail> createState() => _CreationCategoryRailState();
}

class _CreationCategoryRailState extends State<CreationCategoryRail> {
  final _scrollController = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _revealSelected(preserveRestoredOffset: true),
    );
  }

  @override
  void didUpdateWidget(covariant CreationCategoryRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealSelected());
    }
  }

  void _revealSelected({bool preserveRestoredOffset = false}) {
    if (!mounted || !_scrollController.hasClients) return;
    // 상세에서 돌아왔을 때는 사용자가 탐색하던 위치를 우선 복원한다.
    if (preserveRestoredOffset && _scrollController.offset != 0) return;
    final object = _selectedKey.currentContext?.findRenderObject();
    if (object == null) return;
    final position = _scrollController.position;
    position.ensureVisible(
      object,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    );
    position.ensureVisible(
      object,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = ExperienceFormStyle.text(
      context,
      14,
      weight: FontWeight.w600,
    );
    final widths = <String, double>{};
    var rowHeight = 48.0;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    // 두 행의 짝을 같은 폭으로 맞추되 큰 글자와 긴 주제명은 자르지 않는다.
    for (final label in [...widget.topCategories, ...widget.bottomCategories]) {
      painter.text = TextSpan(text: label, style: textStyle);
      painter.layout();
      widths[label] = (painter.width + 32).ceilToDouble();
      final height = (painter.height + 24).ceilToDouble();
      if (height > rowHeight) rowHeight = height;
    }
    painter.dispose();
    final columnCount =
        widget.topCategories.length > widget.bottomCategories.length
        ? widget.topCategories.length
        : widget.bottomCategories.length;
    final behavior = ScrollConfiguration.of(context);

    return SizedBox(
      key: const ValueKey('creation-category-rail'),
      child: ScrollConfiguration(
        behavior: behavior.copyWith(
          scrollbars: false,
          overscroll: false,
          dragDevices: {
            ...behavior.dragDevices,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: SingleChildScrollView(
          key: const PageStorageKey('creation-category-rail-scroll'),
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < columnCount; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                _column(context, index, widths, rowHeight, textStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _column(
    BuildContext context,
    int index,
    Map<String, double> widths,
    double rowHeight,
    TextStyle textStyle,
  ) {
    final top = index < widget.topCategories.length
        ? widget.topCategories[index]
        : null;
    final bottom = index < widget.bottomCategories.length
        ? widget.bottomCategories[index]
        : null;
    var width = 100.0;
    for (final label in [top, bottom]) {
      final labelWidth = widths[label] ?? 0;
      if (labelWidth > width) width = labelWidth;
    }
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: rowHeight,
            child: top == null ? null : _chip(context, top, textStyle),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: rowHeight,
            child: bottom == null ? null : _chip(context, bottom, textStyle),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, TextStyle textStyle) {
    final selected = widget.selected == label;
    final style = selected
        ? ExperienceFormStyle.primary(context)
        : FilledButton.styleFrom(
            backgroundColor: ExperienceFormStyle.surface(context),
            foregroundColor: ExperienceFormStyle.ink(context),
            elevation: 0,
          );
    void select() => widget.onSelected(label);
    return Semantics(
      key: ValueKey('creation-category-$label'),
      label: label,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      onTap: select,
      child: ExcludeSemantics(
        child: FilledButton(
          key: selected ? _selectedKey : null,
          onPressed: select,
          style: style.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
            textStyle: WidgetStatePropertyAll(textStyle),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
          child: Text(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }
}
