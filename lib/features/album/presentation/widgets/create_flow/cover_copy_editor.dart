import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/widgets/experience_style.dart';
import '../../../../profile/domain/order_visibility_owner.dart';
import '../../../../store/presentation/widgets/template_page_renderer.dart';
import '../../../domain/entities/layer.dart';
import 'cover_copy_changes.dart';

/// An isolated text draft. Canceling never touches the creation document.
class CoverCopyEditor extends ConsumerStatefulWidget {
  const CoverCopyEditor({
    super.key,
    required this.layers,
    required this.cover,
    required this.ownerId,
    required this.isCurrent,
    required this.onApply,
    required this.onCancel,
    this.preserveTypography = false,
  });

  final List<LayerModel> layers;
  final CoverSize cover;
  final String ownerId;
  final bool Function() isCurrent;
  final ValueChanged<Map<String, String>> onApply;
  final VoidCallback onCancel;
  final bool preserveTypography;

  @override
  ConsumerState<CoverCopyEditor> createState() => _CoverCopyEditorState();
}

class _CoverCopyEditorState extends ConsumerState<CoverCopyEditor> {
  late final _text = widget.layers
      .where((layer) => layer.type == LayerType.text)
      .toList();
  late final _controllers = {
    for (final layer in _text)
      layer.id: TextEditingController(text: layer.text ?? ''),
  };
  String? _selected;
  bool _closing = false;

  Map<String, String> get _values => {
    for (final entry in _controllers.entries) entry.key: entry.value.text,
  };

  bool get _current =>
      mounted &&
      ref.read(visibleOrderOwnerProvider) == widget.ownerId &&
      widget.isCurrent();

  void _expire() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCancel();
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(visibleOrderOwnerProvider);
    if (owner != widget.ownerId || !widget.isCurrent()) {
      _expire();
      return const SizedBox.shrink();
    }
    final changes = CoverCopyChanges.fromValues(widget.layers, _values);
    final preview = changes.applyTo(widget.layers);
    return Scaffold(
      appBar: ExperienceHeader(
        title: '표지 문구 수정',
        showNotifications: false,
        onBack: widget.onCancel,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final wide =
                bounds.maxWidth >= 840 &&
                bounds.maxHeight >= 480 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.4;
            final canvas = coverCanvasBaseSize(widget.cover);
            final artwork = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? 520 : 420,
                  maxHeight: wide ? bounds.maxHeight - 32 : 280,
                ),
                child: AspectRatio(
                  aspectRatio: widget.cover.ratio,
                  child: ColoredBox(
                    color: Colors.white,
                    child: FittedBox(
                      child: TemplatePageRenderer(
                        key: const ValueKey('cover-copy-preview'),
                        layers: preview,
                        width: canvas.width,
                        height: canvas.height,
                        designCanvasSize: canvas,
                        selectedLayerId: _selected,
                        preserveTypography: widget.preserveTypography,
                        cacheNetworkImages: true,
                        imageDecodeWidth: 1000,
                      ),
                    ),
                  ),
                ),
              ),
            );
            final fields = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '표지를 보며 글만 바꿔보세요.',
                  style: ExperienceFormStyle.text(
                    context,
                    17,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '글꼴과 사진, 배치는 그대로예요.',
                  style: ExperienceFormStyle.text(context, 13, secondary: true),
                ),
                const SizedBox(height: 20),
                for (var index = 0; index < _text.length; index++) ...[
                  TextField(
                    key: ValueKey('cover-copy-field-${_text[index].id}'),
                    controller: _controllers[_text[index].id],
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: ExperienceFormStyle.input(context).copyWith(
                      labelText: '문구 ${index + 1}',
                      alignLabelWithHint: true,
                    ),
                    onTap: () => setState(() => _selected = _text[index].id),
                    onChanged: (_) {
                      if (!_current) {
                        _expire();
                        return;
                      }
                      setState(() => _selected = _text[index].id);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: artwork,
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: fields,
                    ),
                  ),
                ],
              );
            }
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [artwork, const SizedBox(height: 24), fields],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('cover-copy-cancel'),
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(minimumSize: const Size(80, 48)),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const ValueKey('cover-copy-apply'),
                style: FilledButton.styleFrom(minimumSize: const Size(112, 48)),
                onPressed: changes.isEmpty
                    ? null
                    : () {
                        if (!_current) {
                          _expire();
                          return;
                        }
                        widget.onApply(_values);
                      },
                child: const Text('표지에 적용'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
