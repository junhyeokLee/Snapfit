import 'package:flutter/foundation.dart';
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
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF12100E), const Color(0xFF1A1713)]
              : [const Color(0xFFFBF7EF), const Color(0xFFFFFCF7)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > constraints.maxHeight;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20.w,
                      10.h,
                      20.w,
                      isWide ? 72.h : 96.h,
                    ),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildPreviewGroup()),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: _buildManualSettingsGroup(context),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPreviewGroup(),
                              SizedBox(height: 16.h),
                              _buildManualSettingsGroup(context),
                            ],
                          ),
                  );
                },
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

  Widget _buildPreviewGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CreateStepHero(
          cover: widget.selectedCover,
          pageCount: widget.selectedPageCount,
          titleListenable: _titleController,
        ),
        if (_hasTemplate) ...[
          SizedBox(height: 12.h),
          _TemplateSummary(
            title: widget.templateTitle!.trim(),
            previewUrl: widget.templatePreviewImageUrl,
          ),
        ],
      ],
    );
  }

  Widget _buildManualSettingsGroup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingCard(child: _buildTitleBlock(context)),
        SizedBox(height: 16.h),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(
                title: '책 비율',
                caption: '사진에 맞는 책의 형태를 고르세요.',
              ),
              SizedBox(height: 12.h),
              _buildSizeSelector(context),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        _SettingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(
                title: '분량',
                caption: '처음 분량만 정해두고, 편집 중 언제든 바꿀 수 있어요.',
              ),
              SizedBox(height: 12.h),
              _buildPageCountSelector(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTitleBlock(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(title: '앨범 제목', caption: '표지와 내지에 함께 쓰일 이름이에요.'),
        SizedBox(height: 6.h),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF24201C) : const Color(0xFFFBF8F2),
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
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
              counterText: '',
              border: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18.r),
                borderSide: const BorderSide(
                  color: Color(0xFFB28A5E),
                  width: 1.4,
                ),
              ),
              enabledBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 15.w,
                vertical: 13.h,
              ),
            ),
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 12.5.sp,
              height: 1.25,
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
            height: 52.h,
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
                    '표지부터 만들기',
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
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
      (pages: minPage, body: '가볍게', recommended: false),
      (pages: mathMax(minPage, 24), body: '알맞게', recommended: false),
      (pages: mathMax(minPage, 36), body: '넉넉하게', recommended: false),
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

class _SettingCard extends StatelessWidget {
  final Widget child;

  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 17.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1815) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE8DED2),
        ),
      ),
      child: child,
    );
  }
}

class _CreateStepHero extends StatelessWidget {
  final CoverSize? cover;
  final int pageCount;
  final ValueListenable<TextEditingValue> titleListenable;

  const _CreateStepHero({
    required this.cover,
    required this.pageCount,
    required this.titleListenable,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final ratio = cover?.ratio ?? 1.0;
    final previewMaxW = 124.w;
    final previewMaxH = 118.h;
    final previewW = ratio >= 1
        ? previewMaxW
        : (previewMaxH * ratio).clamp(86.w, previewMaxW);
    final previewH = ratio >= 1
        ? (previewMaxW / ratio).clamp(96.h, previewMaxH)
        : previewMaxH;
    final summary = '${cover?.name ?? '책 비율 선택'} / ${pageCount}쪽';

    return Container(
      key: const Key('albumCreateStepHero'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1D1A16) : const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE6DCCF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.26 : 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '미리보기',
            style: TextStyle(
              fontSize: 12.sp,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
              color: SnapFitColors.textMutedOf(context),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: titleListenable,
              builder: (context, value, _) {
                final title = value.text.trim().isEmpty
                    ? '제목 미정'
                    : value.text.trim();
                return _PaperBookPreview(
                  width: previewW,
                  height: previewH,
                  title: title,
                );
              },
            ),
          ),
          SizedBox(height: 9.h),
          Center(
            child: Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: SnapFitColors.textSecondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperBookPreview extends StatelessWidget {
  final double width;
  final double height;
  final String title;

  const _PaperBookPreview({
    required this.width,
    required this.height,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    final coverColor = isDark
        ? const Color(0xFF2A241D)
        : const Color(0xFFF3E2C9);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.16)
        : const Color(0xFFD8C3A6);
    final shadowColor = isDark
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFE8D6BE);
    final photoColor = isDark
        ? Colors.white.withOpacity(0.13)
        : const Color(0xFFD8B58E).withOpacity(0.70);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -8.w,
          bottom: -8.h,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: shadowColor,
              borderRadius: BorderRadius.circular(18.r),
            ),
          ),
        ),
        Container(
          key: const Key('albumCreateHeroPreview'),
          width: width,
          height: height,
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 10.h),
          decoration: BoxDecoration(
            color: coverColor,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: photoColor,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Container(
                      margin: EdgeInsets.all(9.w),
                      width: 42.w,
                      height: 2.h,
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  height: 1.18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: isDark
                      ? Colors.white.withOpacity(0.86)
                      : const Color(0xFF2A2520),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String caption;

  const _SectionLabel({required this.title, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12.sp,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
            color: SnapFitColors.textPrimaryOf(context),
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          caption,
          style: TextStyle(
            fontSize: 10.5.sp,
            height: 1.34,
            fontWeight: FontWeight.w600,
            color: SnapFitColors.textSecondaryOf(context),
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
                  '선택한 표지',
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
