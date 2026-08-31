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
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 96.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CreationCoverBrief(
                      templateTitle: _hasTemplate
                          ? widget.templateTitle!.trim()
                          : null,
                      previewUrl: widget.templatePreviewImageUrl,
                    ),
                    SizedBox(height: 18.h),
                    _buildTitleBlock(context),
                    SizedBox(height: 22.h),
                    const _SectionLabel(title: '책 비율', note: '표지에서 보일 책의 첫인상'),
                    SizedBox(height: 10.h),
                    _buildSizeSelector(context),
                    SizedBox(height: 20.h),
                    const _SectionLabel(
                      title: '분량',
                      note: '사진 수와 이야기 밀도에 맞춰 선택',
                    ),
                    SizedBox(height: 10.h),
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
        const _SectionLabel(title: '앨범 제목', note: '책등에 남을 이름처럼 짧게'),
        SizedBox(height: 10.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.10)
                  : const Color(0xFFE1D4C4),
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF6C5740).withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
          ),
          child: TextField(
            controller: _titleController,
            onChanged: widget.onTitleChanged,
            maxLength: 50,
            decoration: InputDecoration(
              hintText: '',
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
              contentPadding: EdgeInsets.fromLTRB(16.w, 13.h, 16.w, 13.h),
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

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? note;
  const _SectionLabel({required this.title, this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.35,
                  color: SnapFitColors.textPrimaryOf(context),
                ),
              ),
              if (note != null) ...[
                SizedBox(height: 4.h),
                Text(
                  note!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textMutedOf(context),
                    letterSpacing: -0.15,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CreationCoverBrief extends StatelessWidget {
  const _CreationCoverBrief({this.templateTitle, this.previewUrl});

  final String? templateTitle;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final hasTemplate = templateTitle != null && templateTitle!.isNotEmpty;
    final hasPreview = previewUrl != null && previewUrl!.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1A17) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE4D7C7),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF6C5740).withOpacity(0.10),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Row(
        children: [
          _BriefBookStack(hasPreview: hasPreview, previewUrl: previewUrl),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : const Color(0xFFF4E9DC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    hasTemplate ? '표지' : '새 포토북',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? const Color(0xFFEDE7DD)
                          : const Color(0xFF6E5942),
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                SizedBox(height: 9.h),
                Text(
                  hasTemplate ? templateTitle! : '책 비율과 분량만 정하면 바로 편집해요',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18.sp,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    color: SnapFitColors.textPrimaryOf(context),
                    letterSpacing: -0.45,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '커버 · 내지 · 사진 흐름을 유지한 채 시작',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textMutedOf(context),
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

class _BriefBookStack extends StatelessWidget {
  const _BriefBookStack({required this.hasPreview, this.previewUrl});
  final bool hasPreview;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return SizedBox(
      width: 82.w,
      height: 102.h,
      child: Stack(
        children: [
          Positioned(
            left: 16.w,
            top: 8.h,
            child: Transform.rotate(
              angle: 0.08,
              child: _MiniBookPage(
                width: 52.w,
                height: 78.h,
                color: isDark
                    ? const Color(0xFF2B2924)
                    : const Color(0xFFE9D8C4),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _MiniBookPage(
              width: 62.w,
              height: 92.h,
              color: isDark ? const Color(0xFF24221F) : const Color(0xFFF8EFE2),
              previewUrl: hasPreview ? previewUrl : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBookPage extends StatelessWidget {
  const _MiniBookPage({
    required this.width,
    required this.height,
    required this.color,
    this.previewUrl,
  });

  final double width;
  final double height;
  final Color color;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final hasPreview = previewUrl != null && previewUrl!.trim().isNotEmpty;
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.62), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: hasPreview
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11.r),
              child: SnapfitImage(urlOrGs: previewUrl!, fit: BoxFit.cover),
            )
          : Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFCFE3DF),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 28.w,
                    height: 5.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB98B62),
                      borderRadius: BorderRadius.circular(999),
                    ),
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
    final tone = switch (cover.name) {
      '가로형' => const Color(0xFFD9E8E1),
      '정사각형' => const Color(0xFFF1DEC7),
      _ => const Color(0xFFE6DDEE),
    };
    final caption = switch (cover.name) {
      '가로형' => '풍경/여행',
      '정사각형' => '일상/가족',
      _ => '인물/성장',
    };
    return _SelectableInk(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _CheckDot(selected: selected, alignLeft: true)),
              if (selected)
                Text(
                  '선택',
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w900,
                    color: SnapFitColors.isDark(context)
                        ? const Color(0xFFF4F1EA)
                        : const Color(0xFF6E5942),
                  ),
                ),
            ],
          ),
          SizedBox(height: 7.h),
          Center(
            child: _SizePreviewFrame(cover: cover, color: tone),
          ),
          SizedBox(height: 9.h),
          Text(
            cover.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5.sp,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: SnapFitColors.textMutedOf(context),
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
          Row(
            children: [
              Expanded(child: _CheckDot(selected: selected, alignLeft: true)),
              _PageStackMark(pages: pages, selected: selected),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            '${pages}쪽',
            style: TextStyle(
              fontSize: 17.sp,
              height: 1.0,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: SnapFitColors.textPrimaryOf(context),
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            body,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageStackMark extends StatelessWidget {
  const _PageStackMark({required this.pages, required this.selected});
  final int pages;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bars = pages >= 36
        ? 4
        : pages >= 24
        ? 3
        : 2;
    final color = selected
        ? (SnapFitColors.isDark(context)
              ? const Color(0xFFF4F1EA)
              : const Color(0xFF1F1F1D))
        : const Color(0xFFCDBCA7);
    return SizedBox(
      width: 30.w,
      height: 22.h,
      child: Stack(
        children: List.generate(bars, (index) {
          return Positioned(
            left: (index * 5).w,
            top: (index * 2).h,
            child: Container(
              width: 17.w,
              height: 18.h,
              decoration: BoxDecoration(
                color: color.withOpacity(0.16 + index * 0.12),
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(color: color.withOpacity(0.55), width: 1),
              ),
            ),
          );
        }),
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
          padding: EdgeInsets.fromLTRB(11.w, 10.h, 11.w, 11.h),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1D1C1A) : Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(
              color: selected
                  ? activeLine
                  : (isDark
                        ? Colors.white.withOpacity(0.10)
                        : const Color(0xFFE7E1D8)),
              width: selected ? 1.8 : 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: const Color(
                        0xFF6C5740,
                      ).withOpacity(selected ? 0.14 : 0.07),
                      blurRadius: selected ? 22 : 14,
                      offset: const Offset(0, 9),
                    ),
                  ],
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
    const double maxW = 58;
    const double maxH = 48;
    double width;
    double height;
    if (ratio >= 1) {
      width = maxW;
      height = maxW / ratio;
      if (height > maxH) {
        height = maxH;
        width = maxH * ratio;
      }
    } else {
      height = maxH;
      width = maxH * ratio;
    }

    return SizedBox(
      width: maxW.w,
      height: maxH.h,
      child: Center(
        child: Container(
          width: width.w,
          height: height.h,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(9.r),
            border: Border.all(
              color: Colors.white.withOpacity(0.68),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.56),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
              SizedBox(height: 3.h),
              Container(
                width: (width * 0.42).w,
                height: 3.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF6E5942).withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
