import 'package:photo_manager/photo_manager.dart';

import '../../../domain/entities/layer.dart';

class TemplatePhotoPlacement {
  const TemplatePhotoPlacement({
    required this.page,
    required this.layerIndex,
    required this.original,
    required this.photo,
  });

  final int page, layerIndex;
  final LayerModel original;
  final AssetEntity photo;
  String get fileKey => '$page:${original.id}';
}

/// A proposal only. Building it never changes the document or the photo tray.
class TemplatePhotoFillPlan {
  TemplatePhotoFillPlan._({
    required this.sourcePages,
    required this.sourcePhotos,
    required this.placements,
    required this.remainingEmptySlots,
  });

  factory TemplatePhotoFillPlan.create({
    required List<List<LayerModel>> pages,
    required List<AssetEntity> photos,
  }) {
    final sourcePages = [for (final page in pages) List<LayerModel>.of(page)];
    final sourcePhotos = List<AssetEntity>.of(photos);
    final placements = <TemplatePhotoPlacement>[];
    var emptySlots = 0;
    for (var page = 0; page < pages.length; page++) {
      for (var layerIndex = 0; layerIndex < pages[page].length; layerIndex++) {
        final layer = pages[page][layerIndex];
        if (layer.type != LayerType.image || layer.hasImageSource) continue;
        emptySlots++;
        if (placements.length >= photos.length) continue;
        placements.add(
          TemplatePhotoPlacement(
            page: page,
            layerIndex: layerIndex,
            original: layer,
            photo: photos[placements.length],
          ),
        );
      }
    }
    return TemplatePhotoFillPlan._(
      sourcePages: sourcePages,
      sourcePhotos: sourcePhotos,
      placements: placements,
      remainingEmptySlots: emptySlots - placements.length,
    );
  }

  final List<List<LayerModel>> sourcePages;
  final List<AssetEntity> sourcePhotos;
  final List<TemplatePhotoPlacement> placements;
  final int remainingEmptySlots;

  List<AssetEntity> get remainingPhotos =>
      sourcePhotos.skip(placements.length).toList();

  List<List<LayerModel>> buildPages() {
    final result = [for (final page in sourcePages) List<LayerModel>.of(page)];
    for (final placement in placements) {
      result[placement.page][placement.layerIndex] = placement.original
          .copyWith(clearImage: true)
          .copyWith(asset: placement.photo);
    }
    return result;
  }

  bool matches(List<List<LayerModel>> pages, List<AssetEntity> photos) {
    if (sourcePages.length != pages.length ||
        sourcePhotos.length != photos.length)
      return false;
    for (var page = 0; page < pages.length; page++) {
      if (sourcePages[page].length != pages[page].length) return false;
      for (var layer = 0; layer < pages[page].length; layer++) {
        if (!identical(sourcePages[page][layer], pages[page][layer]))
          return false;
      }
    }
    for (var photo = 0; photo < photos.length; photo++) {
      if (!identical(sourcePhotos[photo], photos[photo])) return false;
    }
    return true;
  }
}
