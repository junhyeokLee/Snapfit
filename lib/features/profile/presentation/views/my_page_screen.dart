import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/env.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/utils/app_error_mapper.dart';
import '../../../../core/utils/context_extensions.dart';
import '../../../../core/utils/screen_logger.dart';
import '../../../../shared/web/web_design.dart';
import '../../../../shared/widgets/album_bottom_sheet.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_icon.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../shared/widgets/snapfit_motion.dart';
import '../../../album/data/gallery/browser_photo_asset.dart';
import '../../../album/presentation/providers/home_ui_state_provider.dart';
import '../../../album/presentation/viewmodels/gallery_notifier.dart';
import '../../../auth/data/dto/auth_response.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../auth/presentation/views/auth_gate.dart';
import '../../../home_news/data/admin_home_news_repository.dart';
import '../../../home_news/presentation/views/admin_home_news_screen.dart';
import '../../../onboarding/presentation/app_introduction_screen.dart';
import '../../../onboarding/presentation/first_visit_controller.dart';
import '../widgets/theme_settings_sheet.dart';
import 'account_settings_screen.dart';
import 'admin_order_management_screen.dart';
import 'admin_point_shop_management_screen.dart';
import 'admin_template_management_screen.dart';
import 'notification_settings_screen.dart';
import 'support_inquiry_screen.dart';
import 'terms_policy_screen.dart';

/// The settings destination retains its existing route and class name.
/// Personal collections, wallet and orders live on the owner's profile.
class MyPageScreen extends ConsumerStatefulWidget {
  const MyPageScreen({super.key});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  static bool _logged = false;

  Future<void> _openUsageGuide() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          primary: false,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  '앱 사용 가이드',
                  style: ExperienceFormStyle.text(
                    context,
                    20,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const ExperienceIcon('BookOpen'),
                title: const Text('앱 소개 다시 보기'),
                subtitle: const Text('사진으로 시작하는 나만의 앨범'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, 'introduction'),
              ),
              ListTile(
                leading: const ExperienceIcon('Plus'),
                title: const Text('메인 안내 다시 보기'),
                subtitle: const Text('새 앨범을 시작하는 방법'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, 'home'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'introduction') {
      await Navigator.of(
        context,
      ).push<void>(snapFitRoute(page: const AppIntroductionScreen()));
    } else {
      await ref.read(firstVisitProvider.future);
      if (!mounted) return;
      ref.read(firstVisitProvider.notifier).requestHomeGuide();
      final scope = ExperienceNavigationScope.maybeOf(context);
      if (scope != null) {
        scope.onNavigate(0);
      } else {
        // Settings can be pushed from the public-profile destination, outside
        // the home body's inherited navigation scope. Return to albums before
        // revealing the requested guide on the root route.
        ref.read(homeUiStateProvider.notifier).setBottomNavIndex(0);
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
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
      ScreenLogger.enter('MyPageScreen', '설정 · 계정 · 화면 · 알림 · 도움말');
    }
    final themeMode = ref.watch(themeModeControllerProvider);
    final adminOrders = Env.orderAdminKey.trim().isNotEmpty;
    final adminShop = ref.watch(pointShopAdminAccessProvider);
    final adminNews = ref.watch(adminHomeNewsAccessProvider);
    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, '설정 및 도움말'),
        Tooltip(
          message: '계정 설정',
          child: _accountRow(
            icon: 'Settings2',
            title: '계정 설정',
            subtitle: '로그인 정보 · 보안 · 로그아웃',
            onTap: _openAccountSettings,
          ),
        ),
        _accountRow(
          icon: 'Shapes',
          title: '화면 테마',
          subtitle: switch (themeMode) {
            ThemeMode.dark => '다크',
            ThemeMode.light => '라이트',
            ThemeMode.system => '시스템 설정',
          },
          onTap: () => _showThemeBottomSheet(context, ref, themeMode),
        ),
        _accountRow(
          icon: 'Bell',
          title: '알림 설정',
          onTap: () => _open(const NotificationSettingsScreen()),
        ),
        _accountRow(
          icon: 'MessageCircle',
          title: '고객센터',
          onTap: () => _open(const SupportInquiryScreen()),
        ),
        _accountRow(
          icon: 'BookOpen',
          title: '앱 사용 가이드',
          subtitle: '앱 소개 · 메인 안내 다시 보기',
          onTap: _openUsageGuide,
        ),
        _accountRow(
          icon: 'BookOpen',
          title: '이용 안내',
          subtitle: '이용약관 · 개인정보처리방침',
          onTap: () => _open(const TermsPolicyScreen()),
        ),
        if (adminShop || adminOrders || adminNews) ...[
          const SizedBox(height: 24),
          Divider(color: ExperienceFormStyle.line(context)),
          const SizedBox(height: 20),
          _sectionTitle(context, '관리자'),
          if (adminNews)
            _accountRow(
              icon: 'Bell',
              title: '새 소식 운영',
              subtitle: '이벤트 켜기·끄기 · 기간 · 노출 순서',
              onTap: () => _open(const AdminHomeNewsScreen()),
            ),
          if (adminShop)
            _accountRow(
              icon: 'Shapes',
              title: '상품 가격 관리',
              subtitle: '템플릿 · 소재의 판매 가격',
              onTap: () => _open(const AdminPointShopManagementScreen()),
            ),
          if (adminOrders) ...[
            _accountRow(
              icon: 'BookOpen',
              title: '주문 관리',
              subtitle: '제작 · 배송 주문 상태 처리',
              onTap: () => _open(const AdminOrderManagementScreen()),
            ),
            _accountRow(
              icon: 'LayoutGrid',
              title: '템플릿 관리',
              onTap: () => _open(const AdminTemplateManagementScreen()),
            ),
          ],
        ],
        const SizedBox(height: 32),
        Center(
          child: Text(
            'SnapFit',
            style: ExperienceFormStyle.text(context, 11, secondary: true),
          ),
        ),
      ],
    );
    if (kIsWeb) {
      return SnapFitWebShell(
        section: WebSection.account,
        child: SingleChildScrollView(
          key: const PageStorageKey('profile-menu-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WebPageHeading(
                title: '설정',
                description: '계정과 화면, 알림을 설정하고 도움말을 확인하세요.',
                trailing: Navigator.of(context).canPop()
                    ? OutlinedButton.icon(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('이전'),
                      )
                    : null,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: WebSurface(child: settings),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: SnapFitColors.backgroundOf(context),
      appBar: ExperienceHeader(
        title: '설정',
        showDivider: false,
        showNotifications: false,
        themeAware: true,
        back: Navigator.of(context).canPop(),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, bounds) => ListView(
            key: const PageStorageKey('profile-menu-scroll'),
            padding: EdgeInsets.symmetric(
              horizontal: ((bounds.maxWidth - 680) / 2).clamp(
                20,
                double.infinity,
              ),
              vertical: 20,
            ),
            children: [settings],
          ),
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push<void>(snapFitRoute(page: page));
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      title,
      style: ExperienceFormStyle.text(
        context,
        11,
        weight: FontWeight.w700,
        secondary: true,
      ).copyWith(letterSpacing: 0.6),
    ),
  );

  Widget _accountRow({
    required String icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ExperienceFormStyle.surface(context),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: ExperienceIcon(
                  icon,
                  size: 19,
                  color: ExperienceFormStyle.ink(context),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: ExperienceFormStyle.text(
                        context,
                        12,
                        secondary: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ExperienceIcon(
              'ChevronRight',
              size: 17,
              color: ExperienceFormStyle.muted(context),
            ),
          ],
        ),
      ),
    ),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SnapFitRadius.lg),
        ),
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
      if (context.mounted) context.showSnack('로그인 후 이용해 주세요.');
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
      context.showSnack('로그인 계정이 변경되었어요. 다시 선택해 주세요.');
      return;
    }

    try {
      context.showSnack('프로필 사진 업로드 중...');

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
        context.showSnack('프로필 사진이 저장되었습니다.');
      }
    } catch (e) {
      if (context.mounted) {
        context.showErrorSnack('저장 실패: ${AppErrorMapper.toUserMessage(e)}');
      }
    }
  }
}
