import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/web/web_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../core/constants/page_templates.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';
import '../../../../../shared/widgets/catalog_favorite_widgets.dart';
import 'template_apply_preview.dart';

/// 페이지 템플릿 선택 바텀시트
/// - 여러 레이아웃 템플릿, 슬롯 간 여백 있음
class TemplateSelectionPanel extends ConsumerStatefulWidget {
  final String title;

  const TemplateSelectionPanel({
    super.key,
    this.title = '레이아웃',
    this.closeOnApply = true,
    this.showHeader = true,
  });
  final bool closeOnApply;
  final bool showHeader;

  @override
  ConsumerState<TemplateSelectionPanel> createState() =>
      _TemplateSelectionPanelState();
}

class _TemplateSelectionPanelState
    extends ConsumerState<TemplateSelectionPanel> {
  String? _selectedId;
  bool _favoritesOnly = false;
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) =>
      CatalogFavoritesBuilder(builder: _buildCatalog);

  Widget _buildCatalog(BuildContext context, CatalogFavorites favorites) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final aspect = vm.selectedCover.ratio > 0
        ? vm.selectedCover.ratio
        : (3 / 4);

    final double baseW = kCoverReferenceWidth;
    final Size canvasSize = Size(baseW, baseW / aspect);

    final templates = favorites.arrange(
      pageTemplates,
      (t) => CatalogFavoriteKeys.layout(t.id),
      onlyFavorites: _favoritesOnly,
    );

    final maxSheetHeight = (MediaQuery.sizeOf(context).height * 0.90).clamp(
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
            : BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!kIsWeb) ...[
              SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SnapFitColors.textPrimaryOf(
                      context,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
            ],
            if (widget.showHeader && (!kIsWeb || widget.closeOnApply))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title == '레이아웃' ? '쪽 레이아웃 고르기' : widget.title,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: kIsWeb
                              ? FontWeight.w700
                              : FontWeight.w900,
                          color: kIsWeb
                              ? WebPalette.of(context).ink
                              : SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                    ),
                    if (kIsWeb)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: '레이아웃 닫기',
                        icon: const Icon(Icons.close, size: 20),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CatalogFavoriteFilter(
                selected: _favoritesOnly,
                onChanged: (value) => setState(() => _favoritesOnly = value),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: templates.isEmpty
                    ? CatalogFavoritesEmpty(
                        onShowAll: () => setState(() => _favoritesOnly = false),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent:
                              160 + MediaQuery.textScalerOf(context).scale(24),
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final isSelected = _selectedId == template.id;
                          return CatalogFavoriteTile(
                            key: ValueKey(template.id),
                            itemKey: CatalogFavoriteKeys.layout(template.id),
                            label: template.name,
                            child: RepaintBoundary(
                              child: _TemplateCard(
                                template: template,
                                isSelected: isSelected,
                                pageRatio: aspect,
                                onTap: () async {
                                  if (_isApplying) return;
                                  _isApplying = true;
                                  final pageId = vm.currentPage?.id;
                                  try {
                                    final approved =
                                        await showTemplateApplyPreview(
                                          context,
                                          title: template.name,
                                          replacesContent:
                                              vm
                                                  .currentPage
                                                  ?.layers
                                                  .isNotEmpty ??
                                              false,
                                          preview: AspectRatio(
                                            aspectRatio: aspect,
                                            child: CustomPaint(
                                              painter: _SlotPreviewPainter(
                                                template,
                                              ),
                                            ),
                                          ),
                                        );
                                    if (!mounted ||
                                        !approved ||
                                        vm.currentPage?.id != pageId)
                                      return;
                                    vm.applyTemplateToCurrentPage(
                                      template,
                                      canvasSize,
                                    );
                                    setState(() => _selectedId = template.id);
                                    if (widget.closeOnApply)
                                      Navigator.of(context).pop();
                                  } finally {
                                    _isApplying = false;
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final PageTemplate template;
  final bool isSelected;
  final double pageRatio;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.pageRatio,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SnapFitPressable(
      onTap: onTap,
      semanticLabel: '${template.name} 레이아웃 미리보기',
      selected: isSelected,
      pressedScale: 0.98,
      borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: SnapFitMotion.settle,
        decoration: BoxDecoration(
          color: kIsWeb
              ? WebPalette.of(context).surface
              : SnapFitColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(kIsWeb ? 12 : 8),
          border: Border.all(
            color: isSelected
                ? kIsWeb
                      ? WebPalette.of(context).brandInk
                      : SnapFitColors.accent
                : kIsWeb
                ? WebPalette.of(context).line
                : SnapFitColors.overlayLightOf(context),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: kIsWeb
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      SnapFitColors.isDark(context) ? 0.22 : 0.06,
                    ),
                    blurRadius: isSelected ? 20 : 12,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: pageRatio,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: CustomPaint(
                              painter: _SlotPreviewPainter(template),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SnapFitColors.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: kIsWeb
                                ? WebPalette.of(context).onBrand
                                : Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                template.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.textPrimaryOf(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2),
              Text(
                '${template.slots.length}컷 레이아웃',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textMutedOf(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 슬롯 레이아웃을 CustomPainter로 직접 그려서 위젯 트리 생성 비용을 완전히 제거.
/// LayerBuilder 없이 색 사각형으로만 표현해도 레이아웃 구분이 충분하다.
class _SlotPreviewPainter extends CustomPainter {
  final PageTemplate template;

  static const _imageFill = Color(0xFFF1E7DB);
  static const _imageBorder = Color(0xFFD8CBBB);
  static const _textFill = Color(0xFFFFF8E8);
  static const _textBorder = Color(0xFFE8D5A8);

  const _SlotPreviewPainter(this.template);

  @override
  void paint(Canvas canvas, Size size) {
    // 배경
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = template.backgroundColor,
    );

    final fillPaints = {
      'image': Paint()..color = _imageFill,
      'text': Paint()..color = _textFill,
    };
    final borderPaints = {
      'image': Paint()
        ..color = _imageBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
      'text': Paint()
        ..color = _textBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    };
    const radius = Radius.circular(3);

    for (final slot in template.slots) {
      final l = slot.left * size.width;
      final t = slot.top * size.height;
      final w = slot.width * size.width;
      final h = slot.height * size.height;
      final fill = fillPaints[slot.type] ?? fillPaints['image']!;
      final border = borderPaints[slot.type] ?? borderPaints['image']!;

      if (slot.rotation != 0) {
        canvas.save();
        canvas.translate(l + w / 2, t + h / 2);
        canvas.rotate(slot.rotation * math.pi / 180);
        final rect = Rect.fromLTWH(-w / 2, -h / 2, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), border);
        canvas.restore();
      } else {
        final rect = Rect.fromLTWH(l, t, w, h);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), border);
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPreviewPainter old) => old.template.id != template.id;
}
