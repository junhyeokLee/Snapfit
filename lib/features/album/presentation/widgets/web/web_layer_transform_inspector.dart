import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/web/web_design.dart';
import '../../../domain/entities/layer.dart';

typedef WebLayerTransformChanged =
    void Function({
      double? x,
      double? y,
      double? width,
      double? height,
      double? rotation,
    });

/// Precision controls for a desktop web editor's selected layer.
///
/// The caller passes the current transform in [layer] and its unscaled rendered
/// [baseSize]. Width/height are displayed frame dimensions before rotation,
/// rather than the axis-aligned bounds of a rotated layer. The caller retains
/// ownership of uniform scaling, undo history, and persistence.
class WebLayerTransformInspector extends StatefulWidget {
  const WebLayerTransformInspector({
    super.key,
    required this.layer,
    required this.baseSize,
    required this.onChanged,
    this.enabled = true,
  });

  final LayerModel layer;
  final Size baseSize;
  final WebLayerTransformChanged onChanged;
  final bool enabled;

  @override
  State<WebLayerTransformInspector> createState() =>
      _WebLayerTransformInspectorState();
}

class _WebLayerTransformInspectorState
    extends State<WebLayerTransformInspector> {
  final _rotation = GlobalKey<_TransformNumberFieldState>();
  bool _expanded = false;

  bool get _validBase =>
      widget.baseSize.width.isFinite &&
      widget.baseSize.height.isFinite &&
      widget.baseSize.width > 0 &&
      widget.baseSize.height > 0;

  void _emit(
    String owner, {
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
  }) {
    if (!mounted || !widget.enabled || widget.layer.id != owner) return;
    widget.onChanged(
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: rotation,
    );
  }

  String? _validateDimension(double value, double base) {
    if (value <= 0) return '0보다 큰 값을 입력해주세요.';
    final scale = value / base;
    if (!scale.isFinite || scale < .3 - 1e-9 || scale > 3 + 1e-9) {
      return '${_formatNumber(base * .3)}~${_formatNumber(base * 3)} px 범위예요.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final layer = widget.layer;
    final owner = layer.id;
    final rotation = _normalizeRotation(layer.rotation);
    Widget field({
      required String name,
      required String label,
      required double value,
      required ValueChanged<double> commit,
      String? Function(double)? validate,
      double Function(double)? normalize,
      bool dimension = false,
      GlobalKey<_TransformNumberFieldState>? stateKey,
    }) => _TransformNumberField(
      key: stateKey ?? ValueKey(name),
      fieldKey: ValueKey('web-layer-$name'),
      ownerId: owner,
      label: label,
      value: value,
      unit: name == 'rotation' ? '°' : 'px',
      enabled: widget.enabled && (!dimension || _validBase),
      validate: validate,
      normalize: normalize,
      onCommit: commit,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            expanded: _expanded,
            child: TextButton(
              key: const ValueKey('web-layer-advanced-toggle'),
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                minimumSize: const Size(0, 48),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 17, color: palette.brandInk),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '고급 조정',
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (!_expanded) _caption('위치·크기·회전을 숫자로 조정할 수 있어요.', palette),
          if (_expanded) ...[
            const SizedBox(height: 6),
            _caption('문서 기준 좌표(px) · 페이지 가로 500', palette),
            const SizedBox(height: 14),
            _caption('위치 · 레이어 기준 좌표', palette),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    name: 'x',
                    label: 'X',
                    value: layer.position.dx,
                    commit: (value) => _emit(owner, x: value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: field(
                    name: 'y',
                    label: 'Y',
                    value: layer.position.dy,
                    commit: (value) => _emit(owner, y: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _caption('크기 · 가로·세로 비율 유지', palette)),
                Icon(Icons.link_rounded, size: 15, color: palette.muted),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    name: 'width',
                    label: '가로',
                    value: widget.baseSize.width * layer.scale,
                    dimension: true,
                    validate: (value) =>
                        _validateDimension(value, widget.baseSize.width),
                    commit: (value) => _emit(owner, width: value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: field(
                    name: 'height',
                    label: '세로',
                    value: widget.baseSize.height * layer.scale,
                    dimension: true,
                    validate: (value) =>
                        _validateDimension(value, widget.baseSize.height),
                    commit: (value) => _emit(owner, height: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: field(
                    stateKey: _rotation,
                    name: 'rotation',
                    label: '회전',
                    value: rotation,
                    normalize: _normalizeRotation,
                    commit: (value) => _emit(owner, rotation: value),
                  ),
                ),
                const SizedBox(width: 8),
                Listener(
                  // Mouse reset discards an unfinished angle before the button
                  // takes focus, avoiding a draft commit followed by a reset.
                  onPointerDown: (_) => _rotation.currentState?.revert(),
                  child: TextButton(
                    key: const ValueKey('web-layer-rotation-reset'),
                    onPressed: widget.enabled && rotation != 0
                        ? () {
                            _rotation.currentState?.revert();
                            _emit(owner, rotation: 0);
                          }
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: palette.brandInk,
                      minimumSize: const Size(56, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('0°로', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _caption(switch (layer.type) {
              LayerType.image =>
                '사진 영역의 크기를 조절해요. 사진 안쪽의 위치·잘라내기는 사진 편집 도구에서 바꿔주세요.',
              LayerType.text => '글 내용과 글꼴은 글 편집 도구에서 바꿀 수 있어요.',
              _ => 'Enter 또는 다른 곳을 클릭하면 적용해요. Esc를 누르면 입력을 되돌려요.',
            }, palette),
          ],
        ],
      ),
    );
  }

  Widget _caption(String text, WebPalette palette) => Text(
    text,
    style: TextStyle(fontSize: 11, height: 1.5, color: palette.muted),
  );
}

double _normalizeRotation(double value) {
  if (!value.isFinite) return value;
  final result = (value + 180) % 360 - 180;
  return result == 0 ? 0 : result;
}

String _formatNumber(double value) {
  if (!value.isFinite) return '';
  final formatted = value.toStringAsFixed(3);
  return formatted.contains('e')
      ? formatted
      : formatted.replaceFirst(RegExp(r'\.?0+$'), '');
}

class _TransformNumberField extends StatefulWidget {
  const _TransformNumberField({
    super.key,
    required this.fieldKey,
    required this.ownerId,
    required this.label,
    required this.value,
    required this.unit,
    required this.enabled,
    required this.onCommit,
    this.validate,
    this.normalize,
  });

  final Key fieldKey;
  final String ownerId;
  final String label;
  final double value;
  final String unit;
  final bool enabled;
  final ValueChanged<double> onCommit;
  final String? Function(double)? validate;
  final double Function(double)? normalize;

  @override
  State<_TransformNumberField> createState() => _TransformNumberFieldState();
}

class _TransformNumberFieldState extends State<_TransformNumberField> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _hasDraft = false;
  bool _pendingCommit = false;
  bool _disposing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatNumber(widget.value));
    _focus = FocusNode(onKeyEvent: _handleKey)..addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(covariant _TransformNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId ||
        oldWidget.enabled && !widget.enabled ||
        oldWidget.value != widget.value && !(_focus.hasFocus && _hasDraft)) {
      _restore();
    }
  }

  void _restore() {
    _hasDraft = false;
    _pendingCommit = false;
    _error = null;
    _controller.text = _formatNumber(widget.value);
  }

  void revert() {
    if (_disposing || !mounted) return;
    setState(_restore);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      revert();
      _focus.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusChanged() {
    if (!_focus.hasFocus) _commit();
  }

  void _commit() {
    if (_disposing || !mounted || !widget.enabled || !_pendingCommit) return;
    _pendingCommit = false;
    final parsed = double.tryParse(_controller.text.trim());
    final normalized = parsed == null
        ? null
        : widget.normalize?.call(parsed) ?? parsed;
    final error = normalized == null || !normalized.isFinite
        ? '유효한 숫자를 입력해주세요.'
        : widget.validate?.call(normalized);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final value = normalized!;
    setState(() {
      _hasDraft = false;
      _error = null;
      _controller.text = _formatNumber(value);
    });
    if ((value - widget.value).abs() > 1e-9) widget.onCommit(value);
  }

  @override
  void dispose() {
    _disposing = true;
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = WebPalette.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(7),
      borderSide: BorderSide(color: palette.line),
    );
    return TextField(
      key: widget.fieldKey,
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      textInputAction: TextInputAction.done,
      style: TextStyle(fontSize: 13, color: palette.ink),
      onChanged: (_) {
        _hasDraft = true;
        _pendingCommit = true;
        if (_error != null) setState(() => _error = null);
      },
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.unit,
        labelStyle: TextStyle(fontSize: 12, color: palette.muted),
        suffixStyle: TextStyle(fontSize: 11, color: palette.muted),
        filled: true,
        fillColor: widget.enabled ? palette.surface : palette.canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 13,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: palette.brandInk, width: 1.5),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: palette.danger),
        ),
        errorStyle: TextStyle(fontSize: 10, color: palette.danger),
        errorMaxLines: 3,
        errorText: _error,
      ),
    );
  }
}
