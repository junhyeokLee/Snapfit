import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/design_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../providers/design_template_catalog_provider.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../controllers/layer_builder.dart';
import '../../controllers/layer_interaction_manager.dart';
import '../../../domain/entities/layer.dart';

class DesignTemplatePanel extends ConsumerStatefulWidget {
  const DesignTemplatePanel({super.key});

  @override
  ConsumerState<DesignTemplatePanel> createState() =>
      _DesignTemplatePanelState();
}

class _DesignTemplatePanelState extends ConsumerState<DesignTemplatePanel> {
  String? _selectedId;
  String _selectedCategory = '전체';

  Size _effectiveLogicalCanvasSize({
    required AlbumEditorViewModel vm,
    required AlbumEditorState? stateVal,
  }) {
    final currentPage = vm.currentPage;
    final isCover = currentPage?.isCover ?? false;
    final physical = isCover
        ? stateVal?.coverCanvasSize
        : stateVal?.innerCanvasSize;

    final double aspect =
        (physical != null &&
            physical != Size.zero &&
            physical.width > 0 &&
            physical.height > 0)
        ? (physical.width / physical.height)
        : (vm.selectedCover.ratio > 0 ? vm.selectedCover.ratio : (3 / 4));

    if (physical != null &&
        physical != Size.zero &&
        physical.width > 0 &&
        physical.height > 0) {
      return physical;
    }

    final double baseW = isCover ? kCoverReferenceWidth : 300.0;
    return Size(baseW, baseW / aspect);
  }

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final stateVal = ref.watch(albumEditorViewModelProvider).value;
    final currentPage = vm.currentPage;
    final Size canvasSize = _effectiveLogicalCanvasSize(
      vm: vm,
      stateVal: stateVal,
    );

    final templateAspect = _resolveAspect(canvasSize);

    final catalogAsync = ref.watch(designTemplateCatalogProvider);
    final hasCatalogData = catalogAsync.hasValue && catalogAsync.value != null;
    // 기존 값이 있더라도 로딩 중에는 리스트를 숨겨 "보였다가 바뀌는" 느낌을 제거
    final isCatalogLoading = catalogAsync.isLoading;
    final allTemplates = hasCatalogData ? catalogAsync.value! : designTemplates;

    final categories = <String>{
      '전체',
      ...allTemplates.map((t) => t.category).where((c) => c.trim().isNotEmpty),
    }.toList();
    int _countByCategory(String category) {
      if (category == '전체') {
        return allTemplates.length;
      }
      return allTemplates.where((t) => t.category == category).length;
    }

    final templates =
        allTemplates
            .where(
              (t) =>
                  t.aspect == TemplateAspect.any || t.aspect == templateAspect,
            )
            .where(
              (t) =>
                  _selectedCategory == '전체' || t.category == _selectedCategory,
            )
            // 커버/페이지에서 동일한 템플릿 셋을 노출한다.
            // 기존 cover_* 전용 항목은 중복 노출을 막기 위해 패널에서는 제외한다.
            .where((t) => !t.id.startsWith('cover_'))
            .toList()
          ..sort((a, b) {
            final aRef = a.id.startsWith('data_ref_');
            final bRef = b.id.startsWith('data_ref_');
            if (aRef != bRef) return aRef ? -1 : 1;
            return a.name.compareTo(b.name);
          });

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12.h),
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: SnapFitColors.textPrimaryOf(
                    context,
                  ).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                '템플릿',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                '전체',
                style: TextStyle(
                  fontSize: 11.8.sp,
                  fontWeight: FontWeight.w800,
                  color: SnapFitColors.textSecondaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in categories)
                      Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: _FilterPill(
                          label: c,
                          count: _countByCategory(c),
                          selected: _selectedCategory == c,
                          onTap: () {
                            setState(() {
                              _selectedCategory = c;
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: isCatalogLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2.2,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              '템플릿 불러오는 중...',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: SnapFitColors.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12.w,
                          mainAxisSpacing: 12.h,
                          childAspectRatio: 1 / 1.1,
                        ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          final isSelected = _selectedId == template.id;
                          return _buildTemplateCard(
                            context,
                            template: template,
                            isSelected: isSelected,
                            logicalCanvasSize: canvasSize,
                            ref: ref,
                            onTap: () {
                              setState(() => _selectedId = template.id);
                              vm.applyDesignTemplateToCurrentPage(
                                template,
                                canvasSize,
                              );
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
              ),
            ),
            SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
    BuildContext context, {
    required DesignTemplate template,
    required bool isSelected,
    required Size logicalCanvasSize,
    required WidgetRef ref,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? SnapFitColors.accent
                    : SnapFitColors.overlayLightOf(context),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio:
                        logicalCanvasSize.width / logicalCanvasSize.height,
                    child: Container(
                      decoration: BoxDecoration(
                        color: SnapFitColors.backgroundOf(context),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: _DesignTemplatePreview(
                        template: template,
                        ref: ref,
                        logicalCanvasSize: logicalCanvasSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 6.h),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? const Color(0xFF132331)
        : SnapFitColors.surfaceOf(context);
    final fg = selected ? Colors.white : SnapFitColors.textSecondaryOf(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999.r),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF132331).withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
            border: Border.all(
              color: selected
                  ? const Color(0xFF20384D)
                  : SnapFitColors.overlayMediumOf(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: fg,
                  height: 1.0,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : SnapFitColors.overlayLightOf(context),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : SnapFitColors.textSecondaryOf(context),
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TemplateAspect _resolveAspect(Size canvasSize) {
  final ratio = canvasSize.width / canvasSize.height;
  if ((ratio - 1.0).abs() <= 0.08) {
    return TemplateAspect.square;
  }
  return ratio > 1.0 ? TemplateAspect.landscape : TemplateAspect.portrait;
}

class _DesignTemplatePreview extends StatelessWidget {
  final DesignTemplate template;
  final WidgetRef ref;
  final Size logicalCanvasSize;

  const _DesignTemplatePreview({
    required this.template,
    required this.ref,
    required this.logicalCanvasSize,
  });

  @override
  Widget build(BuildContext context) {
    final previewInteraction = LayerInteractionManager.preview(
      ref,
      () => logicalCanvasSize,
    );
    final layerBuilder = LayerBuilder(
      previewInteraction,
      () => logicalCanvasSize,
    );

    final layers = template.buildLayers(logicalCanvasSize);
    final ordered = previewInteraction.sortByZ(layers);

    return FittedBox(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      child: SizedBox(
        width: logicalCanvasSize.width,
        height: logicalCanvasSize.height,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              for (final layer in ordered)
                layer.type == LayerType.text
                    ? layerBuilder.buildText(layer)
                    : layerBuilder.buildImage(layer),
            ],
          ),
        ),
      ),
    );
  }
}
