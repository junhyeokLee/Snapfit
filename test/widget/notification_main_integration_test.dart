import 'dart:async';
import 'dart:convert';

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/main.dart' as application;
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/splash/presentation/views/splash_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/domain/repositories/template_repository.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import '../support/point_purchase_fakes.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

const _owner = '11111111-1111-4111-8111-111111111111';
const _user = UserInfo(id: _owner, name: '알림 검수', provider: 'EMAIL');

class _Links extends AppLinksPlatform {
  Uri? initial;
  final links = StreamController<Uri>.broadcast();
  @override
  Future<Uri?> getInitialLink() async => initial;
  @override
  Stream<Uri> get uriLinkStream => links.stream;
}

class _Messaging extends FirebaseMessagingPlatform {
  final refresh = StreamController<String>.broadcast();
  RemoteMessage? initial = const RemoteMessage(
    data: {
      'userId': _owner,
      'templateId': '12',
      'deeplink': 'snapfit://template?templateId=12',
    },
  );
  int launchReads = 0;
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => true;
  @override
  Future<void> setAutoInitEnabled(bool enabled) async {}
  @override
  Stream<String> get onTokenRefresh => refresh.stream;
  @override
  Future<String?> getAPNSToken() async => 'fixture-apns';
  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async => 'fixture-no-real-installation';
  @override
  Future<void> deleteToken() async {}
  @override
  Future<void> unsubscribeFromTopic(String topic) async {}
  @override
  Future<RemoteMessage?> getInitialMessage() async {
    launchReads++;
    final message = initial;
    initial = null;
    return message;
  }

  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      const NotificationSettings(
        authorizationStatus: AuthorizationStatus.denied,
        alert: AppleNotificationSetting.disabled,
        announcement: AppleNotificationSetting.disabled,
        badge: AppleNotificationSetting.disabled,
        carPlay: AppleNotificationSetting.disabled,
        lockScreen: AppleNotificationSetting.disabled,
        notificationCenter: AppleNotificationSetting.disabled,
        showPreviews: AppleShowPreviewSetting.never,
        timeSensitive: AppleNotificationSetting.disabled,
        criticalAlert: AppleNotificationSetting.disabled,
        sound: AppleNotificationSetting.disabled,
        providesAppNotificationSettings: AppleNotificationSetting.disabled,
      );
}

class _Auth extends AuthViewModel {
  @override
  UserInfo? build() => _user;
}

class _Home extends HomeViewModel {
  @override
  List<Album> build() => const [];
}

class _Tokens extends TokenStorage {
  @override
  Future<String?> getResolvedUserId() async => _owner;
}

class _Invites extends PendingAlbumInviteStore {
  @override
  Future<PendingAlbumInvite?> read() async => null;
  @override
  Future<void> write(PendingAlbumInvite? invite) async {}
}

class _Print extends Mock implements PrintPaymentService {}

class _Templates extends Mock implements TemplateRepository {}

PremiumTemplate _template(int id) => PremiumTemplate(
  id: id,
  title: '알림 연결 검수 $id',
  coverImageUrl: 'asset:assets/snapfit_home_square.jpg',
  previewImages: const [],
  pageCount: 2,
  userCount: 0,
  templateJson: '{"pages":[{"isCover":true,"layers":[]},{"layers":[]}]}',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  final links = _Links();
  final messaging = _Messaging();
  final requests = <http.Request>[];
  final templateReads = <int>[];
  late AppLinksPlatform previousLinks;
  late FirebaseMessagingPlatform previousMessaging;
  late _Print print;
  late _Templates templates;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'push_permission_requested': true});
    await loadCreationFonts();
    await Firebase.initializeApp();
    previousLinks = AppLinksPlatform.instance;
    AppLinksPlatform.instance = links;
    previousMessaging = FirebaseMessagingPlatform.instance;
    FirebaseMessagingPlatform.instance = messaging;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async => call.method == 'initialize'
              ? true
              : call.method == 'getNotificationAppLaunchDetails'
              ? {'notificationLaunchedApp': false}
              : null,
        );
    await Supabase.initialize(
      url: 'https://main-notification-integration.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/register_push_device') ||
            request.method == 'DELETE') {
          return http.Response('', 204, request: request);
        }
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final jwt =
        '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
        '${base64Url.encode(utf8.encode(jsonEncode({'sub': _owner, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token': jwt,
        'token_type': 'bearer',
        'refresh_token': 'fixture-refresh',
        'expires_in': 3600,
        'expires_at': expiry,
        'user': {
          'id': _owner,
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
        },
      }),
    );
  });

  setUp(() {
    CatalogFavorites.instance = CatalogFavorites();
    templateReads.clear();
    print = _Print();
    when(() => print.busy).thenReturn(false);
    when(
      () => print.recover(),
    ).thenAnswer((_) async => const PrintPaymentOutcome());
    templates = _Templates();
    when(() => templates.getTemplate(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as int;
      templateReads.add(id);
      return _template(id);
    });
    when(() => templates.getTemplates()).thenAnswer((_) async => const []);
  });

  tearDown(() {
    CatalogFavorites.instance.dispose();
    expect(
      requests.every(
        (request) =>
            request.url.host == 'main-notification-integration.invalid',
      ),
      true,
    );
  });

  tearDownAll(() async {
    await FcmNotificationService.clearDevicePushState();
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await Supabase.instance.dispose();
    AppLinksPlatform.instance = previousLinks;
    FirebaseMessagingPlatform.instance = previousMessaging;
    await links.links.close();
    await messaging.refresh.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
  });

  Future<void> mount(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          tokenStorageProvider.overrideWithValue(_Tokens()),
          homeViewModelProvider.overrideWith(_Home.new),
          pendingAlbumInviteStoreProvider.overrideWithValue(_Invites()),
          albumCreationDraftProvider.overrideWith((_) async => null),
          notificationUnreadCountProvider.overrideWith((_) async => 0),
          templateRepositoryProvider.overrideWithValue(templates),
          templateListProvider.overrideWith((_) async => const []),
          pointShopCatalogProvider.overrideWith((_) async => const []),
          ownedPointShopKeysProvider.overrideWith(
            (_) async => const <String>{},
          ),
          printPaymentServiceProvider.overrideWithValue(print),
          pointPurchaseServiceProvider.overrideWith((ref) {
            final service = fakePointPurchaseService();
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const application.MoaEditorApp(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }

  Future<void> expectDestination(WidgetTester tester, int id) async {
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(TemplateDetailScreen), findsNothing);
    expect(
      templateReads,
      isEmpty,
      reason: 'main must wait for the stable native root before fetching',
    );
    for (
      var frame = 0;
      frame < 30 && find.byType(TemplateDetailScreen).evaluate().isEmpty;
      frame++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(
      tester
          .widget<TemplateDetailScreen>(find.byType(TemplateDetailScreen))
          .template
          .id,
      id,
    );
    expect(templateReads, [id]);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(TemplateDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'actual MoaEditorApp opens a terminated template notification after its real splash',
    (tester) async {
      links.initial = null;
      await mount(tester);
      expect(messaging.launchReads, 1);
      await expectDestination(tester, 12);
    },
  );

  testWidgets(
    'actual MoaEditorApp opens an external initial template URI through AppLinks after splash',
    (tester) async {
      links.initial = Uri.parse('snapfit://template?templateId=13');
      await mount(tester);
      await expectDestination(tester, 13);
    },
  );
}
