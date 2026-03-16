import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/design_templates.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../viewmodels/album_editor_view_model.dart';

class DesignTemplatePanel extends ConsumerStatefulWidget {
  const DesignTemplatePanel({super.key});

  @override
  ConsumerState<DesignTemplatePanel> createState() =>
      _DesignTemplatePanelState();
}

class _DesignTemplatePanelState extends ConsumerState<DesignTemplatePanel> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final currentPage = vm.currentPage;
    final isCover = currentPage?.isCover ?? false;
    final aspect = vm.selectedCover.ratio > 0
        ? vm.selectedCover.ratio
        : (3 / 4);

    final Size canvasSize = isCover
        ? coverCanvasBaseSize(vm.selectedCover) // 커버는 고정 캔버스 크기 기준
        : Size(300.0, 300.0 / aspect); // 내지는 기존 논리 좌표계 유지

    final templates = designTemplates
        .where((t) => !t.forCover || isCover == t.forCover || !isCover)
        .toList();

    return Container(
      height: 520.h,
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
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GridView.builder(
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
                      child: Center(
                        child: Text(
                          template.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
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
