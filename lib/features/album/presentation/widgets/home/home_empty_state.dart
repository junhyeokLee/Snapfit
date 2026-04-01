import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';

/// 홈 화면 빈 상태
class HomeEmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const HomeEmptyState({super.key, required this.onCreate});

  static bool _logged = false;

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.widget('HomeEmptyState', '홈 빈 상태 · 프리미엄 디자인');
    }

    final cardColor = SnapFitColors.surfaceOf(context);
    final borderColor = SnapFitColors.overlayLightOf(context);
    final muted = SnapFitColors.textSecondaryOf(context);
    final titleColor = SnapFitColors.textPrimaryOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 520.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(26.r),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 20.h),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.r),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            SnapFitColors.accent.withOpacity(0.22),
                            const Color(0xFFFEE500).withOpacity(0.18),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 6.h,
                              children: const [
                                _MoodChip(text: '감성 템플릿'),
                                _MoodChip(text: '실시간 공동편집'),
                                _MoodChip(text: '인쇄 주문'),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              '첫 앨범을 시작해볼까요?',
                              style: TextStyle(
                                fontSize: 21.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                color: titleColor,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              '사진만 고르면 템플릿이 자동으로 어울리게 정리돼요.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14.r),
                              child: Image.asset(
                                'assets/empty_state.png',
                                width: double.infinity,
                                height: 210.h,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      '지금은 참여 중인 앨범이 없어요.\n새 앨범을 만들거나 친구 초대를 받아 시작할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.sp,
                        height: 1.55,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      height: 54.h,
                      child: ElevatedButton(
                        onPressed: onCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SnapFitColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome_rounded, size: 20.w),
                            SizedBox(width: 8.w),
                            Text(
                              '앨범 시작하기',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: SnapFitColors.textPrimaryOf(context),
        ),
      ),
    );
  }
}
