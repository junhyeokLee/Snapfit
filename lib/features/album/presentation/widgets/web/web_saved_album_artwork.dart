import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/snapfit_image.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../domain/entities/album.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../utils/cover_background_color.dart';
import '../cover/cover.dart';
import '../home/home_album_helpers.dart';

/// Flat view of saved artwork; never changes the stored album or print model.
class WebSavedAlbumArtwork extends ConsumerWidget {
  const WebSavedAlbumArtwork({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratio = album.physicalCoverSize.ratio;
    final base = Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    final layers = parseCoverLayers(album.coverLayersJson, canvasSize: base);
    final theme = resolveCoverTheme(album.coverTheme);
    final interaction = LayerInteractionManager.preview(ref, () => base);
    final builder = LayerBuilder(interaction, () => base);
    final image = [
      album.coverPreviewUrl,
      album.coverImageUrl,
      album.coverThumbnailUrl,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).firstOrNull;
    final empty = ColoredBox(
      color: WebPalette.of(context).canvas,
      child: Center(child: Icon(
        Icons.auto_stories_outlined, size: 32, color: WebPalette.of(context).muted,
      )),
    );

    Widget artwork;
    if (layers != null && layers.isNotEmpty || image == null) {
      artwork = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: base.width,
          height: base.height,
          child: IgnorePointer(
            child: CoverLayout(
              aspect: ratio,
              layers: layers ?? const [],
              isInteracting: false,
              leftSpine: kCoverSpineWidth,
              flatPresentation: true,
              backgroundColor: extractCoverBackgroundColor(album.coverLayersJson),
              onCoverSizeChanged: (_) {},
              buildImage: (layer) => builder.buildImage(layer, isCover: true),
              buildText: (layer) => builder.buildText(layer, isCover: true),
              sortedByZ: interaction.sortByZ,
              theme: theme,
            ),
          ),
        ),
      );
    } else {
      artwork = SnapfitImage(urlOrGs: image, fit: BoxFit.contain, error: empty);
    }
    return AspectRatio(aspectRatio: ratio, child: ClipRect(child: artwork));
  }
}
