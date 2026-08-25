import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/cover_size.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/snapfit_image.dart';

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
    if (oldWidget.albumTitle != widget.albumTitle &&
        _titleController.text != widget.albumTitle) {
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
    final isDark = SnapFitColors.isDark(context);
    final background = isDark
        ? const Color(0xFF111111)
        : const Color(0xFFFAF8F3);

    return ColoredBox(
      color: background,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 96.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _CreateStepTitle(),
                    if (_hasTemplate) ...[
                      SizedBox(height: 10.h),
                      _TemplateSummary(
                        title: widget.templateTitle!.trim(),
                        previewUrl: widget.templatePreviewImageUrl,
                      ),
                    ],
                    SizedBox(height: 14.h),
                    _buildTitleBlock(context),
                    SizedBox(height: 26.h),
                    const _SectionLabel(title: '책 비율'),
                    SizedBox(height: 7.h),
                    _buildSizeSelector(context),
                    SizedBox(height: 18.h),
                    const _SectionLabel(title: '분량'),
                    SizedBox(height: 9.h),
                    _buildPageCountSelector(context),
                  ],
                ),
              ),
            ),
            _buildBottomCta(context),
          ],
        ),
      ),
    );
  }

  bool get _hasTemplate =>
      widget.templateTitle != null && widget.templateTitle!.trim().isNotEmpty;

  Widget _buildTitleBlock(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: '앨범 제목'),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE7E1D8),
            ),
          ),
          child: TextField(
            controller: _titleController,
            onChanged: widget.onTitleChanged,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: '예: 제주 여름 기록',
              hintStyle: TextStyle(
                color: SnapFitColors.textMutedOf(context).withOpacity(0.58),
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              counterText: '',
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.r),
                borderSide: const BorderSide(
                  color: SnapFitColors.accent,
                  width: 1.5,
                ),
              ),
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(13.w, 8.h, 13.w, 8.h),
            ),
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 15.sp,
              height: 1.18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        SizedBox(height: 3.h),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _titleController,
            builder: (context, value, _) => Text(
              '${value.text.length}/50',
              style: TextStyle(
                fontSize: 12.sp,
                height: 1.35,
                color: SnapFitColors.textMutedOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCta(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 9.h, 20.w, 11.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFFAF8F3),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE7E1D8),
          ),
        ),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _titleController,
        builder: (context, value, _) {
          final canProceed =
              value.text.trim().isNotEmpty && widget.selectedCover != null;
          return SizedBox(
            width: double.infinity,
            height: 48.h,
            child: ElevatedButton(
              onPressed: canProceed ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: isDark
                    ? const Color(0xFFF4F1EA)
                    : const Color(0xFF1F1F1D),
                disabledBackgroundColor: isDark
                    ? Colors.white.withOpacity(0.12)
                    : const Color(0xFFE7E1D8),
                foregroundColor: isDark
                    ? const Color(0xFF111111)
                    : Colors.white,
                disabledForegroundColor: SnapFitColors.textMutedOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '다음',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSizeSelector(BuildContext context) {
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
    final sizeOptions = [horizontal, square, vertical];

    return Row(
      children: sizeOptions.asMap().entries.map((entry) {
        final index = entry.key;
        final cover = entry.value;
        final isSelected = widget.selectedCover?.name == cover.name;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == sizeOptions.length - 1 ? 0 : 9.w,
            ),
            child: _RatioCard(
              cover: cover,
              selected: isSelected,
              onTap: () => widget.onCoverSelected(cover),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPageCountSelector(BuildContext context) {
    final minPage = widget.minPageCount.clamp(1, _maxPageCount);
    final suggested = <({int pages, String body, bool recommended})>[
      (pages: minPage, body: '기본', recommended: false),
      (pages: mathMax(minPage, 24), body: '중간', recommended: false),
      (pages: mathMax(minPage, 36), body: '여유', recommended: false),
    ];
    final options = <({int pages, String body, bool recommended})>[];
    final seen = <int>{};
    for (final option in suggested) {
      final pages = option.pages.clamp(minPage, _maxPageCount);
      if (seen.add(pages)) {
        options.add((
          pages: pages,
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

    return Row(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final isSelected = safePageCount == option.pages;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == options.length - 1 ? 0 : 9.w,
            ),
            child: _PageCountCard(
              pages: option.pages,
              body: option.body,
              recommended: option.recommended,
              selected: isSelected,
              onTap: () => widget.onPageCountChanged(option.pages),
            ),
          ),
        );
      }).toList(),
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;
}

class _CreateStepTitle extends StatelessWidget {
  const _CreateStepTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      '새 앨범',
      style: TextStyle(
        fontSize: 24.sp,
        height: 1.12,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.65,
        color: SnapFitColors.textPrimaryOf(context),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;

  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14.sp,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
      ],
    );
  }
}

class _TemplateSummary extends StatelessWidget {
  final String title;
  final String? previewUrl;

  const _TemplateSummary({required this.title, this.previewUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final hasPreview = previewUrl != null && previewUrl!.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(9.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE7E1D8),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF151412)
                    : const Color(0xFFFAF8F3),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE7E1D8),
                ),
              ),
              child: hasPreview
                  ? SnapfitImage(urlOrGs: previewUrl!, fit: BoxFit.cover)
                  : Center(
                      child: Container(
                        width: 18.w,
                        height: 24.h,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: SnapFitColors.textMutedOf(context),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(width: 13.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '표지',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    height: 1.28,
                    fontWeight: FontWeight.w800,
                    color: SnapFitColors.textMutedOf(context),
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RatioCard extends StatelessWidget {
  final CoverSize cover;
  final bool selected;
  final VoidCallback onTap;

  const _RatioCard({
    required this.cover,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectableInk(
      selected: selected,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: _CheckDot(selected: selected),
          ),
          SizedBox(height: 2.h),
          _SizePreviewFrame(
            cover: cover,
            color: selected
                ? (SnapFitColors.isDark(context)
                      ? const Color(0xFFF4F1EA)
                      : const Color(0xFF1F1F1D))
                : SnapFitColors.textMutedOf(context),
          ),
          SizedBox(height: 4.h),
          SizedBox(
            height: 18.h,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                cover.name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.0,
                  fontWeight: FontWeight.w900,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageCountCard extends StatelessWidget {
  final int pages;
  final String body;
  final bool recommended;
  final bool selected;
  final VoidCallback onTap;

  const _PageCountCard({
    required this.pages,
    required this.body,
    required this.recommended,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectableInk(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _CheckDot(selected: selected, alignLeft: true),
          ),
          SizedBox(height: 6.h),
          Text(
            '${pages}쪽',
            style: TextStyle(
              fontSize: 15.5.sp,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.8.sp,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableInk extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectableInk({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final activeLine = isDark
        ? const Color(0xFFF4F1EA)
        : const Color(0xFF1F1F1D);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.fromLTRB(8.w, 7.h, 8.w, 8.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: selected
                  ? activeLine
                  : (isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFFE7E1D8)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CheckDot extends StatelessWidget {
  final bool selected;
  final bool alignLeft;

  const _CheckDot({required this.selected, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? (SnapFitColors.isDark(context)
              ? const Color(0xFFF4F1EA)
              : const Color(0xFF1F1F1D))
        : SnapFitColors.textMutedOf(context).withOpacity(0.45);
    return Align(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 13.w,
        height: 13.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: selected
            ? Center(
                child: Container(
                  width: 5.w,
                  height: 5.w,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 사이즈 카드 내부에 사용하는 비율 미리보기 프레임
class _SizePreviewFrame extends StatelessWidget {
  final CoverSize cover;
  final Color color;

  const _SizePreviewFrame({required this.cover, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = cover.realSize.width / cover.realSize.height;
    const double maxSide = 30;
    double width;
    double height;
    if (ratio >= 1) {
      width = maxSide;
      height = maxSide / ratio;
    } else {
      height = maxSide;
      width = maxSide * ratio;
    }

    return SizedBox(
      width: maxSide.w,
      height: maxSide.w,
      child: Center(
        child: Container(
          width: width.w,
          height: height.w,
          decoration: BoxDecoration(
            color: color.withOpacity(0.04),
            borderRadius: BorderRadius.circular(5.r),
            border: Border.all(color: color, width: 1.8),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 5.w,
              margin: EdgeInsets.symmetric(vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.20),
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(4.r),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
