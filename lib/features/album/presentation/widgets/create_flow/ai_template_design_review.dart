import 'package:flutter/material.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/theme/snapfit_design_tokens.dart';
import '../../../ai_album/domain/ai_album_models.dart';
import '../../../domain/entities/layer.dart';
import 'creation_document_preview.dart';

class AiTemplateDesignReview extends StatefulWidget {
  const AiTemplateDesignReview({
    super.key,
    required this.design,
    this.targetCover,
    required this.onBack,
    required this.onAccept,
    required this.isAccepting,
  });
  final AiTemplateDesign design;
  final CoverSize? targetCover;
  final VoidCallback onBack;
  final VoidCallback onAccept;
  final bool isAccepting;

  @override
  State<AiTemplateDesignReview> createState() => _AiTemplateDesignReviewState();
}

class _AiTemplateDesignReviewState extends State<AiTemplateDesignReview> {
  Size get _canvas => widget.targetCover == null
      ? widget.design.canvasSize
      : coverCanvasBaseSize(widget.targetCover!);
  late List<List<LayerModel>> _layers = widget.design.buildLayers(
    targetSize: _canvas,
  );

  @override
  void didUpdateWidget(covariant AiTemplateDesignReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design != widget.design ||
        oldWidget.targetCover != widget.targetCover) {
      _layers = widget.design.buildLayers(targetSize: _canvas);
    }
  }

  String get _format {
    final cover = widget.targetCover ?? widget.design.coverSize;
    final size = cover.realSize;
    String number(double value) => value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
    final coverLabel = cover.productId == null
        ? ''
        : ' · ${cover.coverType.label}';
    return '${number(size.width)} × ${number(size.height)} cm$coverLabel · 내지 ${widget.design.pages.length - 1}쪽';
  }

  Future<void> _showDirection() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SnapFitColors.backgroundOf(context),
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (context) {
      final plan = widget.design.artDirection;
      final ink = SnapFitColors.textPrimaryOf(context);
      final muted = SnapFitColors.textSecondaryOf(context);
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
                          fontWeight: FontWeight.w600,
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
                        widget.design.concept,
                        style: TextStyle(
                          fontSize: 20,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _format,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.design.rationale,
                        style: TextStyle(fontSize: 14, height: 1.6, color: ink),
                      ),
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
    },
  );

  Widget _accept({required bool compact}) => FilledButton(
    onPressed: widget.isAccepting ? null : widget.onAccept,
    style: FilledButton.styleFrom(
      backgroundColor: SnapFitColors.textPrimaryOf(context),
      foregroundColor: SnapFitColors.backgroundOf(context),
      minimumSize: Size(compact ? 144 : double.infinity, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      textStyle: const TextStyle(
        fontFamily: SnapFitFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: widget.isAccepting
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Text('이 디자인 사용'),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: SnapFitColors.backgroundOf(context),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 640 &&
              constraints.maxWidth > constraints.maxHeight;
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
                            widget.design.concept,
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
                    IconButton(
                      tooltip: '디자인 요청 수정',
                      onPressed: widget.isAccepting ? null : widget.onBack,
                      icon: const Icon(Icons.edit_outlined, size: 21),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 12),
                      _accept(compact: true),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: CreationDocumentPreview(
                  pages: _layers,
                  canvas: _canvas,
                  preserveTypography: widget.design.artDirection != null,
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
