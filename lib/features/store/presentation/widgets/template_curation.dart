import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../data/store_curation_provider.dart';
import '../../domain/entities/premium_template.dart';
import 'catalog_edition_artwork.dart';

List<PremiumTemplate> curateTemplates(List<PremiumTemplate> templates) =>
    StoreCuration.templates.resolve(templates, pointShopTemplateKey);

class TemplateCuration extends StatefulWidget {
  const TemplateCuration({
    super.key,
    required this.templates,
    required this.onOpen,
    this.selection = StoreCuration.templates,
  });
  final List<PremiumTemplate> templates;
  final ValueChanged<PremiumTemplate> onOpen;
  final StoreCuration selection;
  @override
  State<TemplateCuration> createState() => _TemplateCurationState();
}

class _TemplateCurationState extends State<TemplateCuration> {
  final _controller = PageController();
  int _index = 0;
  List<PremiumTemplate> _items(TemplateCuration widget) =>
      widget.selection.resolve(widget.templates, pointShopTemplateKey);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TemplateCuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_items(oldWidget).map((t) => t.id).join(',') !=
        _items(widget).map((t) => t.id).join(',')) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  void _move(int direction, int count) {
    if (!_controller.hasClients) return;
    final next = (_index + direction).clamp(0, count - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(next);
    } else {
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items(widget);
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, bounds) {
        final horizontal =
            bounds.maxWidth >= 620 &&
            MediaQuery.textScalerOf(context).scale(24) <= 32;
        final artHeight = horizontal
            ? (MediaQuery.sizeOf(context).height < 600 ? 228.0 : 360.0)
            : (bounds.maxWidth * .96).clamp(270.0, 390.0);
        final titleStyle = ExperienceFormStyle.text(
          context,
          horizontal ? 22 : 25,
          weight: FontWeight.w700,
        ).copyWith(fontFamily: 'BookMyungjo', height: 1.3);
        final titleWidth =
            (bounds.maxWidth * (horizontal ? .4 : 1) -
                    (horizontal ? 48 : 40) -
                    35)
                .clamp(1.0, double.infinity);
        var titleHeight = 0.0;
        // Keep the shelf below still while titles with different lengths change.
        for (final item in items) {
          final measure = TextPainter(
            text: TextSpan(text: item.title, style: titleStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 2,
          )..layout(maxWidth: titleWidth);
          titleHeight = math.max(titleHeight, measure.height);
          measure.dispose();
        }
        final artwork = SizedBox(
          height: artHeight,
          child: PageView.builder(
            key: const ValueKey('curation-pager'),
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final template = items[index];
              return Semantics(
                button: true,
                label: '${template.title} 표지와 내지, 상세 보기',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('curation-edition-${template.id}'),
                    onTap: () => widget.onOpen(template),
                    child: RepaintBoundary(
                      child: StoreEditorialScene(template: template),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        final current = items[_index.clamp(0, items.length - 1)];
        final details = Padding(
          key: const ValueKey('curation-details'),
          padding: EdgeInsets.fromLTRB(horizontal ? 28 : 20, 18, 20, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.selection.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        weight: FontWeight.w600,
                        color: ExperienceFormStyle.selectionInk(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${(_index.clamp(0, items.length - 1) + 1).toString().padLeft(2, '0')} / ${items.length.toString().padLeft(2, '0')}',
                    key: const ValueKey('curation-position'),
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      secondary: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                hint: widget.selection.subtitle,
                child: InkWell(
                  onTap: () => widget.onOpen(current),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: titleHeight,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                current.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ExperienceIcon(
                          'ArrowUpRight',
                          size: 20,
                          color: ExperienceFormStyle.muted(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${current.category ?? '포토북'} · 내지 ${current.pageCount}쪽',
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ),
                  if (items.length > 1) ...[
                    _arrow(-1, items.length),
                    _arrow(1, items.length),
                  ],
                ],
              ),
            ],
          ),
        );
        return horizontal
            ? Row(
                children: [
                  Expanded(flex: 6, child: artwork),
                  Expanded(flex: 4, child: details),
                ],
              )
            : Column(children: [artwork, details]);
      },
    );
  }

  Widget _arrow(int direction, int count) => IconButton(
    tooltip: direction < 0 ? '이전 컬렉션' : '다음 컬렉션',
    onPressed: (direction < 0 ? _index > 0 : _index < count - 1)
        ? () => _move(direction, count)
        : null,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    padding: const EdgeInsets.all(10),
    icon: ExperienceIcon(direction < 0 ? 'ArrowLeft' : 'ArrowRight', size: 20),
  );
}

class StoreEditorialScene extends StatelessWidget {
  const StoreEditorialScene({super.key, required this.template});
  final PremiumTemplate template;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final hasSpread = catalogEditorialSpread(template) != null;
      final width = math.min(bounds.maxWidth, bounds.maxHeight * 1.9);
      final palette = CatalogEditionPalette.of(template.category);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final scene = switch (template.category) {
        '여행' => 0,
        '웨딩' || '커플·기념일' => 1,
        _ => 2,
      };
      final paper = dark
          ? Color.lerp(palette.ink, const Color(0xFF202423), .78)!
          : Color.lerp(palette.paper, Colors.white, .65)!;
      final w = width;
      final h = bounds.maxHeight;
      Widget cover() => CreationCatalogCover(
        template: template,
        useThumbnail: true,
        showBookMaterial: true,
      );
      Widget spread() => CatalogSpreadPreview(
        template: template,
        decodeWidth: bounds.maxWidth >= 560 ? 1024 : 640,
      );
      return Center(
        child: SizedBox(
          width: width,
          height: bounds.maxHeight,
          child: ColoredBox(
            color: paper,
            child: Stack(
              key: ValueKey('curation-scene-$scene'),
              children: switch (scene) {
                0 => [
                  Positioned(
                    left: w * .035,
                    top: h * .055,
                    width: w * .78,
                    height: h * .86,
                    child: cover(),
                  ),
                  if (hasSpread)
                    Positioned(
                      right: w * .035,
                      bottom: h * .015,
                      width: w * .43,
                      height: h * .26,
                      child: Transform.rotate(angle: -.035, child: spread()),
                    ),
                ],
                1 => [
                  Positioned(
                    right: w * .08,
                    top: h * .06,
                    width: w * .44,
                    height: h * .65,
                    child: Transform.rotate(angle: .04, child: cover()),
                  ),
                  if (hasSpread)
                    Positioned(
                      left: w * .04,
                      bottom: h * .07,
                      width: w * .92,
                      height: h * .6,
                      child: Transform.rotate(angle: -.025, child: spread()),
                    )
                  else
                    Positioned(
                      left: w * .05,
                      top: h * .04,
                      width: w * .6,
                      height: h * .9,
                      child: cover(),
                    ),
                ],
                _ => [
                  if (hasSpread)
                    Positioned(
                      left: w * .035,
                      top: h * .12,
                      width: w * .72,
                      height: h * .62,
                      child: Transform.rotate(angle: -.04, child: spread()),
                    ),
                  Positioned(
                    right: w * .065,
                    top: h * .075,
                    width: w * (hasSpread ? .6 : .85),
                    height: h * .86,
                    child: Transform.rotate(angle: .025, child: cover()),
                  ),
                ],
              },
            ),
          ),
        ),
      );
    },
  );
}
