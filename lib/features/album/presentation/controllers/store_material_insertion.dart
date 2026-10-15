import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../../core/constants/cover_size.dart';
import '../../../../core/templates/studio_decoration_catalog.dart';
import '../../../../core/templates/studio_phrase_catalog.dart';
import '../../../../core/templates/studio_word_art_catalog.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';

bool isStoreMaterialSupported(String key) =>
    studioDecorations.any((item) => 'sticker:${item.id}' == key) ||
    studioPhrases.any((item) => 'phrase:${item.id}' == key) ||
    studioWordArts.any((item) => item.productKey == key) ||
    imageFrameStyles.any(
      (item) => item.key.isNotEmpty && 'frame:${item.key}' == key,
    );

Future<bool> insertStoreMaterial(
  AlbumEditorViewModel vm,
  String key, {
  AssetEntity? photo,
}) async {
  if (vm.currentPage == null || !isStoreMaterialSupported(key)) return false;
  final canvas = Size(
    kCoverReferenceWidth,
    kCoverReferenceWidth / vm.selectedCover.ratio,
  );
  final decoration = studioDecorations
      .where((item) => 'sticker:${item.id}' == key)
      .firstOrNull;
  if (decoration != null) {
    if (decoration.assetPath != null) {
      vm.addAssetSticker(decoration.assetPath!, canvas);
    } else {
      vm.addDecorationSticker(decoration.id, canvas);
    }
    return true;
  }
  final art = studioWordArts
      .where((item) => item.productKey == key)
      .firstOrNull;
  if (art != null) {
    vm.addWordArt(art, canvas);
    return true;
  }
  final phrase = studioPhrases
      .where((item) => 'phrase:${item.id}' == key)
      .firstOrNull;
  if (phrase != null) {
    vm.addTextLayer(
      phrase.text,
      style: phrase.lettering.style,
      mode: TextStyleType.none,
      canvasSize: canvas,
      textAlign: phrase.alignment,
    );
    return true;
  }
  if (key.startsWith('frame:') && photo != null) {
    await vm.addImage(
      photo,
      canvas,
      imageFrameKey: key.substring('frame:'.length),
    );
    return true;
  }
  return false;
}
