import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../splash/presentation/views/splash_screen.dart';
import '../../../album/presentation/viewmodels/gallery_notifier.dart'; // Add import
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../album/presentation/views/album_category_screen.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/domain/entities/storage_quota.dart';
import '../../../billing/domain/entities/subscription_status.dart';
import '../../../notification/presentation/providers/notification_provider.dart';
import '../../data/order_repository.dart';
import '../../domain/entities/order_history_item.dart';
import 'notification_settings_screen.dart';
import 'order_history_screen.dart';
import 'support_inquiry_screen.dart';
import 'terms_policy_screen.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  bool _isDeletingAccount = false;

  static bool _logged = false;

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.enter('MyPageScreen', '마이 · 테마 설정(라이트/다크) · 로그아웃');
    }
    final authAsync = ref.watch(authViewModelProvider);
    final albumsAsync = ref.watch(homeViewModelProvider);
    final subscriptionAsync = ref.watch(mySubscriptionProvider);
    final storageQuotaAsync = ref.watch(myStorageQuotaProvider);
    final orderSummaryAsync = ref.watch(myOrderSummaryProvider);
    final unreadNotiAsync = ref.watch(notificationUnreadCountProvider);
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

    return PopScope(
      canPop: !_isDeletingAccount,
      child: Scaffold(
        backgroundColor: SnapFitColors.isDark(context)
            ? SnapFitColors.backgroundOf(context)
            : SnapFitColors.surfaceLight,
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isDeletingAccount,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 28.h),
                children: [
                  SizedBox(height: MediaQuery.of(context).padding.top),
                  _buildTopBar(
                    context,
                    ref,
                    textColor,
                    themeMode,
                    unreadNotiAsync.maybeWhen(
                      data: (count) => count,
                      orElse: () => 0,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildProfileHero(
                    context,
                    ref,
                    userInfo,
                    textColor,
                    subColor,
                    subscriptionAsync,
                  ),
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
                  _buildStorageUsageCard(context, storageQuotaAsync),
                  SizedBox(height: 12.h),
                  _buildOrderStatusCard(
                    context,
                    ref,
                    currentUserId,
                    orderSummaryAsync,
                    ref.watch(myOrderStatusBadgesProvider),
                  ),
                  SizedBox(height: 12.h),
                  _buildMenuCard(
                    context: context,
                    rows: [
                      _menuRow(
                        context: context,
                        icon: Icons.history_rounded,
                        title: '나의 주문 내역',
                        trailingDot: false,
                        onTap: () async {
                          final summary = orderSummaryAsync.maybeWhen(
                            data: (s) => s,
                            orElse: () => null,
                          );
                          if (summary != null && currentUserId.isNotEmpty) {
                            await ref
                                .read(orderRepositoryProvider)
                                .markOrderSummarySeen(
                                  userId: currentUserId,
                                  summary: summary,
                                );
                            ref.invalidate(myOrderStatusBadgesProvider);
                          }
                          if (!context.mounted) return;
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
                        icon: Icons.credit_card_rounded,
                        title: '구독 및 결제 관리',
                        trailingDot: false,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '구독/결제관리는 점검 중입니다. 잠시 후 다시 열릴 예정입니다.',
                              ),
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
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SupportInquiryScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await ref
                              .read(authViewModelProvider.notifier)
                              .logout();
                          if (context.mounted) {
                            _showToast('로그아웃되었습니다.');
                          }
                        },
                        child: Text(
                          '로그아웃',
                          style: context.sfSub(
                            size: 12.sp,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      TextButton(
                        onPressed: _isDeletingAccount
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('회원 탈퇴'),
                                    content: const Text(
                                      '정말 탈퇴하시겠어요?\n앨범/주문/구독/프로필 정보가 모두 삭제되며 복구할 수 없습니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('취소'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('탈퇴하기'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true) return;
                                if (mounted) {
                                  setState(() => _isDeletingAccount = true);
                                }
                                try {
                                  await ref
                                      .read(authViewModelProvider.notifier)
                                      .deleteAccount();
                                  if (!context.mounted) return;
                                  _showToast('탈퇴가 완료되었습니다.');
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const SplashScreen(),
                                    ),
                                    (_) => false,
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  final errorText =
                                      AppErrorMapper.toUserMessage(e);
                                  final isAuthError =
                                      errorText.contains('세션') ||
                                      errorText.contains('권한') ||
                                      errorText.contains('세션이 만료');
                                  _showToast(
                                    isAuthError
                                        ? '세션이 만료되었거나 권한이 없습니다. 다시 로그인 후 탈퇴를 시도해주세요.'
                                        : '탈퇴 처리 실패: $errorText',
                                  );
                                } finally {
                                  if (context.mounted) {
                                    setState(() => _isDeletingAccount = false);
                                  }
                                }
                              },
                        child: Text(
                          '탈퇴하기',
                          style: context.sfSub(
                            size: 12.sp,
                            weight: FontWeight.w600,
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
            ),
            if (_isDeletingAccount)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.32),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.w,
                        vertical: 16.h,
                      ),
                      decoration: BoxDecoration(
                        color: SnapFitColors.surfaceOf(context),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 22.w,
                            height: 22.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2.6,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            '탈퇴 처리 중입니다...',
                            style: context.sfSub(
                              size: 12.sp,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    WidgetRef ref,
    Color textColor,
    ThemeMode themeMode,
    int unreadCount,
  ) {
    return Row(
      children: [
        Text('마이페이지', style: context.sfTitle(size: 16.sp)),
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
            if (unreadCount > 0)
              Positioned(
                right: 10.w,
                top: 10.h,
                child: Container(
                  width: 7.w,
                  height: 7.w,
                  decoration: const BoxDecoration(
                    color: SnapFitColors.accent,
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
    AsyncValue<SubscriptionStatusModel> subscriptionAsync,
  ) {
    final name = userInfo?.name ?? '사용자';
    final email = _displayEmail(userInfo);
    final profileUrl = userInfo?.profileImageUrl;

    final membershipLabel = subscriptionAsync.maybeWhen(
      data: (sub) => sub.isActive ? '✪ SnapFit Pro 구독중' : '구독 미이용',
      orElse: () => '구독 상태 확인중...',
    );
    final membershipBg = subscriptionAsync.maybeWhen(
      data: (sub) =>
          sub.isActive ? SnapFitColors.accentLight : SnapFitStylePalette.gray,
      orElse: () => SnapFitStylePalette.gray,
    );
    final membershipColor = subscriptionAsync.maybeWhen(
      data: (sub) => sub.isActive
          ? SnapFitColors.accent
          : SnapFitColors.textSecondaryOf(context),
      orElse: () => SnapFitColors.textSecondaryOf(context),
    );

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
                color: SnapFitStylePalette.coral,
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
                              Container(color: SnapFitStylePalette.beige),
                        )
                      : Container(color: SnapFitStylePalette.beige),
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
                    color: SnapFitColors.accent,
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
            color: membershipBg,
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Text(
            membershipLabel,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: membershipColor,
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

  String _displayEmail(UserInfo? userInfo) {
    final raw = userInfo?.email?.trim() ?? '';
    if (raw.isNotEmpty && raw.contains('@')) {
      return raw;
    }
    final provider = (userInfo?.provider ?? '').toUpperCase();
    if (provider == 'KAKAO') return '카카오 계정(이메일 미제공)';
    if (provider == 'GOOGLE') return '구글 계정(이메일 미제공)';
    return '이메일 정보 없음';
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

  Widget _buildOrderStatusCard(
    BuildContext context,
    WidgetRef ref,
    String currentUserId,
    AsyncValue<OrderSummaryResult> summaryAsync,
    AsyncValue<OrderStatusBadges> badgeAsync,
  ) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    final summary = summaryAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final badges = badgeAsync.maybeWhen(
      data: (b) => b,
      orElse: () => const OrderStatusBadges.zero(),
    );

    final statuses = [
      (Icons.credit_card_rounded, '결제대기', badges.paymentPending),
      (Icons.payments_rounded, '결제완료', badges.paymentCompleted),
      (Icons.auto_awesome_motion_rounded, '제작중', badges.inProduction),
      (Icons.local_shipping_rounded, '배송중', badges.shipping),
      (Icons.task_alt_rounded, '배송완료', badges.delivered),
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
          InkWell(
            onTap: () async {
              if (summary != null && currentUserId.isNotEmpty) {
                await ref
                    .read(orderRepositoryProvider)
                    .markOrderSummarySeen(
                      userId: currentUserId,
                      summary: summary,
                    );
                ref.invalidate(myOrderStatusBadgesProvider);
              }
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
              );
            },
            borderRadius: BorderRadius.circular(12.r),
            child: Row(
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
          ),
          SizedBox(height: 10.h),
          if (summaryAsync.isLoading && !summaryAsync.hasValue)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 12.w,
                    height: 12.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    '주문 현황 동기화 중...',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: subColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
                          if (s.$3 > 0)
                            Positioned(
                              right: -6.w,
                              top: -6.h,
                              child: Container(
                                constraints: BoxConstraints(minWidth: 20.w),
                                height: 20.w,
                                padding: EdgeInsets.symmetric(horizontal: 4.w),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: SnapFitColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  s.$3 > 99 ? '99+' : '${s.$3}',
                                  style: TextStyle(
                                    fontSize: 9.sp,
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

  Widget _buildStorageUsageCard(
    BuildContext context,
    AsyncValue<StorageQuotaStatus> storageQuotaAsync,
  ) {
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);

    String formatBytes(int bytes) {
      const kb = 1024;
      const mb = 1024 * kb;
      const gb = 1024 * mb;
      if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
      if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
      if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
      return '$bytes B';
    }

    return Container(
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: storageQuotaAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => Row(
          children: [
            SizedBox(
              width: 16.w,
              height: 16.w,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10.w),
            Text(
              '저장 사용량 확인중...',
              style: TextStyle(
                fontSize: 11.sp,
                color: subColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '저장 사용량',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              '운영상 무제한 · 사용량 데이터 수집중',
              style: TextStyle(
                fontSize: 10.sp,
                color: subColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        data: (quota) {
          final hard = quota.hardLimitBytes <= 0 ? 1 : quota.hardLimitBytes;
          final progress = (quota.usedBytes / hard).clamp(0.0, 1.0);
          final usedText = formatBytes(quota.usedBytes);
          final limitText = quota.hardLimitBytes > 0
              ? formatBytes(quota.hardLimitBytes)
              : '미정';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '저장 사용량',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: SnapFitStylePalette.gray,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      quota.planCode,
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
              Text(
                '$usedText / $limitText',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: subColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(999.r),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8.h,
                  backgroundColor: SnapFitColors.overlayLightOf(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    SnapFitColors.accent,
                  ),
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                '용량 초과 시 저장/업로드가 차단됩니다. FREE 1GB · PRO 10GB',
                style: TextStyle(
                  fontSize: 9.sp,
                  color: subColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
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
                color: SnapFitColors.accent,
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
          SnackBar(content: Text('저장 실패: ${AppErrorMapper.toUserMessage(e)}')),
        );
      }
    }
  }
}
