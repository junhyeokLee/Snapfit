import '../../../core/templates/template_catalog_categories.dart';

/// The same subjects are available when discovering and publishing an album.
const socialTopicLabels = <String>[...templateTopicOrder, '기타'];

/// Existing publications keep their stored subject while sharing new filters.
String socialTopicLabel(String topic) => switch (topic.trim()) {
  '가족' => '가족·친구',
  '커플' => '커플·기념일',
  final label => label,
};
