import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_primary_action_button.dart';

/// 스텝1: 제목, 커버 사이즈 선택, 페이지 수 선택
class AlbumCreateStep1 extends StatefulWidget {
  final String albumTitle;
  final CoverSize? selectedCover;
  final int selectedPageCount;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<CoverSize> onCoverSelected;
  final ValueChanged<int> onPageCountChanged;
  final VoidCallback onNext;

  const AlbumCreateStep1({
    super.key,
    required this.albumTitle,
    required this.selectedCover,
    required this.selectedPageCount,
    required this.onTitleChanged,
    required this.onCoverSelected,
    required this.onPageCountChanged,
    required this.onNext,
  });

  @override
  State<AlbumCreateStep1> createState() => _AlbumCreateStep1State();
}

class _AlbumCreateStep1State extends State<AlbumCreateStep1> {
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
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 메인 타이틀 (STEP 표시는 플로우 상단에서 공통 표시)
          Text(
            '새로운 추억의 정보를 입력해 주세요',
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 40.h),
          // 앨범 제목
          Text(
            '앨범 제목',
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
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: TextField(
                controller: _titleController,
                onChanged: (value) {
                  widget.onTitleChanged(value);
                },
                decoration: InputDecoration(
                  hintText: '예: 우리 가족의 제주 여행',
                  hintStyle: TextStyle(
                    // 예시 텍스트는 아주 연하게
                    color: SnapFitColors.textMutedOf(context).withOpacity(0.3),
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
                '나중에도 언제든지 수정할 수 있어요.',
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
          SizedBox(height: 40.h),
          // 사이즈 선택
          Text(
            '사이즈 선택',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          SizedBox(height: 16.h),
          _buildSizeSelector(context),
          SizedBox(height: 40.h),
          // 페이지 수 선택
          Text(
            '페이지 수 선택',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          SizedBox(height: 16.h),
          _buildPageCountSelector(context),
          SizedBox(height: 40.h),
          // 다음 버튼 (제목/사이즈 상태에 따라 활성화)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _titleController,
            builder: (context, value, _) {
              final canProceed =
                  value.text.isNotEmpty && widget.selectedCover != null;
              return SnapFitPrimaryActionButton(
                label: '앨범 생성하기',
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
    final horizontal =
        coverSizes.firstWhere((s) => s.name == '가로형', orElse: () => coverSizes[2]);
    final square =
        coverSizes.firstWhere((s) => s.name == '정사각형', orElse: () => coverSizes[1]);
    final vertical =
        coverSizes.firstWhere((s) => s.name == '세로형', orElse: () => coverSizes[0]);

    // 가로형, 정사각형, 세로형 옵션
    final sizeOptions = [
      {
        'name': '가로형',
        'cover': horizontal,
      },
      {
        'name': '정사각형',
        'cover': square,
      },
      {
        'name': '세로형',
        'cover': vertical,
      },
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
              margin: EdgeInsets.only(right: index != sizeOptions.length - 1 ? 12.w : 0),
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? SnapFitColors.accent.withOpacity(0.15)
                    : SnapFitColors.surfaceOf(context),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: isSelected
                      ? SnapFitColors.accent
                      : SnapFitColors.overlayLightOf(context),
                  width: isSelected ? 2 : 1,
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
                      color: SnapFitColors.textPrimaryOf(context)
                          .withOpacity(0.35),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    option['name'] as String,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
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
    return Column(
      children: [
        // 슬라이더
        Slider(
          value: widget.selectedPageCount.toDouble(),
          min: 10,
          max: 21,
          divisions: 11,
          activeColor: SnapFitColors.accent,
          inactiveColor: SnapFitColors.overlayLightOf(context),
          onChanged: (value) {
            widget.onPageCountChanged(value.toInt());
          },
        ),
        SizedBox(height: 8.h),
        // 페이지 수 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '10p',
              style: TextStyle(
                fontSize: 12.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: SnapFitColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: SnapFitColors.accent,
                  width: 1,
                ),
              ),
              child: Text(
                '${widget.selectedPageCount}p',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: SnapFitColors.accent,
                ),
              ),
            ),
            Text(
              '21p',
              style: TextStyle(
                fontSize: 12.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Text(
              '나중에도 언제든지 수정할 수 있어요.',
              style: TextStyle(
                fontSize: 11.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 사이즈 카드 내부에 사용하는 비율 미리보기 프레임
class _SizePreviewFrame extends StatelessWidget {
  final CoverSize cover;
  final Color color;

  const _SizePreviewFrame({
    required this.cover,
    required this.color,
  });

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
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

