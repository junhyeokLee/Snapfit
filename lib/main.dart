import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'core/notifications/fcm_notification_service.dart';
import 'core/navigation/app_root_route_observer.dart';
import 'core/navigation/notification_content_navigation.dart';
import 'core/navigation/web_app_location.dart';
import 'core/navigation/web_app_router.dart';
import 'core/navigation/web_navigation_return_store.dart';
import 'core/templates/template_update_notification_service.dart';
import 'core/theme/snapfit_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/frame_timing_monitor.dart';
import 'features/album/presentation/views/add_cover_screen.dart';
import 'features/album/presentation/views/album_create_flow_screen.dart';
import 'features/album/presentation/web/web_album_library_screen.dart';
import 'features/album/presentation/views/page_editor_screen.dart';
import 'features/album/presentation/views/print_order_preview_screen.dart';
import 'features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'features/album/presentation/viewmodels/home_view_model.dart';
import 'features/album/service/pending_album_invite.dart';
import 'features/album/data/api/album_provider.dart';
import 'features/album/data/album_creation_draft_store.dart';
import 'features/album/domain/entities/album.dart';
import 'features/album/presentation/widgets/home/home_album_actions.dart';
import 'features/billing/data/billing_provider.dart';
import 'features/billing/data/point_purchase_service.dart';
import 'features/notification/presentation/providers/notification_provider.dart';
import 'features/notification/presentation/views/notification_screen.dart';
import 'features/store/data/api/template_provider.dart';
import 'features/store/presentation/views/template_detail_screen.dart';
import 'features/store/presentation/views/store_hub_screen.dart';
import 'features/store/presentation/views/material_catalog_screen.dart';
import 'features/store/presentation/views/public_discovery_screen.dart';
import 'features/album/data/bundled_creation_templates.dart';
import 'features/auth/presentation/viewmodels/auth_view_model.dart';
import 'features/auth/presentation/views/auth_gate.dart';
import 'features/auth/presentation/views/login_screen.dart';
import 'features/auth/domain/web_oauth.dart';
import 'features/profile/domain/order_deep_link.dart';
import 'features/profile/domain/order_detail_navigation.dart';
import 'features/profile/domain/order_visibility_owner.dart';
import 'features/profile/data/print_payment_service.dart';
import 'features/profile/data/order_repository.dart';
import 'features/album/presentation/views/print_order_complete_screen.dart';
import 'features/profile/presentation/views/order_history_screen.dart';
import 'features/profile/presentation/views/my_page_screen.dart';
import 'features/commerce/presentation/public_commerce_screen.dart';
import 'core/commerce/commerce_policy.dart';
import 'features/splash/presentation/views/splash_screen.dart';
import 'firebase_options.dart';
import 'shared/web/web_design.dart';
import 'shared/web/web_theme_controller.dart';
import 'shared/web/web_document_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  AppLogger.debug('[FCM] background message: ${message.messageId}');
}

Future<void> _initializeAppSupabase() async {
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      detectSessionInUriPredicate: kIsWeb
          ? (uri) => isTrustedAuthCallback(
              uri,
              current: Uri.base,
              configured: Env.authWebRedirectUrl,
            )
          : null,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FrameTimingMonitor.start();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  // Keep the Android status bar visible but hide the bottom system
  // navigation bar by default so it does not cover Snapfit's UI.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeAppSupabase();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb && Env.kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }

  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true, // 글자 크기 자동 조정
        splitScreenMode: true, // 분할 화면 대응 (Fold,ㄹ Split 등)
        enableScaleWH: () => !kIsWeb,
        enableScaleText: () => !kIsWeb,
        builder: (context, child) {
          return const MoaEditorApp();
        },
      ),
    ),
  );
}

class MoaEditorApp extends ConsumerStatefulWidget {
  const MoaEditorApp({super.key});

  @override
  ConsumerState<MoaEditorApp> createState() => _MoaEditorAppState();
}

class _MoaEditorAppState extends ConsumerState<MoaEditorApp>
    with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<AuthState>? _authSub;
  PointPurchaseService? _pointPurchases;
  final _orderDetailNavigation = OrderDetailNavigation();
  final _notificationContentNavigation = NotificationContentNavigation();
  bool _notificationContentScheduled = false, _notificationContentBusy = false;
  late final AppRootRouteObserver _appRootRouteObserver;
  bool _appRootInstalled = false;
  bool _orderDetailNavigationScheduled = false;
  String? _printRecoveryOwner;
  bool _printRecoveryNoticeShown = false;
  WebAppRouter? _webRouter;
  WebAppLocation? _pendingWebLocation;
  WebAppLocation? _openingWebLocation;
  String? _pendingWebOwner;
  int _webNavigationRevision = 0;
  bool _webNavigationScheduled = false;
  bool _webNavigationBusy = false;
  static const _webReturnKey = 'snapfit_web_navigation_return_v1';
  late final _webReturnStore = WebNavigationReturnStore(
    read: () async =>
        (await SharedPreferences.getInstance()).getString(_webReturnKey),
    write: (value) async {
      await (await SharedPreferences.getInstance()).setString(
        _webReturnKey,
        value,
      );
    },
    remove: () async {
      await (await SharedPreferences.getInstance()).remove(_webReturnKey);
    },
  );

  @override
  void initState() {
    super.initState();
    _appRootRouteObserver = AppRootRouteObserver(onReady: _onAppRootReady);
    if (kIsWeb) {
      _webRouter = WebAppRouter(
        navigatorKey: _navigatorKey,
        observers: [_appRootRouteObserver],
        routeBuilder: (settings) => settings.name == '/add_cover'
            ? MaterialPageRoute<void>(
                settings: const WebAppRouteSettings(WebAppLocation.create),
                builder: (_) => const AlbumCreateFlowScreen(),
              )
            : MaterialPageRoute<void>(
                settings: const AppRootRouteSettings(),
                builder: (_) => const AuthGate(),
              ),
        onLocationRequested: _receiveWebLocation,
      );
    }
    _printRecoveryOwner = Supabase.instance.client.auth.currentUser?.id;
    _notificationContentNavigation.observeOwner(_printRecoveryOwner);
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      final purchases = ref.read(pointPurchaseServiceProvider);
      purchases.start();
      _pointPurchases = purchases;
    }
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) {
        ref
            .read(orderSessionOwnerProvider.notifier)
            .observe(event.session?.user.id);
        ref.invalidate(myPointBalanceProvider);
        ref.invalidate(myPointLedgerProvider);
        ref.invalidate(notificationInboxProvider);
        ref.invalidate(notificationUnreadCountProvider);
        ref.invalidate(myOrderHistoryProvider);
        ref.invalidate(myOrderSummaryProvider);
        ref.invalidate(myOrderStatusBadgesProvider);
        final owner = event.session?.user.id;
        _notificationContentNavigation.observeOwner(owner);
        if (_printRecoveryOwner != owner) {
          final previousOwner = _printRecoveryOwner;
          _printRecoveryOwner = owner;
          _printRecoveryNoticeShown = false;
          if (kIsWeb) ref.invalidate(homeViewModelProvider);
          if (previousOwner != null) {
            final requestedLocation =
                _pendingWebLocation ?? _openingWebLocation;
            _webNavigationRevision++;
            _pendingWebLocation = null;
            _pendingWebOwner = null;
            if (kIsWeb) unawaited(_clearWebReturn());
            // A route can contain a previous customer's delivery/payment data.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (kIsWeb) {
                  _webRouter?.resetForSessionChange(
                    pendingLocation: requestedLocation,
                  );
                } else {
                  _navigatorKey.currentState?.popUntil(
                    (route) => route.isFirst,
                  );
                }
              }
            });
            WidgetsBinding.instance.ensureVisualUpdate();
          }
        }
        if (event.session != null) unawaited(_pointPurchases?.recover());
        if (event.session != null) unawaited(_recoverPrintPayment());
        if (event.session != null) _scheduleOrderDetailOpen();
        if (event.session != null) _scheduleNotificationContentOpen();
        if (kIsWeb && event.event != AuthChangeEvent.initialSession) {
          unawaited(_synchronizeWebAuth(event.event));
        }
      },
      onError: (Object error) {
        if (!kIsWeb || !mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            _messengerKey.currentState?.showSnackBar(
              SnackBar(content: Text(socialAuthErrorMessage(error))),
            );
        });
        WidgetsBinding.instance.ensureVisualUpdate();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(orderSessionOwnerProvider.notifier)
          .observe(Supabase.instance.client.auth.currentUser?.id);
      unawaited(
        FcmNotificationService.initialize(onNotificationTap: _openNotification),
      );
      unawaited(_pointPurchases?.recover());
      unawaited(_recoverPrintPayment());
      if (kIsWeb) {
        unawaited(ref.read(webThemeModeProvider.notifier).loadFromStorage());
      } else {
        ref.read(themeModeControllerProvider.notifier).loadFromStorage();
      }
      TemplateUpdateNotificationService.checkAndNotifyIfUpdated();
      _initDeepLinkListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _authSub?.cancel();
    _webRouter?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleNotificationContentOpen();
      unawaited(_pointPurchases?.recover());
      unawaited(_recoverPrintPayment());
    }
  }

  Future<void> _initDeepLinkListener() async {
    if (kIsWeb) {
      if (isPrintPaymentReturn(Uri.base)) {
        unawaited(_recoverPrintPayment());
      }
      // Supabase exchanges browser auth callbacks exactly once. Native
      // app_links must not exchange the same PKCE code a second time.
      return;
    }
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        unawaited(_handleIncomingUri(initial));
      }
    } catch (_) {
      // ignore: 초기 링크 실패 시 스트림 이벤트로 후속 처리
    }

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_handleIncomingUri(uri));
    });
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    if (isPrintPaymentReturn(uri)) {
      await _recoverPrintPayment();
      return;
    }
    if (uri.scheme.toLowerCase() != 'snapfit') {
      return;
    }

    if (uri.host.toLowerCase() == 'auth') {
      await _handleAuthCallback(uri);
      return;
    }

    if (uri.host.toLowerCase() == 'invite') {
      final received = ref
          .read(pendingAlbumInviteProvider.notifier)
          .receive(uri);
      if (received) {
        _notificationContentNavigation.cancel();
        _orderDetailNavigation.cancel();
      }
      if (!received) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('올바르지 않은 초대 링크예요. 새 링크를 요청해 주세요.')),
        );
      }
      return;
    }

    final orderId = orderDetailIdFromUri(uri);
    if (orderId != null) {
      _openOrderDetail(orderId);
      return;
    }
    final content = NotificationContentTarget.fromUri(uri);
    if (content != null) _openNotificationContent(content);
  }

  Future<void> _recoverPrintPayment() async {
    final owner = Supabase.instance.client.auth.currentUser?.id;
    if (!mounted || !_appRootInstalled || owner == null) return;
    try {
      final service = ref.read(printPaymentServiceProvider);
      if (service.busy) return;
      final result = await service.recover();
      if (mounted &&
          Supabase.instance.client.auth.currentUser?.id == owner &&
          result.pending &&
          !_printRecoveryNoticeShown) {
        _printRecoveryNoticeShown = true;
        final pending = await service.pending();
        if (!mounted || Supabase.instance.client.auth.currentUser?.id != owner)
          return;
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('이전 앨범 주문의 결제 결과를 확인하고 있어요.'),
            action: SnackBarAction(
              label: '주문 확인',
              onPressed: () {
                final nav = _navigatorKey.currentState;
                if (nav != null &&
                    Supabase.instance.client.auth.currentUser?.id == owner) {
                  unawaited(
                    nav.push(
                      MaterialPageRoute(
                        settings: const WebAppRouteSettings(
                          WebAppLocation.orders,
                        ),
                        builder: (_) => OrderHistoryScreen(
                          initialOrderId: pending?.orderId,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
      if (!mounted ||
          Supabase.instance.client.auth.currentUser?.id != owner ||
          result.receipt == null)
        return;
      _printRecoveryNoticeShown = false;
      ref.invalidate(myOrderHistoryProvider);
      ref.invalidate(myOrderSummaryProvider);
      final nav = _navigatorKey.currentState;
      if (nav != null) {
        unawaited(
          nav.push(
            MaterialPageRoute(
              builder: (_) =>
                  PrintOrderCompleteScreen(receipt: result.receipt!),
            ),
          ),
        );
      }
    } catch (_) {
      /* Leave unresolved invoices durable for the next recovery. */
    }
  }

  Future<void> _openNotification(Map<String, dynamic> data) async {
    if (!mounted) return;
    final nav = _navigatorKey.currentState;
    final user = Supabase.instance.client.auth.currentUser;
    final expectedOwner = data['userId']?.toString();
    if (user != null && expectedOwner != null && expectedOwner != user.id)
      return;
    final uri = Uri.tryParse(data['deeplink']?.toString() ?? '');
    final webLocation = kIsWeb && uri != null
        ? WebAppLocation.parse(uri)
        : null;
    String? value(String key) =>
        data[key]?.toString() ?? uri?.queryParameters[key];
    final orderId =
        value('orderId') ??
        (uri == null ? null : orderDetailIdFromUri(uri)) ??
        (webLocation?.page == WebAppPage.order ? webLocation!.id : null);
    if (orderId != null && orderId.isNotEmpty) {
      if (user == null && expectedOwner == null) return;
      _openOrderDetail(orderId, ownerId: expectedOwner);
      return;
    }
    if (nav == null || user == null) return;
    if (webLocation?.page == WebAppPage.testOrder) {
      _webRouter?.requestLocation(webLocation!);
      return;
    }
    final content = NotificationContentTarget.fromPayload(data);
    if (content != null) {
      _openNotificationContent(content, ownerId: expectedOwner);
      return;
    }
    if (kIsWeb &&
        const {
          WebAppPage.album,
          WebAppPage.editor,
          WebAppPage.print,
          WebAppPage.template,
        }.contains(webLocation?.page)) {
      _webRouter?.requestLocation(webLocation!);
      return;
    }
    unawaited(
      nav.push(MaterialPageRoute(builder: (_) => const NotificationScreen())),
    );
  }

  void _openNotificationContent(
    NotificationContentTarget target, {
    String? ownerId,
  }) {
    _orderDetailNavigation.cancel();
    if (kIsWeb) {
      _webRouter?.requestLocation(
        WebAppLocation(
          target.kind == NotificationContentKind.album
              ? WebAppPage.album
              : WebAppPage.template,
          '${target.id}',
        ),
      );
      return;
    }
    _notificationContentNavigation.receive(
      target,
      ownerId: ownerId ?? Supabase.instance.client.auth.currentUser?.id,
    );
    _scheduleNotificationContentOpen();
  }

  void _scheduleNotificationContentOpen() {
    if (!mounted ||
        !_appRootInstalled ||
        !_notificationContentNavigation.hasPending ||
        _notificationContentScheduled ||
        _notificationContentBusy)
      return;
    _notificationContentScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationContentScheduled = false;
      if (mounted) unawaited(_openPendingNotificationContent());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openPendingNotificationContent() async {
    if (!mounted || _notificationContentBusy) return;
    final nav = _navigatorKey.currentState;
    final opening = _notificationContentNavigation.take(
      ownerId: Supabase.instance.client.auth.currentUser?.id,
      profileOwnerId: ref.read(authViewModelProvider).asData?.value?.id,
      navigatorReady: nav != null && _appRootInstalled,
      now: DateTime.now(),
    );
    if (nav == null || opening == null) return;
    bool current() =>
        mounted &&
        nav.context.mounted &&
        _notificationContentNavigation.isCurrent(
          opening,
          ownerId: Supabase.instance.client.auth.currentUser?.id,
          profileOwnerId: ref.read(authViewModelProvider).asData?.value?.id,
        );
    Future<T?> readCurrent<T>(Future<T> read) => Future.any<T?>([
      read.then<T?>((value) => value),
      opening.cancelled.then<T?>((_) => null),
    ]);
    _notificationContentBusy = true;
    var opened = false;
    try {
      if (opening.target.kind == NotificationContentKind.album) {
        await Future.any<void>([
          HomeAlbumActions.waitForReaderToClose(),
          opening.cancelled,
        ]);
        if (!current()) return;
        final album = await readCurrent(
          ref.read(albumRepositoryProvider).fetchAlbum('${opening.target.id}'),
        );
        if (album == null || !current()) return;
        final ready = Completer<void>();
        unawaited(
          HomeAlbumActions.openAlbum(
            nav.context,
            ref,
            album,
            canContinue: current,
            onReaderOpened: () {
              opened = true;
              if (!ready.isCompleted) ready.complete();
            },
          ).then(
            (_) {
              if (!ready.isCompleted) ready.complete();
            },
            onError: (Object error, StackTrace stack) {
              if (!ready.isCompleted) ready.completeError(error, stack);
            },
          ),
        );
        await Future.any<void>([ready.future, opening.cancelled]);
      } else {
        final template = await readCurrent(
          ref.read(templateRepositoryProvider).getTemplate(opening.target.id),
        );
        if (template == null || !current()) return;
        unawaited(
          nav.push(
            MaterialPageRoute<void>(
              builder: (_) => TemplateDetailScreen(template: template),
            ),
          ),
        );
        opened = true;
      }
    } catch (_) {
      if (current()) {
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('알림의 내용을 열 수 없습니다. 접근 권한이나 삭제 여부를 확인해 주세요.'),
          ),
        );
      }
    } finally {
      _notificationContentNavigation.finish(
        opening,
        opened: opened,
        now: DateTime.now(),
      );
      _notificationContentBusy = false;
      if (mounted && _notificationContentNavigation.hasPending)
        _scheduleNotificationContentOpen();
    }
  }

  Future<void> _handleAuthCallback(Uri uri) async {
    try {
      final redirectType = await ref
          .read(authViewModelProvider.notifier)
          .handleAuthCallback(uri);
      _messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            redirectType == 'recovery'
                ? '비밀번호 재설정 링크가 확인되었어요.'
                : '이메일 인증이 완료되었어요.',
          ),
        ),
      );
      if (redirectType == 'recovery') {
        _openPasswordResetScreen();
      }
    } catch (e) {
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('인증 링크 처리 실패: $e')),
      );
    }
  }

  void _openPasswordResetScreen() {
    final nav = _navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPasswordResetScreen(),
      );
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(startInPasswordReset: true),
      ),
    );
  }

  void _onAppRootReady() {
    if (!mounted) return;
    _appRootInstalled = true;
    _scheduleOrderDetailOpen();
    _scheduleNotificationContentOpen();
    unawaited(_recoverPrintPayment());
    if (kIsWeb) _scheduleWebLocationOpen();
  }

  Future<void> _synchronizeWebAuth(AuthChangeEvent event) async {
    if (!mounted) return;
    // The SDK owns callback exchange; the app only validates the resulting
    // session and loads this account's profile after that exchange completes.
    await ref.read(authViewModelProvider.future).catchError((_) => null);
    if (!mounted) return;
    await ref.read(authViewModelProvider.notifier).synchronizeSupabaseSession();
    if (!mounted) return;
    if (event == AuthChangeEvent.passwordRecovery) {
      _openPasswordResetScreen();
    } else {
      _scheduleWebLocationOpen();
    }
  }

  Future<void> _clearWebReturn() => _webReturnStore.clear();

  Future<void> _rememberWebReturn(WebAppLocation location) =>
      _webReturnStore.remember(location);

  Future<WebAppLocation?> _takeWebReturn() => _webReturnStore.take();

  void _receiveWebLocation(WebAppLocation location) {
    _notificationContentNavigation.cancel();
    _orderDetailNavigation.cancel();
    _webNavigationRevision++;
    _pendingWebLocation = location;
    _pendingWebOwner = location.isPublic
        ? null
        : Supabase.instance.client.auth.currentUser?.id;
    if (location == WebAppLocation.login &&
        _webRouter?.observedLocation.page == WebAppPage.template) {
      unawaited(_rememberWebReturn(_webRouter!.observedLocation));
    }
    if (_pendingWebOwner == null && !location.isPublic)
      unawaited(_rememberWebReturn(location));
    _scheduleWebLocationOpen();
  }

  void _scheduleWebLocationOpen() {
    if (!kIsWeb ||
        !mounted ||
        !_appRootInstalled ||
        _webNavigationScheduled ||
        _webNavigationBusy)
      return;
    _webNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _webNavigationScheduled = false;
      if (mounted) unawaited(_openPendingWebLocation());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _openPendingWebLocation() async {
    if (_webNavigationBusy || !mounted || !_appRootInstalled) return;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    // AuthGate must have finished a server-validated account restoration.
    if (_pendingWebLocation?.isPublic != true &&
        owner != null &&
        ref.read(authViewModelProvider).asData?.value?.id != owner)
      return;
    var target = _pendingWebLocation;
    if (target == null) return;
    if (owner == null && !target.isPublic) {
      // A public product/policy route can sit above AuthGate. A private menu
      // request must reveal that login screen while retaining its return path.
      _webNavigationBusy = true;
      final publicExitRevision = _webNavigationRevision;
      try {
        if (!await _webRouter!.returnToRoot()) {
          _pendingWebLocation = null;
          return;
        }
        if (!mounted ||
            publicExitRevision != _webNavigationRevision ||
            Supabase.instance.client.auth.currentUser?.id != null)
          return;
        final nav = _navigatorKey.currentState;
        if (nav != null) {
          unawaited(
            nav.push(
              MaterialPageRoute<void>(
                settings: const WebAppRouteSettings(WebAppLocation.login),
                builder: (_) => const AuthGate(allowDiscovery: false),
              ),
            ),
          );
          _webRouter?.finishInitialNavigation();
        }
      } finally {
        _webNavigationBusy = false;
        if (mounted && publicExitRevision != _webNavigationRevision)
          _scheduleWebLocationOpen();
      }
      return;
    }
    if (!target.isPublic &&
        _pendingWebOwner != null &&
        _pendingWebOwner != owner) {
      _pendingWebLocation = null;
      _webRouter?.restoreObservedLocation();
      return;
    }
    _webNavigationBusy = true;
    _openingWebLocation = target;
    final revision = _webNavigationRevision;
    try {
      if (owner != null &&
          (target == WebAppLocation.home || target == WebAppLocation.login)) {
        target = await _takeWebReturn() ?? WebAppLocation.home;
      }
      if (!mounted ||
          revision != _webNavigationRevision ||
          (!target.isPublic &&
              Supabase.instance.client.auth.currentUser?.id != owner))
        return;
      // OAuth can restore a private destination from an originally public '/'.
      // Validate it only after rejecting an obsolete navigation or account.
      if (!target.isPublic &&
          owner != null &&
          ref.read(authViewModelProvider).asData?.value?.id != owner) {
        _pendingWebLocation = target;
        _pendingWebOwner = owner;
        return;
      }
      _pendingWebLocation = null;
      _pendingWebOwner = null;
      final router = _webRouter!;
      final nav = _navigatorKey.currentState;
      if (nav == null) return;
      if (router.isDisplayingLocation(target)) {
        router.finishInitialNavigation();
        return;
      }
      if (router.updateDisplayedLocation(target)) return;
      if (!await router.returnToRoot()) return;
      await HomeAlbumActions.waitForReaderToClose();
      if (!mounted ||
          revision != _webNavigationRevision ||
          (!target.isPublic &&
              Supabase.instance.client.auth.currentUser?.id != owner))
        return;
      Route<void> route(Widget child) => MaterialPageRoute<void>(
        settings: WebAppRouteSettings(target!),
        builder: (_) => child,
      );
      switch (target.page) {
        case WebAppPage.home:
          break;
        case WebAppPage.login:
          if (owner == null) {
            unawaited(nav.push(route(const AuthGate(allowDiscovery: false))));
          }
        case WebAppPage.albums:
          unawaited(nav.push(route(const WebAlbumLibraryScreen())));
        case WebAppPage.printProducts:
          unawaited(nav.push(route(const PrintProductsScreen())));
        case WebAppPage.policy:
          unawaited(
            nav.push(
              route(
                CommercePolicyScreen(
                  kind: CommercePolicyKind.values.byName(target.id!),
                ),
              ),
            ),
          );
        case WebAppPage.create:
        case WebAppPage.aiCreate:
          final draft = await ref.read(albumCreationDraftProvider.future);
          if (!mounted ||
              revision != _webNavigationRevision ||
              Supabase.instance.client.auth.currentUser?.id != owner)
            return;
          var resume = false;
          if (draft != null) {
            final choice = await showDialog<bool>(
              context: nav.context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('만들던 앨범이 있습니다'),
                content: Text(
                  '${draft.title.trim().isEmpty ? '제목 없는 앨범' : draft.title}\n'
                  '이어서 만들거나 새 앨범을 시작하세요. 새 앨범을 임시 저장하면 기존 임시 저장을 대체합니다.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('새 앨범 만들기'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('이어서 만들기'),
                  ),
                ],
              ),
            );
            if (!mounted ||
                revision != _webNavigationRevision ||
                Supabase.instance.client.auth.currentUser?.id != owner)
              return;
            if (choice == null) {
              router.restoreObservedLocation();
              return;
            }
            resume = choice;
          }
          final startAi = !resume && target.page == WebAppPage.aiCreate;
          if (resume) target = WebAppLocation.create;
          unawaited(
            nav.push(
              route(
                AlbumCreateFlowScreen(
                  initialDraft: resume ? draft : null,
                  initialAiMode: startAi,
                ),
              ),
            ),
          );
        case WebAppPage.orders:
          unawaited(nav.push(route(const OrderHistoryScreen())));
        case WebAppPage.account:
          unawaited(nav.push(route(const MyPageScreen())));
        case WebAppPage.designs:
        case WebAppPage.materials:
          if (owner == null) {
            unawaited(
              nav.push(route(const PublicDiscoveryScreen(catalogOnly: true))),
            );
          } else {
            final catalogLocation = WebAppRouteController(
              target,
              pages: const {WebAppPage.designs, WebAppPage.materials},
            );
            unawaited(
              nav
                  .push<void>(
                    MaterialPageRoute<void>(
                      settings: WebAppRouteSettings(
                        target,
                        controller: catalogLocation,
                      ),
                      builder: (_) => ValueListenableBuilder<WebAppLocation>(
                        valueListenable: catalogLocation,
                        builder: (_, location, _) => StoreHubScreen(
                          initialMaterials:
                              location.page == WebAppPage.materials,
                          onDepartmentChanged: (materials) =>
                              catalogLocation.update(
                                materials
                                    ? WebAppLocation.materials
                                    : WebAppLocation.designs,
                              ),
                        ),
                      ),
                    ),
                  )
                  .whenComplete(catalogLocation.dispose),
            );
          }
        case WebAppPage.template:
          final templateId = int.parse(target.id!);
          final bundled = publishedCreationTemplates
              .where((item) => item.id == templateId)
              .firstOrNull;
          // Public links expose only the curated published catalog. A guessed
          // identifier never grants access to server or customer documents.
          if (owner == null && bundled == null) {
            throw StateError('unpublished_template');
          }
          final template =
              bundled ??
              await ref
                  .read(templateRepositoryProvider)
                  .getTemplate(templateId);
          if (!mounted ||
              revision != _webNavigationRevision ||
              Supabase.instance.client.auth.currentUser?.id != owner)
            return;
          unawaited(
            nav.push(
              route(
                TemplateDetailScreen(
                  template: template,
                  guestPreview: owner == null,
                ),
              ),
            ),
          );
        case WebAppPage.library:
          unawaited(
            nav.push(route(const MaterialCatalogScreen(library: true))),
          );
        case WebAppPage.notifications:
          unawaited(nav.push(route(const NotificationScreen())));
        case WebAppPage.order:
          unawaited(
            nav.push(route(OrderHistoryScreen(initialOrderId: target.id))),
          );
        case WebAppPage.testOrder:
          unawaited(
            nav.push(route(OrderHistoryScreen(initialTestRunId: target.id))),
          );
        case WebAppPage.album:
        case WebAppPage.editor:
        case WebAppPage.print:
          final album = await ref
              .read(albumRepositoryProvider)
              .fetchAlbum(target.id!);
          if (!mounted ||
              revision != _webNavigationRevision ||
              Supabase.instance.client.auth.currentUser?.id != owner)
            return;
          if (target.page == WebAppPage.album) {
            final opened = Completer<void>();
            unawaited(
              HomeAlbumActions.openAlbum(
                nav.context,
                ref,
                album,
                canContinue: () =>
                    mounted &&
                    revision == _webNavigationRevision &&
                    Supabase.instance.client.auth.currentUser?.id == owner,
                onReaderOpened: () {
                  if (!opened.isCompleted) opened.complete();
                },
              ).then(
                (_) {
                  if (!opened.isCompleted) opened.complete();
                },
                onError: (Object error, StackTrace stack) {
                  if (!opened.isCompleted) opened.completeError(error, stack);
                },
              ),
            );
            // Publish a direct link only after its actual reader is installed.
            await opened.future;
          } else if (target.page == WebAppPage.print) {
            unawaited(
              nav.push(
                route(
                  PrintOrderPreviewScreen(
                    albumId: album.id,
                    albumTitle: album.title,
                  ),
                ),
              ),
            );
          } else {
            if (!album.allowsEditing) throw StateError('album_read_only');
            final repository = ref.read(albumRepositoryProvider);
            await repository.lockAlbum(album.id);
            try {
              if (!mounted ||
                  Supabase.instance.client.auth.currentUser?.id != owner)
                throw StateError('web_navigation_obsolete');
              await ref.read(albumEditorViewModelProvider.future);
              await ref
                  .read(albumEditorViewModelProvider.notifier)
                  .prepareAlbumForEdit(album);
              if (!mounted ||
                  revision != _webNavigationRevision ||
                  Supabase.instance.client.auth.currentUser?.id != owner)
                throw StateError('web_navigation_obsolete');
              unawaited(
                nav
                    .push(
                      route(
                        const PageEditorScreen(returnToPreviousOnSave: true),
                      ),
                    )
                    .whenComplete(() async {
                      if (Supabase.instance.client.auth.currentUser?.id ==
                          owner) {
                        try {
                          await repository.unlockAlbum(album.id);
                        } catch (_) {}
                      }
                    }),
              );
            } catch (_) {
              if (Supabase.instance.client.auth.currentUser?.id == owner) {
                try {
                  await repository.unlockAlbum(album.id);
                } catch (_) {}
              }
              rethrow;
            }
          }
      }
      if (mounted &&
          revision == _webNavigationRevision &&
          (target.isPublic ||
              Supabase.instance.client.auth.currentUser?.id == owner)) {
        router.finishInitialNavigation();
        if (target.page != WebAppPage.login) unawaited(_clearWebReturn());
      }
    } catch (_) {
      if (mounted &&
          revision == _webNavigationRevision &&
          Supabase.instance.client.auth.currentUser?.id == owner) {
        _webRouter?.restoreObservedLocation();
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('이 페이지를 열 수 없어요. 로그인과 앨범 접근 권한을 확인해주세요.'),
          ),
        );
      }
    } finally {
      _openingWebLocation = null;
      _webNavigationBusy = false;
      if (_pendingWebLocation != null && mounted) _scheduleWebLocationOpen();
    }
  }

  void _openOrderDetail(String orderId, {String? ownerId}) {
    if (orderId.trim().isEmpty || orderId.trim().length > 200) return;
    _notificationContentNavigation.cancel();
    _orderDetailNavigation.receive(
      orderId,
      ownerId: ownerId ?? Supabase.instance.client.auth.currentUser?.id,
    );
    _scheduleOrderDetailOpen();
  }

  void _scheduleOrderDetailOpen() {
    if (!mounted ||
        !_orderDetailNavigation.hasPending ||
        _orderDetailNavigationScheduled)
      return;
    _orderDetailNavigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orderDetailNavigationScheduled = false;
      if (!mounted) return;
      final nav = _navigatorKey.currentState;
      final orderId = _orderDetailNavigation.take(
        ownerId: Supabase.instance.client.auth.currentUser?.id,
        navigatorReady: nav != null && _appRootInstalled,
        now: DateTime.now(),
      );
      if (nav == null && _appRootInstalled) {
        _scheduleOrderDetailOpen();
        return;
      }
      if (nav == null || orderId == null) return;
      unawaited(
        nav.push(
          MaterialPageRoute(
            settings: WebAppRouteSettings(
              WebAppLocation(WebAppPage.order, orderId),
            ),
            builder: (_) => OrderHistoryScreen(initialOrderId: orderId),
          ),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    ref.listen(authViewModelProvider, (_, next) {
      if (next.asData?.value != null) _scheduleNotificationContentOpen();
    });
    if (kIsWeb) {
      ref.listen(authViewModelProvider, (_, next) {
        if (next.asData?.value != null) {
          if (_pendingWebLocation == null &&
              _webRouter?.observedLocation == WebAppLocation.login) {
            _receiveWebLocation(WebAppLocation.home);
          } else {
            _scheduleWebLocationOpen();
          }
        }
      });
      return MaterialApp.router(
        title: '스냅핏',
        debugShowCheckedModeBanner: false,
        theme: SnapFitWebTheme.from(SnapFitTheme.light()),
        darkTheme: SnapFitWebTheme.from(SnapFitTheme.dark()),
        themeMode: ref.watch(webThemeModeProvider),
        scaffoldMessengerKey: _messengerKey,
        routerDelegate: _webRouter!,
        routeInformationParser: const WebAppRouteParser(),
        builder: (context, child) {
          syncWebDocumentTheme(Theme.of(context).brightness == Brightness.dark);
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SnapFitTheme.systemOverlayStyle(context),
            child: WebNavigationScope(
              onNavigate: (section) =>
                  _webRouter!.requestLocation(switch (section) {
                    WebSection.albums => WebAppLocation.albums,
                    WebSection.create => WebAppLocation.create,
                    WebSection.designs => WebAppLocation.designs,
                    WebSection.orders => WebAppLocation.orders,
                    WebSection.account => WebAppLocation.account,
                  }),
              onNotifications: () =>
                  _webRouter!.requestLocation(WebAppLocation.notifications),
              onPublicNavigate: _webRouter!.requestLocation,
              child: child!,
            ),
          );
        },
      );
    }
    return MaterialApp(
      title: '스냅핏',
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: themeMode,
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      navigatorObservers: [_appRootRouteObserver],
      initialRoute: kIsWeb && isPrintPaymentReturn(Uri.base) ? '/' : null,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SnapFitTheme.systemOverlayStyle(context),
        child: child!,
      ),
      home: const SplashScreen(),
      routes: {'/add_cover': (context) => const AddCoverScreen()},
    );
  }
}
