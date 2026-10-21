import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../shared/web/web_design.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/templates/authored_collections.dart';
import '../../../../core/templates/data_template_engine.dart';
import '../../../../core/templates/template_document_pages.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/presentation/widgets/create_flow/creation_document_preview.dart';
import '../../../point_shop/presentation/point_shop_access.dart';

Future<int?> showTemplateEditionSheet(
  BuildContext context, {
  required PremiumVolume volume,
  required String title,
  required String productKey,
  required int initialCount,
  String? previewVariant,
}) => kIsWeb
    ? showWebAwareDialog<int>(
        context: context,
        maxWidth: 1040,
        maxHeight: 820,
        builder: (_) => TemplateEditionSheet(
          volume: volume,
          title: title,
          productKey: productKey,
          initialCount: initialCount,
          previewVariant: previewVariant,
        ),
      )
    : showModalBottomSheet<int>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: SnapFitColors.backgroundOf(context),
        constraints: const BoxConstraints(maxWidth: 840),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
        builder: (_) => TemplateEditionSheet(
          volume: volume,
          title: title,
          productKey: productKey,
          initialCount: initialCount,
          previewVariant: previewVariant,
        ),
      );

class TemplateEditionSheet extends StatefulWidget {
  const TemplateEditionSheet({
    super.key,
    required this.volume,
    required this.title,
    required this.productKey,
    required this.initialCount,
    this.previewVariant,
  });

  final PremiumVolume volume;
  final String title, productKey;
  final int initialCount;
  final String? previewVariant;

  @override
  State<TemplateEditionSheet> createState() => _TemplateEditionSheetState();
}

class _TemplateEditionSheetState extends State<TemplateEditionSheet> {
  late int _count = widget.volume.pageCounts.contains(widget.initialCount)
      ? widget.initialCount
      : widget.volume.extendedPages;
  int _page = 0;
  final _previews = <int, _EditionPreview>{};

  _EditionPreview get _preview => _previews.putIfAbsent(_count, () {
    final aspect =
        CollectionAspect.values
            .where((aspect) => aspect.name == widget.previewVariant)
            .firstOrNull ??
        CollectionAspect.square;
    final shown = refinePaidCatalogDocument(
      widget.volume.id,
      aspect,
      widget.volume.document(aspect, innerPages: _count),
    );
    final canvas = Size(
      (shown['designWidth'] as num).toDouble(),
      (shown['designHeight'] as num).toDouble(),
    );
    final pages = templateDocumentPages(shown)
        .map(
          (page) => DataTemplateEngine.buildLayersFromJson({
            'strictLayout': true,
            'designWidth': canvas.width,
            'designHeight': canvas.height,
            'layers': page['layers'] ?? const [],
          }, canvas),
        )
        .toList(growable: false);
    return _EditionPreview(canvas, pages);
  });

  void _select(int count) {
    if (_count == count) return;
    setState(() {
      _count = count;
      // Preserve the inspected page where possible, including a shortened edition.
      _page = _page.clamp(0, _preview.pages.length - 1);
    });
  }

  Widget _options(_EditionPreview preview) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '내지 분량',
        style: ExperienceFormStyle.text(context, 13, weight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          key: const ValueKey('template-edition-selector'),
          showSelectedIcon: false,
          segments: [
            for (final count in widget.volume.pageCounts)
              ButtonSegment<int>(
                value: count,
                label: Column(
                  key: ValueKey('template-edition-$count'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == PremiumVolume.minimumPages ? '기본판' : '확장판',
                      style: ExperienceFormStyle.text(context, 11),
                    ),
                    Text(
                      '$count쪽',
                      style: ExperienceFormStyle.text(
                        context,
                        16,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          selected: {_count},
          onSelectionChanged: (value) => _select(value.single),
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            backgroundColor: ExperienceFormStyle.surface(context),
            selectedBackgroundColor: ExperienceFormStyle.selection(context),
            foregroundColor: ExperienceFormStyle.ink(context),
            selectedForegroundColor: ExperienceFormStyle.selectionInk(context),
            side: BorderSide(color: ExperienceFormStyle.line(context)),
            shape: const StadiumBorder(),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text(
        '표지 + 내지 $_count쪽',
        key: const ValueKey('template-edition-summary'),
        style: ExperienceFormStyle.text(context, 14, weight: FontWeight.w600),
      ),
      Text(
        '사진 자리 ${preview.photoCount}개 · 분량별 템플릿 가격 동일',
        key: const ValueKey('template-edition-photo-count'),
        style: ExperienceFormStyle.text(context, 12, secondary: true),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).vertical;
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final wide = bounds.maxWidth >= 600;
          return SizedBox(
            key: const ValueKey('template-edition-sheet'),
            height: math.min(
              700,
              math.min(bounds.maxHeight, availableHeight) * .94,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '앨범 분량',
                              style: ExperienceFormStyle.text(
                                context,
                                18,
                                weight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ExperienceFormStyle.text(
                                context,
                                12,
                                secondary: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '분량 선택 닫기',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 22),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, content) {
                      final artwork = CreationDocumentPreview(
                        key: const ValueKey('template-edition-preview'),
                        pages: preview.pages,
                        canvas: preview.canvas,
                        preserveTypography: true,
                        showBookMaterial: !kIsWeb,
                        showThumbnails: false,
                        initialPage: _page,
                        onPageChanged: (page) => _page = page,
                      );
                      return wide
                          ? Row(
                              children: [
                                Expanded(child: artwork),
                                const SizedBox(width: 20),
                                SizedBox(
                                  width: 260,
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: _options(preview),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: math.max(
                                      180,
                                      content.maxHeight - 180,
                                    ),
                                    child: artwork,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      16,
                                      20,
                                      20,
                                    ),
                                    child: _options(preview),
                                  ),
                                ],
                              ),
                            );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: ExperienceFormStyle.line(context)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: PointShopProductBadge(
                          productKey: widget.productKey,
                          unlistedLabel: '판매 준비 중',
                          compact: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: FilledButton(
                          key: const ValueKey('template-edition-continue'),
                          style: ExperienceFormStyle.primary(context),
                          onPressed: () => Navigator.pop(context, _count),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Flexible(child: Text('이 분량으로 계속')),
                              const SizedBox(width: 8),
                              const ExperienceIcon('ArrowRight', size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditionPreview {
  _EditionPreview(this.canvas, this.pages)
    : photoCount = pages.fold(
        0,
        (total, page) =>
            total + page.where((layer) => layer.type == LayerType.image).length,
      );

  final Size canvas;
  final List<List<LayerModel>> pages;
  final int photoCount;
}
