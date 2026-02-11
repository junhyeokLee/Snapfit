import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../album/data/api/album_provider.dart';
import '../../../album/presentation/viewmodels/album_editor_view_model.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';

/// 마이 페이지 (이미지 구조: 프로필, 주문/배송, 공유 앨범, 앱 설정·테마, 로그아웃)
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
    final userInfo = authAsync.asData?.value;
    final themeMode = ref.watch(themeModeControllerProvider);
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: AppBar(
        title: Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        backgroundColor: SnapFitColors.backgroundOf(context),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor, size: 24.sp),
            onPressed: () {
              // TODO: 설정 화면
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          // 1. 프로필 영역
          _buildProfileSection(context, ref, userInfo, textColor, subColor),
          SizedBox(height: 24.h),

          // 2. 주문 배송 조회
          _buildSectionTitle(context, '주문 배송 조회', '전체보기', textColor, ref),
          SizedBox(height: 8.h),
          _buildOrderDeliveryCard(context, textColor, subColor),
          SizedBox(height: 24.h),

          // 3. 공유된 앨범
          _buildSectionTitle(context, '공유된 앨범', null, textColor, ref),
          SizedBox(height: 8.h),
          _buildSharedAlbumCard(context, textColor, subColor),
          SizedBox(height: 24.h),

          // 4. 앱 설정 및 지원 (테마 포함)
          _buildSectionTitle(context, '앱 설정 및 지원', null, textColor, ref),
          SizedBox(height: 8.h),
          _buildAppSettingsCard(context, ref, themeMode, textColor, subColor),
          SizedBox(height: 24.h),

          // 5. 로그아웃
          _buildLogoutButton(context, ref, textColor),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    WidgetRef ref,
    UserInfo? userInfo,
    Color textColor,
    Color subColor,
  ) {
    final name = userInfo?.name ?? '사용자';
    final email = userInfo?.email ?? '';
    final profileUrl = userInfo?.profileImageUrl;

    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: SnapFitColors.accent, width: 2),
                color: SnapFitColors.surfaceOf(context),
              ),
              child: ClipOval(
                child: profileUrl != null && profileUrl.isNotEmpty
                    ? Image.network(
                        profileUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.person,
                          size: 36.sp,
                          color: subColor,
                        ),
                      )
                    : Icon(
                        Icons.person,
                        size: 36.sp,
                        color: subColor,
                      ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () => _pickAndSaveProfileImage(context, ref, userInfo),
                child: Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: SnapFitColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SnapFitColors.backgroundOf(context),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.edit, size: 12.sp, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: SnapFitColors.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      'OWNER',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (email.isNotEmpty) ...[
                SizedBox(height: 4.h),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: subColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    String? actionLabel,
    Color textColor,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: () {
              // TODO: 전체보기
            },
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: SnapFitColors.accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildOrderDeliveryCard(
    BuildContext context,
    Color textColor,
    Color subColor,
  ) {
    final items = [
      ('2', '결제완료'),
      ('1', '제작중'),
      ('1', '배송중'),
      ('12', '배송완료'),
    ];
    return _buildCard(
      context: context,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) {
              final isHighlight = e.key == 2;
              return Column(
                children: [
                  Text(
                    e.value.$1,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: isHighlight
                          ? SnapFitColors.accent
                          : textColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    e.value.$2,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isHighlight
                          ? SnapFitColors.accent
                          : subColor,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedAlbumCard(
    BuildContext context,
    Color textColor,
    Color subColor,
  ) {
    return _buildCard(
      context: context,
      children: [
        _listTile(
          context: context,
          icon: Icons.folder_outlined,
          title: '초대받은 앨범',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: SnapFitColors.accent,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  '3',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.chevron_right, color: subColor, size: 20.sp),
            ],
          ),
          onTap: () {},
        ),
        Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
        _listTile(
          context: context,
          icon: Icons.group_outlined,
          title: '함께 편집중인 친구',
          trailing: Icon(Icons.chevron_right, color: subColor, size: 20.sp),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildAppSettingsCard(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
    Color textColor,
    Color subColor,
  ) {
    return _buildCard(
      context: context,
      children: [
        _listTile(
          context: context,
          icon: Icons.notifications_outlined,
          title: '알림 설정',
          trailing: Icon(Icons.chevron_right, color: subColor, size: 20.sp),
          onTap: () {},
        ),
        Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
        _listTile(
          context: context,
          icon: Icons.help_outline,
          title: '고객 센터',
          trailing: Icon(Icons.chevron_right, color: subColor, size: 20.sp),
          onTap: () {},
        ),
        Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
        _listTile(
          context: context,
          icon: Icons.info_outline,
          title: '약관 및 정책',
          trailing: Icon(Icons.chevron_right, color: subColor, size: 20.sp),
          onTap: () {},
        ),
        Divider(height: 1, color: SnapFitColors.overlayLightOf(context)),
        // 테마 (기존 유지)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, color: textColor, size: 22.sp),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '테마',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        _themeChip(
                          context,
                          ref,
                          label: '라이트',
                          mode: ThemeMode.light,
                          current: themeMode,
                          onTap: () =>
                              ref.read(themeModeControllerProvider.notifier).setLight(),
                        ),
                        SizedBox(width: 12.w),
                        _themeChip(
                          context,
                          ref,
                          label: '다크',
                          mode: ThemeMode.dark,
                          current: themeMode,
                          onTap: () =>
                              ref.read(themeModeControllerProvider.notifier).setDark(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _themeChip(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required ThemeMode mode,
    required ThemeMode current,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == current;
    final textColor = SnapFitColors.textPrimaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? SnapFitColors.accent.withOpacity(0.2)
              : SnapFitColors.overlayLightOf(context),
          borderRadius: BorderRadius.circular(12.r),
          border: isSelected
              ? Border.all(color: SnapFitColors.accent, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? SnapFitColors.accent : textColor,
          ),
        ),
      ),
    );
  }

  Widget _listTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    return ListTile(
      leading: Icon(icon, color: textColor, size: 22.sp),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref, Color textColor) {
    return Center(
      child: TextButton(
        onPressed: () async {
          await ref.read(authViewModelProvider.notifier).logout();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('로그아웃되었습니다.')),
            );
          }
        },
        child: Text(
          '로그아웃',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.red,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 후 이용해 주세요.')),
        );
      }
      return;
    }

    await ref.read(albumEditorViewModelProvider.notifier).ensureGalleryLoaded();
    if (!context.mounted) return;

    final asset = await showPhotoSelectionSheet(context, ref);
    if (asset == null || !context.mounted) return;

    final file = await asset.file;
    if (file == null || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사진 파일을 불러올 수 없습니다.')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 사진 업로드 중...')),
      );

      await ref.read(authViewModelProvider.notifier).updateProfileImage(file);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 사진이 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${e is Exception ? e.toString().replaceFirst('Exception: ', '') : e}')),
        );
      }
    }
  }
}
