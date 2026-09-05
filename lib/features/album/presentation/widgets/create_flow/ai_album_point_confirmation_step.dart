import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumPointConfirmationStep extends StatelessWidget {
  const AiAlbumPointConfirmationStep({
    super.key,
    required this.theme,
    required this.range,
    required this.pointCost,
    required this.balance,
    required this.onConfirm,
    this.isFirstAiDraftFree = true,
    this.usesServerDraftProvider = false,
    this.usesAdvancedServerAnalysis = false,
    required this.onBack,
  });

  final AlbumTheme theme;
  final AiPhotoRange range;
  final int pointCost;
  final int balance;
  final bool isFirstAiDraftFree;
  final bool usesServerDraftProvider;
  final bool usesAdvancedServerAnalysis;
  final VoidCallback onConfirm;
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: onBack,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        '이전',
                        style: TextStyle(
                          color: SnapFitColors.textSecondaryOf(context),
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    _DraftTicket(
                      pointCost: pointCost,
                      isFirstAiDraftFree: isFirstAiDraftFree,
                    ),
                    SizedBox(height: 18.h),
                    Text(
                      '초안 생성',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 23.sp,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _PaperCard(
                      children: [
                        _InfoRow(label: '주제', value: _themeLabel(theme)),
                        _InfoRow(label: '사진 범위', value: _rangeLabel(range)),
                        _InfoRow(
                          label: '사용 포인트',
                          value: isFirstAiDraftFree
                              ? '무료'
                              : '${_format(pointCost)}P',
                        ),
                        if (isFirstAiDraftFree)
                          const _InfoRow(label: '무료 혜택', value: '첫 AI 생성 1회'),
                        _InfoRow(
                          label: '보유 포인트',
                          value: '${_format(balance)}P',
                        ),
                        const _InfoRow(label: '사용 기준', value: '성공 시만 처리'),
                        const _InfoRow(label: '실패 시', value: '실패 시 차감 없음'),
                      ],
                    ),
                    if (usesServerDraftProvider) ...[
                      SizedBox(height: 12.h),
                      _ServerAnalysisConsentCard(
                        usesAdvancedServerAnalysis: usesAdvancedServerAnalysis,
                      ),
                    ],
                    SizedBox(height: 22.h),
                    SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: onConfirm,
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
                          isFirstAiDraftFree ? '무료로 초안 만들기' : '초안 만들기',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _format(int value) {
    final text = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final left = text.length - i;
      out.write(text[i]);
      if (left > 1 && left % 3 == 1) out.write(',');
    }
    return out.toString();
  }

  String _themeLabel(AlbumTheme theme) => switch (theme) {
    AlbumTheme.couple => '커플',
    AlbumTheme.travel => '여행',
    AlbumTheme.family => '가족',
    AlbumTheme.friends => '친구',
    AlbumTheme.baby => '아기·성장',
    AlbumTheme.birthday => '생일·기념일',
    AlbumTheme.daily => '일상',
    AlbumTheme.custom => '직접 입력',
  };

  String _rangeLabel(AiPhotoRange range) => switch (range) {
    AiPhotoRange.recent30Days => '최근 30일',
    AiPhotoRange.dateRange => '날짜 선택',
    AiPhotoRange.album => '앨범 선택',
    AiPhotoRange.manualSelection => '직접 고르기',
    AiPhotoRange.limitedLibrary => '선택한 사진',
  };
}

class _ServerAnalysisConsentCard extends StatelessWidget {
  const _ServerAnalysisConsentCard({required this.usesAdvancedServerAnalysis});

  final bool usesAdvancedServerAnalysis;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(15.w, 14.h, 15.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE7E1D8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usesAdvancedServerAnalysis ? '고급 AI 확인' : '서버 초안 확인',
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 14.sp,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            usesAdvancedServerAnalysis
                ? '선택한 사진의 작은 미리보기 이미지를 서버에서 살펴보고 앨범 흐름에 맞는 초안을 만들어요.'
                : '선택한 사진의 날짜·크기 같은 정보로 서버에서 초안을 만들어요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 12.5.sp,
              height: 1.38,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '초안은 바로 확정되지 않아요. 편집 전에 직접 확인해요.',
            style: TextStyle(
              color: const Color(0xFF4C6A55),
              fontSize: 12.5.sp,
              height: 1.34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftTicket extends StatelessWidget {
  const _DraftTicket({
    required this.pointCost,
    required this.isFirstAiDraftFree,
  });
  final int pointCost;
  final bool isFirstAiDraftFree;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 178.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(30.r),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF5B4A34).withOpacity(0.09),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _TicketPage(color: const Color(0xFFEFE1CD), tall: true),
          ),
          Positioned(
            left: 70.w,
            top: 18.h,
            child: _TicketPage(color: const Color(0xFFE4F3F5)),
          ),
          Positioned(
            right: 0,
            top: 6.h,
            child: Container(
              width: 108.w,
              padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF24252B)
                    : const Color(0xFFF7F1E7),
                borderRadius: BorderRadius.circular(22.r),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReceiptLine(width: 48.w, color: const Color(0xFF8FAF9A)),
                  SizedBox(height: 10.h),
                  _ReceiptLine(width: 74.w, color: const Color(0xFFCDAA82)),
                  SizedBox(height: 10.h),
                  _ReceiptLine(width: 54.w, color: const Color(0xFFD7C5EF)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 6.w,
            bottom: 0,
            child: Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFF4F1EA)
                    : const Color(0xFF222222),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isFirstAiDraftFree ? 'FREE' : '✓',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF111111) : Colors.white,
                    fontSize: isFirstAiDraftFree ? 13.sp : 24.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.width, required this.color});
  final double width;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 7.h,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _TicketPage extends StatelessWidget {
  const _TicketPage({required this.color, this.tall = false});
  final Color color;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72.w,
      height: tall ? 104.h : 90.h,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.white.withOpacity(0.75), width: 2),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 20.h,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 8.h,
            child: Container(
              width: 34.w,
              height: 6.h,
              color: Colors.black.withOpacity(0.12),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 0,
            child: Container(
              width: 24.w,
              height: 6.h,
              color: Colors.black.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperCard extends StatelessWidget {
  const _PaperCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
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
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: SnapFitColors.textMutedOf(context),
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: SnapFitColors.textPrimaryOf(context),
                fontSize: 14.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
