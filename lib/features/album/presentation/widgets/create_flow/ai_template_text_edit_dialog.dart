import 'package:flutter/material.dart';

import '../../../ai_album/domain/ai_album_models.dart';
import '../../../ai_album/domain/ai_template_text_edit.dart';

class AiTemplateTextEditDialog extends StatefulWidget {
  const AiTemplateTextEditDialog({
    super.key,
    required this.design,
    required this.originalDesign,
    required this.initialPage,
  });

  final AiTemplateDesign design;
  final AiTemplateDesign originalDesign;
  final int initialPage;

  @override
  State<AiTemplateTextEditDialog> createState() =>
      _AiTemplateTextEditDialogState();
}

class _AiTemplateTextEditDialogState extends State<AiTemplateTextEditDialog> {
  late final _choices = [
    for (final (page, designPage) in widget.design.pages.indexed)
      for (final element in designPage.elements)
        if (element.kind == 'text') (page: page, element: element),
  ];
  late var _selected = _choices
      .indexWhere((entry) => entry.page == widget.initialPage)
      .clamp(0, _choices.length - 1);
  late final _controller = TextEditingController(
    text: _choices[_selected].element.text,
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final selected = _choices[_selected];
    final updated = withAiTemplateText(
      widget.design,
      pageIndex: selected.page,
      elementId: selected.element.id,
      text: _controller.text,
    );
    if (updated == null) {
      setState(
        () => _error = _controller.text.trim().isEmpty
            ? '문구를 입력해 주세요.'
            : '현재 글꼴과 크기에 문구가 들어가지 않아요. 더 짧게 다듬어 주세요.',
      );
      return;
    }
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('문구 수정'),
    scrollable: true,
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('글꼴·크기·배치는 유지해요. 추가 AI 요청이나 포인트 사용은 없어요.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: const ValueKey('ai-text-element'),
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '수정할 문구'),
            items: [
              for (final (index, choice) in _choices.indexed)
                DropdownMenuItem(
                  key: ValueKey(
                    'ai-text-choice-${choice.page}-${choice.element.id}',
                  ),
                  value: index,
                  child: Text(
                    '${choice.page == 0 ? '앞표지' : '내지 ${choice.page}쪽'} · ${choice.element.text}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selected = value;
                _controller.text = _choices[value].element.text ?? '';
                _error = null;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('ai-text-edit-input'),
            controller: _controller,
            minLines: 2,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: '문구',
              errorText: _error,
              errorMaxLines: 4,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          TextButton(
            key: const ValueKey('ai-text-restore'),
            onPressed: () {
              final choice = _choices[_selected];
              final original = widget.originalDesign.pages[choice.page].elements
                  .where(
                    (element) =>
                        element.id == choice.element.id &&
                        element.kind == 'text',
                  )
                  .firstOrNull;
              if (original == null) return;
              setState(() {
                _controller.text = original.text ?? '';
                _error = null;
              });
            },
            child: const Text('원래 문구 불러오기'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const ValueKey('ai-text-apply'),
        onPressed: _apply,
        child: const Text('문구 적용'),
      ),
    ],
  );
}
