import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../store/data/api/template_provider.dart';
import '../../store/domain/entities/premium_template.dart';
import 'bundled_creation_templates.dart';

/// Creation and the store share the same published collection policy.
final albumCreationCatalogProvider =
    StreamProvider.autoDispose<List<PremiumTemplate>>((ref) async* {
      yield bundledCreationTemplates;
      try {
        yield withBundledCreationTemplates(
          await ref.watch(templateListProvider.future),
        );
      } catch (_) {
        // Bundled originals stay usable even without server credentials.
      }
    });
