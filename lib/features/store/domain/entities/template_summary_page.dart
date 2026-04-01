import 'premium_template.dart';

class TemplateSummaryPage {
  final List<PremiumTemplate> content;
  final int page;
  final int size;
  final int totalPages;
  final int totalElements;
  final bool hasNext;

  const TemplateSummaryPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalPages,
    required this.totalElements,
    required this.hasNext,
  });
}
