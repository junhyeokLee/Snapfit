import 'package:flutter/widgets.dart';
import '../../core/templates/preview_cache.dart';
import '../../features/album/domain/entities/layer.dart';
import '../../core/templates/studio_word_art_catalog.dart';
import '../../features/store/presentation/widgets/template_page_renderer.dart';

final _previews = PreviewCache<String, List<LayerModel>>(capacity: 48);

class StudioWordArtPreview extends StatelessWidget {
  const StudioWordArtPreview({super.key, required this.art});
  final StudioWordArt art;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: TemplatePageRenderer(
      layers: _previews.get(
        art.id,
        art,
        () => List.unmodifiable(art.previewLayers()),
      ),
      width: art.sourceSize.width,
      height: art.sourceSize.height,
      designCanvasSize: art.sourceSize,
      preserveTypography: true,
    ),
  );
}
