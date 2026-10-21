import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import 'creation_workspace.dart';
import '../../../ai_album/domain/ai_album_models.dart';
import '../../../ai_album/domain/ai_template_paper_tone.dart';
import '../../../domain/entities/layer.dart';
import 'creation_document_preview.dart';
import 'ai_template_text_edit_dialog.dart';

class AiTemplateDesignReview extends StatefulWidget {
  const AiTemplateDesignReview({
    super.key,
    required this.design,
    this.targetCover,
    required this.onBack,
    required this.onAccept,
    required this.isAccepting,
    this.originalDesign,
    this.previousDesign,
    this.onDesignChanged,
    this.readOnly = false,
    this.alreadyAccepted = false,
  });
  final AiTemplateDesign design;
  final CoverSize? targetCover;
  final VoidCallback onBack;
  final VoidCallback onAccept;
  final bool isAccepting;
  final AiTemplateDesign? originalDesign;
  final AiTemplateDesign? previousDesign;
  final ValueChanged<AiTemplateDesign>? onDesignChanged;
  final bool readOnly;
  final bool alreadyAccepted;

  @override
  State<AiTemplateDesignReview> createState() => _AiTemplateDesignReviewState();
}

class _AiTemplateDesignReviewState extends State<AiTemplateDesignReview> {
  final _ownedDialogs = <Route<dynamic>, NavigatorState>{};
  bool _showPrevious = false;
  int _currentPage = 0;
  AiTemplateDesign get _design =>
      _showPrevious ? widget.previousDesign! : widget.design;
  Size get _canvas => _showPrevious || widget.targetCover == null
      ? _design.canvasSize
      : coverCanvasBaseSize(widget.targetCover!);
  late List<List<LayerModel>> _layers = _design.buildLayers(
    targetSize: _canvas,
  );

  void _refreshLayers() => _layers = _design.buildLayers(targetSize: _canvas);

  void _toggleComparison() => setState(() {
    _showPrevious = !_showPrevious;
    _currentPage = 0;
    _refreshLayers();
  });

  Future<T?> _showOwnedDialog<T>(WidgetBuilder builder) async {
    final navigator = Navigator.of(context);
    final route = DialogRoute<T>(
      context: context,
      builder: builder,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    );
    _ownedDialogs[route] = navigator;
    try {
      return await navigator.push<T>(route);
    } finally {
      _ownedDialogs.remove(route);
    }
  }

  void _closeOwnedDialogs() {
    final dialogs = _ownedDialogs.entries.toList(growable: false);
    _ownedDialogs.clear();
    if (dialogs.isEmpty) return;
    // Disposal can occur during a Navigator transition. Close only routes this
    // review created, once the transition's stack mutation has completed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final entry in dialogs) {
        if (entry.value.mounted && entry.key.isActive) {
          entry.value.removeRoute(entry.key);
        }
      }
    });
  }

  @override
  void dispose() {
    _closeOwnedDialogs();
    super.dispose();
  }

  Future<void> _showTextEditor() async {
    final startedDesign = widget.design;
    final updated = await _showOwnedDialog<AiTemplateDesign>(
      (_) => AiTemplateTextEditDialog(
        design: widget.design,
        originalDesign: widget.originalDesign ?? widget.design,
        initialPage: _currentPage,
      ),
    );
    if (!mounted ||
        updated == null ||
        widget.isAccepting ||
        !identical(startedDesign, widget.design))
      return;
    widget.onDesignChanged?.call(updated);
  }

  Future<void> _showPaperTones() async {
    final startedDesign = widget.design;
    final original = widget.originalDesign ?? widget.design;
    final selected = await _showOwnedDialog<AiTemplatePaperTone>(
      (context) => SimpleDialog(
        title: const Text('종이 톤'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              '사진·글·배치는 유지하고 밝은 종이 배경만 조절해요. 추가 AI 요청이나 포인트 사용은 없어요.',
            ),
          ),
          for (final tone in AiTemplatePaperTone.values)
            Builder(
              builder: (context) {
                final adjusted = withAiTemplatePaperTone(original, tone);
                final available =
                    tone == AiTemplatePaperTone.original ||
                    !identical(adjusted, original);
                final label = switch (tone) {
                  AiTemplatePaperTone.original => '원본으로 복원',
                  AiTemplatePaperTone.warm => '따뜻한 종이',
                  AiTemplatePaperTone.cool => '차분한 종이',
                };
                return SimpleDialogOption(
                  key: ValueKey('ai-paper-tone-${tone.name}'),
                  onPressed: available
                      ? () => Navigator.pop(context, tone)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(available ? label : '$label · 조절할 배경 없음'),
                  ),
                );
              },
            ),
        ],
      ),
    );
    if (!mounted ||
        selected == null ||
        widget.isAccepting ||
        !identical(startedDesign, widget.design))
      return;
    widget.onDesignChanged?.call(
      withAiTemplatePaperTone(original, selected, current: widget.design),
    );
  }

  @override
  void didUpdateWidget(covariant AiTemplateDesignReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design != widget.design ||
        oldWidget.targetCover != widget.targetCover ||
        oldWidget.previousDesign != widget.previousDesign ||
        oldWidget.isAccepting != widget.isAccepting ||
        oldWidget.readOnly != widget.readOnly) {
      _closeOwnedDialogs();
      if (widget.previousDesign == null) _showPrevious = false;
      _refreshLayers();
    }
  }

  String get _format {
    final cover = _showPrevious
        ? _design.coverSize
        : widget.targetCover ?? _design.coverSize;
    final size = cover.realSize;
    String number(double value) => value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    final coverLabel = cover.productId == null
        ? ''
        : ' · ${cover.coverType.label}';
    return '${number(size.width)} × ${number(size.height)} cm$coverLabel · 내지 ${_design.pages.length - 1}쪽';
  }

  Future<void> _showDirection() => _showOwnedDialog<void>(
    (context) => Dialog(
      child: SizedBox(
        width: kIsWeb ? 760 : 560,
        child: _directionContent(context),
      ),
    ),
  );

  Widget _directionContent(BuildContext context) {
    final plan = _design.artDirection;
    final ink = kIsWeb
        ? WebPalette.of(context).ink
        : SnapFitColors.textPrimaryOf(context);
    final muted = kIsWeb
        ? WebPalette.of(context).muted
        : SnapFitColors.textSecondaryOf(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '디자인 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '디자인 정보 닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _design.concept,
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_format, style: TextStyle(fontSize: 12, color: muted)),
                    const SizedBox(height: 16),
                    Text(
                      _design.rationale,
                      style: TextStyle(fontSize: 14, height: 1.6, color: ink),
                    ),
                    if (_design.compositionPlan case final intent?) ...[
                      const SizedBox(height: 24),
                      Text(
                        '요청 해석',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        intent.understanding,
                        style: TextStyle(fontSize: 14, height: 1.6, color: ink),
                      ),
                      if (intent.avoid.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '피할 요소',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          intent.avoid.join(' · '),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: ink,
                          ),
                        ),
                      ],
                      if (intent.verbatim.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '필수 문구',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                        const SizedBox(height: 6),
                        for (final copy in intent.verbatim)
                          Text(
                            copy,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: ink,
                            ),
                          ),
                      ],
                    ],
                    if (plan != null) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final hex in plan.palette)
                            Tooltip(
                              message: hex,
                              child: Semantics(
                                label: '색상 $hex',
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(hex.substring(1), radix: 16) +
                                          0xFF000000,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ink.withValues(alpha: .16),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        plan.typography.values
                            .map((type) => type.fontFamily)
                            .toSet()
                            .join(' · '),
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                      const SizedBox(height: 24),
                      for (final requirement in plan.requirements)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            requirement,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: ink,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accept({required bool compact}) => FilledButton(
    onPressed: widget.isAccepting
        ? null
        : widget.readOnly
        ? widget.onBack
        : _showPrevious
        ? _toggleComparison
        : widget.onAccept,
    style: CreationStyle.primary(context).copyWith(
      minimumSize: WidgetStatePropertyAll(
        Size(compact ? 144 : double.infinity, 48),
      ),
    ),
    child: widget.isAccepting
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(
            widget.readOnly
                ? '비교 닫기'
                : _showPrevious
                ? '현재 결과로 돌아가기'
                : widget.alreadyAccepted
                ? '이어서 편집'
                : '이 디자인 사용',
          ),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: kIsWeb
        ? WebPalette.of(context).surface
        : SnapFitColors.backgroundOf(context),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= (kIsWeb ? 720 : 520) &&
              (kIsWeb || constraints.maxWidth > constraints.maxHeight);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _design.concept,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: SnapFitColors.textPrimaryOf(context),
                            ),
                          ),
                          if (wide || constraints.maxHeight > 460) ...[
                            const SizedBox(height: 3),
                            Text(
                              _format,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: 11,
                                color: SnapFitColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '디자인 정보',
                      onPressed: _showDirection,
                      icon: const Icon(Icons.info_outline_rounded, size: 21),
                    ),
                    if (!widget.readOnly &&
                        !_showPrevious &&
                        widget.onDesignChanged != null)
                      IconButton(
                        tooltip: '종이 톤 조절',
                        onPressed: widget.isAccepting ? null : _showPaperTones,
                        icon: const Icon(Icons.palette_outlined, size: 21),
                      ),
                    if (!widget.readOnly &&
                        !_showPrevious &&
                        widget.onDesignChanged != null &&
                        widget.design.artDirection != null &&
                        widget.design.pages.any(
                          (page) => page.elements.any(
                            (element) => element.kind == 'text',
                          ),
                        ))
                      IconButton(
                        tooltip: '문구 수정',
                        onPressed: widget.isAccepting ? null : _showTextEditor,
                        icon: const Icon(Icons.edit_note_rounded, size: 21),
                      ),
                    IconButton(
                      tooltip: widget.readOnly ? '비교 닫기' : '디자인 요청 수정',
                      onPressed: widget.isAccepting ? null : widget.onBack,
                      icon: Icon(
                        widget.readOnly
                            ? Icons.close_rounded
                            : Icons.edit_outlined,
                        size: 21,
                      ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 12),
                      _accept(compact: true),
                    ],
                  ],
                ),
              ),
              if (widget.previousDesign != null || widget.readOnly)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.previousDesign != null)
                        TextButton.icon(
                          key: const ValueKey('ai-design-compare'),
                          onPressed: widget.isAccepting
                              ? null
                              : _toggleComparison,
                          icon: const Icon(
                            Icons.compare_arrows_rounded,
                            size: 18,
                          ),
                          label: Text(_showPrevious ? '현재 결과 보기' : '이전 결과와 비교'),
                        ),
                      if (_showPrevious || widget.readOnly)
                        const Text(
                          '이전 결과 · 비교 전용',
                          key: ValueKey('ai-design-comparison-only'),
                        ),
                    ],
                  ),
                ),
              if (widget.alreadyAccepted && !_showPrevious && !widget.readOnly)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('포인트 사용이 확인된 디자인이에요. 추가 차감 없이 이어서 편집해요.'),
                ),
              Expanded(
                child: CreationDocumentPreview(
                  key: ValueKey(_showPrevious),
                  pages: _layers,
                  initialPage: _currentPage,
                  onPageChanged: (page) => _currentPage = page,
                  canvas: _canvas,
                  preserveTypography: _design.artDirection != null,
                  showBookMaterial: true,
                  pageKeyPrefix: 'ai_design_page_',
                ),
              ),
              if (!wide)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: _accept(compact: false),
                ),
            ],
          );
        },
      ),
    ),
  );
}
