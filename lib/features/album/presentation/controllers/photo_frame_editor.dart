import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/gallery/photo_asset_image_provider.dart';

import '../../../../shared/snapfit_image.dart';
import '../../../../shared/widgets/image_frame_style_picker.dart';
import '../../domain/entities/album_page.dart';
import '../../domain/entities/layer.dart';
import '../../service/album_editor_service.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'layer_builder.dart';

Future<bool> editPhotoFrame(
  BuildContext context,
  WidgetRef ref,
  LayerModel layer, {
  required LayerBuilder layerBuilder,
}) async {
  if (ModalRoute.of(context)?.isCurrent == false) return false;
  final vm = ref.read(albumEditorViewModelProvider.notifier);
  final pageId = vm.currentPage?.id;
  final original = vm.findLayerById(layer.id);
  if (pageId == null || original?.type != LayerType.image) return false;
  final currentKey = original!.imageBackground ?? '';
  final key = await ImageFrameStylePicker.show(
    context,
    currentKey: currentKey,
    framedPhotoBuilder: (_, frameKey) => EditorPhotoFramePreview(
      layer: original,
      frameKey: frameKey,
      layerBuilder: layerBuilder,
    ),
  );
  if (key == null || !context.mounted) return false;
  if (vm.currentPage?.id != pageId ||
      !identical(vm.findLayerById(layer.id), original)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('페이지가 변경됐어요. 사진을 다시 선택해주세요.')));
    return false;
  }
  if (key == currentKey) return false;
  vm.updateImageFrame(layer.id, key);
  return true;
}

class EditorPhotoFramePreview extends StatelessWidget {
  const EditorPhotoFramePreview({
    super.key,
    required this.layer,
    required this.frameKey,
    required this.layerBuilder,
  });

  final LayerModel layer;
  final String frameKey;
  final LayerBuilder layerBuilder;

  @override
  Widget build(BuildContext context) {
    // Simulate only on a detached page; previewing never changes the document.
    final page = AlbumPage(id: 'frame-preview', layers: [layer], pageIndex: 0);
    const AlbumEditorService().updateImageFrame(
      page: page,
      id: layer.id,
      frameKey: frameKey,
    );
    final preview = page.layers.single;
    final width = preview.width.isFinite && preview.width > 0
        ? preview.width
        : 240.0;
    final height = preview.height.isFinite && preview.height > 0
        ? preview.height
        : 320.0;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: width,
        height: height,
        child: Opacity(
          opacity: preview.opacity,
          child: layerBuilder.buildPhotoFrame(
            preview,
            _photo(context, preview),
          ),
        ),
      ),
    );
  }

  Widget _photo(BuildContext context, LayerModel preview) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 28,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    ImageProvider provider;
    if (preview.asset != null) {
      provider = photoAssetImageProvider(preview.asset!);
    } else {
      final source = [
        preview.previewUrl,
        preview.imageUrl,
        preview.originalUrl,
      ].whereType<String>().where((url) => url.isNotEmpty).firstOrNull;
      if (source == null) return placeholder;
      if (source.startsWith('asset:')) {
        provider = AssetImage(source.substring('asset:'.length));
      } else {
        return SnapfitImage(
          urlOrGs: source,
          fit: BoxFit.cover,
          alignment: preview.imageAlignment,
          memCacheWidth: 640,
          placeholder: placeholder,
          error: placeholder,
        );
      }
    }
    return Image(
      image: ResizeImage(
        provider,
        width: 960,
        height: 960,
        policy: ResizeImagePolicy.fit,
      ),
      fit: BoxFit.cover,
      alignment: preview.imageAlignment,
      errorBuilder: (_, __, ___) => placeholder,
    );
  }
}
