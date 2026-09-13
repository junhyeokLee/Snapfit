import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/studio_word_art_catalog.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';

class Editor extends AlbumEditorViewModel {
  String? kind, value;
  Size? canvas;
  double? scale, font;
  @override
  void addAssetSticker(String path, Size size) {
    kind = 'asset';
    value = path;
    canvas = size;
  }

  @override
  void addDecorationSticker(String key, Size size, {double scale = 1}) {
    kind = 'deco';
    value = key;
    canvas = size;
    this.scale = scale;
  }

  @override
  void addWordArt(StudioWordArt art, Size size) {
    kind = 'wordart';
    value = art.id;
    canvas = size;
  }

  @override
  void addTextLayer(
    String text, {
    required TextStyle style,
    required TextStyleType mode,
    Color? color,
    required Size canvasSize,
    TextAlign textAlign = TextAlign.center,
  }) {
    kind = 'emoji';
    value = text;
    canvas = canvasSize;
    font = style.fontSize;
    expect(mode, TextStyleType.none);
  }
}

void main() {
  test('editor owns insertion parsing, scale, canvas and dispatch', () {
    final vm = Editor();
    expect(
      vm.insertMaterial('deco:stickerBlueStar@0.74', emojiFontSize: 60),
      true,
    );
    expect(vm.kind, 'deco');
    expect(vm.scale, .74);
    expect(
      vm.canvas,
      Size(kCoverReferenceWidth, kCoverReferenceWidth / vm.selectedCover.ratio),
    );
    expect(
      vm.insertMaterial('asset:assets/sticker/scrap1.png', emojiFontSize: 60),
      true,
    );
    expect(vm.kind, 'asset');
    expect(vm.value, 'assets/sticker/scrap1.png');
    expect(
      vm.insertMaterial(studioWordArts.first.insertionValue, emojiFontSize: 60),
      true,
    );
    expect(vm.kind, 'wordart');
    expect(vm.insertMaterial('wordart:missing', emojiFontSize: 60), false);
    expect(vm.insertMaterial('🎀', emojiFontSize: 72), true);
    expect(vm.kind, 'emoji');
    expect(vm.font, 72);
    vm.insertMaterial('deco:stickerBlueStar@oops', emojiFontSize: 60);
    expect(vm.scale, 1);
  });
}
