import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'core/notifications/fcm_notification_service.dart';
import 'core/templates/template_update_notification_service.dart';
import 'core/theme/snapfit_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/frame_timing_monitor.dart';
import 'features/album/presentation/views/add_cover_screen.dart';
import 'features/album/data/api/album_provider.dart';
import 'features/album/presentation/widgets/home/home_album_actions.dart';
import 'features/billing/data/billing_provider.dart';
import 'features/billing/data/point_purchase_service.dart';
import 'features/notification/presentation/providers/notification_provider.dart';
import 'features/notification/presentation/views/notification_screen.dart';
import 'features/store/data/api/template_provider.dart';
import 'features/store/presentation/views/template_detail_screen.dart';
import 'features/auth/presentation/viewmodels/auth_view_model.dart';
import 'features/auth/presentation/views/login_screen.dart';
import 'features/profile/domain/order_deep_link.dart';
import 'features/profile/presentation/views/order_history_screen.dart';
import 'features/splash/presentation/views/splash_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  AppLogger.debug('[FCM] background message: ${message.messageId}');
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
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (Env.kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }

  runApp(
    ProviderScope(
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        minTextAdapt: true, // 글자 크기 자동 조정
        splitScreenMode: true, // 분할 화면 대응 (Fold,ㄹ Split 등)
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
  late final PointPurchaseService _pointPurchases;
  String? _lastOpenedOrderDetailId;
  DateTime? _lastOpenedOrderDetailAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pointPurchases = ref.read(pointPurchaseServiceProvider)..start();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      ref.invalidate(myPointBalanceProvider);
      ref.invalidate(myPointLedgerProvider);
      ref.invalidate(notificationInboxProvider);
      ref.invalidate(notificationUnreadCountProvider);
      if (event.session != null) unawaited(_pointPurchases.recover());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        FcmNotificationService.initialize(onNotificationTap: _openNotification),
      );
      unawaited(_pointPurchases.recover());
      ref.read(themeModeControllerProvider.notifier).loadFromStorage();
      TemplateUpdateNotificationService.checkAndNotifyIfUpdated();
      _initDeepLinkListener();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed)
      unawaited(_pointPurchases.recover());
  }

  Future<void> _initDeepLinkListener() async {
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
    if (uri.scheme.toLowerCase() != 'snapfit') {
      return;
    }

    if (uri.host.toLowerCase() == 'auth') {
      await _handleAuthCallback(uri);
      return;
    }

    final orderId = orderDetailIdFromUri(uri);
    if (orderId != null) _openOrderDetail(orderId);
  }

  Future<void> _openNotification(Map<String, dynamic> data) async {
    if (!mounted) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || (data['userId'] != null && data['userId'] != user.id))
      return;
    final uri = Uri.tryParse(data['deeplink']?.toString() ?? '');
    String? value(String key) =>
        data[key]?.toString() ?? uri?.queryParameters[key];
    final orderId = value('orderId');
    if (orderId != null && orderId.isNotEmpty) {
      _openOrderDetail(orderId);
      return;
    }
    try {
      final albumId = int.tryParse(value('albumId') ?? '');
      if (albumId != null) {
        final album = await ref
            .read(albumRepositoryProvider)
            .fetchAlbum(albumId.toString());
        if (mounted &&
            nav.context.mounted &&
            Supabase.instance.client.auth.currentUser?.id == user.id) {
          await HomeAlbumActions.openAlbum(nav.context, ref, album);
        }
        return;
      }
      final templateId = int.tryParse(value('templateId') ?? '');
      if (templateId != null) {
        final template = await ref
            .read(templateRepositoryProvider)
            .getTemplate(templateId);
        if (mounted &&
            Supabase.instance.client.auth.currentUser?.id == user.id) {
          unawaited(
            nav.push(
              MaterialPageRoute(
                builder: (_) => TemplateDetailScreen(template: template),
              ),
            ),
          );
        }
        return;
      }
      unawaited(
        nav.push(MaterialPageRoute(builder: (_) => const NotificationScreen())),
      );
    } catch (_) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('알림의 내용을 열 수 없습니다. 접근 권한이나 삭제 여부를 확인해 주세요.'),
        ),
      );
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

  void _openOrderDetail(String orderId) {
    if (orderId.isEmpty) return;
    final now = DateTime.now();
    if (_lastOpenedOrderDetailId == orderId &&
        _lastOpenedOrderDetailAt != null &&
        now.difference(_lastOpenedOrderDetailAt!).inSeconds < 2) {
      return;
    }
    _lastOpenedOrderDetailId = orderId;
    _lastOpenedOrderDetailAt = now;

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openOrderDetail(orderId);
      });
      return;
    }
    nav.push(
      MaterialPageRoute(
        builder: (_) => OrderHistoryScreen(initialOrderId: orderId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeControllerProvider);
    return MaterialApp(
      title: '스냅핏',
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: themeMode,
      scaffoldMessengerKey: _messengerKey,
      navigatorKey: _navigatorKey,
      home: const SplashScreen(),
      routes: {'/add_cover': (context) => const AddCoverScreen()},
    );
  }
}
