import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';

import 'config/env.dart';
import 'core/notifications/fcm_notification_service.dart';
import 'core/templates/template_update_notification_service.dart';
import 'core/theme/snapfit_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/frame_timing_monitor.dart';
import 'features/album/presentation/views/add_cover_screen.dart';
import 'features/billing/data/billing_provider.dart';
import 'features/profile/data/order_repository.dart';
import 'features/profile/presentation/views/order_history_screen.dart';
import 'features/splash/presentation/views/splash_screen.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.debug('[FCM] background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FrameTimingMonitor.start();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await FcmNotificationService.initialize();

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

class _MoaEditorAppState extends ConsumerState<MoaEditorApp> {
  final AppLinks _appLinks = AppLinks();
  final Set<String> _handledBillingOrderIds = <String>{};
  final Set<String> _handledPrintOrderIds = <String>{};
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSub;
  String? _lastOpenedOrderDetailId;
  DateTime? _lastOpenedOrderDetailAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(themeModeControllerProvider.notifier).loadFromStorage();
      TemplateUpdateNotificationService.checkAndNotifyIfUpdated();
      _initBillingDeepLinkListener();
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  Future<void> _initBillingDeepLinkListener() async {
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

    final path = uri.path.toLowerCase();
    final host = uri.host.toLowerCase();

    if (host == 'billing') {
      final orderId = uri.queryParameters['orderId']?.trim() ?? '';
      if (orderId.isEmpty) return;
      if (_handledBillingOrderIds.contains(orderId)) return;
      _handledBillingOrderIds.add(orderId);

      if (path.contains('success')) {
        final paymentKey = uri.queryParameters['paymentKey']?.trim();
        final amount = int.tryParse(uri.queryParameters['amount'] ?? '');
        try {
          await ref
              .read(billingRepositoryProvider)
              .approveOrder(
                orderId: orderId,
                paymentKey: paymentKey,
                amount: amount,
              );
          ref.invalidate(mySubscriptionProvider);
          ref.invalidate(myStorageQuotaProvider);
          _messengerKey.currentState?.showSnackBar(
            const SnackBar(content: Text('결제 완료가 자동 반영되었습니다.')),
          );
        } catch (e) {
          _messengerKey.currentState?.showSnackBar(
            SnackBar(content: Text('결제 승인 자동 반영 실패: $e')),
          );
        }
        return;
      }

      if (path.contains('fail')) {
        final message = uri.queryParameters['message']?.trim();
        _messengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              message?.isNotEmpty == true ? message! : '결제가 취소되거나 실패했습니다.',
            ),
          ),
        );
      }
      return;
    }

    if (host != 'order') {
      return;
    }

    final orderId = uri.queryParameters['orderId']?.trim() ?? '';
    if (path.contains('detail')) {
      _openOrderDetail(orderId);
      return;
    }

    if (orderId.isEmpty) return;
    if (_handledPrintOrderIds.contains(orderId)) return;
    _handledPrintOrderIds.add(orderId);

    if (path.contains('success')) {
      try {
        await ref.read(orderRepositoryProvider).confirmPayment(orderId);
        ref.invalidate(myOrderHistoryProvider);
        _messengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('주문 결제가 완료되어 제작 단계로 반영되었습니다.')),
        );
        _openOrderDetail(orderId);
      } catch (e) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('주문 결제 반영 실패: $e')),
        );
      }
      return;
    }

    if (path.contains('fail')) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('주문 결제가 취소되거나 실패했습니다.')),
      );
    }
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
      title: 'SnapFit',
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
