import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumRecommendationReviewStep extends StatefulWidget {
  const AiAlbumRecommendationReviewStep({
    super.key,
    required this.draft,
    required this.onAcceptDraft,
    required this.onBack,
  });

  final AlbumRecommendationDraft draft;
  final FutureOr<void> Function(AlbumRecommendationDraft) onAcceptDraft;
  final VoidCallback onBack;

  @override
  State<AiAlbumRecommendationReviewStep> createState() =>
      _AiAlbumRecommendationReviewStepState();
}

class _AiAlbumRecommendationReviewStepState
    extends State<AiAlbumRecommendationReviewStep> {
  late AlbumRecommendationDraft _draft;
  bool _isAcceptingDraft = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  @override
  void didUpdateWidget(AiAlbumRecommendationReviewStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _draft = widget.draft;
    }
  }

  void _addExcludedPhoto(ExcludedPhoto photo) {
    if (_isAcceptingDraft) return;

    final promoted = RecommendedPhoto(
      candidate: photo.candidate,
      score: 0.62,
      reasons: photo.reasons,
    );
    setState(() {
      _draft = _draft.copyWith(
        recommendedPhotos: [..._draft.recommendedPhotos, promoted],
        excludedPhotos: _draft.excludedPhotos
            .where((excluded) => excluded.assetId != photo.assetId)
            .toList(growable: false),
      );
    });
  }

  Future<void> _handleAcceptDraft() async {
    if (_isAcceptingDraft) return;

    setState(() => _isAcceptingDraft = true);
    try {
      await widget.onAcceptDraft(_draft);
    } finally {
      if (mounted) {
        setState(() => _isAcceptingDraft = false);
      }
    }
  }

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
                    _BackTextButton(
                      onPressed: _isAcceptingDraft ? null : widget.onBack,
                    ),
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
                    _DraftSummaryCard(draft: _draft),
                    SizedBox(height: 14.h),
                    _StorySectionList(draft: _draft),
                    SizedBox(height: 14.h),
                    _RecommendationDetails(
                      draft: _draft,
                      onAddExcludedPhoto: _addExcludedPhoto,
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ),
            _BottomCta(
              isAcceptingDraft: _isAcceptingDraft,
              onAcceptDraft: _handleAcceptDraft,
            ),
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
  const _RecommendationDetails({
    required this.draft,
    required this.onAddExcludedPhoto,
  });

  final AlbumRecommendationDraft draft;
  final ValueChanged<ExcludedPhoto> onAddExcludedPhoto;

  @override
  Widget build(BuildContext context) {
    final recommendedReasons = _uniqueReasons(
      draft.recommendedPhotos.expand((photo) => photo.reasons),
    ).take(3).toList(growable: false);
    final selected = draft.recommendedPhotos.take(2).toList(growable: false);
    final excluded = draft.excludedPhotos.take(2).toList(growable: false);
    final excludedReasonLabels = _excludedReasonLabels(draft.excludedPhotos);

    return _PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'AI가 이렇게 골랐어요',
            caption: '대표 컷은 먼저 넣고, 비슷한 사진은 잠시 빼뒀어요.',
          ),
          if (recommendedReasons.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Wrap(
              spacing: 7.w,
              runSpacing: 7.h,
              children: recommendedReasons
                  .map(
                    (reason) => _ReasonChip(text: _chipLabelFor(reason.type)),
                  )
                  .toList(growable: false),
            ),
          ],
          if (selected.isNotEmpty) ...[
            SizedBox(height: 13.h),
            _ReasonGroupLabel(text: '추천한 사진'),
            SizedBox(height: 7.h),
            _ReasonBulletList(messages: _selectedReasonMessages(selected)),
          ],
          if (draft.excludedPhotos.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _ReasonGroupLabel(
                    text: '잠시 빼둔 사진 ${draft.excludedPhotos.length}장',
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      onAddExcludedPhoto(draft.excludedPhotos.first),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 5.h,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: SnapFitColors.textPrimaryOf(context),
                  ),
                  child: Text(
                    '초안에 넣기',
                    style: TextStyle(
                      fontSize: 12.2.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              '${excludedReasonLabels.join(', ')} 사진은 잠시 제외했어요. 원하면 다시 넣을 수 있어요.',
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 12.3.sp,
                height: 1.36,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 7.h),
            _ReasonBulletList(messages: _excludedReasonMessages(excluded)),
          ] else ...[
            SizedBox(height: 12.h),
            Text(
              '원하면 잠시 빼둔 사진도 초안에 넣을 수 있어요. 지금은 모두 초안에 들어갔어요.',
              style: TextStyle(
                color: SnapFitColors.textSecondaryOf(context),
                fontSize: 12.3.sp,
                height: 1.36,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<AiCurationReason> _uniqueReasons(Iterable<AiCurationReason> reasons) {
    final seen = <AiCurationReasonType>{};
    final result = <AiCurationReason>[];
    for (final reason in reasons) {
      if (seen.add(reason.type)) result.add(reason);
    }
    return result;
  }

  List<String> _selectedReasonMessages(List<RecommendedPhoto> photos) {
    return _uniqueMessages(
      photos.expand((photo) => photo.reasons).map((reason) => reason.message),
      fallback: '앨범에 먼저 넣기 좋은 대표 장면이에요',
      maxItems: 1,
    );
  }

  List<String> _excludedReasonMessages(List<ExcludedPhoto> photos) {
    return _uniqueMessages(
      photos.expand((photo) => photo.reasons).map((reason) => reason.message),
      fallback: '초안에는 넣지 않았지만 편집 때 다시 추가 가능해요',
      maxItems: 2,
    );
  }

  List<String> _uniqueMessages(
    Iterable<String> messages, {
    required String fallback,
    required int maxItems,
  }) {
    final seen = <String>{};
    final result = <String>[];
    for (final message in messages) {
      if (message.trim().isEmpty) continue;
      if (seen.add(message)) result.add(message);
      if (result.length == maxItems) break;
    }
    return result.isEmpty ? [fallback] : result;
  }

  List<String> _excludedReasonLabels(List<ExcludedPhoto> photos) {
    final labels = <String>[];
    final seen = <AiCurationReasonType>{};
    for (final photo in photos) {
      for (final reason in photo.reasons) {
        if (seen.add(reason.type)) labels.add(_excludedLabelFor(reason.type));
      }
    }
    return labels.isEmpty ? ['비슷한'] : labels.take(3).toList(growable: false);
  }

  String _chipLabelFor(AiCurationReasonType type) {
    return switch (type) {
      AiCurationReasonType.highResolution => '선명한 사진 우선',
      AiCurationReasonType.themeOrientation => '테마에 잘 맞는 컷',
      AiCurationReasonType.dateFlow => '날짜 흐름',
      AiCurationReasonType.timeClusterRepresentative => '대표 컷',
      AiCurationReasonType.coverCandidate => '표지 후보',
      AiCurationReasonType.endingCandidate => '마무리 컷',
      AiCurationReasonType.screenshotExcluded => '스크린샷 제외',
      AiCurationReasonType.lowResolutionExcluded => '해상도 확인',
      AiCurationReasonType.duplicateTimeExcluded => '비슷한 컷 정리',
      AiCurationReasonType.dailyLimitExcluded => '날짜별 균형',
      AiCurationReasonType.totalLimitExcluded => '분량 조정',
      AiCurationReasonType.weakThemeFitExcluded => '주제 확인',
    };
  }

  String _excludedLabelFor(AiCurationReasonType type) {
    return switch (type) {
      AiCurationReasonType.screenshotExcluded => '스크린샷',
      AiCurationReasonType.lowResolutionExcluded => '낮은 해상도',
      AiCurationReasonType.duplicateTimeExcluded => '비슷한 시간대',
      AiCurationReasonType.dailyLimitExcluded => '날짜별 균형',
      AiCurationReasonType.totalLimitExcluded => '전체 분량 조정',
      AiCurationReasonType.weakThemeFitExcluded => '테마와 거리 있는',
      _ => '비슷한',
    };
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: SnapFitColors.isDark(context)
            ? Colors.white.withOpacity(0.08)
            : const Color(0xFFE9F4EC),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: SnapFitColors.isDark(context)
              ? const Color(0xFFE9F4EC)
              : const Color(0xFF4C6A55),
          fontSize: 11.3.sp,
          height: 1.15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReasonGroupLabel extends StatelessWidget {
  const _ReasonGroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: SnapFitColors.textPrimaryOf(context),
        fontSize: 13.sp,
        height: 1.25,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.15,
      ),
    );
  }
}

class _ReasonBulletList extends StatelessWidget {
  const _ReasonBulletList({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messages
          .map(
            (message) => Padding(
              padding: EdgeInsets.only(bottom: 5.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h, right: 7.w),
                    child: Container(
                      width: 4.5.w,
                      height: 4.5.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5B6F58),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 12.2.sp,
                        height: 1.34,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({
    required this.isAcceptingDraft,
    required this.onAcceptDraft,
  });

  final bool isAcceptingDraft;
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
          onPressed: isAcceptingDraft ? null : onAcceptDraft,
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
            isAcceptingDraft ? '편집 준비 중' : '편집 시작',
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

  final VoidCallback? onPressed;

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
