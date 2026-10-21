import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../album/data/bundled_creation_templates.dart';
import '../../../store/domain/entities/premium_template.dart';

/// A guest's choice lasts only for this running app session. Only a published
/// template identifier is held; artwork, prices and customer data are not saved.
final publicTemplateReturnIntentProvider =
    NotifierProvider<PublicTemplateReturnIntent, int?>(
      PublicTemplateReturnIntent.new,
    );

class PublicTemplateReturnIntent extends Notifier<int?> {
  @override
  int? build() => null;

  bool remember(int templateId) {
    final known = publishedCreationTemplates.any(
      (item) => item.id == templateId,
    );
    state = known ? templateId : null;
    return known;
  }

  /// Re-resolve against the canonical public catalog, never a guest's object.
  PremiumTemplate? consume() {
    final templateId = state;
    state = null;
    return publishedCreationTemplates
        .where((item) => item.id == templateId)
        .firstOrNull;
  }

  void clear() => state = null;
}
