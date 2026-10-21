import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/templates/published_premium_templates.dart';
import '../../../../core/templates/template_document_pages.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_product.dart';
import '../../../point_shop/domain/point_shop_template_key.dart';
import '../../domain/entities/premium_template.dart';

final _factsCache = Expando<PublicTemplateFacts>();

final publicPointShopCatalogProvider = FutureProvider<List<PointShopProduct>>(
  (ref) => ref
      .watch(pointShopRepositoryProvider)
      .loadCatalog()
      .timeout(const Duration(seconds: 12)),
  retry: (_, __) => null,
);

/// Public document facts do not imply a purchase or individual material rights.
class PublicTemplateFacts {
  const PublicTemplateFacts({
    required this.innerPageCount,
    required this.designShapes,
    required this.printSizes,
    this.availablePageCounts = const [],
  });

  final int? innerPageCount;
  final List<String> designShapes;
  final List<CoverSize> printSizes;
  final List<int> availablePageCounts;

  factory PublicTemplateFacts.fromTemplate(PremiumTemplate template) {
    final cached = _factsCache[template];
    if (cached != null) return cached;
    int? innerPageCount;
    final ratios = <double>[];
    void readCanvas(Map<dynamic, dynamic> node) {
      final metadata = node['metadata'];
      final width =
          node['designWidth'] ??
          (metadata is Map ? metadata['designWidth'] : null);
      final height =
          node['designHeight'] ??
          (metadata is Map ? metadata['designHeight'] : null);
      if (width is num &&
          height is num &&
          width.isFinite &&
          height.isFinite &&
          width > 0 &&
          height > 0) {
        ratios.add(width / height);
      }
    }

    try {
      final raw = jsonDecode(template.templateJson ?? 'null');
      if (raw is Map<String, dynamic>) {
        final pages = templateDocumentPages(raw);
        // The detail reader and creation flow treat the first page as a cover.
        if (pages.isNotEmpty) innerPageCount = pages.length - 1;
        readCanvas(raw);
        final variants = raw['variants'];
        final nodes = variants is Map
            ? variants.values
            : variants is List
            ? variants
            : const [];
        for (final node in nodes.whereType<Map>()) {
          if (templateDocumentPages(
            Map<String, dynamic>.from(node),
          ).isNotEmpty) {
            readCanvas(node);
          }
        }
      }
    } on FormatException {
      // Unknown metadata stays unknown rather than becoming a guessed size.
    } on TypeError {
      // A malformed optional document must not prevent browsing its artwork.
    }
    final shapes = <String>{
      for (final ratio in ratios)
        if ((ratio - 1).abs() < .01)
          '정사각형'
        else if (ratio > 1)
          '가로형'
        else
          '세로형',
    }.toList(growable: false);
    final facts = PublicTemplateFacts(
      innerPageCount: innerPageCount,
      designShapes: List.unmodifiable(shapes),
      printSizes: List.unmodifiable([
        for (final size in coverSizes)
          if (ratios.any((ratio) => (ratio - size.ratio).abs() < .01)) size,
      ]),
      availablePageCounts: List.unmodifiable(
        publishedPremiumVolume(template.id)?.pageCounts ?? const [],
      ),
    );
    _factsCache[template] = facts;
    return facts;
  }

  String get pageLabel =>
      innerPageCount == null ? '쪽수 확인 필요' : '내지 $innerPageCount쪽';
  String get shapeLabel =>
      designShapes.isEmpty ? '모양 확인 필요' : designShapes.join(' · ');
  String get compactLabel => '$pageLabel · $shapeLabel';
}

({String label, bool retry}) publicCatalogPrice(
  String productKey,
  AsyncValue<List<PointShopProduct>> catalog,
) {
  if (catalog.isLoading) return (label: '가격 확인 중', retry: false);
  if (catalog.hasError) return (label: '가격을 확인하지 못했어요', retry: true);
  final matches = catalog.asData?.value.where(
    (product) => product.productKey == productKey,
  );
  if (matches == null || matches.length != 1) {
    return (label: '가격 준비 중', retry: false);
  }
  final product = matches.single;
  final price = product.pointPrice;
  if (!product.isActive || price == null || price < 0) {
    return (label: '판매 준비 중', retry: false);
  }
  return (
    label: price == 0
        ? '무료 (0P)'
        : '${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}P',
    retry: false,
  );
}

class PublicTemplatePriceLabel extends StatelessWidget {
  const PublicTemplatePriceLabel({
    super.key,
    required this.template,
    this.compact = true,
  });
  final PremiumTemplate template;
  final bool compact;

  @override
  Widget build(BuildContext context) => PublicCatalogPriceLabel(
    productKey: pointShopTemplateKey(template),
    compact: compact,
  );
}

/// Only the publicly readable product catalog is watched here. Ownership,
/// balance and access RPCs remain behind the existing signed-in use action.
class PublicCatalogPriceLabel extends ConsumerWidget {
  const PublicCatalogPriceLabel({
    super.key,
    required this.productKey,
    this.compact = true,
  });
  final String productKey;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = publicCatalogPrice(
      productKey,
      ref.watch(publicPointShopCatalogProvider),
    );
    return Column(
      key: ValueKey('public-price-$productKey'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: price.label,
          child: Text(
            price.label,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : null,
            style: TextStyle(
              fontSize: compact ? 12 : 18,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (price.retry && !compact)
          TextButton.icon(
            key: ValueKey('public-price-retry-$productKey'),
            onPressed: () => ref.invalidate(publicPointShopCatalogProvider),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('가격 다시 확인'),
          ),
      ],
    );
  }
}

class PublicTemplateInformation extends StatelessWidget {
  const PublicTemplateInformation({super.key, required this.template});
  final PremiumTemplate template;

  @override
  Widget build(BuildContext context) {
    final facts = PublicTemplateFacts.fromTemplate(template);
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('public-template-information'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '디자인 이용 안내',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          PublicTemplatePriceLabel(template: template, compact: false),
          const SizedBox(height: 12),
          Text('${facts.pageLabel} · 표지 별도'),
          if (facts.availablePageCounts.length > 1) ...[
            const SizedBox(height: 6),
            Text('선택 가능한 내지 구성: ${facts.availablePageCounts.join(' / ')}쪽'),
          ],
          const SizedBox(height: 6),
          Text('디자인 모양: ${facts.shapeLabel}'),
          const SizedBox(height: 6),
          Text(
            facts.printSizes.isEmpty
                ? '같은 비율의 인쇄 규격은 아직 확인되지 않았어요.'
                : '같은 비율의 인쇄 규격: ${facts.printSizes.map((size) => size.displayName).join(' · ')}',
          ),
          if (facts.designShapes.contains('세로형')) ...[
            const SizedBox(height: 6),
            const Text('세로형은 화면용 디자인 모양이며 현재 공식 인쇄 규격과 달라요.'),
          ],
          const SizedBox(height: 14),
          const Text(
            '이용 가능 조건을 충족하면 표지와 내지에 내 사진과 글을 넣어 앨범을 만들 수 있어요. 샘플 사진은 포함되지 않아요.',
          ),
          const SizedBox(height: 8),
          const Text(
            '디자인 안에 배치된 꾸밈 소재는 그 상태로 사용할 수 있어요. 다른 앨범에 개별 추가할 권한은 소재별로 확인해요.',
          ),
          const SizedBox(height: 8),
          Text(
            '디자인 이용 포인트와 인쇄·배송 비용은 별도예요. 로그인 후 보유 여부와 최종 이용 조건을 다시 확인하며, 인쇄 가능 여부와 비용은 인쇄 검토에서 확인해요.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
          ),
        ],
      ),
    );
  }
}
