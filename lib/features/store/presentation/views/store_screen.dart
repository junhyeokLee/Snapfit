import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/platform_ui.dart';
import '../../../../core/utils/image_url_policy.dart';
import '../../../album/domain/entities/layer.dart';
import '../../../album/domain/entities/layer_export_mapper.dart';
import '../../data/api/template_provider.dart';
import '../../domain/entities/premium_template.dart';
import '../widgets/premium_template_list.dart';
import '../widgets/template_page_renderer.dart';
import 'template_detail_screen.dart';

String _storeCoverPreviewUrl(PremiumTemplate template) {
  final cover = template.coverImageUrl.trim();
  if (cover.isNotEmpty) return cover;
  final previews = template.previewImages
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
  if (previews.isNotEmpty) return previews.first;
  return '';
}

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templateListProvider);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      body: SafeArea(
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _StoreErrorView(
            onRetry: () => ref.invalidate(templateListProvider),
          ),
          data: (templates) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(templateListProvider);
              await ref.read(templateListProvider.future);
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: platformScrollPhysics(alwaysScrollable: true),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),
                      const PremiumTemplateList(maxItems: 3),
                      const SizedBox(height: 28),
                      const _AllTemplatesHeader(),
                      const SizedBox(height: 14),
                    ]),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  sliver: templates.isEmpty
                      ? const SliverToBoxAdapter(
                          child: _EmptyState(message: '템플릿을 준비 중입니다.'),
                        )
                      : SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 14,
                                childAspectRatio: 0.62,
                              ),
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final template = templates[index];
                            return _TemplateGridCard(
                              template: template,
                              onTap: () => _openDetail(template),
                            );
                          }, childCount: templates.length),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  void _openDetail(PremiumTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateDetailScreen(template: template),
      ),
    );
  }
}

class _AllTemplatesHeader extends StatelessWidget {
  const _AllTemplatesHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '모든 템플릿',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: SnapFitColors.textPrimaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateGridCard extends StatelessWidget {
  final PremiumTemplate template;
  final VoidCallback onTap;

  const _TemplateGridCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = template.isPremium ? 'PREMIUM' : 'FREE';
    final labelColor = template.isPremium
        ? SnapFitColors.accent
        : SnapFitColors.textSecondaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _StoreTemplateCoverPreview(template: template),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.62)
                            : Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${template.likeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            template.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _StoreErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '템플릿을 불러오지 못했어요.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: SnapFitColors.textSecondaryOf(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StoreTemplateCoverPreview extends StatelessWidget {
  final PremiumTemplate template;

  const _StoreTemplateCoverPreview({required this.template});

  @override
  Widget build(BuildContext context) {
    final directCoverUrl = _storeCoverPreviewUrl(template);
    if (directCoverUrl.isNotEmpty) {
      return _NetworkImage(url: directCoverUrl, variant: ImageVariant.thumb);
    }
    final parsed = _parseFirstPage(template);
    if (parsed != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final targetAspect = parsed.$2;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final drawWidth = math.min(maxWidth, maxHeight * targetAspect);
          final drawHeight = drawWidth / targetAspect;
          return Container(
            color: SnapFitColors.overlayLightOf(context),
            alignment: Alignment.center,
            child: SizedBox(
              width: drawWidth,
              height: drawHeight,
              child: TemplatePageRenderer(
                layers: parsed.$1,
                width: drawWidth,
                height: drawHeight,
                designCanvasSize: parsed.$3,
              ),
            ),
          );
        },
      );
    }
    return _NetworkImage(url: directCoverUrl, variant: ImageVariant.thumb);
  }
}

(List<LayerModel>, double, Size)? _parseFirstPage(PremiumTemplate template) {
  final raw = template.templateJson;
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final metadata =
        (data['metadata'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final pages = data['pages'];
    if (pages is! List || pages.isEmpty) return null;
    final page = pages.first;
    if (page is! Map<String, dynamic>) return null;
    final layersJson = page['layers'];
    if (layersJson is! List || layersJson.isEmpty) return null;

    final designWidth =
        (data['designWidth'] as num?)?.toDouble() ??
        (metadata['designWidth'] as num?)?.toDouble() ??
        1080.0;
    final designHeight =
        (data['designHeight'] as num?)?.toDouble() ??
        (metadata['designHeight'] as num?)?.toDouble() ??
        1440.0;
    final canvasSize = Size(designWidth, designHeight);
    final layers = layersJson
        .whereType<Map<String, dynamic>>()
        .map(
          (layer) => LayerExportMapper.fromJson(layer, canvasSize: canvasSize),
        )
        .toList(growable: false);
    if (layers.isEmpty) return null;
    final aspect = (designWidth / designHeight).clamp(0.6, 1.8);
    return (layers, aspect, canvasSize);
  } catch (_) {
    return null;
  }
}

class _NetworkImage extends StatelessWidget {
  final String url;
  final ImageVariant variant;

  const _NetworkImage({required this.url, this.variant = ImageVariant.thumb});

  @override
  Widget build(BuildContext context) {
    final bundledAsset = bundledTemplateAssetPath(url);
    if (bundledAsset != null) {
      return Image.asset(
        bundledAsset,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      );
    }
    final transformed = imageUrlByVariant(url, variant: variant);
    if (transformed.startsWith('asset:')) {
      return Image.asset(
        transformed.substring('asset:'.length),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            size: 32,
            color: SnapFitColors.textMutedOf(context),
          ),
        ),
      );
    }
    return Image.network(
      transformed,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Container(
        color: SnapFitColors.overlayLightOf(context),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          size: 32,
          color: SnapFitColors.textMutedOf(context),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: SnapFitColors.overlayLightOf(context),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}
