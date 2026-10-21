import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/snapfit_colors.dart';
import '../../../../core/theme/snapfit_design_tokens.dart';
import '../../../../shared/widgets/experience_form_style.dart';
import '../../../../shared/widgets/experience_style.dart';
import '../../../../core/notifications/fcm_notification_service.dart';
import '../../../../core/notifications/browser_push_state.dart';
import '../../../../shared/web/web_design.dart';
import '../widgets/customer_web_page.dart';
import '../../domain/order_visibility_owner.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _loadFailed = false;
  bool _requestingPermission = false;
  BrowserPushState? _browserPush;
  bool _browserBusy = false;
  int _loadEpoch = 0;
  String? _settingsOwnerId;
  String? _webOwnerId;
  bool get _webOwnerCurrent =>
      _webOwnerId != null && ref.read(visibleOrderOwnerProvider) == _webOwnerId;

  bool all = true;
  bool order = true;
  bool invite = true;
  bool comment = true;
  bool marketing = false;
  bool newTemplate = true;
  bool nightMute = false;
  bool permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    if (kIsWeb) {
      final owner = ref.read(visibleOrderOwnerProvider);
      if (owner == null) return;
      _webOwnerId ??= owner;
      if (!_webOwnerCurrent) return;
    }
    try {
      final settings = await FcmNotificationService.loadSettings();
      final browserPush = kIsWeb
          ? await FcmNotificationService.loadBrowserPushState()
          : null;
      if (!mounted || epoch != _loadEpoch) return;
      if (kIsWeb && !_webOwnerCurrent) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
        return;
      }
      setState(() {
        all = settings.all;
        order = settings.order;
        invite = settings.invite;
        comment = settings.comment;
        marketing = settings.marketing;
        newTemplate = settings.newTemplate;
        nightMute = settings.nightMute;
        permissionGranted = settings.permissionGranted;
        _settingsOwnerId = settings.ownerId;
        _browserPush = browserPush;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted && epoch == _loadEpoch)
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    if (kIsWeb && !_webOwnerCurrent) return;
    _loadEpoch++;
    setState(() {
      switch (key) {
        case FcmNotificationService.kAll:
          all = value;
          break;
        case FcmNotificationService.kOrder:
          order = value;
          break;
        case FcmNotificationService.kInvite:
          invite = value;
          break;
        case FcmNotificationService.kComment:
          comment = value;
          break;
        case FcmNotificationService.kMarketing:
          marketing = value;
          break;
        case FcmNotificationService.kNewTemplate:
          newTemplate = value;
          break;
        case FcmNotificationService.kNightMute:
          nightMute = value;
          break;
      }
    });
    try {
      await FcmNotificationService.updateSettings(
        all: all,
        order: order,
        invite: invite,
        comment: comment,
        marketing: marketing,
        newTemplate: newTemplate,
        nightMute: nightMute,
        expectedOwnerId: _settingsOwnerId,
      );
    } catch (error) {
      if (!mounted || (kIsWeb && !_webOwnerCurrent)) return;
      if (error is StateError &&
          error.message == 'notification_settings_owner_changed') {
        setState(() => _loadFailed = true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('설정은 저장했지만 서버 연결이 지연되고 있어요. 연결되면 다시 적용합니다.'),
        ),
      );
    }
  }

  Future<void> _requestPermission() async {
    if (_requestingPermission) return;
    setState(() => _requestingPermission = true);
    try {
      final granted = await FcmNotificationService.requestPermission();
      if (mounted) setState(() => permissionGranted = granted);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기기 알림 설정을 열지 못했어요. 다시 시도해 주세요.')),
      );
    } finally {
      if (mounted) setState(() => _requestingPermission = false);
    }
  }

  Future<void> _changeBrowserPush({required bool enable}) async {
    if (_browserBusy || !_webOwnerCurrent) return;
    setState(() => _browserBusy = true);
    try {
      // The service requests browser permission as its first async operation,
      // preserving the click gesture; it never prompts on page load.
      final result = await (enable
          ? FcmNotificationService.enableBrowserPush()
          : FcmNotificationService.disableBrowserPush());
      if (!mounted || !_webOwnerCurrent) return;
      setState(() {
        _browserPush = result;
        permissionGranted = result.environment.permission == 'granted';
      });
      if (enable && !result.active) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('브라우저 알림 연결을 완료하지 못했어요. 권한과 연결 상태를 확인해주세요.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted || !_webOwnerCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('브라우저 알림 연결 상태를 변경하지 못했어요. 다시 확인해주세요.')),
      );
      // Reload real state; never turn a failed registration into a success.
      try {
        final result = await FcmNotificationService.loadBrowserPushState();
        if (mounted && _webOwnerCurrent) setState(() => _browserPush = result);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _browserBusy = false);
    }
  }

  Future<void> _refreshBrowserPush() async {
    if (_browserBusy || !_webOwnerCurrent) return;
    setState(() => _browserBusy = true);
    try {
      await FcmNotificationService.syncSession();
      final result = await FcmNotificationService.loadBrowserPushState();
      if (mounted && _webOwnerCurrent) setState(() => _browserPush = result);
    } catch (_) {
      if (mounted && _webOwnerCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('브라우저 연결 상태를 확인하지 못했어요. 잠시 후 다시 시도해주세요.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _browserBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => kIsWeb
      ? _webSettingsPage()
      : Scaffold(
          backgroundColor: SnapFitColors.backgroundOf(context),
          appBar: const ExperienceHeader(
            title: '알림 설정',
            themeAware: true,
            showNotifications: false,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadFailed
              ? SafeArea(
                  top: false,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '알림 설정을 불러오지 못했어요.',
                            style: ExperienceFormStyle.text(context, 15),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _loading = true);
                              _load();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : NotificationSettingsContent(
                  settings: NotificationSettingsState(
                    all: all,
                    order: order,
                    invite: invite,
                    comment: comment,
                    marketing: marketing,
                    newTemplate: newTemplate,
                    nightMute: nightMute,
                    permissionGranted: permissionGranted,
                  ),
                  onToggle: _toggle,
                  onRequestPermission: _requestingPermission
                      ? null
                      : _requestPermission,
                ),
        );

  Widget _webSettingsPage() {
    final owner = ref.watch(visibleOrderOwnerProvider);
    if (owner != null && _webOwnerId == null) {
      _webOwnerId = owner;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _webOwnerCurrent) _load();
      });
    }
    if (owner == null || owner != _webOwnerId) {
      return const CustomerWebPage(
        title: '알림 설정',
        eyebrow: 'NOTIFICATIONS',
        child: Center(child: Text('로그인 계정을 확인하고 알림 설정을 다시 열어주세요.')),
      );
    }
    return CustomerWebPage(
      title: '알림 설정',
      description: '앨범·주문 소식과 브라우저 알림을 설정하세요.',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('계정의 알림 설정을 불러오지 못했어요.'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() => _loading = true);
                      _load();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('설정 다시 확인'),
                  ),
                ],
              ),
            )
          : NotificationSettingsContent(
              settings: NotificationSettingsState(
                all: all,
                order: order,
                invite: invite,
                comment: comment,
                marketing: marketing,
                newTemplate: newTemplate,
                nightMute: nightMute,
                permissionGranted: permissionGranted,
              ),
              onToggle: _toggle,
              onRequestPermission: null,
              browserPush: _browserPush,
              browserBusy: _browserBusy,
              onEnableBrowser: () => _changeBrowserPush(enable: true),
              onDisableBrowser: () => _changeBrowserPush(enable: false),
              onRefreshBrowser: _refreshBrowserPush,
            ),
    );
  }
}

class NotificationSettingsContent extends StatelessWidget {
  const NotificationSettingsContent({
    super.key,
    required this.settings,
    required this.onToggle,
    required this.onRequestPermission,
    this.browserPush,
    this.browserBusy = false,
    this.onEnableBrowser,
    this.onDisableBrowser,
    this.onRefreshBrowser,
  });
  final NotificationSettingsState settings;
  final void Function(String key, bool value) onToggle;
  final VoidCallback? onRequestPermission;
  final BrowserPushState? browserPush;
  final bool browserBusy;
  final VoidCallback? onEnableBrowser, onDisableBrowser, onRefreshBrowser;

  @override
  Widget build(BuildContext context) => kIsWeb
      ? SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, bounds) {
              final overview = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _heading(context, '알림 수신'),
                  _master(context),
                  const SizedBox(height: 24),
                  _browserPanel(context),
                ],
              );
              final categories = _categories(context, compact: false);
              return bounds.maxWidth >= 860
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 300, child: overview),
                        const SizedBox(width: 48),
                        Expanded(child: categories),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        overview,
                        const SizedBox(height: 32),
                        categories,
                      ],
                    );
            },
          ),
        )
      : SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 540 &&
                  MediaQuery.orientationOf(context) == Orientation.landscape;
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1040 : 640),
                  child: wide
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: (constraints.maxWidth * .35).clamp(
                                  180,
                                  300,
                                ),
                                child: SingleChildScrollView(
                                  key: const PageStorageKey(
                                    'notification-summary',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: _overview(context, compact: true),
                                ),
                              ),
                              const SizedBox(width: 20),
                              VerticalDivider(
                                width: 1,
                                color: ExperienceFormStyle.line(context),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: ListView(
                                  key: const PageStorageKey(
                                    'notification-preferences',
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  children: [
                                    _categories(context, compact: true),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          key: const PageStorageKey('notification-preferences'),
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          children: [
                            _overview(context, compact: false),
                            const SizedBox(height: 28),
                            _categories(context, compact: false),
                          ],
                        ),
                ),
              );
            },
          ),
        );

  Widget _browserPanel(BuildContext context) {
    final palette = WebPalette.of(context);
    final state = browserPush;
    final environment = state?.environment;
    final active = state?.active == true;
    return WebSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            active ? Icons.notifications_active_outlined : Icons.web_outlined,
            size: 26,
            color: palette.brandInk,
          ),
          const SizedBox(height: 16),
          Text(
            '이 브라우저 알림',
            style: TextStyle(
              color: palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            active
                ? '현재 계정에 연결되어 있어요'
                : state?.enabled == true
                ? '연결 상태를 다시 확인해주세요'
                : '아직 연결하지 않았어요',
            style: TextStyle(
              color: active ? palette.brandInk : palette.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            environment?.message ?? '브라우저 알림 지원 여부를 확인하고 있어요.',
            style: TextStyle(color: palette.muted, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 18),
          if (active || state?.enabled == true)
            OutlinedButton.icon(
              onPressed: browserBusy ? null : onDisableBrowser,
              icon: const Icon(Icons.notifications_off_outlined, size: 18),
              label: const Text('이 브라우저 연결 끄기'),
            ),
          if (!active && environment?.canEnable == true) ...[
            if (state?.enabled == true) const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: browserBusy ? null : onEnableBrowser,
              style: FilledButton.styleFrom(
                backgroundColor: palette.brand,
                foregroundColor: palette.onBrand,
              ),
              icon: const Icon(Icons.notifications_none, size: 18),
              label: Text(state?.enabled == true ? '브라우저 다시 연결' : '브라우저 알림 켜기'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: browserBusy ? null : onRefreshBrowser,
            icon: browserBusy
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.brandInk,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            style: TextButton.styleFrom(foregroundColor: palette.brandInk),
            label: Text(browserBusy ? '연결 확인 중' : '연결 상태 새로 확인'),
          ),
          const SizedBox(height: 14),
          Text(
            '계정별 수신 설정과 이 브라우저의 연결은 별도로 관리돼요. 로그아웃하면 브라우저 연결이 해제됩니다. 브라우저를 완전히 종료하거나 운영체제에서 알림을 차단하면 수신되지 않을 수 있어요.',
            style: TextStyle(color: palette.muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 8),
          Text(
            '알림함에서는 브라우저 권한과 관계없이 새 소식을 확인할 수 있어요.',
            style: TextStyle(color: palette.muted, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _overview(BuildContext context, {required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (compact) ...[
        _heading(context, '알림 수신'),
        _master(context),
        const SizedBox(height: 16),
      ] else ...[
        Text(
          '받고 싶은 소식만',
          style: ExperienceFormStyle.text(context, 24, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '앨범과 주문 소식을 내 생활에 맞춰 받아요.',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
        const SizedBox(height: 24),
      ],
      if (!settings.permissionGranted) ...[
        _permissionNotice(context),
        const SizedBox(height: 16),
      ] else if (compact)
        Text(
          '기기 알림이 켜져 있어요',
          style: ExperienceFormStyle.text(context, 13, secondary: true),
        ),
      if (!compact) _master(context),
    ],
  );

  Widget _permissionNotice(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ExperienceFormStyle.surface(context),
      borderRadius: BorderRadius.circular(SnapFitRadius.lg),
      border: Border.all(color: ExperienceFormStyle.line(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 20,
              color: ExperienceFormStyle.muted(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '기기 알림이 꺼져 있어요',
                style: ExperienceFormStyle.text(
                  context,
                  14,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '알림을 받으려면 기기 권한도 켜 주세요.',
          style: ExperienceFormStyle.text(context, 12, secondary: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('notification-permission-action'),
          onPressed: onRequestPermission,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            foregroundColor: ExperienceFormStyle.ink(context),
            shape: const StadiumBorder(),
          ),
          child: const Text('기기 알림 설정'),
        ),
      ],
    ),
  );

  Widget _master(BuildContext context) => _setting(
    context,
    '전체 알림',
    settings.all,
    FcmNotificationService.kAll,
    subtitle: settings.all ? '선택한 소식을 받아요' : '개별 설정은 그대로 보관돼요',
    master: true,
  );

  Widget _categories(BuildContext context, {required bool compact}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(context, '앨범과 주문'),
      _setting(
        context,
        '앨범 초대와 참여',
        settings.invite,
        FcmNotificationService.kInvite,
      ),
      _setting(
        context,
        '새 댓글',
        settings.comment,
        FcmNotificationService.kComment,
      ),
      _setting(
        context,
        '구매와 주문 소식',
        settings.order,
        FcmNotificationService.kOrder,
      ),
      SizedBox(height: compact ? 20 : 28),
      _heading(context, '스토어 소식'),
      _setting(
        context,
        '새로운 컬렉션',
        settings.newTemplate,
        FcmNotificationService.kNewTemplate,
      ),
      _setting(
        context,
        '혜택과 이벤트',
        settings.marketing,
        FcmNotificationService.kMarketing,
        subtitle: '마케팅 알림 · 선택',
      ),
      SizedBox(height: compact ? 20 : 28),
      _heading(context, '방해받지 않는 시간'),
      _setting(
        context,
        '야간 알림 끄기',
        settings.nightMute,
        FcmNotificationService.kNightMute,
        subtitle: '오후 10시부터 오전 8시까지',
      ),
    ],
  );

  Widget _heading(BuildContext context, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      value,
      style: ExperienceFormStyle.text(
        context,
        12,
        weight: FontWeight.w600,
        secondary: true,
      ),
    ),
  );

  Widget _setting(
    BuildContext context,
    String title,
    bool value,
    String key, {
    String? subtitle,
    bool master = false,
  }) {
    final enabled = master || settings.all;
    return Container(
      key: ValueKey('notification-setting-$key'),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ExperienceFormStyle.line(context)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ExperienceFormStyle.text(
                    context,
                    14,
                    secondary: !enabled,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
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
          const SizedBox(width: 12),
          Semantics(
            label: title,
            child: Switch.adaptive(
              value: value,
              activeTrackColor: kIsWeb
                  ? WebPalette.of(context).brand
                  : ExperienceStyle.accent,
              onChanged: enabled ? (v) => onToggle(key, v) : null,
            ),
          ),
        ],
      ),
    );
  }
}
