import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/editor/edit_cover_theme.dart';
/// Toolbar 버튼 액션 전담. 기존 EditCover 내부 onAddPhoto / onOpenCoverSelector 그대로.
class ToolbarActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  ToolbarActionHandler(this.context, this.ref);

  Future<void> addPhoto(Size canvasSize) async {
    await showPhotoSelectionSheet(
      context,
      ref,
      onSelect: (asset) {
        final vm = ref.read(albumEditorViewModelProvider.notifier);
        vm.addImage(asset, canvasSize);
      },
    );
  }

  Future<void> openCoverTheme() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF9893a9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const EditCoverTheme(),
    );
  }

  /// 슬롯용: 단일 사진만 선택해서 AssetEntity 반환
  Future<AssetEntity?> pickSinglePhoto() async {
    AssetEntity? result;

    await showPhotoSelectionSheet(
      context,
      ref,
      onSelect: (asset) {
        result = asset;
      },
    );

    return result;
  }
}