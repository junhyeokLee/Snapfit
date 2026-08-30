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
    required this.onBack,
  });

  final AlbumTheme theme;
  final AiPhotoRange range;
  final int pointCost;
  final int balance;
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
                    _DraftTicket(pointCost: pointCost),
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
                          value: '${_format(pointCost)}P',
                        ),
                        _InfoRow(
                          label: '보유 포인트',
                          value: '${_format(balance)}P',
                        ),
                      ],
                    ),
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
                          '초안 만들기',
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

class _DraftTicket extends StatelessWidget {
  const _DraftTicket({required this.pointCost});
  final int pointCost;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 150.h,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.10)
              : const Color(0xFFE6DED3),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 12.h,
            child: _TicketPage(color: const Color(0xFFEFE1CD)),
          ),
          Positioned(
            left: 58.w,
            top: 0,
            child: _TicketPage(color: const Color(0xFFE4F3F5), tall: true),
          ),
          Positioned(
            left: 114.w,
            top: 18.h,
            child: _TicketPage(color: const Color(0xFFE7DDF3)),
          ),
          Positioned(
            right: 0,
            bottom: 4.h,
            child: Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF24252B)
                    : const Color(0xFFF7F1E7),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 22.sp,
                color: isDark
                    ? const Color(0xFFEFE1CD)
                    : const Color(0xFF6E6558),
              ),
            ),
          ),
        ],
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
          Text(
            value,
            style: TextStyle(
              color: SnapFitColors.textPrimaryOf(context),
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
