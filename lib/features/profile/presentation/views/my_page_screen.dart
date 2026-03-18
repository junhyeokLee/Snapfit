import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../album/presentation/viewmodels/gallery_notifier.dart'; // Add import
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../album/presentation/views/album_category_screen.dart';
import 'notification_settings_screen.dart';
import 'order_history_screen.dart';
import 'terms_policy_screen.dart';

class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  static bool _logged = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.enter('MyPageScreen', '마이 · 테마 설정(라이트/다크) · 로그아웃');
    }
    final authAsync = ref.watch(authViewModelProvider);
    final albumsAsync = ref.watch(homeViewModelProvider);
    final userInfo = authAsync.asData?.value;
    final themeMode = ref.watch(themeModeControllerProvider);
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    final currentUserId = userInfo?.id.toString() ?? '';
    final albums = albumsAsync.asData?.value ?? const [];
    final sharedAlbums = albums.where((a) {
      if (currentUserId.isEmpty) return false;
      return a.userId.trim().isNotEmpty && a.userId.trim() != currentUserId;
    }).toList();
    final completedAlbums = albums.where(isCompletedAlbum).toList();
    final totalPhotos = albums.fold<int>(0, (sum, a) => sum + a.totalPages);

    return Scaffold(
      backgroundColor: SnapFitColors.isDark(context)
          ? SnapFitColors.backgroundOf(context)
          : const Color(0xFFF7F8FA),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          _buildTopBar(context, ref, textColor, themeMode),
          SizedBox(height: 12.h),
          _buildProfileHero(context, ref, userInfo, textColor, subColor),
          SizedBox(height: 12.h),
          _buildStatsRow(
            context,
            textColor: textColor,
            subColor: subColor,
            totalPhotos: totalPhotos,
            sharedCount: sharedAlbums.length,
            completedCount: completedAlbums.length,
          ),
          SizedBox(height: 12.h),
          _buildOrderStatusCard(context),
          SizedBox(height: 12.h),
          _buildMenuCard(
            context: context,
            rows: [
              _menuRow(
                context: context,
                icon: Icons.history_rounded,
                title: '나의 주문 내역',
                trailingDot: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OrderHistoryScreen(),
                    ),
                  );
                },
              ),
              _menuRow(
                context: context,
                icon: Icons.photo_library_outlined,
                title: '공유된 앨범',
                trailingDot: sharedAlbums.isNotEmpty,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumCategoryScreen(
                        category: AlbumCategory.shared,
                        initialAlbums: sharedAlbums,
                        currentUserId: currentUserId,
                      ),
                    ),
                  );
                },
              ),
              _menuRow(
                context: context,
                icon: Icons.notifications_none_rounded,
                title: '알림 설정',
                trailingDot: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationSettingsScreen(),
                    ),
                  );
                },
              ),
              _menuRow(
                context: context,
                icon: Icons.description_outlined,
                title: '약관 및 정책',
                trailingDot: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermsPolicyScreen(),
                    ),
                  );
                },
              ),
              _menuRow(
                context: context,
                icon: Icons.help_outline_rounded,
                title: '고객 센터',
                trailingDot: false,
                onTap: () {},
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  await ref.read(authViewModelProvider.notifier).logout();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
                  }
                },
                child: Text(
                  '로그아웃',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              TextButton(
                onPressed: () {},
                child: Text(
                  '탈퇴하기',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Center(
            child: Text(
              'SnapFit Version 1.4.2 (2024)',
              style: TextStyle(
                fontSize: 10.sp,
                color: SnapFitColors.textMutedOf(context),
              ),
            ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    Color textColor,
    ThemeMode themeMode,
  ) {
    return Row(
      children: [
        Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.settings_rounded, size: 20.sp, color: textColor),
          onPressed: () => _showThemeBottomSheet(context, ref, themeMode),
        ),
        Stack(
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_rounded,
                size: 20.sp,
                color: textColor,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            Positioned(
              right: 10.w,
              top: 10.h,
              child: Container(
                width: 7.w,
                height: 7.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF10BEE2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileHero(
    BuildContext context,
    WidgetRef ref,
    UserInfo? userInfo,
    Color textColor,
    Color subColor,
  ) {
    final name = userInfo?.name ?? '사용자';
    final email = userInfo?.email ?? 'snapfit_user@example.com';
    final profileUrl = userInfo?.profileImageUrl;

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 126.w,
              height: 126.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF3C6AD),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: SizedBox(
                  width: 126.w,
                  height: 126.w,
                  child: profileUrl != null && profileUrl.isNotEmpty
                      ? Image.network(
                          profileUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFFE9D8CE)),
                        )
                      : Container(color: const Color(0xFFE9D8CE)),
                ),
              ),
            ),
            Positioned(
              right: -2.w,
              bottom: 6.h,
              child: GestureDetector(
                onTap: () => _pickAndSaveProfileImage(context, ref, userInfo),
                child: Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10BEE2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit, size: 16.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Text(
          name,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F6FB),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Text(
            '✪ Family Plan 멤버십',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF10BEE2),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          email,
          style: TextStyle(
            fontSize: 10.sp,
            color: subColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(
    BuildContext context, {
    required Color textColor,
    required Color subColor,
    required int totalPhotos,
    required int sharedCount,
    required int completedCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _statItem('나의 사진', totalPhotos, textColor, subColor),
        Container(
          width: 1,
          height: 38.h,
          color: SnapFitColors.overlayLightOf(context),
        ),
        _statItem('공유된앨범', sharedCount, textColor, subColor),
        Container(
          width: 1,
          height: 38.h,
          color: SnapFitColors.overlayLightOf(context),
        ),
        _statItem('제작 완료', completedCount, textColor, subColor),
      ],
    );
  }

  Widget _statItem(String label, int value, Color textColor, Color subColor) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            color: subColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderStatusCard(BuildContext context) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    final statuses = const [
      (Icons.credit_card_rounded, '결제대기', '1'),
      (Icons.payments_rounded, '결제완료', '2'),
      (Icons.auto_awesome_motion_rounded, '제작중', '1'),
      (Icons.local_shipping_rounded, '배송중', '1'),
      (Icons.task_alt_rounded, '배송완료', '3'),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '나의 주문 현황',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, size: 20.sp, color: subColor),
            ],
          ),
          SizedBox(height: 10.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) {
                return Padding(
                  padding: EdgeInsets.only(right: 10.w),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: SnapFitColors.overlayLightOf(context),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Icon(s.$1, size: 20.sp, color: textColor),
                          ),
                          Positioned(
                            right: -6.w,
                            top: -6.h,
                            child: Container(
                              width: 20.w,
                              height: 20.w,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10BEE2),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                s.$3,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required List<Widget> rows,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
          ],
        ],
      ),
    );
  }

  Widget _menuRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool trailingDot,
    required VoidCallback onTap,
  }) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 3.h),
      leading: Container(
        width: 34.w,
        height: 34.w,
        decoration: BoxDecoration(
          color: SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(icon, size: 17.sp, color: textColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingDot)
            Container(
              width: 8.w,
              height: 8.w,
              decoration: const BoxDecoration(
                color: Color(0xFF10BEE2),
                shape: BoxShape.circle,
              ),
            ),
          SizedBox(width: trailingDot ? 10.w : 0),
          Icon(Icons.chevron_right, color: subColor, size: 20.sp),
        ],
      ),
    );
  }

  void _showThemeBottomSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 14.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '테마 설정',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: SnapFitColors.textPrimaryOf(context),
                  ),
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    Expanded(
                      child: _themeOptionButton(
                        context: context,
                        label: '라이트',
                        selected: themeMode == ThemeMode.light,
                        onTap: () {
                          ref
                              .read(themeModeControllerProvider.notifier)
                              .setLight();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _themeOptionButton(
                        context: context,
                        label: '다크',
                        selected: themeMode == ThemeMode.dark,
                        onTap: () {
                          ref
                              .read(themeModeControllerProvider.notifier)
                              .setDark();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeOptionButton({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? SnapFitColors.accent.withValues(alpha: 0.2)
              : SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(12.r),
          border: selected ? Border.all(color: SnapFitColors.accent) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: selected
                ? SnapFitColors.accent
                : SnapFitColors.textPrimaryOf(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// 앱 내 갤러리에서 사진 선택 → 업로드 → 서버 프로필 저장
  static Future<void> _pickAndSaveProfileImage(
    BuildContext context,
    WidgetRef ref,
    UserInfo? userInfo,
  ) async {
    final userId = userInfo?.id.toString();
    if (userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 후 이용해 주세요.')));
      }
      return;
    }

    final gallery = ref.read(galleryProvider);
    if (gallery.albums.isEmpty) {
      await ref.read(galleryProvider.notifier).fetchInitialData();
    }
    if (!context.mounted) return;

    final asset = await showPhotoSelectionSheet(context, ref);
    if (!context.mounted || asset == null) return;

    final file = await asset.file;
    if (!context.mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('사진 파일을 불러올 수 없습니다.')));
      return;
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필 사진 업로드 중...')));

      await ref.read(authViewModelProvider.notifier).updateProfileImage(file);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('프로필 사진이 저장되었습니다.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '저장 실패: ${e is Exception ? e.toString().replaceFirst('Exception: ', '') : e}',
            ),
          ),
        );
      }
    }
  }
}
