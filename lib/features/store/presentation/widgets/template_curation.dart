import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
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
  final _controller = PageController(viewportFraction: .94);
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TemplateCuration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.selection.resolve(
      widget.templates,
      pointShopTemplateKey,
    );
    if (items.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth * .94 > 500;
        final artworkHeight = wide ? 264.0 : 246.0;
        final infoHeight = scale.scale(20) * 2.8 + scale.scale(11) * 1.5 + 62;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CURATED BY SNAPFIT',
                    style: ExperienceFormStyle.text(
                      context,
                      10,
                      weight: FontWeight.w600,
                      secondary: true,
                    ),
                  ),
                ),
                Text(
                  '${(_index.clamp(0, items.length - 1) + 1).toString().padLeft(2, '0')} / ${items.length.toString().padLeft(2, '0')}',
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              widget.selection.title,
              style: ExperienceFormStyle.text(
                context,
                21,
                weight: FontWeight.w600,
              ).copyWith(height: 1.35),
            ),
            if (widget.selection.subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.selection.subtitle,
                style: ExperienceFormStyle.text(
                  context,
                  12,
                  secondary: true,
                ).copyWith(height: 1.55),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: wide
                  ? (infoHeight > artworkHeight ? infoHeight : artworkHeight)
                  : artworkHeight + infoHeight,
              child: PageView.builder(
                key: const ValueKey('curation-pager'),
                controller: _controller,
                itemCount: items.length,
                padEnds: false,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final template = items[i];
                  final palette = CatalogEditionPalette.of(template.category);
                  final art = ColoredBox(
                    color: palette.ink,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          top: 24,
                          bottom: 12,
                          child: CatalogEditionArtwork(template: template),
                        ),
                        Positioned(
                          left: 16,
                          top: 13,
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                color: palette.accent,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                '${template.category ?? '앨범'} COLLECTION',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  final details = Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${template.category ?? '포토북'} · ${template.pageCount}쪽',
                          style: ExperienceFormStyle.text(
                            context,
                            11,
                            secondary: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          template.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ExperienceFormStyle.text(
                            context,
                            20,
                            weight: FontWeight.w600,
                          ).copyWith(fontFamily: 'BookMyungjo', height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: PointShopProductBadge(
                                productKey: pointShopTemplateKey(template),
                                compact: false,
                                unlistedLabel: template.isPremium
                                    ? '판매 준비 중'
                                    : '무료',
                              ),
                            ),
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: palette.ink,
                              child: const ExperienceIcon(
                                'ArrowRight',
                                size: 19,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Semantics(
                      button: true,
                      label: '${template.title} 표지와 내지, 상세 보기',
                      child: Material(
                        color: ExperienceFormStyle.surface(context),
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('curation-edition-${template.id}'),
                          onTap: () => widget.onOpen(template),
                          child: wide
                              ? Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(flex: 6, child: art),
                                    Expanded(flex: 4, child: details),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(height: artworkHeight, child: art),
                                    Expanded(child: details),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(right: 3),
                            color: ExperienceFormStyle.ink(
                              context,
                            ).withValues(alpha: i == _index ? .9 : .12),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: '이전 컬렉션',
                  onPressed: _index > 0
                      ? () => _controller.previousPage(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        )
                      : null,
                  icon: const ExperienceIcon('ArrowLeft', size: 19),
                ),
                IconButton(
                  tooltip: '다음 컬렉션',
                  onPressed: _index < items.length - 1
                      ? () => _controller.nextPage(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        )
                      : null,
                  icon: const ExperienceIcon('ArrowRight', size: 19),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
