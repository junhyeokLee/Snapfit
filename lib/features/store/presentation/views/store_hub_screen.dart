import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/navigation/web_app_location.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../core/constants/snapfit_colors.dart';
import 'material_catalog_screen.dart';
import 'store_screen.dart';

/// Both departments retain search and scroll position, and mount on demand.
class StoreHubScreen extends StatefulWidget {
  const StoreHubScreen({
    super.key,
    this.initialMaterials = false,
    this.onDepartmentChanged,
  });
  final bool initialMaterials;
  final ValueChanged<bool>? onDepartmentChanged;
  @override
  State<StoreHubScreen> createState() => _StoreHubScreenState();
}

class _StoreHubScreenState extends State<StoreHubScreen> {
  late int _index = widget.initialMaterials ? 1 : 0;
  late final Set<int> _visited = {_index};

  @override
  void didUpdateWidget(covariant StoreHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMaterials != oldWidget.initialMaterials) {
      _index = widget.initialMaterials ? 1 : 0;
      _visited.add(_index);
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _selectCatalog(int index) {
    if (_index == index) return;
    setState(() {
      FocusManager.instance.primaryFocus?.unfocus();
      _index = index;
      _visited.add(index);
    });
    widget.onDepartmentChanged?.call(index == 1);
  }

  void _openLibrary() {
    final scope = ExperienceNavigationScope.maybeOf(context);
    if (scope != null) {
      scope.onNavigate(6);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: kIsWeb
              ? const WebAppRouteSettings(WebAppLocation.library)
              : null,
          builder: (_) => const MaterialCatalogScreen(library: true),
        ),
      );
    }
  }

  void _openSearch() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _index == 0
          ? const StoreScreen(searchMode: true)
          : const MaterialCatalogScreen(searchMode: true),
    ),
  );

  double _departmentWidth(BuildContext context) {
    var width = 24.0;
    for (final label in ['템플릿', '꾸밈소재']) {
      final measure = TextPainter(
        text: TextSpan(
          text: label,
          style: ExperienceFormStyle.text(context, 16, weight: FontWeight.w700),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      width += measure.width.clamp(48, double.infinity);
      measure.dispose();
    }
    return width;
  }

  Widget _departments({bool inset = false}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: inset ? 20 : 0),
    child: LayoutBuilder(
      builder: (context, box) {
        final width = _departmentWidth(context);
        final gap = width <= box.maxWidth ? 24.0 : 8.0;
        final tabs = Row(
          key: const ValueKey('store-departments'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, label) in [(0, '템플릿'), (1, '꾸밈소재')]) ...[
              if (index > 0) SizedBox(width: gap),
              Semantics(
                button: true,
                selected: _index == index,
                child: InkWell(
                  key: ValueKey('store-department-$index'),
                  onTap: () => _selectCatalog(index),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: ExperienceFormStyle.text(
                            context,
                            16,
                            weight: FontWeight.w700,
                            color: _index == index
                                ? ExperienceFormStyle.selectionInk(context)
                                : ExperienceFormStyle.muted(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          width: _index == index ? 24 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: ExperienceFormStyle.selectionInk(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
        return width - 24 + gap <= box.maxWidth
            ? tabs
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: tabs,
              );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget body({bool showDepartments = false}) => Column(
      children: [
        if (showDepartments && MediaQuery.viewInsetsOf(context).bottom == 0)
          Align(
            alignment: Alignment.centerLeft,
            child: _departments(inset: true),
          ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: [
              TickerMode(
                enabled: _index == 0,
                child: _visited.contains(0)
                    ? StoreScreen(
                        embedded: true,
                        editorial: true,
                        onBrowseMaterials: () => _selectCatalog(1),
                      )
                    : const SizedBox.shrink(),
              ),
              TickerMode(
                enabled: _index == 1,
                child: _visited.contains(1)
                    ? const MaterialCatalogScreen(embedded: true)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
    if (kIsWeb) {
      return SnapFitWebShell(
        section: WebSection.designs,
        actions: [
          OutlinedButton.icon(
            onPressed: _openLibrary,
            icon: const Icon(Icons.bookmark_outline, size: 18),
            label: const Text('내 디자인 보관함'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WebPageHeading(title: '스토어'),
            const SizedBox(height: 12),
            Expanded(child: body(showDepartments: true)),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) {
        // Large accessibility text gets its own row, not truncated department names.
        final inline =
            MediaQuery.textScalerOf(context).scale(16) <= 26 &&
            _departmentWidth(context) <= box.maxWidth - 176;
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        return Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: ExperienceHeader(
            title: '스토어',
            back: false,
            showDivider: false,
            titleContent: inline && !keyboard ? _departments() : null,
            actions: [
              IconButton(
                tooltip: '스토어 검색',
                onPressed: _openSearch,
                icon: const ExperienceIcon('Search'),
              ),
              IconButton(
                key: const ValueKey('store-department-2'),
                tooltip: '내 디자인',
                onPressed: _openLibrary,
                icon: const ExperienceIcon('Bookmark'),
              ),
            ],
          ),
          body: body(showDepartments: !inline),
        );
      },
    );
  }
}
