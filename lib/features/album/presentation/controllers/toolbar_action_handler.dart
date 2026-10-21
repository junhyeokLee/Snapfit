import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/web/web_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/editor_modal_scope.dart';
import '../../../../shared/widgets/image_template_picker.dart';
import '../viewmodels/album_editor_view_model.dart';
import '../widgets/editor/edit_cover_theme.dart';
import 'editor_canvas_coordinates.dart';

/// Toolbar 버튼 액션 전담. 기존 EditCover 내부 onAddPhoto / onOpenCoverSelector 그대로.
class ToolbarActionHandler {
  final BuildContext context;
  final WidgetRef ref;
  final Future<AssetEntity?> Function(BuildContext, WidgetRef) _selectPhoto;
  final Future<String?> Function(BuildContext) _selectTemplate;

  ToolbarActionHandler(
    this.context,
    this.ref, {
    Future<AssetEntity?> Function(BuildContext, WidgetRef)? selectPhoto,
    Future<String?> Function(BuildContext)? selectTemplate,
  }) : _selectPhoto =
           selectPhoto ??
           ((context, ref) => showPhotoSelectionSheet(context, ref)),
       _selectTemplate =
           selectTemplate ??
           ((context) => ImageTemplatePicker.show(context, currentKey: 'free'));

  /// The optional display size is retained for existing toolbar callers; it is
  /// never used as the document geometry, regardless of viewport or zoom.
  Future<void> addPhoto([Size? displayCanvasSize]) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final pageId = vm.currentPage?.id;
    if (pageId == null) return;
    final canvasSize = editorReferenceCanvasSize(vm.selectedCover);
    final asset = await _selectPhoto(context, ref);
    if (asset == null || !context.mounted || vm.currentPage?.id != pageId)
      return;
    final templateKey = await _selectTemplate(context);
    if (templateKey == null || !context.mounted || vm.currentPage?.id != pageId)
      return;
    await vm.addImage(asset, canvasSize, templateKey: templateKey);
  }

  Future<void> openCoverTheme() async {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final editorScope = ProviderScope.containerOf(context, listen: false);
    if (kIsWeb) {
      await showWebAwareDialog<void>(
        context: context,
        useRootNavigator: false,
        routeSettings: editorModalRouteSettings(context),
        maxWidth: 1000,
        maxHeight: 740,
        builder: (_) => UncontrolledProviderScope(
          container: editorScope,
          child: const EditCoverTheme(),
        ),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      routeSettings: editorModalRouteSettings(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: editorScope,
        child: const EditCoverTheme(),
      ),
    );
  }

  /// 슬롯용: 단일 사진만 선택해서 AssetEntity 반환
  Future<AssetEntity?> pickSinglePhoto() async {
    return showPhotoSelectionSheet(context, ref);
  }
}
