import 'package:flutter/widgets.dart';
import '../../core/templates/studio_word_art_catalog.dart';
import '../../features/store/presentation/widgets/template_page_renderer.dart';

class StudioWordArtPreview extends StatelessWidget {
  const StudioWordArtPreview({super.key, required this.art});
  final StudioWordArt art;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: TemplatePageRenderer(
      layers: art.previewLayers(),
      width: art.sourceSize.width,
      height: art.sourceSize.height,
      designCanvasSize: art.sourceSize,
      preserveTypography: true,
    ),
  );
}
