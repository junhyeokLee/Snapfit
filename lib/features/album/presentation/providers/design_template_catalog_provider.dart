import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/design_templates.dart';
import '../../../../../core/templates/authored_collections.dart';
import '../../../../../core/templates/data_template_engine.dart';

/// The editor must not restore retired catalog entries from legacy assets.
final publishedDesignTemplates = List<DesignTemplate>.unmodifiable([
  for (final collection in authoredCollections)
    DesignTemplate(
      id: collection.id,
      name: collection.title,
      category: collection.category,
      tags: collection.styleTags,
      buildLayers: (canvas) {
        final ratio = canvas.width / canvas.height;
        final aspect = ratio < 0.9
            ? CollectionAspect.portrait
            : ratio > 1.1
            ? CollectionAspect.landscape
            : CollectionAspect.square;
        final document = collection.document(aspect);
        final cover = document['cover'] as Map<String, dynamic>;
        return DataTemplateEngine.buildLayersFromJson({
          'strictLayout': true,
          'designWidth': aspect.canvas.width,
          'designHeight': aspect.canvas.height,
          'layers': cover['layers'],
        }, canvas);
      },
    ),
]);

final designTemplateCatalogProvider = FutureProvider<List<DesignTemplate>>(
  (ref) async => publishedDesignTemplates,
);
