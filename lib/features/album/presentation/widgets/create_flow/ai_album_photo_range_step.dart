import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../ai_album/domain/ai_album_models.dart';

class AiAlbumPhotoRangeStep extends StatelessWidget {
  const AiAlbumPhotoRangeStep({
    super.key,
    required this.theme,
    required this.onRangeSelected,
    required this.onBack,
    this.usesServerDraftProvider = false,
    this.usesAdvancedServerAnalysis = false,
  });

  final AlbumTheme theme;
  final ValueChanged<AiPhotoRange> onRangeSelected;
  final VoidCallback onBack;
  final bool usesServerDraftProvider;
  final bool usesAdvancedServerAnalysis;

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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackTextButton(onPressed: onBack),
                    SizedBox(height: 14.h),
                    _RangePreview(theme: theme),
                    SizedBox(height: 18.h),
                    Text(
                      'AI 초안',
                      style: TextStyle(
                        color: SnapFitColors.textMutedOf(context),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '사진 범위',
                      style: TextStyle(
                        color: SnapFitColors.textPrimaryOf(context),
                        fontSize: 24.sp,
                        height: 1.16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _RangeCard(
                      title: '최근 30일',
                      subtitle: '휴대폰의 최근 사진만 새 순서로 살펴봐요',
                      icon: Icons.auto_awesome_rounded,
                      emphasized: true,
                      onTap: () => onRangeSelected(AiPhotoRange.recent30Days),
                    ),
                    _RangeCard(
                      title: '허용한 사진 전체',
                      subtitle: '최근 사진이 부족할 때 전체에서 찾아요',
                      icon: Icons.photo_library_rounded,
                      onTap: () => onRangeSelected(AiPhotoRange.limitedLibrary),
                    ),
                    SizedBox(height: 14.h),
                    Text(
                      usesAdvancedServerAnalysis
                          ? '고급 AI를 켜면 선택한 사진의 작은 미리보기 이미지를 서버에서 살펴봐요.'
                          : usesServerDraftProvider
                          ? '선택한 사진의 날짜·크기 같은 정보가 서버로 전송돼요. 초안은 확인 전까지 확정되지 않아요.'
                          : '날짜 선택·앨범 선택·직접 고르기는 실제 선택 화면을 붙인 뒤 열게요. 지금은 최근 30일 또는 허용한 사진 전체만 정확히 살펴봐요.',
                      style: TextStyle(
                        color: SnapFitColors.textSecondaryOf(context),
                        fontSize: 12.5.sp,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
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
}

class _RangePreview extends StatelessWidget {
  const _RangePreview({required this.theme});
  final AlbumTheme theme;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Container(
      width: double.infinity,
      height: 154.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B20) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF5B4A34).withOpacity(0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _TravelFrame(color: _accent(theme), height: 96.h),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _TravelFrame(
                    color: const Color(0xFFECC7A1),
                    height: 78.h,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _TravelFrame(
                    color: const Color(0xFFB9C8A9),
                    height: 88.h,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _TravelFrame(
                    color: const Color(0xFFD8CAE8),
                    height: 70.h,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _TimelineDot(color: _accent(theme)),
              Expanded(
                child: Container(height: 2.h, color: const Color(0xFFE6DED3)),
              ),
              _TimelineDot(color: const Color(0xFFECC7A1)),
              Expanded(
                child: Container(height: 2.h, color: const Color(0xFFE6DED3)),
              ),
              _TimelineDot(color: const Color(0xFFB9C8A9)),
              Expanded(
                child: Container(height: 2.h, color: const Color(0xFFE6DED3)),
              ),
              _TimelineDot(color: const Color(0xFFD8CAE8)),
            ],
          ),
        ],
      ),
    );
  }

  Color _accent(AlbumTheme theme) => switch (theme) {
    AlbumTheme.travel => const Color(0xFF95B8D1),
    AlbumTheme.family => const Color(0xFFCDAF8D),
    AlbumTheme.baby => const Color(0xFFF0B8C9),
    AlbumTheme.couple => const Color(0xFFE8A0A0),
    AlbumTheme.birthday => const Color(0xFFF6C15E),
    AlbumTheme.daily => const Color(0xFFAFC5A5),
    AlbumTheme.friends => const Color(0xFFB7B0E5),
    AlbumTheme.custom => const Color(0xFFC9C1E6),
  };
}

class _TravelFrame extends StatelessWidget {
  const _TravelFrame({required this.color, required this.height});
  final Color color;
  final double height;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 22.w,
            height: 22.w,
            margin: EdgeInsets.all(7.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.34),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10.w,
      height: 10.w,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RangeCard extends StatelessWidget {
  const _RangeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isDark = SnapFitColors.isDark(context);
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: onTap,
          child: Ink(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(14.w, 13.h, 14.w, 13.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1B20)
                  : (emphasized ? const Color(0xFFF7F7FF) : Colors.white),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : (emphasized
                          ? const Color(0xFFBFC7DC)
                          : const Color(0xFFE7E1D8)),
                width: emphasized ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: emphasized
                        ? const Color(0xFF9DB6C8)
                        : const Color(0xFFEDE7DD),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Center(
                    child: Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: emphasized
                              ? Colors.white
                              : const Color(0xFF6E6558),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: SnapFitColors.textPrimaryOf(context),
                          fontSize: 15.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SnapFitColors.textMutedOf(context),
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '›',
                  style: TextStyle(
                    color: SnapFitColors.textMutedOf(context),
                    fontSize: 27.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
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
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: Size(0, 34.h),
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
    );
  }
}
