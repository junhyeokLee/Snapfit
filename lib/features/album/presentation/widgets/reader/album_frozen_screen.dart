import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/snapfit_colors.dart';

// ── 제작확정 완료 화면 ────────────────────────────────────────────
class AlbumFrozenScreen extends StatefulWidget {
  final dynamic album;
  final VoidCallback onClose;
  final VoidCallback onOrder;

  const AlbumFrozenScreen({
    super.key,
    required this.album,
    required this.onClose,
    required this.onOrder,
  });

  @override
  State<AlbumFrozenScreen> createState() => _AlbumFrozenScreenState();
}

class _AlbumFrozenScreenState extends State<AlbumFrozenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<double>(
      begin: 40,
      end: 0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SnapFitColors.freezeBackground,
      body: Stack(
        children: [
          // 배경 별빛 파티클
          ..._buildStars(),

          SafeArea(
            child: Column(
              children: [
                // X 닫기 버튼
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 12.h,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // 블러 앨범 카드 + FREEZE 배지
                FadeTransition(
                  opacity: _fadeIn,
                  child: AnimatedBuilder(
                    animation: _slideUp,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _slideUp.value),
                      child: child,
                    ),
                    child: _buildAlbumCard(context),
                  ),
                ),

                SizedBox(height: 48.h),

                // 텍스트
                FadeTransition(
                  opacity: _fadeIn,
                  child: AnimatedBuilder(
                    animation: _slideUp,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, _slideUp.value * 1.5),
                      child: child,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '제작이 확정되었습니다!',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          '이제 이 앨범은 누구도 수정할 수 없는\n소중한 기록이 되었습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white.withValues(alpha: 0.6),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // 버튼들
                FadeTransition(
                  opacity: _fadeIn,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Column(
                      children: [
                        // 주문하러가기 버튼
                        GestureDetector(
                          onTap: widget.onOrder,
                          child: Container(
                            width: double.infinity,
                            height: 56.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  SnapFitColors.freezeAccent,
                                  const Color(0xFF00B8D4), // Cyan-ish sub color
                                ],
                              ),
                              borderRadius: BorderRadius.circular(28.r),
                              boxShadow: [
                                BoxShadow(
                                  color: SnapFitColors.freezeGlow.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '주문하러가기',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // 앨범 보관함으로 버튼
                        GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            width: double.infinity,
                            height: 52.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(26.r),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '앨범 보관함으로',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topRight,
      children: [
        // 블러 카드
        Container(
          width: 220.w,
          height: 280.w,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20.r),
            child: Stack(
              children: [
                // 흐림 처리된 내부
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        SnapFitColors.freezeSurface,
                        SnapFitColors.freezeSurfaceDark,
                      ],
                    ),
                  ),
                ),
                // 내부 라인 효과 (책 페이지 느낌)
                Positioned(
                  top: 20.h,
                  left: 20.w,
                  right: 20.w,
                  child: Container(
                    height: 140.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40.h,
                  left: 20.w,
                  right: 60.w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 8.h,
                        width: 80.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        height: 6.h,
                        width: 120.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        height: 6.h,
                        width: 90.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // FREEZE 배지
        Positioned(
          top: -12.h,
          right: -12.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  SnapFitColors.freezeAccent,
                  SnapFitColors.freezeAccentDark,
                ],
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: SnapFitColors.freezeGlow.withValues(alpha: 0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.ac_unit_rounded, color: Colors.white, size: 14.sp),
                SizedBox(width: 4.w),
                Text(
                  'FREEZE',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 배경 별빛 파티클 생성
  List<Widget> _buildStars() {
    final rng = math.Random(42);
    return List.generate(18, (i) {
      final x = rng.nextDouble();
      final y = rng.nextDouble();
      final size = rng.nextDouble() * 3 + 1.5;
      final opacity = rng.nextDouble() * 0.5 + 0.2;
      return Positioned(
        left: x * MediaQuery.sizeOf(context).width,
        top: y * MediaQuery.sizeOf(context).height,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      );
    });
  }
}
