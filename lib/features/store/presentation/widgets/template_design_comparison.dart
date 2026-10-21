import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/template_design_profile.dart';
import 'catalog_edition_artwork.dart';
import 'public_template_information.dart';

enum TemplateDesignComparisonAddResult { added, alreadySelected, limitReached }

/// Selection survives category, search and layout changes by catalog identity.
/// The caller owns it; browsing a comparison does not create or purchase an album.
@immutable
class TemplateDesignComparisonSelection {
  const TemplateDesignComparisonSelection.empty() : ids = const [];

  factory TemplateDesignComparisonSelection.fromIds(Iterable<int> source) {
    final ids = source.toSet().toList(growable: false);
    if (ids.length > limit) {
      throw ArgumentError.value(source, 'source', '최대 $limit개를 비교할 수 있어요.');
    }
    return TemplateDesignComparisonSelection._(List.unmodifiable(ids));
  }

  const TemplateDesignComparisonSelection._(this.ids);
  static const limit = 3;
  static const limitMessage = '디자인은 최대 3개까지 비교할 수 있어요. 선택한 디자인을 빼고 추가해 주세요.';

  final List<int> ids;
  bool get isFull => ids.length == limit;
  bool contains(int id) => ids.contains(id);

  TemplateDesignComparisonAddResult addResult(int id) => contains(id)
      ? TemplateDesignComparisonAddResult.alreadySelected
      : isFull
      ? TemplateDesignComparisonAddResult.limitReached
      : TemplateDesignComparisonAddResult.added;

  TemplateDesignComparisonSelection add(int id) =>
      addResult(id) != TemplateDesignComparisonAddResult.added
      ? this
      : TemplateDesignComparisonSelection.fromIds([...ids, id]);

  TemplateDesignComparisonSelection remove(int id) => contains(id)
      ? TemplateDesignComparisonSelection.fromIds(
          ids.where((item) => item != id),
        )
      : this;

  TemplateDesignComparisonSelection clear() =>
      const TemplateDesignComparisonSelection.empty();
}

/// A controlled tray shared by the app and web catalog.
class TemplateDesignComparisonTray extends StatelessWidget {
  const TemplateDesignComparisonTray({
    super.key,
    required this.designs,
    required this.onRemove,
    required this.onClear,
    required this.onCompare,
  }) : assert(designs.length <= TemplateDesignComparisonSelection.limit);

  final List<PremiumTemplate> designs;
  final ValueChanged<PremiumTemplate> onRemove;
  final VoidCallback onClear;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    if (designs.isEmpty) return const SizedBox.shrink();
    return Material(
      key: const ValueKey('template-comparison-tray'),
      color: Theme.of(context).colorScheme.surface,
      elevation: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ExperienceFormStyle.line(context)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            // Even a 320px-tall viewport retains room to browse the catalog.
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.sizeOf(context).height * .42).clamp(
                96,
                240,
              ),
            ),
            child: SingleChildScrollView(
              primary: false,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '비교할 디자인 ${designs.length}/3',
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final design in designs)
                            Tooltip(
                              message: design.title,
                              child: Material(
                                key: ValueKey(
                                  'comparison-selected-${design.id}',
                                ),
                                color: ExperienceFormStyle.surface(context),
                                shape: StadiumBorder(
                                  side: BorderSide(
                                    color: ExperienceFormStyle.line(context),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        8,
                                        0,
                                        8,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 170,
                                        ),
                                        child: Text(
                                          design.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: ExperienceFormStyle.text(
                                            context,
                                            13,
                                            weight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      key: ValueKey(
                                        'comparison-selected-remove-${design.id}',
                                      ),
                                      tooltip: '${design.title} 비교에서 빼기',
                                      constraints: const BoxConstraints(
                                        minWidth: 48,
                                        minHeight: 48,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      color: ExperienceFormStyle.ink(context),
                                      onPressed: () => onRemove(design),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          FilledButton(
                            key: const ValueKey('template-comparison-open'),
                            style: ExperienceFormStyle.primary(context),
                            onPressed: designs.length >= 2 ? onCompare : null,
                            child: Text(
                              designs.length < 2
                                  ? '하나 더 선택해 주세요'
                                  : '${designs.length}개 비교하기',
                            ),
                          ),
                          TextButton(
                            key: const ValueKey('template-comparison-clear'),
                            onPressed: onClear,
                            child: const Text('선택 비우기'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Uses a route-local copy only to reflect removal immediately while the caller
/// remains the source of catalog selection. No persistence or entitlement writes.
Future<void> showTemplateDesignComparison(
  BuildContext context, {
  required List<PremiumTemplate> designs,
  required ValueChanged<PremiumTemplate> onRemove,
  required VoidCallback onClear,
  required ValueChanged<PremiumTemplate> onOpen,
}) async {
  assert(designs.length <= TemplateDesignComparisonSelection.limit);
  var selected = List<PremiumTemplate>.of(designs);
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (routeContext) => StatefulBuilder(
        builder: (context, setState) => TemplateDesignComparisonView(
          designs: selected,
          onRemove: (design) {
            setState(
              () => selected = selected
                  .where((item) => item.id != design.id)
                  .toList(),
            );
            onRemove(design);
          },
          onClear: () {
            setState(() => selected = []);
            onClear();
          },
          onOpen: (design) {
            Navigator.of(routeContext).pop();
            onOpen(design);
          },
        ),
      ),
    ),
  );
}

/// Fixed artwork stages and aligned fact rows make differences visible without
/// changing the authored canvas. Both axes remain scrollable at large text sizes.
class TemplateDesignComparisonView extends StatefulWidget {
  const TemplateDesignComparisonView({
    super.key,
    required this.designs,
    required this.onRemove,
    required this.onClear,
    required this.onOpen,
  }) : assert(designs.length <= TemplateDesignComparisonSelection.limit);

  final List<PremiumTemplate> designs;
  final ValueChanged<PremiumTemplate> onRemove;
  final VoidCallback onClear;
  final ValueChanged<PremiumTemplate> onOpen;

  @override
  State<TemplateDesignComparisonView> createState() =>
      _TemplateDesignComparisonViewState();
}

class _TemplateDesignComparisonViewState
    extends State<TemplateDesignComparisonView> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          Navigator.of(context).maybePop(),
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        key: const ValueKey('template-comparison-view'),
        appBar: AppBar(
          title: const Text(
            '디자인 비교',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            tooltip: '비교 닫기',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('template-comparison-vertical-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.designs.isEmpty
                              ? '비교할 디자인을 다시 골라 주세요.'
                              : '표지와 대표 내지를 같은 크기로 살펴보세요.',
                          style: ExperienceFormStyle.text(
                            context,
                            14,
                            secondary: true,
                          ),
                        ),
                        if (widget.designs.isNotEmpty)
                          TextButton(
                            key: const ValueKey('comparison-view-clear'),
                            onPressed: widget.onClear,
                            child: const Text('선택 비우기'),
                          ),
                      ],
                    ),
                    if (widget.designs.isNotEmpty) ...[
                      Text(
                        '사진 수는 표지를 포함한 칸 수예요. 같은 사진을 여러 번 쓸 수 있어요.',
                        style: ExperienceFormStyle.text(
                          context,
                          12,
                          secondary: true,
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width < 620 &&
                          widget.designs.length > 1)
                        Text(
                          '옆으로 넘겨 다른 디자인도 비교해 보세요.',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final width = bounds.maxWidth < 620
                              ? (bounds.maxWidth * .9).clamp(248.0, 360.0)
                              : ((bounds.maxWidth - 32) / widget.designs.length)
                                    .clamp(280.0, 420.0);
                          return Scrollbar(
                            controller: _horizontal,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.metrics.axis == Axis.horizontal,
                            child: SingleChildScrollView(
                              key: const ValueKey(
                                'template-comparison-horizontal-scroll',
                              ),
                              controller: _horizontal,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _comparisonTable(context, width),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _comparisonTable(BuildContext context, double columnWidth) {
    final designs = widget.designs;
    TableRow row(Widget Function(PremiumTemplate) build, {bool last = false}) =>
        TableRow(
          children: [
            for (final design in designs)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, last ? 20 : 10),
                  color: ExperienceFormStyle.surface(context),
                  child: build(design),
                ),
              ),
          ],
        );
    Widget fact(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 5),
        value,
      ],
    );
    return Table(
      key: const ValueKey('template-comparison-table'),
      defaultColumnWidth: FixedColumnWidth(columnWidth),
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: [
        row(
          (design) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${designs.indexOf(design) + 1}',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('comparison-remove-${design.id}'),
                    tooltip: '${design.title} 비교에서 빼기',
                    onPressed: () => widget.onRemove(design),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Text(
                design.title,
                style: ExperienceFormStyle.text(
                  context,
                  19,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        row(
          (design) => Semantics(
            image: true,
            label: '${design.title} 표지',
            child: ExcludeSemantics(
              child: AspectRatio(
                aspectRatio: 1,
                child: RepaintBoundary(
                  child: CreationCatalogCover(
                    template: design,
                    useThumbnail: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        row(
          (design) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '대표 내지',
                style: ExperienceFormStyle.text(context, 12, secondary: true),
              ),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 2,
                child:
                    usesLiveCatalogSpreadArtwork(design) ||
                        catalogEditorialSpread(design) != null
                    ? Semantics(
                        image: true,
                        label: '${design.title} 대표 내지 펼침면',
                        child: ExcludeSemantics(
                          child: CatalogSpreadPreview(
                            template: design,
                            decodeWidth: 768,
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          '내지는 디자인 보기에서 확인해 주세요.',
                          style: ExperienceFormStyle.text(
                            context,
                            12,
                            secondary: true,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        row(
          (design) => fact(
            '주제',
            Text(
              design.category ?? '앨범',
              style: ExperienceFormStyle.text(context, 14),
            ),
          ),
        ),
        row((design) {
          final profile = TemplateDesignProfile.of(design);
          return fact(
            '사진 구성',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.photoLabel,
                  style: ExperienceFormStyle.text(
                    context,
                    15,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profile.compositionLabel,
                  style: ExperienceFormStyle.text(context, 13, secondary: true),
                ),
              ],
            ),
          );
        }),
        row(
          (design) => fact(
            '기본 분량',
            Text(
              TemplateDesignProfile.of(design).pageLabel,
              style: ExperienceFormStyle.text(context, 15),
            ),
          ),
        ),
        row(
          (design) => fact(
            '템플릿 이용',
            PublicTemplatePriceLabel(
              key: ValueKey('comparison-price-${design.id}'),
              template: design,
              compact: false,
            ),
          ),
        ),
        row(
          (design) => FilledButton(
            key: ValueKey('comparison-open-${design.id}'),
            style: ExperienceFormStyle.primary(context),
            onPressed: () => widget.onOpen(design),
            child: const Text('디자인 보기'),
          ),
          last: true,
        ),
      ],
    );
  }
}
