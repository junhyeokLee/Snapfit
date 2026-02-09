import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import 'dart:ui' as ui;

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
          // STEP 표시
          Text(
            'STEP 01/04',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.accent,
            ),
          ),
          SizedBox(height: 16.h),
          // 메인 타이틀
          Text(
            '새로운 추억의 정보를 입력해 주세요',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 40.h),
          // 앨범 제목
          Text(
            '앨범제목',
            style: TextStyle(
              fontSize: 14.sp,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _titleController,
            onChanged: widget.onTitleChanged,
            decoration: InputDecoration(
              hintText: '우리 가족의 제주 여행',
              hintStyle: TextStyle(
                color: SnapFitColors.textMutedOf(context),
              ),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: SnapFitColors.overlayLightOf(context),
                  width: 1,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: SnapFitColors.overlayLightOf(context),
                  width: 1,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: SnapFitColors.accent,
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 12.h,
              ),
              suffixIcon: Icon(
                Icons.edit_outlined,
                color: SnapFitColors.accent,
                size: 20.sp,
              ),
            ),
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 16.sp,
            ),
            maxLength: 50,
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
          // 다음 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.albumTitle.isNotEmpty && widget.selectedCover != null ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: SnapFitColors.accent,
                foregroundColor: SnapFitColors.pureWhite,
                padding: EdgeInsets.symmetric(vertical: 18.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '앨범 생성하기',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_forward, size: 20.sp),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector(BuildContext context) {
    // 세로 정사각형과 가로 정사각형 옵션
    final sizeOptions = [
      {
        'name': '세로 정사각형',
        'cover': CoverSize(name: '세로형', ratio: 6 / 8, realSize: Size(14.5, 19.4)),
        'iconRotation': 0.0, // 세로형
      },
      {
        'name': '가로 정사각형',
        'cover': CoverSize(name: '가로형', ratio: 8 / 6, realSize: Size(19.4, 14.5)),
        'iconRotation': 1.5708, // 90도 회전 (가로형)
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
              margin: EdgeInsets.only(right: index == 0 ? 12.w : 0),
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
                  // 겹쳐진 사각형 아이콘 (이미지와 동일하게)
                  SizedBox(
                    width: 80.w,
                    height: 80.w,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 뒷면 사각형
                        Transform.rotate(
                          angle: (option['iconRotation'] as double) + 0.1,
                          child: Container(
                            width: 60.w,
                            height: 60.w,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SnapFitColors.textPrimaryOf(context).withOpacity(0.3),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                        // 앞면 사각형
                        Transform.rotate(
                          angle: (option['iconRotation'] as double) - 0.1,
                          child: Container(
                            width: 60.w,
                            height: 60.w,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: SnapFitColors.textPrimaryOf(context).withOpacity(0.3),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                        ),
                      ],
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
      ],
    );
  }
}
