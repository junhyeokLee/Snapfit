// lib/screen/widget/EditCoverWidget/Controllers/text_editor_manager.dart
import 'package:flutter/material.dart';
import '../../../../core/widget/common/edit_text_overlay.dart';
import '../../data/models/layer.dart';
import '../viewmodels/album_editor_view_model.dart';

/// 기존 _openTextEditor(layer) 로직 1:1 래핑. 동작 동일.
class TextEditorManager {
  final BuildContext context;
  final AlbumEditorViewModel vm;

  TextEditorManager(this.context, this.vm);

  /// 선택된 텍스트 레이어 편집. 완료 시 updateLayer.
  Future<void> open(LayerModel layer) async {
    final safeStyle = layer.textStyle ??
        const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.normal);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: EditTextOverlay(
                initialText: layer.text ?? "",
                initialStyle: safeStyle,
                initialMode: layer.textStyleType,
                initialBubbleColor: layer.bubbleColor,
                onSubmit: (newText, newStyle, mode, color, align) {
                  vm.updateLayer(
                    layer.copyWith(
                      text: newText,
                      textStyle: (newStyle ?? safeStyle),
                      textStyleType: mode,
                      bubbleColor: color,
                      textAlign: align,
                    ),
                  );
                  Navigator.pop(context);
                },
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }

  /// “새 텍스트 추가” 모달. 완료 시 addTextLayer. 빈 문자열이면 무시.
  Future<void> openAndCreateNew(Size canvasSize) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: EditTextOverlay(
            initialText: "",
            initialStyle: const TextStyle(
              fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold,
            ),
            onSubmit: (newText, newStyle, mode, color, align) {
              if (newText.trim().isEmpty) { Navigator.pop(context); return; } // 빈값 방지
              vm.addTextLayer(
                newText,
                style: newStyle,
                mode: mode,
                color: color,
                textAlign: align,
                canvasSize: canvasSize,
              );
              Navigator.pop(context);
            },
            onCancel: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  /// 기존 레이어 편집용 (open()과 동일하나 명시적 호출용)
  Future<void> openForExisting(LayerModel layer) async {
    final safeStyle = layer.textStyle ??
        const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.normal);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: EditTextOverlay(
                initialText: layer.text ?? "",
                initialStyle: safeStyle,
                initialMode: layer.textStyleType,
                initialBubbleColor: layer.bubbleColor,
                onSubmit: (newText, newStyle, mode, color, align) {
                  vm.updateLayer(
                    layer.copyWith(
                      text: newText,
                      textStyle: (newStyle ?? safeStyle),
                      textStyleType: mode,
                      bubbleColor: color,
                      textAlign: align,
                    ),
                  );
                  Navigator.pop(context);
                },
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
        );
      },
    );
  }
}