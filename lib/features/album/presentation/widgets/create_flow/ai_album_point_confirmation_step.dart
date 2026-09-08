import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumPointConfirmationStep extends StatelessWidget {
  const AiAlbumPointConfirmationStep({
    super.key,
    this.designBrief,
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
  final AiTemplateBrief? designBrief;
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
    if (designBrief != null) return _buildTemplateConfirmation(context);
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
                      'AI 템플릿 생성',
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
                        if (designBrief != null) ...[
                          _InfoRow(label: '디자인 요청', value: designBrief!.prompt),
                          _InfoRow(
                            label: '구성',
                            value: '표지 + 내지 ${designBrief!.pageCount}쪽',
                          ),
                          const _InfoRow(label: '사진', value: '디자인 완성 후 직접 추가'),
                        ] else ...[
                          _InfoRow(label: '템플릿 무드', value: _themeLabel(theme)),
                          _InfoRow(label: '사진 범위', value: _rangeLabel(range)),
                        ],
                        _InfoRow(
                          label: '사용 포인트',
                          value: isFirstAiDraftFree
                              ? '무료'
                              : '${_format(pointCost)}P',
                        ),
                        if (isFirstAiDraftFree)
                          const _InfoRow(label: '무료 혜택', value: '첫 AI 템플릿 1회'),
                        _InfoRow(
                          label: '보유 포인트',
                          value: '${_format(balance)}P',
                        ),
                        const _InfoRow(label: '사용 기준', value: '성공 시만 처리'),
                        const _InfoRow(label: '실패 시', value: '실패 시 차감 없음'),
                      ],
                    ),
                    if (designBrief != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '입력한 디자인 요청을 AI에 전달해요. 사진첩에 접근하거나 사진을 전송하지 않아요.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: SnapFitColors.textSecondaryOf(context),
                        ),
                      ),
                    ] else if (usesServerDraftProvider) ...[
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
                          isFirstAiDraftFree ? '무료로 템플릿 만들기' : '템플릿 만들기',
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

  Widget _buildTemplateConfirmation(BuildContext context) {
    final brief = designBrief!;
    final foreground = SnapFitColors.textPrimaryOf(context);
    return ColoredBox(
      color: SnapFitColors.isDark(context)
          ? const Color(0xFF111111)
          : const Color(0xFFF5F6F4),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: onBack,
                    tooltip: '요청 수정',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '이런 앨범을 만들어요',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    brief.prompt,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    '${brief.coverSize.displayName} · ${brief.coverSize.coverType.label} · 표지 + 내지 ${brief.pageCount}쪽',
                    style: TextStyle(fontSize: 14, color: foreground),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '디자인 적용 시 최대 ${_format(pointCost)}P · 보유 ${_format(balance)}P',
                    style: TextStyle(fontSize: 14, color: foreground),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '사용 가능한 무료 혜택은 적용할 때 반영돼요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '입력한 디자인 요청을 AI에 전달해요. 사진첩에 접근하거나 사진을 전송하지 않아요.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: SnapFitColors.textSecondaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF203D35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '템플릿 만들기',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
    );
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
            usesAdvancedServerAnalysis ? '고급 AI 템플릿 확인' : 'AI 템플릿 확인',
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
                ? '선택한 사진의 작은 미리보기 이미지를 서버에서 참고해 앨범 흐름과 슬롯 구조를 잡아요.'
                : '선택한 사진의 날짜·크기 같은 정보로 서버에서 템플릿 슬롯과 흐름을 잡아요.',
            style: TextStyle(
              color: SnapFitColors.textSecondaryOf(context),
              fontSize: 12.5.sp,
              height: 1.38,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            '사진은 자동으로 확정되지 않아요. 템플릿을 만든 뒤 편집 화면에서 직접 넣고 바꿔요.',
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
