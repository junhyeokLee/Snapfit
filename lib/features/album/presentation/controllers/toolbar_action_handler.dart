import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widget/common/album_bottom_sheet.dart';
import '../widgets/editor/edit_cover_theme.dart';
/// Toolbar 버튼 액션 전담. 기존 EditCover 내부 onAddPhoto / onOpenCoverSelector 그대로.
class ToolbarActionHandler {
  final BuildContext context;
  final WidgetRef ref;

  ToolbarActionHandler(this.context, this.ref);

  Future<void> addPhoto() async {
    await showPhotoSelectionSheet(context, ref);
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
}