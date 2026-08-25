import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../core/utils/screen_logger.dart';
import '../../../../../shared/widgets/snapfit_motion.dart';

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

    final isDark = SnapFitColors.isDark(context);
    final titleColor = SnapFitColors.textPrimaryOf(context);
    final muted = SnapFitColors.textSecondaryOf(context);
    final cardColor = isDark
        ? const Color(0xFF171A22)
        : const Color(0xFFFFFBF6);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SnapFitFadeIn(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(32.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFEFE4D7),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.28 : 0.08),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32.r),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -34.w,
                          top: -30.h,
                          child: _GlowOrb(
                            size: 130.w,
                            color: SnapFitColors.accent.withOpacity(0.24),
                          ),
                        ),
                        Positioned(
                          left: -24.w,
                          bottom: 68.h,
                          child: _GlowOrb(
                            size: 96.w,
                            color: const Color(0xFFFFC37A).withOpacity(0.22),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 24.h),
                          child: Column(
                            children: [
                              const _MiniAlbumStack(),
                              SizedBox(height: 28.h),
                              Text(
                                '아직 비어있는\n앨범 서재',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 25.sp,
                                  fontWeight: FontWeight.w900,
                                  height: 1.12,
                                  letterSpacing: -0.7,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                '지금은 참여 중인 앨범이 없어요.\n사진을 고르고 한 권의 앨범으로 정리해보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  height: 1.55,
                                  color: muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 22.h),
                              SnapFitPressable(
                                onTap: onCreate,
                                pressedScale: 0.965,
                                borderRadius: BorderRadius.circular(18.r),
                                child: Container(
                                  width: double.infinity,
                                  height: 56.h,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18.r),
                                    color: isDark
                                        ? const Color(0xFFF4F1EA)
                                        : const Color(0xFF1F1F1D),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '앨범 만들기',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAlbumStack extends StatelessWidget {
  const _MiniAlbumStack();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230.h,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.13,
            child: _AlbumMockCard(
              width: 142.w,
              height: 188.h,
              gradient: const [Color(0xFFFFE7C8), Color(0xFFFFF9EF)],
              alignment: Alignment.centerLeft,
            ),
          ),
          Transform.translate(
            offset: Offset(34.w, 10.h),
            child: Transform.rotate(
              angle: 0.11,
              child: _AlbumMockCard(
                width: 150.w,
                height: 204.h,
                gradient: const [Color(0xFFDFF8FF), Color(0xFFFFF7F0)],
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(0, -2.h),
            child: Container(
              width: 170.w,
              height: 214.h,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: Image.asset(
                  'assets/empty_state.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFE1EC), Color(0xFFE1F7FF)],
                      ),
                    ),
                    child: const Icon(Icons.photo_library_outlined),
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

class _AlbumMockCard extends StatelessWidget {
  const _AlbumMockCard({
    required this.width,
    required this.height,
    required this.gradient,
    required this.alignment,
  });

  final double width;
  final double height;
  final List<Color> gradient;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Align(
        alignment: alignment,
        child: Container(
          width: width * 0.74,
          height: height * 0.78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            gradient: LinearGradient(colors: gradient),
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
