import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/page_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/web/web_design.dart';
import '../../viewmodels/album_editor_view_model.dart';
import 'page_layout_catalog.dart';
import 'template_apply_preview.dart';
import '../../../../../shared/widgets/experience_icon.dart';

/// Shared layout catalog for the native bottom sheet and web editor panel.
class TemplateSelectionPanel extends ConsumerStatefulWidget {
  const TemplateSelectionPanel({
    super.key,
    this.title = '레이아웃',
    this.closeOnApply = true,
    this.showHeader = true,
  });
  final String title;
  final bool closeOnApply;
  final bool showHeader;

  @override
  ConsumerState<TemplateSelectionPanel> createState() =>
      _TemplateSelectionPanelState();
}

class _TemplateSelectionPanelState
    extends ConsumerState<TemplateSelectionPanel> {
  String? _selectedId;
  bool _isApplying = false;

  Future<void> _select(PageTemplate template) async {
    if (_isApplying) return;
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    if (!vm.editingAllowed) return;
    final ratio = vm.selectedCover.ratio > 0 ? vm.selectedCover.ratio : 3 / 4;
    final canvasSize = Size(kCoverReferenceWidth, kCoverReferenceWidth / ratio);
    final session = vm.editSessionIdentity;
    final albumId = vm.editingAlbumId;
    final pageId = vm.currentPage?.id;
    _isApplying = true;
    try {
      final approved = await showTemplateApplyPreview(
        context,
        title: template.name,
        replacesContent: vm.currentPage?.layers.isNotEmpty ?? false,
        preview: AspectRatio(
          aspectRatio: ratio,
          child: PageLayoutPreview(template: template),
        ),
      );
      if (!mounted ||
          !approved ||
          !identical(vm.editSessionIdentity, session) ||
          vm.editingAlbumId != albumId ||
          vm.currentPage?.id != pageId ||
          !vm.editingAllowed)
        return;
      if (!vm.applyTemplateToCurrentPage(template, canvasSize)) return;
      setState(() => _selectedId = template.id);
      if (widget.closeOnApply) Navigator.of(context).pop();
    } finally {
      _isApplying = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final ratio = vm.selectedCover.ratio > 0 ? vm.selectedCover.ratio : 3 / 4;
    final maxSheetHeight = (MediaQuery.sizeOf(context).height * .90).clamp(
      0.0,
      900.0,
    );
    return Container(
      height: kIsWeb ? double.infinity : maxSheetHeight,
      decoration: BoxDecoration(
        color: kIsWeb
            ? WebPalette.of(context).surface
            : SnapFitColors.surfaceOf(context),
        borderRadius: kIsWeb
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SnapFitColors.overlayStrongOf(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.showHeader && (!kIsWeb || widget.closeOnApply))
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 8, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title == '레이아웃' ? '쪽 레이아웃 고르기' : widget.title,
                        style: TextStyle(
                          color: SnapFitColors.textPrimaryOf(context),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: '레이아웃 닫기',
                      icon: const ExperienceIcon('X', size: 20),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: PageLayoutCatalog(
                selectedId: _selectedId,
                pageRatio: ratio,
                onSelect: _select,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
