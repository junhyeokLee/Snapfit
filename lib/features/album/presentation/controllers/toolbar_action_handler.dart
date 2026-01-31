import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/image_template_picker.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/editor/edit_cover_theme.dart';
/// Toolbar 버튼 액션 전담. 기존 EditCover 내부 onAddPhoto / onOpenCoverSelector 그대로.
class ToolbarActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  ToolbarActionHandler(this.context, this.ref);

  Future<void> addPhoto(Size canvasSize) async {
    // 갤러리는 필요할 때만 로딩 (신규 생성 진입 시 "불러오기 X" 요구사항 대응)
    await ref.read(albumEditorViewModelProvider.notifier).ensureGalleryLoaded();
    // 사진 선택 시 갤러리 시트가 먼저 닫히고, 선택한 사진만 반환됨
    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !context.mounted) return;
    // 그 다음 템플릿(정사각형, 4:3 등) 선택 → 슬롯 비율 고정, 사진은 contain으로 짤리지 않게
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
      backgroundColor: const Color(0xFF9893a9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const EditCoverTheme(),
    );
  }

  /// 슬롯용: 단일 사진만 선택해서 AssetEntity 반환
  Future<AssetEntity?> pickSinglePhoto() async {
    return showPhotoSelectionSheet(context, ref);
  }
}