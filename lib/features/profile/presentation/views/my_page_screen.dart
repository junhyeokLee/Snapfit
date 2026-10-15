import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../store/presentation/views/material_catalog_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/navigation/web_app_location.dart';
import '../../../album/data/gallery/browser_photo_asset.dart';
import '../../../../config/env.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/auth_gate.dart';
import '../../../album/presentation/viewmodels/gallery_notifier.dart'; // Add import
import '../../../album/presentation/viewmodels/home_view_model.dart';
import '../../../album/presentation/widgets/home/home_album_helpers.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../../shared/web/web_design.dart';
import '../../../album/presentation/views/album_category_screen.dart';
import '../../../billing/data/billing_provider.dart';
import '../../../billing/domain/entities/storage_quota.dart';
import '../../../point_shop/data/point_shop_provider.dart';
import '../../../notification/presentation/views/notification_screen.dart';
import '../../data/order_repository.dart';
import '../../domain/order_visibility_owner.dart';
import 'notification_settings_screen.dart';
import 'account_settings_screen.dart';
import 'admin_order_management_screen.dart';
import 'admin_template_management_screen.dart';
import 'billing_management_screen.dart';
import '../widgets/my_point_balance_card.dart';
import '../widgets/personal_collection_shelf.dart';
import '../../../album/domain/entities/album.dart';
import '../../../album/presentation/widgets/home/home_album_actions.dart';
import '../widgets/theme_settings_sheet.dart';
import 'admin_point_shop_management_screen.dart';
import 'order_history_screen.dart';
import 'support_inquiry_screen.dart';
import 'terms_policy_screen.dart';

class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  static bool _logged = false;

  void _openLibrary([String type = '전체']) {
    if (kIsWeb) {
      Navigator.push(context, snapFitRoute(
        page: MaterialCatalogScreen(library: true, initialType: type),
        settings: const WebAppRouteSettings(WebAppLocation.library),
      ));
      return;
    }
    final scope = ExperienceNavigationScope.maybeOf(context);
    if (type == '전체' && scope != null) {
      scope.onNavigate(6);
      return;
    }
    Navigator.push(
      context,
      snapFitRoute(
        page: MaterialCatalogScreen(library: true, initialType: type),
      ),
    );
  }

  void _openAlbums(List<Album> albums, String currentUserId) => Navigator.push(
    context,
    snapFitRoute(
      page: AlbumCategoryScreen(
        category: AlbumCategory.recent,
        initialAlbums: albums,
        currentUserId: currentUserId,
      ),
    ),
  );

  void _openSharedAlbums(List<Album> albums, String ownerId) {
    if (ref.read(visibleOrderOwnerProvider) != ownerId) return;
    Navigator.push(context, snapFitRoute(page: AlbumCategoryScreen(
      category: AlbumCategory.shared, initialAlbums: albums,
      currentUserId: ownerId,
    )));
  }

  Future<void> _openPointCharge() async {
    await Navigator.push(
      context,
      snapFitRoute(page: const BillingManagementScreen()),
    );
    if (mounted) {
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
    }
  }

  Future<void> _openAccountSettings() async {
    final result = await Navigator.push<AccountSettingsResult>(
      context,
      snapFitRoute(
        page: AccountSettingsScreen(onChangePhoto: _pickAndSaveProfileImage),
      ),
    );
    if (mounted && result != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_logged) {
      _logged = true;
      ScreenLogger.enter('MyPageScreen', '마이 · 테마 설정(라이트/다크) · 로그아웃');
    }
    final authAsync = ref.watch(authViewModelProvider);
    final albumsAsync = ref.watch(homeViewModelProvider);
    final pointBalanceAsync = ref.watch(myPointBalanceProvider);
    final storageQuotaAsync = ref.watch(myStorageQuotaProvider);
    final orderSummaryAsync = ref.watch(myOrderSummaryProvider);
    final userInfo = authAsync.asData?.value;
    final themeMode = ref.watch(themeModeControllerProvider);
    final textColor = SnapFitColors.textPrimaryOf(context);
    final subColor = SnapFitColors.textSecondaryOf(context);
    final hasAdminOrderAccess = Env.orderAdminKey.trim().isNotEmpty;
    final hasPointShopAdminAccess = ref.watch(pointShopAdminAccessProvider);
    final currentUserId = userInfo?.id.toString() ?? '';
    final albums = albumsAsync.asData?.value ?? const [];
    final sharedAlbums = albums.where((a) {
      if (currentUserId.isEmpty) return false;
      return a.userId.trim().isNotEmpty && a.userId.trim() != currentUserId;
    }).toList();
    final completedAlbums = albums.where(isCompletedAlbum).toList();
    final totalPhotos = albums.fold<int>(0, (sum, a) => sum + a.totalPages);

    if (kIsWeb) {
      return _webOverview(
        userInfo: userInfo,
        albums: albumsAsync,
        points: pointBalanceAsync,
        quota: storageQuotaAsync,
        summary: orderSummaryAsync,
      );
    }

    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: const ExperienceHeader(title: '마이', themeAware: true),
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, bounds) {
                final wide =
                    bounds.maxWidth >= 540 &&
                    MediaQuery.orientationOf(context) == Orientation.landscape;
                final items = <Widget>[
                  _buildProfileHero(
                    context,
                    ref,
                    userInfo,
                    textColor,
                    subColor,
                    pointBalanceAsync,
                    compact: wide,
                  ),
                  const SizedBox(height: 12),
                  MyPointBalanceCard(onCharge: _openPointCharge),
                  const SizedBox(height: 28),
                  PersonalAlbumShelf(
                    key: const ValueKey('profile-album-collection'),
                    albums: albumsAsync,
                    onShowAll: () => _openAlbums(albums, currentUserId),
                    onRetry: () => ref.invalidate(homeViewModelProvider),
                    onOpen: (album) => HomeAlbumActions.openAlbum(
                      context,
                      ref,
                      album,
                      onAlbumDeleted: (_) =>
                          ref.invalidate(homeViewModelProvider),
                    ),
                  ),
                  const SizedBox(height: 28),
                  OwnedDesignShelf(
                    key: const ValueKey('profile-design-collection'),
                    onOpen: _openLibrary,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, '구매 및 이용'),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.inventory_2_outlined,
                    title: '인쇄 주문 내역',
                    subtitle: '제작 진행 · 배송 조회',
                    onTap: () => Navigator.push(
                      context,
                      snapFitRoute(
                        page: const OrderHistoryScreen(),
                        settings: const WebAppRouteSettings(
                          WebAppLocation.orders,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(context, '설정 및 도움말'),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.manage_accounts_outlined,
                    title: '계정 설정',
                    subtitle: '로그인 정보 · 프로필 · 보안',
                    onTap: _openAccountSettings,
                  ),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.palette_outlined,
                    title: '화면 테마',
                    subtitle: themeMode == ThemeMode.dark ? '다크' : '라이트',
                    onTap: () => _showThemeBottomSheet(context, ref, themeMode),
                  ),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.notifications_none,
                    title: '알림 설정',
                    onTap: () => Navigator.push(
                      context,
                      snapFitRoute(page: const NotificationSettingsScreen()),
                    ),
                  ),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.chat_bubble_outline,
                    title: '고객센터',
                    onTap: () => Navigator.push(
                      context,
                      snapFitRoute(page: const SupportInquiryScreen()),
                    ),
                  ),
                  ExperienceRow(
                    themeAware: true,
                    icon: Icons.description_outlined,
                    title: '이용 안내',
                    onTap: () => Navigator.push(
                      context,
                      snapFitRoute(page: const TermsPolicyScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ExpansionTile(
                    key: const PageStorageKey('profile-activity'),
                    subtitle: Text(
                      '저장 공간 · 함께 만든 앨범 · 관리 도구',
                      style: ExperienceStyle.text(12, color: subColor),
                    ),
                    title: Text(
                      '앨범 활동 및 관리',
                      style: ExperienceStyle.text(13, color: subColor),
                    ),
                    tilePadding: EdgeInsets.zero,
                    children: [
                      ExpansionTile(
                        key: const PageStorageKey('profile-storage'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '앨범과 저장 공간',
                          style: ExperienceStyle.text(
                            14,
                            weight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        leading: const Icon(
                          Icons.auto_stories_outlined,
                          size: 21,
                        ),
                        children: [
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
                        ],
                      ),
                      SizedBox(height: 12.h),
                      ExpansionTile(
                        key: const PageStorageKey('profile-orders'),
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          '인쇄 주문 현황',
                          style: ExperienceStyle.text(
                            14,
                            weight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          size: 21,
                        ),
                        children: [
                          _buildOrderStatusCard(
                            context,
                            ref,
                            currentUserId,
                            orderSummaryAsync,
                            ref.watch(myOrderStatusBadgesProvider),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      _buildMenuSection(
                        context: context,
                        title: '내 활동',
                        subtitle: '앨범과 주문 흐름을 빠르게 확인해요',
                        rows: [
                          _menuRow(
                            context: context,
                            icon: Icons.history_rounded,
                            title: '나의 주문 내역',
                            subtitle: '주문/배송 상태 확인',
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
                                snapFitRoute(
                                  page: const OrderHistoryScreen(),
                                  settings: const WebAppRouteSettings(
                                    WebAppLocation.orders,
                                  ),
                                ),
                              );
                            },
                          ),
                          _menuRow(
                            context: context,
                            icon: Icons.photo_library_outlined,
                            title: '공유된 앨범',
                            subtitle: '${sharedAlbums.length}개의 함께 만든 앨범',
                            trailingDot: sharedAlbums.isNotEmpty,
                            onTap: () {
                              Navigator.push(
                                context,
                                snapFitRoute(
                                  page: AlbumCategoryScreen(
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
                            icon: Icons.credit_card_rounded,
                            title: '포인트 충전',
                            subtitle: '포인트 충전과 사용 내역 확인',
                            trailingDot: false,
                            onTap: _openPointCharge,
                          ),
                        ],
                      ),
                      if (hasPointShopAdminAccess) ...[
                        SizedBox(height: 12.h),
                        _buildMenuSection(
                          context: context,
                          title: '포인트 상점 관리',
                          subtitle: '판매할 상품과 포인트 가격 설정',
                          rows: [
                            _menuRow(
                              context: context,
                              icon: Icons.price_change_outlined,
                              title: '상품 가격 관리',
                              subtitle: '템플릿·스티커·문구·프레임',
                              trailingDot: false,
                              onTap: () => Navigator.push(
                                context,
                                snapFitRoute(
                                  page: const AdminPointShopManagementScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (hasAdminOrderAccess) ...[
                        SizedBox(height: 12.h),
                        _buildMenuSection(
                          context: context,
                          title: '관리자',
                          subtitle: '운영 도구는 별도 섹션으로 정리했어요',
                          rows: [
                            _menuRow(
                              context: context,
                              icon: Icons.admin_panel_settings_outlined,
                              title: '주문 관리',
                              subtitle: '제작/배송 주문 상태 처리',
                              trailingDot: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  snapFitRoute(
                                    page: const AdminOrderManagementScreen(),
                                  ),
                                );
                              },
                            ),
                            _menuRow(
                              context: context,
                              icon: Icons.dashboard_customize_outlined,
                              title: '템플릿 관리',
                              subtitle: '스토어 템플릿 운영',
                              trailingDot: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  snapFitRoute(
                                    page: const AdminTemplateManagementScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 12.h),
                      SizedBox(height: 24.h),
                      SizedBox(height: 24.h),
                      Center(
                        child: Text(
                          'SnapFit',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: SnapFitColors.textMutedOf(context),
                          ),
                        ),
                      ),
                      SizedBox(height: 24.h),
                    ],
                  ),
                ];
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: (bounds.maxWidth * .36).clamp(220.0, 280.0),
                          child: SingleChildScrollView(
                            key: const PageStorageKey('profile-summary-scroll'),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(children: items.take(3).toList()),
                          ),
                        ),
                        const SizedBox(width: 20),
                        VerticalDivider(
                          width: 1,
                          color: ExperienceFormStyle.line(context),
                        ),
                        Expanded(
                          child: ListView(
                            key: const PageStorageKey('profile-menu-scroll'),
                            padding: const EdgeInsets.fromLTRB(20, 12, 0, 24),
                            children: items.skip(3).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  key: const PageStorageKey('profile-menu-scroll'),
                  padding: EdgeInsets.symmetric(
                    horizontal: ((bounds.maxWidth - 680) / 2).clamp(
                      20,
                      double.infinity,
                    ),
                    vertical: 20,
                  ),
                  children: items,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _webHome() {
    final webNavigation = WebNavigationScope.maybeOf(context);
    if (webNavigation != null) {
      webNavigation.onNavigate(WebSection.albums);
      return;
    }
    final scope = ExperienceNavigationScope.maybeOf(context);
    if (scope != null) {
      scope.onNavigate(0);
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _webOrders() {
    final webNavigation = WebNavigationScope.maybeOf(context);
    if (webNavigation != null) {
      webNavigation.onNavigate(WebSection.orders);
      return;
    }
    Navigator.push(context, snapFitRoute(
      page: const OrderHistoryScreen(),
      settings: const WebAppRouteSettings(WebAppLocation.orders),
    ));
  }

  Widget _webOverview({
    required UserInfo? userInfo,
    required AsyncValue<List<Album>> albums,
    required AsyncValue<int> points,
    required AsyncValue<StorageQuotaStatus> quota,
    required AsyncValue<OrderSummaryResult> summary,
  }) {
    final visibleOwner = ref.watch(visibleOrderOwnerProvider);
    if (userInfo == null || visibleOwner != userInfo.id) {
      return const SnapFitWebShell(showNavigation: false,
        child: WebSurface(child: Text('로그인한 계정을 확인한 뒤 계정 정보를 볼 수 있어요.')));
    }
    final name = userInfo.name;
    final photo = userInfo.profileImageUrl;
    final ownedDesigns = ref.watch(ownedPointShopKeysProvider);
    final sharedAlbums = albums.asData?.value.where((album) =>
      album.userId.trim().isNotEmpty && album.userId != userInfo.id).toList();
    final ownAlbums = albums.asData?.value
        .where((album) => album.userId == userInfo.id).length;
    final order = summary.asData?.value;
    final pending = order == null ? null :
        order.paymentPending + order.paymentCompleted + order.inProduction + order.shipping;
    String value(AsyncValue<dynamic> source, Object? result) =>
        source.hasError ? '조회 필요' : result?.toString() ?? '확인 중';
    return SnapFitWebShell(
      section: WebSection.account,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WebPageHeading(
              eyebrow: 'MY ACCOUNT', title: '계정 개요',
              description: '나의 앨범과 주문, 계정 설정을 한곳에서 확인하세요.',
              trailing: OutlinedButton.icon(
                onPressed: _openAccountSettings,
                icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                label: const Text('계정 설정'),
              ),
            ),
            const SizedBox(height: 28),
            WebSurface(
              child: Row(children: [
                Tooltip(message: '프로필 사진 크게 보기', child: InkWell(
                  onTap: () => _openProfileImageViewer(context, photo, ownerId: userInfo.id),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 64, height: 64,
                      child: photo != null && photo.isNotEmpty
                        ? Image.network(photo, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: WebPalette.of(context).softBrand,
                              child: Icon(Icons.person_outline, color: WebPalette.of(context).brandInk)))
                        : ColoredBox(color: WebPalette.of(context).softBrand,
                            child: Icon(Icons.person_outline, color: WebPalette.of(context).brandInk)),
                    ),
                  ),
                )),
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$name님', style: TextStyle(fontSize: 22,
                    fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
                  const SizedBox(height: 6),
                  Text(userInfo.email ?? '로그인 정보를 확인해주세요.',
                    style: TextStyle(fontSize: 14, color: WebPalette.of(context).muted)),
                ])),
                TextButton(
                  onPressed: () => _pickAndSaveProfileImage(context, ref, userInfo),
                  child: const Text('사진 변경'),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(builder: (context, bounds) {
              final columns = bounds.maxWidth >= 900 ? 3 : bounds.maxWidth >= 560 ? 2 : 1;
              final width = (bounds.maxWidth - (columns - 1) * 20) / columns;
              return Wrap(spacing: 20, runSpacing: 20, children: [
                SizedBox(width: width, child: _webMetric('나의 앨범',
                  value(albums, ownAlbums), '개', '내 앨범 보기', _webHome)),
                SizedBox(width: width, child: _webMetric('진행 중인 주문',
                  value(summary, pending), '건', '주문내역 보기', _webOrders)),
                SizedBox(width: width, child: _webMetric('보유 포인트',
                  value(points, points.asData?.value), 'P', '포인트 관리', _openPointCharge)),
              ]);
            }),
            const SizedBox(height: 24),
            WebSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('나의 모음', style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
              const SizedBox(height: 12),
              _webLink('공유된 앨범',
                albums.hasError ? '앨범 목록을 다시 확인해주세요.'
                  : sharedAlbums == null ? '함께 만든 앨범을 확인하고 있습니다.'
                  : '${sharedAlbums.length}개의 함께 만든 앨범',
                Icons.people_outline,
                () => _openSharedAlbums(sharedAlbums ?? const [], userInfo.id)),
              _webLink('내 보관함', '구매한 템플릿과 스티커·프레임·문구·종이',
                Icons.collections_bookmark_outlined, _openLibrary),
              ownedDesigns.when(
                loading: () => Padding(padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('구매한 디자인을 확인하고 있습니다.',
                    style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted))),
                error: (_, __) => Align(alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => ref.invalidate(ownedPointShopKeysProvider),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('구매한 디자인 다시 확인'))),
                data: (keys) => Text(
                  '보유 템플릿 ${keys.where((key) => key.startsWith('template:')).length}종 · 소재 ${keys.where((key) => !key.startsWith('template:')).length}종',
                  style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)),
              ),
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final type in const ['템플릿', '스티커', '프레임', '문구', '종이'])
                  OutlinedButton(onPressed: () => _openLibrary(type), child: Text(type)),
              ]),
            ])),
            const SizedBox(height: 32),
            LayoutBuilder(builder: (context, bounds) {
              final wide = bounds.maxWidth >= 900;
              final settings = WebSurface(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('설정과 도움말', style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
                  const SizedBox(height: 12),
                  _webLink('프로필 및 로그인 정보', '이메일, 로그인 방식과 보안 설정',
                    Icons.person_outline, _openAccountSettings),
                  _webLink('알림 설정', '서비스와 주문 알림 확인',
                    Icons.notifications_none, () => Navigator.push(context,
                      snapFitRoute(page: const NotificationSettingsScreen()))),
                  _webLink('알림함', '앨범 초대·새 댓글·주문 진행 소식',
                    Icons.inbox_outlined, () => Navigator.push(context,
                      snapFitRoute(page: const NotificationScreen(),
                        settings: const WebAppRouteSettings(WebAppLocation.notifications)))),
                  _webLink('고객센터', '서비스 이용 문의와 도움말',
                    Icons.chat_bubble_outline, () => Navigator.push(context,
                      snapFitRoute(page: const SupportInquiryScreen()))),
                  _webLink('이용 안내', '이용약관과 개인정보처리방침',
                    Icons.description_outlined, () => Navigator.push(context,
                      snapFitRoute(page: const TermsPolicyScreen()))),
                  const SizedBox(height: 16),
                  const WebThemeSetting(),
                ],
              ));
              final storage = WebSurface(child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('내 저장 공간', style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.w600, color: WebPalette.of(context).ink)),
                  const SizedBox(height: 24),
                  quota.when(
                    data: (q) => q.userId != userInfo.id
                      ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('계정의 저장 공간을 다시 확인해주세요.',
                            style: TextStyle(fontSize: 14, color: WebPalette.of(context).muted)),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => ref.invalidate(myStorageQuotaProvider),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('저장 공간 다시 확인')),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${(q.usedBytes / 1048576).toStringAsFixed(1)} MB 사용',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                          color: WebPalette.of(context).ink)),
                      const SizedBox(height: 16),
                      ClipRRect(borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: q.hardLimitBytes > 0
                              ? (q.usedBytes / q.hardLimitBytes).clamp(0.0, 1.0).toDouble() : 0,
                          color: WebPalette.of(context).brand, backgroundColor: WebPalette.of(context).canvas,
                          minHeight: 6,
                        )),
                      const SizedBox(height: 12),
                      Text(q.hardLimitBytes > 0
                        ? '전체 ${(q.hardLimitBytes / 1048576).toStringAsFixed(0)} MB'
                        : '계정의 저장 한도를 확인하고 있습니다.',
                        style: TextStyle(color: WebPalette.of(context).muted, fontSize: 13)),
                    ]),
                    loading: () => Text('저장 공간을 확인하고 있습니다.',
                      style: TextStyle(color: WebPalette.of(context).muted)),
                    error: (_, __) => TextButton.icon(
                      onPressed: () => ref.invalidate(myStorageQuotaProvider),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('저장 공간 다시 확인'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('앨범에 사용하는 사진과 편집 내용은 계정에 보관됩니다.',
                    style: TextStyle(fontSize: 13, height: 1.7, color: WebPalette.of(context).muted)),
                ],
              ));
              return wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: settings), const SizedBox(width: 24),
                Expanded(flex: 2, child: storage),
              ]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [settings, const SizedBox(height: 24), storage]);
            }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _webMetric(String label, String value, String unit,
      String action, VoidCallback onTap) => WebSurface(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 13, color: WebPalette.of(context).muted)),
      const SizedBox(height: 18),
      Text.rich(TextSpan(text: value,
        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600, color: WebPalette.of(context).ink),
        children: [TextSpan(text: ' $unit', style: TextStyle(fontSize: 14,
          fontWeight: FontWeight.w400, color: WebPalette.of(context).muted))])),
      const SizedBox(height: 12),
      TextButton(onPressed: onTap, child: Text(action)),
    ]),
  );

  Widget _webLink(String title, String detail, IconData icon, VoidCallback onTap) =>
    InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Icon(icon, size: 21, color: WebPalette.of(context).muted), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
              color: WebPalette.of(context).ink)), const SizedBox(height: 5),
            Text(detail, style: TextStyle(fontSize: 12, color: WebPalette.of(context).muted)),
          ])),
          Icon(Icons.arrow_forward, size: 18, color: WebPalette.of(context).muted),
        ]),
      ),
    );

  Widget _buildProfileHero(
    BuildContext context,
    WidgetRef ref,
    UserInfo? userInfo,
    Color textColor,
    Color subColor,
    AsyncValue<int> pointBalanceAsync, {
    bool compact = false,
  }) {
    final name = userInfo?.name ?? '사용자';
    final profileUrl = userInfo?.profileImageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '프로필 사진 보기',
            child: SnapFitPressable(
              onTap: () => _openProfileImageViewer(context, profileUrl),
              child: CircleAvatar(
                radius: compact ? 20 : 27,
                backgroundColor: SnapFitColors.accentLight,
                child: ClipOval(
                  child: SizedBox(
                    width: compact ? 40 : 54,
                    height: compact ? 40 : 54,
                    child: profileUrl != null && profileUrl.isNotEmpty
                        ? Image.network(
                            profileUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.person_outline, size: 32),
                          )
                        : const Icon(Icons.person_outline, size: 32),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name님',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceStyle.text(
                    compact ? 18 : 22,
                    weight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _displayEmail(userInfo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExperienceStyle.text(12, color: subColor),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '계정 설정',
            onPressed: _openAccountSettings,
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: subColor,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: ExperienceFormStyle.text(
      context,
      12,
      weight: FontWeight.w600,
      secondary: true,
    ),
  );

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
          height: 38,
          color: SnapFitColors.overlayLightOf(context),
        ),
        _statItem('공유된앨범', sharedCount, textColor, subColor),
        Container(
          width: 1,
          height: 38,
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
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
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(6),
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
                MaterialPageRoute(
                  settings: const WebAppRouteSettings(WebAppLocation.orders),
                  builder: (_) => const OrderHistoryScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Text(
                  '나의 주문 현황',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, size: 20, color: subColor),
              ],
            ),
          ),
          SizedBox(height: 10),
          if (summaryAsync.isLoading && !summaryAsync.hasValue)
            Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '주문 현황 동기화 중...',
                    style: TextStyle(
                      fontSize: 12,
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
                  padding: EdgeInsets.only(right: 10),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: SnapFitColors.overlayLightOf(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(s.$1, size: 20, color: textColor),
                          ),
                          if (s.$3 > 0)
                            Positioned(
                              right: -6,
                              top: -6,
                              child: Container(
                                constraints: BoxConstraints(minWidth: 20),
                                height: 20,
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: SnapFitColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  s.$3 > 99 ? '99+' : '${s.$3}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 7),
                      Text(
                        s.$2,
                        style: TextStyle(
                          fontSize: 12,
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
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: SnapFitColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SnapFitColors.overlayLightOf(context)),
      ),
      child: storageQuotaAsync.when(
        skipLoadingOnRefresh: true,
        loading: () => Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text(
              '저장 사용량 확인중...',
              style: TextStyle(
                fontSize: 13,
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
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '사용량을 불러오지 못했어요. 잠시 후 다시 확인해 주세요.',
              style: TextStyle(
                fontSize: 12,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SnapFitStylePalette.gray,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      quota.planCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: SnapFitColors.textSecondaryOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                '$usedText / $limitText',
                style: TextStyle(
                  fontSize: 13,
                  color: subColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: SnapFitColors.overlayLightOf(context),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    SnapFitColors.accent,
                  ),
                ),
              ),
              SizedBox(height: 7),
              Text(
                '용량 초과 시 저장/업로드가 차단됩니다. FREE 1GB · PRO 10GB',
                style: TextStyle(
                  fontSize: 12,
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

  Widget _buildMenuSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _sectionTitle(context, title),
        ...rows,
      ],
    );
  }

  Widget _menuRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool trailingDot,
    required VoidCallback onTap,
  }) => ExperienceRow(
    themeAware: true,
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onTap,
  );

  void _showThemeBottomSheet(
    BuildContext context,
    WidgetRef ref,
    ThemeMode themeMode,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520),
      useSafeArea: true,
      backgroundColor: SnapFitColors.surfaceOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
        ),
        child: ThemeSettingsSheet(
          selected: themeMode,
          onSelected: (mode) {
            if (!context.mounted ||
                !sheetContext.mounted ||
                ModalRoute.of(sheetContext)?.isCurrent == false)
              return;
            final controller = ref.read(themeModeControllerProvider.notifier);
            if (mode == ThemeMode.dark) {
              controller.setDark();
            } else {
              controller.setLight();
            }
            Navigator.pop(sheetContext);
          },
        ),
      ),
    );
  }

  /// 앱 내 갤러리에서 사진 선택 → 업로드 → 서버 프로필 저장
  static Future<void> _pickAndSaveProfileImage(
    BuildContext context,
    WidgetRef ref,
    UserInfo userInfo,
  ) async {
    final userId = userInfo.id;
    if (userId.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인 후 이용해 주세요.')));
      }
      return;
    }

    if (!kIsWeb) {
      final gallery = ref.read(galleryProvider);
      if (gallery.albums.isEmpty) {
        await ref.read(galleryProvider.notifier).fetchInitialData();
      }
    }
    if (!context.mounted) return;

    final asset = await showPhotoSelectionSheet(context, ref);
    if (!context.mounted || asset == null) return;

    if (ref.read(authViewModelProvider).asData?.value?.id != userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 계정이 변경되었어요. 다시 선택해 주세요.')),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('프로필 사진 업로드 중...')));

      final auth = ref.read(authViewModelProvider.notifier);
      if (asset is BrowserPhotoAsset) {
        if (asset.ownerId != userId) {
          throw Exception('로그인 계정이 변경되었어요. 사진을 다시 선택해주세요.');
        }
        // A profile uses the browser's 1600px JPEG preview; album uploads and
        // printing retain the separate, unchanged originalBytes.
        await auth.updateProfileImageBytes(
          asset.previewBytes,
          fileName: 'profile.jpg',
        );
      } else {
        final file = await asset.file;
        if (!context.mounted) return;
        if (file == null) {
          throw Exception('사진 파일을 불러올 수 없습니다.');
        }
        if (ref.read(authViewModelProvider).asData?.value?.id != userId) {
          throw Exception('로그인 계정이 변경되었어요. 사진을 다시 선택해주세요.');
        }
        await auth.updateProfileImage(file);
      }

      if (context.mounted &&
          ref.read(authViewModelProvider).asData?.value?.id == userId) {
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

  static void _openProfileImageViewer(
    BuildContext context,
    String? profileUrl, {
    String? ownerId,
  }) {
    final trimmed = profileUrl?.trim() ?? '';
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('등록된 프로필 사진이 없습니다.')));
      return;
    }

    if (kIsWeb) {
      if (ownerId == null) return;
      showWebAwareDialog<void>(context: context, maxWidth: 800, maxHeight: 760,
        builder: (_) => _WebProfileImageViewer(imageUrl: trimmed, ownerId: ownerId));
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _ProfileImageViewer(imageUrl: trimmed),
      ),
    );
  }
}

class _WebProfileImageViewer extends ConsumerWidget {
  const _WebProfileImageViewer({required this.imageUrl, required this.ownerId});
  final String imageUrl, ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerCurrent = ref.watch(visibleOrderOwnerProvider) == ownerId;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.fromLTRB(24, 16, 12, 16),
        child: Row(children: [
          Expanded(child: Text('프로필 사진', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w600, color: WebPalette.of(context).ink))),
          IconButton(onPressed: () => Navigator.maybePop(context),
            tooltip: '사진 닫기', icon: const Icon(Icons.close)),
        ])),
      const Divider(height: 1),
      Expanded(child: ownerCurrent
        ? InteractiveViewer(minScale: 1, maxScale: 4,
            child: Center(child: Image.network(imageUrl, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('프로필 사진을 불러오지 못했어요.'))))
        : const Center(child: Text('로그인 계정이 변경되었어요. 이 창을 닫아주세요.'))),
    ]);
  }
}

class _ProfileImageViewer extends StatelessWidget {
  const _ProfileImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.94),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_circle,
                      color: Colors.white54,
                      size: 120,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
