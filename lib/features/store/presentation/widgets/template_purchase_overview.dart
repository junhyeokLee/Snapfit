import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/templates/free_template_material_policy.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../point_shop/domain/point_shop_product.dart';
import '../../../point_shop/presentation/point_shop_access.dart';

/// Visual inclusion is not an entitlement. Only owned keys or free products
/// qualify for individual reuse; unknown catalog entries stay unconfirmed.
({bool reusable, String label}) templateMaterialReuse(
  String key,
  AsyncValue<List<PointShopProduct>> catalog,
  AsyncValue<Set<String>> owned,
) {
  if (owned.asData?.value.contains(key) == true) {
    return (reusable: true, label: '재사용 가능 · 구매 완료');
  }
  final product = catalog.asData?.value
      .where((item) => item.productKey == key)
      .firstOrNull;
  if (product != null) {
    if (!product.isActive || product.pointPrice == null) {
      return (reusable: false, label: '개별 사용 판매 준비 중');
    }
    if (product.pointPrice == 0) {
      return (reusable: true, label: '재사용 가능 · 무료');
    }
    if (owned.isLoading || owned.hasError) {
      return (
        reusable: false,
        label: owned.hasError ? '보유 권한 확인 필요' : '보유 권한 확인 중',
      );
    }
    return (reusable: false, label: '다른 앨범 사용 · ${product.pointPrice}P');
  }
  if (freeTemplateMaterialProductKeys.contains(key)) {
    return (reusable: true, label: '재사용 가능 · 무료');
  }
  return (
    reusable: false,
    label: catalog.isLoading ? '이용 권한 확인 중' : '개별 사용 권한 확인 필요',
  );
}

class TemplateMaterialReuseLabel extends ConsumerWidget {
  const TemplateMaterialReuseLabel({super.key, required this.productKey});
  final String productKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = templateMaterialReuse(
      productKey,
      ref.watch(pointShopCatalogProvider),
      ref.watch(ownedPointShopKeysProvider),
    );
    return Text(
      usage.label,
      key: ValueKey('template-material-reuse-$productKey'),
      style: ExperienceFormStyle.text(
        context,
        12,
        color: usage.reusable
            ? ExperienceFormStyle.selectionInk(context)
            : ExperienceFormStyle.muted(context),
      ),
    );
  }
}

class TemplatePurchaseOverview extends ConsumerWidget {
  const TemplatePurchaseOverview({
    super.key,
    required this.productKey,
    required this.materialKeys,
    required this.isPublishedFree,
    required this.onMaterials,
  });

  final String productKey;
  final Set<String> materialKeys;
  final bool isPublishedFree;
  final VoidCallback onMaterials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(pointShopCatalogProvider);
    final owned = ref.watch(ownedPointShopKeysProvider);
    final reusable = materialKeys
        .where((key) => templateMaterialReuse(key, catalog, owned).reusable)
        .length;
    return Container(
      key: const ValueKey('template-purchase-overview'),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isPublishedFree ? '무료 템플릿 안내' : '템플릿 구매 안내',
                  style: ExperienceFormStyle.text(
                    context,
                    17,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: PointShopProductBadge(
                    key: const ValueKey('template-overview-price'),
                    productKey: productKey,
                    unlistedLabel: isPublishedFree ? '무료' : '판매 준비 중',
                    compact: false,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          if (materialKeys.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: ExperienceFormStyle.surface(context),
                border: Border(
                  left: BorderSide(
                    color: ExperienceFormStyle.selectionInk(context),
                    width: 2,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 14,
                  children: [
                    for (final kind in const {
                      'frame': '사진 프레임',
                      'sticker': '종이·스티커',
                      'phrase': '문구 디자인',
                    }.entries)
                      if (materialKeys.any(
                        (key) => key.startsWith('${kind.key}:'),
                      ))
                        _MaterialCount(
                          title: kind.value,
                          count: materialKeys
                              .where((key) => key.startsWith('${kind.key}:'))
                              .length,
                        ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          _UsageLine(
            icon: 'BookOpen',
            title: '내 사진으로 만드는 앨범',
            detail: '표지와 내지 디자인을 사용할 수 있어요. 샘플 사진은 포함되지 않아요.',
          ),
          const SizedBox(height: 16),
          _UsageLine(
            icon: 'Shapes',
            title: '디자인에 배치된 꾸밈 소재 ${materialKeys.length}종',
            detail: isPublishedFree
                ? '무료 소재만으로 구성했어요. 프레임·스티커·문구를 별도로 구매할 필요 없이 나의 사진으로 완성할 수 있어요.'
                : '이 템플릿 안의 소재는 배치된 상태로 사용할 수 있어요. 템플릿 구매만으로 개별 소재 이용권이 지급되지는 않아요.',
          ),
          if (materialKeys.isNotEmpty) ...[
            const SizedBox(height: 16),
            _UsageLine(
              icon: 'Layers2',
              title: '다른 앨범에서 개별 재사용',
              detail: reusable == materialKeys.length
                  ? '현재 ${materialKeys.length}종 모두 무료 또는 보유한 소재로, 다른 앨범에도 추가할 수 있어요.'
                  : '현재 재사용 가능 $reusable종 · 나머지 ${materialKeys.length - reusable}종은 소재별 가격과 보유 권한을 확인해 주세요.',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const ValueKey('template-reuse-details'),
                onPressed: onMaterials,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(child: Text('소재별 이용 범위')),
                    const SizedBox(width: 6),
                    ExperienceIcon(
                      'ChevronRight',
                      size: 16,
                      color: ExperienceFormStyle.selectionInk(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialCount extends StatelessWidget {
  const _MaterialCount({required this.title, required this.count});
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$count종',
        style: ExperienceFormStyle.text(context, 20, weight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        title,
        style: ExperienceFormStyle.text(context, 11, secondary: true),
      ),
    ],
  );
}

class _UsageLine extends StatelessWidget {
  const _UsageLine({
    required this.icon,
    required this.title,
    required this.detail,
  });
  final String icon, title, detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ExperienceIcon(
          icon,
          size: 19,
          color: ExperienceFormStyle.muted(context),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: ExperienceFormStyle.text(
                context,
                13,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              style: ExperienceFormStyle.text(
                context,
                12,
                secondary: true,
              ).copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    ],
  );
}
