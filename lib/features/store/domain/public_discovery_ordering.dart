import '../../../core/templates/template_catalog_categories.dart';
import 'entities/premium_template.dart';

/// Gives every subject a turn before repeating one in public discovery.
///
/// Within each subject and publication tier, the supplied catalog order stays
/// intact. Two ordinary editions and one premium edition are preferred across
/// the output; a missing tier never hides the other editions in that subject.
/// This uses publication metadata only: prices and availability still come from
/// the public price catalog, and no popularity or quality score is inferred.
List<PremiumTemplate> orderPublicDiscoveryTemplates(
  Iterable<PremiumTemplate> source,
) {
  final seen = <int>{};
  final subjects = <String, _DiscoverySubject>{};
  for (final template in source) {
    if (!seen.add(template.id)) continue;
    final subject = template.category?.trim() ?? '';
    final queue = subjects.putIfAbsent(subject, _DiscoverySubject.new);
    (template.isPremium ? queue.premium : queue.ordinary).add(template);
  }
  final topics = [
    ...orderedTemplateTopics(subjects.keys),
    if (subjects.containsKey('')) '',
  ];
  final result = <PremiumTemplate>[];
  while (result.length < seen.length) {
    for (final topic in topics) {
      final next = subjects[topic]!.take(preferPremium: result.length % 3 == 2);
      if (next != null) result.add(next);
    }
  }
  return List.unmodifiable(result);
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
