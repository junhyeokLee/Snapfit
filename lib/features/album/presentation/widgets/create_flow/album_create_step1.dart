import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_primary_action_button.dart';

/// 스텝1: 제목, 커버 사이즈 선택, 페이지 수 선택
class AlbumCreateStep1 extends StatefulWidget {
  final String albumTitle;
  final String? templateTitle;
  final String? templatePreviewImageUrl;
  final CoverSize? selectedCover;
  final int selectedPageCount;
  final int minPageCount;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<CoverSize> onCoverSelected;
  final ValueChanged<int> onPageCountChanged;
  final VoidCallback onNext;

  const AlbumCreateStep1({
    super.key,
    required this.albumTitle,
    this.templateTitle,
    this.templatePreviewImageUrl,
    required this.selectedCover,
    required this.selectedPageCount,
    this.minPageCount = 10,
    required this.onTitleChanged,
    required this.onCoverSelected,
    required this.onPageCountChanged,
    required this.onNext,
  });

  @override
  State<AlbumCreateStep1> createState() => _AlbumCreateStep1State();
}

class _AlbumCreateStep1State extends State<AlbumCreateStep1> {
  static const int _maxPageCount = 50;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    ScreenLogger.widget('AlbumCreateStep1', '앨범 생성 Step 1 · 제목/커버/페이지 수 입력');
    _titleController = TextEditingController(text: widget.albumTitle);
  }

  @override
  void didUpdateWidget(AlbumCreateStep1 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumTitle != widget.albumTitle) {
      _titleController.text = widget.albumTitle;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 18.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.templateTitle != null &&
              widget.templateTitle!.trim().isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: SnapFitColors.overlayLightOf(context),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: SizedBox(
                      width: 52.w,
                      height: 52.w,
                      child:
                          (widget.templatePreviewImageUrl != null &&
                              widget.templatePreviewImageUrl!.isNotEmpty)
                          ? Image.network(
                              widget.templatePreviewImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: SnapFitColors.overlayLightOf(context),
                              ),
                            )
                          : Container(
                              color: SnapFitColors.overlayLightOf(context),
                            ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '선택한 템플릿',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          widget.templateTitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: SnapFitColors.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 18.h),
          ],
          // 메인 타이틀 (STEP 표시는 플로우 상단에서 공통 표시)
          Text(
            '어떤 추억을\n책으로 만들까요?',
            style: TextStyle(
              fontSize: 23.sp,
              fontWeight: FontWeight.w900,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            '제목은 나중에 바꿀 수 있어요. 먼저 사진이 담길 책의 분위기와 분량을 가볍게 정해보세요.',
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.42,
              fontWeight: FontWeight.w600,
              color: SnapFitColors.textSecondaryOf(context),
            ),
          ),
          SizedBox(height: 24.h),
          Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: SnapFitColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(color: SnapFitColors.overlayLightOf(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    SnapFitColors.isDark(context) ? 0.20 : 0.05,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 앨범 제목
                Text(
                  '포토북 제목',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
                SizedBox(height: 8.h),
                // 그라데이션 테두리 + 카드형 텍스트 에디터
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: SnapFitColors.primaryGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Container(
                    margin: EdgeInsets.all(1.5.w),
                    decoration: BoxDecoration(
                      color: SnapFitColors.surfaceOf(context),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: TextField(
                      controller: _titleController,
                      onChanged: (value) {
                        widget.onTitleChanged(value);
                      },
                      decoration: InputDecoration(
                        hintText: '제주 바람 기록 · 우리 아기 첫 계절',
                        hintStyle: TextStyle(
                          // 예시 텍스트는 아주 연하게
                          color: SnapFitColors.textMutedOf(
                            context,
                          ).withOpacity(0.3),
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 14.h,
                        ),
                        prefixIcon: Icon(
                          Icons.auto_awesome_rounded,
                          color: SnapFitColors.accentLight,
                          size: 20.sp,
                        ),
                        suffixIcon: Icon(
                          Icons.edit_outlined,
                          color: SnapFitColors.textMutedOf(context),
                          size: 18.sp,
                        ),
                        counterText: '',
                      ),
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLength: 50,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '언제든 다시 바꿀 수 있어요.',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: SnapFitColors.textMutedOf(context),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (context, value, _) {
                        return Text(
                          '${value.text.length}/50',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 30.h),
                // 사이즈 선택
                Text(
                  '책 크기 선택',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
                SizedBox(height: 16.h),
                _buildSizeSelector(context),
                SizedBox(height: 30.h),
                // 페이지 수 선택
                Text(
                  '분량 선택',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
                SizedBox(height: 16.h),
                _buildPageCountSelector(context),
              ],
            ),
          ),
          SizedBox(height: 28.h),
          // 다음 버튼 (제목/사이즈 상태에 따라 활성화)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _titleController,
            builder: (context, value, _) {
              final canProceed =
                  value.text.isNotEmpty && widget.selectedCover != null;
              return SnapFitPrimaryActionButton(
                label: '표지 먼저 확인하기',
                onPressed: canProceed ? widget.onNext : null,
                icon: Icons.arrow_forward,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector(BuildContext context) {
    // 기획 기준: 가로 / 정사각형 / 세로
    final horizontal = coverSizes.firstWhere(
      (s) => s.name == '가로형',
      orElse: () => coverSizes[2],
    );
    final square = coverSizes.firstWhere(
      (s) => s.name == '정사각형',
      orElse: () => coverSizes[1],
    );
    final vertical = coverSizes.firstWhere(
      (s) => s.name == '세로형',
      orElse: () => coverSizes[0],
    );

    // 가로형, 정사각형, 세로형 옵션
    final sizeOptions = [
      {'name': '가로형', 'cover': horizontal},
      {'name': '정사각형', 'cover': square},
      {'name': '세로형', 'cover': vertical},
    ];

    return Row(
      children: sizeOptions.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final cover = option['cover'] as CoverSize;
        final isSelected = widget.selectedCover?.name == cover.name;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              widget.onCoverSelected(cover);
            },
            child: Container(
              margin: EdgeInsets.only(
                right: index != sizeOptions.length - 1 ? 12.w : 0,
              ),
              padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 18.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? SnapFitColors.accent.withOpacity(0.12)
                    : SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayLightOf(context),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 사이즈 비율 미리보기 (가로/정사각형/세로형)
                  SizedBox(
                    width: 80.w,
                    height: 80.w,
                    child: _SizePreviewFrame(
                      cover: cover,
                      color: SnapFitColors.textPrimaryOf(
                        context,
                      ).withOpacity(0.35),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    option['name'] as String,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: SnapFitColors.textPrimaryOf(context),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    '${cover.realSize.width.toInt()}x${cover.realSize.height.toInt()} cm',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: SnapFitColors.textMutedOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageCountSelector(BuildContext context) {
    final minPage = widget.minPageCount.clamp(1, _maxPageCount);
    final suggested =
        <({int pages, String title, String body, bool recommended})>[
          (
            pages: minPage,
            title: '${minPage}쪽',
            body: '가볍게 시작',
            recommended: false,
          ),
          (
            pages: mathMax(minPage, 24),
            title: '${mathMax(minPage, 24)}쪽',
            body: '가장 추천',
            recommended: true,
          ),
          (
            pages: mathMax(minPage, 36),
            title: '${mathMax(minPage, 36)}쪽',
            body: '풍성하게',
            recommended: false,
          ),
        ];
    final options =
        <({int pages, String title, String body, bool recommended})>[];
    final seen = <int>{};
    for (final option in suggested) {
      final pages = option.pages.clamp(minPage, _maxPageCount);
      if (seen.add(pages)) {
        options.add((
          pages: pages,
          title: '${pages}쪽',
          body: option.body,
          recommended: option.recommended,
        ));
      }
    }
    final safePageCount = widget.selectedPageCount.clamp(
      minPage,
      _maxPageCount,
    );
    if (safePageCount != widget.selectedPageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onPageCountChanged(safePageCount);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = safePageCount == option.pages;
            return Expanded(
              child: GestureDetector(
                onTap: () => widget.onPageCountChanged(option.pages),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: EdgeInsets.only(
                    right: index == options.length - 1 ? 0 : 10.w,
                  ),
                  padding: EdgeInsets.fromLTRB(12.w, 13.h, 12.w, 12.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? SnapFitColors.accent.withOpacity(0.12)
                        : SnapFitColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(18.r),
                    border: Border.all(
                      color: isSelected
                          ? SnapFitColors.accent.withOpacity(0.72)
                          : SnapFitColors.overlayLightOf(context),
                      width: isSelected ? 1.6 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: SnapFitColors.accent.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (option.recommended) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: SnapFitColors.accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                          child: Text(
                            '추천',
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w900,
                              color: SnapFitColors.accent,
                            ),
                          ),
                        ),
                        SizedBox(height: 9.h),
                      ] else
                        SizedBox(height: 25.h),
                      Text(
                        option.title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: SnapFitColors.textPrimaryOf(context),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        option.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: SnapFitColors.textMutedOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: 10.h),
        Text(
          '분량은 편집 중에도 페이지를 더하거나 줄일 수 있어요.',
          style: TextStyle(
            fontSize: 11.sp,
            color: SnapFitColors.textMutedOf(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;
}

/// 사이즈 카드 내부에 사용하는 비율 미리보기 프레임
class _SizePreviewFrame extends StatelessWidget {
  final CoverSize cover;
  final Color color;

  const _SizePreviewFrame({required this.cover, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = cover.realSize.width / cover.realSize.height;
    // 모든 타입의 최대 변 길이는 동일하게 맞추고,
    // 정사각형보다 크지 않게 스케일링
    const double maxSide = 60;
    double width;
    double height;
    if (ratio >= 1) {
      // 가로형: 가로가 최대, 세로는 비율에 맞게 축소
      width = maxSide;
      height = maxSide / ratio;
    } else {
      // 세로형: 세로가 최대, 가로는 비율에 맞게 축소
      height = maxSide;
      width = maxSide * ratio;
    }

    return SizedBox(
      width: maxSide,
      height: maxSide,
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.r),
            border: Border.all(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}
