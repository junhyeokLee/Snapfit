import 'store_template_recommendations.dart';
import 'store_product_discovery.dart';
import '../../point_shop/domain/point_shop_template_key.dart';
import 'entities/premium_template.dart';

/// Gives every subject a turn before repeating one in public discovery.
///
/// New verified releases lead; the remaining subjects keep a balanced order.
/// Within each subject and publication tier, the supplied catalog order stays
/// intact. Two ordinary editions and one premium edition are preferred across
/// the output; a missing tier never hides the other editions in that subject.
/// This uses publication metadata only: prices and availability still come from
/// the public price catalog, and no popularity or quality score is inferred.
List<PremiumTemplate> orderPublicDiscoveryTemplates(
  Iterable<PremiumTemplate> source, {
  Map<String, StoreProductDiscovery>? discovery,
  DateTime? now,
}) {
  final seen = <int>{};
  final subjects = <String, _DiscoverySubject>{};
  for (final template in source) {
    if (!seen.add(template.id)) continue;
    final subject = template.category?.trim() ?? '';
    final queue = subjects.putIfAbsent(subject, _DiscoverySubject.new);
    (template.isPremium ? queue.premium : queue.ordinary).add(template);
  }
  final topics = [
    ...storeTemplateCategories(
      subjects.keys,
    ).where((topic) => topic != '전체' && topic != storeRecommendedCategory),
    if (subjects.containsKey('')) '',
  ];
  final result = <PremiumTemplate>[];
  while (result.length < seen.length) {
    for (final topic in topics) {
      final next = subjects[topic]!.take(preferPremium: result.length % 3 == 2);
      if (next != null) result.add(next);
    }
  }
  return List.unmodifiable(
    prioritizeNewStoreProducts<PremiumTemplate>(
      result,
      productKey: pointShopTemplateKey,
      discovery: discovery ?? bundledStoreDiscovery,
      now: now ?? DateTime.now().toUtc(),
    ),
  );
}

class _DiscoverySubject {
  final ordinary = <PremiumTemplate>[];
  final premium = <PremiumTemplate>[];
  int _ordinaryIndex = 0;
  int _premiumIndex = 0;

  PremiumTemplate? take({required bool preferPremium}) {
    if (preferPremium && _premiumIndex < premium.length) {
      return premium[_premiumIndex++];
    }
    if (_ordinaryIndex < ordinary.length) return ordinary[_ordinaryIndex++];
    if (_premiumIndex < premium.length) return premium[_premiumIndex++];
    return null;
  }
}
