import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/image_template_picker.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/editor/edit_cover_theme.dart';
import '../viewmodels/gallery_notifier.dart';

/// Toolbar 버튼 액션 전담. 기존 EditCover 내부 onAddPhoto / onOpenCoverSelector 그대로.
class ToolbarActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  ToolbarActionHandler(this.context, this.ref);

  Future<void> addPhoto(Size canvasSize) async {
    final gallery = ref.read(galleryProvider);
    if (gallery.albums.isEmpty) {
      await ref.read(galleryProvider.notifier).fetchInitialData();
    }
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !context.mounted) return;
    final templateKey = await ImageTemplatePicker.show(
      context,
      currentKey: 'free',
    );
    if (!context.mounted) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    await vm.addImage(asset, canvasSize, templateKey: templateKey ?? 'free');
  }

  Future<void> openCoverTheme() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditCoverTheme(),
    );
  }

  /// 슬롯용: 단일 사진만 선택해서 AssetEntity 반환
  Future<AssetEntity?> pickSinglePhoto() async {
    return showPhotoSelectionSheet(context, ref);
  }
}
