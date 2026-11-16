import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../album/presentation/widgets/create_flow/creation_catalog_cover.dart';
import '../../../album/presentation/widgets/create_flow/creation_template_image.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../../point_shop/presentation/point_shop_access.dart';
import '../../domain/entities/premium_template.dart';
import '../../domain/store_template_discovery.dart';
import 'catalog_edition_artwork.dart';
import 'public_template_information.dart';

class TemplateRelatedSection extends StatefulWidget {
  const TemplateRelatedSection({
    super.key,
    required this.recommendations,
    required this.onOpen,
    this.guestPreview = false,
  });

  final List<RelatedStoreTemplate> recommendations;
  final ValueChanged<PremiumTemplate> onOpen;
  final bool guestPreview;

  @override
  State<TemplateRelatedSection> createState() => _TemplateRelatedSectionState();
}

class _TemplateRelatedSectionState extends State<TemplateRelatedSection> {
  final _scroll = ScrollController();
  bool _canPrevious = false, _canNext = false;
  double _cardExtent = 200;

  @override
  void initState() {
    super.initState();
    _canNext = widget.recommendations.length > 1;
    _scroll.addListener(_updateNavigation);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateNavigation() {
    if (!mounted || !_scroll.hasClients) return;
    final previous = _scroll.offset > 1;
    final next = _scroll.offset < _scroll.position.maxScrollExtent - 1;
    if (previous == _canPrevious && next == _canNext) return;
    setState(() {
      _canPrevious = previous;
      _canNext = next;
    });
  }

  void _move(int direction) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * _cardExtent).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (SnapFitMotion.reduced(context)) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(
        target,
        duration: SnapFitMotion.duration(context, SnapFitMotion.medium),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recommendations.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('template-related-section'),
      padding: const EdgeInsets.only(top: 26),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              '비슷한 분위기',
              style: ExperienceFormStyle.text(
                context,
                19,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '닮은 취향, 다른 이야기',
            style: ExperienceFormStyle.text(context, 12, secondary: true),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, bounds) {
              final largeText =
                  MediaQuery.textScalerOf(context).scale(13) > 19.5;
              const gap = 14.0;
              final width = largeText
                  ? (bounds.maxWidth * .9).clamp(180.0, 360.0)
                  : bounds.maxWidth >= 700
                  ? ((bounds.maxWidth - gap * 2) / 3).clamp(180.0, 320.0)
                  : (bounds.maxWidth * .56).clamp(156.0, 260.0);
              _cardExtent = width + gap;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _updateNavigation(),
              );
              // A horizontal single-child viewport takes the tallest card's
              // natural height. Large text and price states never rely on a
              // guessed fixed rail height or truncate a title to fit it.
              return NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _updateNavigation(),
                  );
                  return false;
                },
                child: SingleChildScrollView(
                  key: const ValueKey('template-related-rail'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (
                        var i = 0;
                        i < widget.recommendations.length;
                        i++
                      ) ...[
                        if (i > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: width,
                          child: _RelatedTemplateCard(
                            recommendation: widget.recommendations[i],
                            guestPreview: widget.guestPreview,
                            onOpen: () => widget.onOpen(
                              widget.recommendations[i].template,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          if (widget.recommendations.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.recommendations.length}개의 다른 이야기',
                    style: ExperienceFormStyle.text(
                      context,
                      11,
                      secondary: true,
                    ),
                  ),
                ),
                if (_canPrevious || _canNext) ...[
                  IconButton(
                    key: const ValueKey('template-related-previous'),
                    tooltip: '이전 추천 디자인',
                    onPressed: _canPrevious ? () => _move(-1) : null,
                    icon: ExperienceIcon(
                      'ArrowLeft',
                      size: 18,
                      color: _canPrevious
                          ? ExperienceFormStyle.ink(context)
                          : ExperienceFormStyle.muted(
                              context,
                            ).withValues(alpha: .35),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    key: const ValueKey('template-related-next'),
                    tooltip: '다음 추천 디자인',
                    onPressed: _canNext ? () => _move(1) : null,
                    icon: ExperienceIcon(
                      'ArrowRight',
                      size: 18,
                      color: _canNext
                          ? ExperienceFormStyle.ink(context)
                          : ExperienceFormStyle.muted(
                              context,
                            ).withValues(alpha: .35),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _compactReason(String reason) {
  if (reason.startsWith('같은 ') && reason.endsWith(' 이야기')) {
    return reason.substring(0, reason.length - ' 이야기'.length);
  }
  return reason
      .replaceFirst(' 분위기가 닮았어요', ' 무드')
      .replaceFirst(' 취향이 닮았어요', ' 취향');
}

class _RelatedTemplateCard extends StatelessWidget {
  const _RelatedTemplateCard({
    required this.recommendation,
    required this.onOpen,
    required this.guestPreview,
  });
  final RelatedStoreTemplate recommendation;
  final VoidCallback onOpen;
  final bool guestPreview;

  @override
  Widget build(BuildContext context) {
    final template = recommendation.template;
    final palette = CatalogEditionPalette.of(template.category);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final productKey = pointShopTemplateKey(template);
    final largeText = MediaQuery.textScalerOf(context).scale(13) > 19.5;
    return SnapFitPressable(
      semanticLabel: '${template.title} 상세 보기, ${recommendation.reason}',
      pressedScale: .99,
      borderRadius: BorderRadius.circular(16),
      onTap: onOpen,
      child: Padding(
        key: ValueKey('template-related-${template.id}'),
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: largeText ? 1.25 : .96,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? [
                              Color.lerp(
                                palette.ink,
                                const Color(0xFF202726),
                                .65,
                              )!,
                              const Color(0xFF202726),
                            ]
                          : [
                              Color.lerp(palette.paper, Colors.white, .12)!,
                              Color.lerp(palette.paper, Colors.white, .5)!,
                            ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: RepaintBoundary(
                      child: usesLiveCatalogArtwork(template)
                          ? CreationCatalogCover(
                              template: template,
                              useThumbnail: true,
                            )
                          : CreationTemplateImage(
                              url: template.coverImageUrl,
                              decodeWidth: 384,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Tooltip(
              message: recommendation.reason,
              child: Container(
                key: ValueKey('template-related-reason-${template.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ExperienceFormStyle.selection(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _compactReason(recommendation.reason),
                  style: ExperienceFormStyle.text(
                    context,
                    11,
                    color: ExperienceFormStyle.selectionInk(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.title,
              style: ExperienceFormStyle.text(
                context,
                14,
                weight: FontWeight.w600,
              ).copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${template.pageCount}쪽',
                  style: ExperienceFormStyle.text(context, 11, secondary: true),
                ),
                guestPreview
                    ? PublicCatalogPriceLabel(productKey: productKey)
                    : PointShopProductBadge(
                        productKey: productKey,
                        unlistedLabel: template.isPremium ? '가격 확인 중' : '무료',
                        fontSize: 12,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
