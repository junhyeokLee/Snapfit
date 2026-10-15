import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/create_flow/photo_crop_sheet.dart';
import 'layer_builder.dart';

Future<void> editPhotoCrop(
  BuildContext context,
  WidgetRef ref,
  LayerModel layer, {
  LayerBuilder? layerBuilder,
}) async {
  if (ModalRoute.of(context)?.isCurrent == false) return;
  final vm = ref.read(albumEditorViewModelProvider.notifier);
  final pageId = vm.currentPage?.id;
  final original = vm.findLayerById(layer.id);
  if (pageId == null || original?.type != LayerType.image) return;
  final result = await showPhotoCropSheet(
    context,
    layer: original!,
    frameBuilder: layerBuilder?.buildPhotoFrame,
  );
  if (result == null || !context.mounted) return;
  final current = vm.findLayerById(layer.id);
  // A modal result must never overwrite a page or photo changed underneath it.
  if (vm.currentPage?.id != pageId || !identical(current, original)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('페이지가 변경됐어요. 사진을 다시 선택해주세요.')));
    return;
  }
  if (original.imageZoom == result.imageZoom &&
      (original.imageOffset ?? Offset.zero) ==
          (result.imageOffset ?? Offset.zero)) {
    return;
  }
  vm.updateLayer(
    original.copyWith(
      imageZoom: result.imageZoom,
      imageOffset: result.imageOffset ?? Offset.zero,
    ),
  );
}

Future<bool> replacePhotoInSlot(
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
  final asset = await showPhotoSelectionSheet(context, ref);
  if (asset == null ||
      !context.mounted ||
      ModalRoute.of(context)?.isCurrent == false)
    return false;

  bool currentTarget() =>
      vm.currentPage?.id == pageId &&
      identical(vm.findLayerById(layer.id), original);
  void reportStaleTarget() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('페이지가 변경됐어요. 사진을 다시 선택해주세요.')));
  if (!currentTarget()) {
    reportStaleTarget();
    return false;
  }
  final hasPhoto =
      original!.asset != null ||
      [
        original.previewUrl,
        original.imageUrl,
        original.originalUrl,
      ].whereType<String>().any((url) => url.isNotEmpty);
  final draft = original.copyWith(clearImage: true).copyWith(asset: asset);
  final result = await showPhotoCropSheet(
    context,
    layer: draft,
    title: hasPhoto ? '사진 바꾸기' : '사진 넣기',
    frameBuilder: layerBuilder.buildPhotoFrame,
  );
  if (result == null ||
      !context.mounted ||
      ModalRoute.of(context)?.isCurrent == false)
    return false;
  if (!currentTarget()) {
    reportStaleTarget();
    return false;
  }
  await vm.updateSlotImage(
    original.id,
    asset,
    expectedPageId: pageId,
    expectedLayer: original,
    imageZoom: result.imageZoom,
    imageOffset: result.imageOffset,
  );
  return !identical(vm.findLayerById(original.id), original);
}
