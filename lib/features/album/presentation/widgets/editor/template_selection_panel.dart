import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../domain/entities/layer.dart';
import '../../viewmodels/album_editor_view_model.dart';
import '../../../../../core/constants/page_templates.dart';

/// 페이지 템플릿 선택 바텀시트
/// - 다른 바텀시트들과 동일한 라운드/핸들 스타일
/// - Current(현재 레이아웃 유지) + 여러 템플릿 카드들을 가로 스크롤로 제공
class TemplateSelectionPanel extends ConsumerStatefulWidget {
  const TemplateSelectionPanel({super.key});

  @override
  ConsumerState<TemplateSelectionPanel> createState() => _TemplateSelectionPanelState();
}

class _TemplateSelectionPanelState extends ConsumerState<TemplateSelectionPanel> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final vm = ref.read(albumEditorViewModelProvider.notifier);
    final currentPage = vm.currentPage;
    final isCover = currentPage?.isCover ?? false;
    final aspect = vm.selectedCover.ratio > 0 ? vm.selectedCover.ratio : (3 / 4);

    // 캔버스 기준 사이즈 (내지는 300xH, 커버는 500xH 레퍼런스를 사용 – createPageFromTemplate와 동일 좌표계)
    final double baseW = isCover ? kCoverReferenceWidth : 300.0;
    final Size canvasSize = Size(baseW, baseW / aspect);

    final templates = pageTemplates;

    return Container(
      height: 290.h,
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
                  color: SnapFitColors.textPrimaryOf(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  final isSelected = _selectedId == template.id;
                  final isNew = index < 3; // 앞의 몇 개는 추천 느낌으로 뱃지 표시
                  return _buildTemplateCard(
                    context,
                    template: template,
                    isSelected: isSelected,
                    isNew: isNew,
                    pageRatio: aspect,
                    onTap: () {
                      setState(() {
                        _selectedId = template.id;
                      });
                      vm.applyTemplateToCurrentPage(template, canvasSize);
                      // 템플릿 적용 후 바텀시트 닫기
                      Navigator.of(context).pop();
                    },
                  );
                },
                separatorBuilder: (_, __) => SizedBox(width: 14.w),
                itemCount: templates.length,
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
    required PageTemplate template,
    required bool isSelected,
    required bool isNew,
    required double pageRatio,
    required VoidCallback onTap,
  }) {
    final baseColor = SnapFitColors.surfaceOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 112.w,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? SnapFitColors.accent : SnapFitColors.overlayLightOf(context),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: 10.h, left: 4.w, right: 4.w, bottom: 8.h),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: pageRatio, // 커버/페이지 비율에 맞춘 미리보기
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: SnapFitColors.backgroundOf(context),
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: SnapFitColors.overlayLightOf(context),
                          width: 1,
                        ),
                      ),
                      child: _TemplatePreview(
                        template: template,
                        pageRatio: pageRatio,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 6.h,
                left: 6.w,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    size: 12.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            if (isNew)
              Positioned(
                top: 2.h,
                right: 4.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C2E0).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12.sp,
                        color: Colors.white,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _templateSubtitle(PageTemplate template) {
    // 간단한 카테고리/서브텍스트를 이름 기반으로 매핑
    if (template.id == 'blank') return '자유 배치';
    if (template.name.contains('여행')) return '여행, 지도, 기록';
    if (template.name.contains('해변') || template.name.contains('바다')) return '바다, 휴가';
    if (template.name.contains('로드트립')) return '차, 드라이브';
    if (template.name.contains('모험')) return '액티비티';
    if (template.name.contains('스포츠')) return '팀, 경기';
    if (template.name.contains('결혼')) return '웨딩, 예식';
    if (template.name.contains('가족')) return '패밀리';
    if (template.name.contains('친구')) return '친구, 모임';
    return '사진 & 텍스트 조합';
  }
}

/// 하나의 템플릿을 작은 카드 안에 미니 레이아웃으로 그려주는 위젯
class _TemplatePreview extends StatelessWidget {
  final PageTemplate template;
  final double pageRatio;

  const _TemplatePreview({
    required this.template,
    required this.pageRatio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double w = constraints.maxWidth;
        double h = constraints.maxHeight;

        // 안전하게 비율 보정 (혹시라도 LayoutBuilder 제약과 어긋날 경우)
        if (w / (h == 0 ? 1 : h) != pageRatio) {
          h = w / pageRatio;
        }
        return Stack(
          children: template.slots.map((slot) {
            final left = slot.left * w;
            final top = slot.top * h;
            final width = slot.width * w;
            final height = slot.height * h;

            final isImage = slot.type == 'image';
            Widget child = isImage
                ? _buildImageSlotPreview(context, slot, width, height)
                : _buildTextSlotPreview(context, slot, width, height);

            if (slot.rotation != 0) {
              child = Transform.rotate(
                angle: slot.rotation * 3.1415926535 / 180,
                child: child,
              );
            }

            return Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }

  /// 실제 이미지 슬롯 스타일(polaroid, round, tape 등)을 최대한 비슷하게 표현
  Widget _buildImageSlotPreview(
    BuildContext context,
    PageTemplateSlot slot,
    double width,
    double height,
  ) {
    final bgKey = (slot.imageBackground ?? '').toLowerCase();
    final baseColor = SnapFitColors.textPrimaryOf(context).withOpacity(0.06);
    final borderColor = SnapFitColors.textPrimaryOf(context).withOpacity(0.20);

    BorderRadius radius;
    EdgeInsets innerPadding = EdgeInsets.zero;

    if (bgKey.contains('round')) {
      radius = BorderRadius.circular(width * 0.22);
    } else {
      radius = BorderRadius.circular(4.r);
    }

    // 폴라로이드류는 아래 여백을 살짝 더 줌
    if (bgKey.contains('polaroid')) {
      innerPadding = EdgeInsets.only(bottom: height * 0.10);
    }

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 0.7),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            left: 2.w,
            right: 2.w,
            top: 2.h,
            bottom: innerPadding.bottom == 0 ? 2.h : innerPadding.bottom,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.45),
                borderRadius: radius.subtract(BorderRadius.circular(1.r)),
              ),
            ),
          ),
          if (bgKey.contains('tape'))
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                width: width * 0.45,
                height: height * 0.14,
                margin: EdgeInsets.only(top: height * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 텍스트 슬롯 배경(tag, bubble, note 등)을 실제와 비슷하게 표현
  Widget _buildTextSlotPreview(
    BuildContext context,
    PageTemplateSlot slot,
    double width,
    double height,
  ) {
    final bgKey = (slot.textBackground ?? '').toLowerCase();
    final base = SnapFitColors.textPrimaryOf(context);

    BorderRadius radius = BorderRadius.circular(4.r);
    Color fill = base.withOpacity(0.03);
    Color line = base.withOpacity(0.28);

    if (bgKey.contains('tag')) {
      radius = BorderRadius.circular(999.r);
      fill = base.withOpacity(0.06);
    } else if (bgKey.contains('bubble')) {
      radius = BorderRadius.circular(999.r);
      fill = base.withOpacity(0.05);
    } else if (bgKey.contains('note')) {
      radius = BorderRadius.circular(6.r);
      fill = const Color(0xFFFFFDE7).withOpacity(0.9);
      line = const Color(0xFFFFC107).withOpacity(0.7);
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: base.withOpacity(0.15), width: 0.7),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: width * 0.65,
              height: 2.h,
              color: line,
            ),
            if (height > 18.h) ...[
              SizedBox(height: 3.h),
              Container(
                width: width * 0.45,
                height: 2.h,
                color: line.withOpacity(0.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
