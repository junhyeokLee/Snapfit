import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/edit_text_overlay.dart';
import '../../../../shared/web/web_design.dart';
import '../../domain/entities/layer.dart';
import '../viewmodels/album_editor_view_model.dart';
import 'editor_canvas_coordinates.dart';

/// Text drafts only update the editor after explicit confirmation.
class TextEditorManager {
  final BuildContext context;
  final AlbumEditorViewModel vm;

  TextEditorManager(this.context, this.vm);

  /// 선택된 텍스트 레이어 편집. 완료 시 updateLayer.
  Future<void> open(LayerModel layer) async {
    final safeStyle =
        layer.textStyle ??
        const TextStyle(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.normal,
        );

    await _show(
      initialText: layer.text ?? '',
      initialStyle: safeStyle,
      initialMode: layer.textStyleType,
      initialBubbleColor: layer.bubbleColor,
      initialAlign: layer.textAlign ?? TextAlign.center,
      onSubmit: (newText, newStyle, mode, color, align) {
        vm.updateLayer(
          layer.copyWith(
            text: newText,
            textStyle: newStyle,
            textStyleType: mode,
            bubbleColor: color,
            textAlign: align,
          ),
        );
      },
    );
  }

  /// “새 텍스트 추가” 모달. 완료 시 addTextLayer. 빈 문자열이면 무시.
  Future<void> openAndCreateNew([Size? displayCanvasSize]) async {
    final canvasSize = editorReferenceCanvasSize(vm.selectedCover);
    final pageId = vm.currentPage?.id;
    await _show(
      initialText: '',
      // 글쓰기 모드 기본 텍스트는 항상 흰색으로 시작
      initialStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      onSubmit: (newText, newStyle, mode, color, align) {
        if (newText.trim().isEmpty || vm.currentPage?.id != pageId) {
          return;
        } // 빈값 방지
        vm.addTextLayer(
          newText,
          style: newStyle,
          mode: mode,
          color: color,
          textAlign: align,
          canvasSize: canvasSize,
        );
      },
    );
  }

  /// 기존 레이어 편집용 (open()과 동일하나 명시적 호출용)
  Future<void> openForExisting(LayerModel layer) => open(layer);

  Future<void> _show({
    required String initialText,
    required TextStyle initialStyle,
    TextStyleType? initialMode,
    Color? initialBubbleColor,
    TextAlign initialAlign = TextAlign.center,
    required void Function(String, TextStyle, TextStyleType, Color?, TextAlign)
    onSubmit,
  }) async {
    if (!context.mounted) return;
    FocusScope.of(context).unfocus();
    if (kIsWeb) {
      await showWebAwareDialog<void>(
        context: context,
        maxWidth: 1100,
        maxHeight: 760,
        builder: (dialogContext) => EditTextOverlay(
          initialText: initialText,
          initialStyle: initialStyle,
          initialMode: initialMode,
          initialBubbleColor: initialBubbleColor,
          initialAlign: initialAlign,
          onSubmit: (newText, newStyle, mode, color, align) {
            onSubmit(newText, newStyle, mode, color, align);
            Navigator.pop(dialogContext);
          },
          onCancel: () => Navigator.pop(dialogContext),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 960),
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => EditTextOverlay(
        initialText: initialText,
        initialStyle: initialStyle,
        initialMode: initialMode,
        initialBubbleColor: initialBubbleColor,
        initialAlign: initialAlign,
        onSubmit: (newText, newStyle, mode, color, align) {
          onSubmit(newText, newStyle, mode, color, align);
          Navigator.pop(sheetContext);
        },
        onCancel: () => Navigator.pop(sheetContext),
      ),
    );
  }
}
