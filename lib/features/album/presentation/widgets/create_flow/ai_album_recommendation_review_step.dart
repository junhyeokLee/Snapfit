import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumRecommendationReviewStep extends StatelessWidget {
  const AiAlbumRecommendationReviewStep({
    super.key,
    required this.draft,
    required this.onAcceptDraft,
    required this.onBack,
  });

  final AlbumRecommendationDraft draft;
  final VoidCallback onAcceptDraft;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final background = SnapFitColors.isDark(context)
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
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 26.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackTextButton(onPressed: onBack),
                    SizedBox(height: 14.h),
                    Text(
                      'AI 초안',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 23.sp,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '사진 · 흐름 · 제외',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 14.sp,
                        height: 1.42,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _DraftSummaryCard(draft: draft),
                    SizedBox(height: 14.h),
                    _StorySectionList(draft: draft),
                    SizedBox(height: 14.h),
                    _RecommendationDetails(draft: draft),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
            _BottomCta(onAcceptDraft: onAcceptDraft),
          ],
        ),
      ),
    );
  }
}

class _DraftSummaryCard extends StatelessWidget {
  const _DraftSummaryCard({required this.draft});

  final AlbumRecommendationDraft draft;

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MemoLabel(text: '추천 구성'),
          SizedBox(height: 10.h),
          Text(
            draft.title,
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 20.sp,
              height: 1.22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            draft.summary,
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 13.sp,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _InfoChip(text: '추천 사진 ${draft.recommendedPhotos.length}장'),
              _InfoChip(text: '${draft.pageCount}쪽'),
              _InfoChip(text: '잠시 빼둔 사진 ${draft.excludedPhotos.length}장'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorySectionList extends StatelessWidget {
  const _StorySectionList({required this.draft});

  final AlbumRecommendationDraft draft;

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '앨범 흐름', caption: '날짜별 흐름이 자연스럽도록 먼저 나눴어요.'),
          SizedBox(height: 12.h),
          ...draft.storySections.map((section) {
            return Padding(
              padding: EdgeInsets.only(bottom: 11.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    margin: EdgeInsets.only(top: 7.h, right: 10.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5B6F58),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          style: TextStyle(
                            color: SnapFitColors.textPrimaryOf(context),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          section.description,
                          style: TextStyle(
                            color: SnapFitColors.textSecondaryOf(context),
                            fontSize: 12.5.sp,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecommendationDetails extends StatelessWidget {
  const _RecommendationDetails({required this.draft});

  final AlbumRecommendationDraft draft;

  @override
  Widget build(BuildContext context) {
    return _PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: '추천 구성', caption: draft.templateTone),
          SizedBox(height: 12.h),
          if (draft.curationNotes.isEmpty) ...[
            _ReasonRow(label: '대표 장면', value: '앨범에 들어가요'),
            _ReasonRow(label: '표지 후보', value: '첫 인상이 좋은 사진을 우선했어요'),
            _ReasonRow(label: '잠시 빼둔 사진', value: '흐리거나 비슷한 사진은 초안에서 잠시 제외했어요.'),
          ] else
            ...draft.curationNotes.asMap().entries.map(
              (entry) => _ReasonRow(
                label: entry.key == 0 ? 'AI 기준' : '확인 기준',
                value: entry.value,
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onAcceptDraft});

  final VoidCallback onAcceptDraft;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? const Color(0xFF111111)
            : const Color(0xFFFAF8F3),
        border: Border(
          top: BorderSide(
            color: SnapFitColors.isDark(context)
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFE7E1D8),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52.h,
        child: ElevatedButton(
          onPressed: onAcceptDraft,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: SnapFitColors.isDark(context)
                ? const Color(0xFFF4F1EA)
                : const Color(0xFF1F1F1D),
            foregroundColor: SnapFitColors.isDark(context)
                ? const Color(0xFF111111)
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            '편집 시작',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82.w,
            child: Text(
              label,
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 12.5.sp,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: SnapFitColors.textPrimaryOf(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 5.h),
        Text(
          caption,
          style: TextStyle(
            color: SnapFitColors.textSecondaryOf(context),
            fontSize: 12.5.sp,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(17.w),
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? const Color(0xFF1D1C1A)
            : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: SnapFitColors.isDark(context)
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE7E1D8),
        ),
      ),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEE5),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF6C5E4B),
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MemoLabel extends StatelessWidget {
  const _MemoLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F4EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF4C6A55),
          fontSize: 11.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _BackTextButton extends StatelessWidget {
  const _BackTextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(0, 34.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 14.sp,
        color: SnapFitColors.textSecondaryOf(context),
      ),
      label: Text(
        '이전',
        style: TextStyle(
          color: SnapFitColors.textSecondaryOf(context),
          fontSize: 12.5.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
