import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:snap_fit/core/navigation/web_app_location.dart';
import 'package:snap_fit/core/navigation/web_app_router.dart';
import 'package:snap_fit/core/notifications/fcm_notification_service.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/web/web_album_library_screen.dart';
import 'package:snap_fit/features/album/service/pending_album_invite.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/features/home_news/presentation/providers/home_news_providers.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/profile/data/print_payment_service.dart';
import 'package:snap_fit/features/referral/data/pending_referral.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/presentation/views/store_hub_screen.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';
UserInfo _user(String owner) => UserInfo(
  id: owner,
  name: owner == _ownerA ? 'Account A' : 'Account B',
  email: 'fixture@example.test',
  provider: 'EMAIL',
);

class _Auth extends AuthViewModel {
  int retries = 0;
  @override
  Future<UserInfo?> build() async => _user(_ownerA);
  void waitForVerification() => state = const AsyncLoading();
  void failVerification() => state = AsyncError(
    TimeoutException('isolated authentication request stalled'),
    StackTrace.current,
  );
  void recover(String owner) => state = AsyncData(_user(owner));
  @override
  Future<void> refresh() async {
    retries++;
    final owner = Supabase.instance.client.auth.currentUser?.id;
    state = AsyncData(owner == null ? null : _user(owner));
  }

  // This fixture controls validation separately from the SDK owner. Merely
  // restoring a local SDK session must not validate a private destination.
  @override
  Future<void> synchronizeSupabaseSession() async {}
}

class _Home extends HomeViewModel {
  @override
  Future<List<Album>> build() async => const [];
}

class _Tokens extends TokenStorage {
  @override
  Future<String?> getResolvedUserId() async =>
      Supabase.instance.client.auth.currentUser?.id;
}

class _Invites extends PendingAlbumInviteStore {
  @override
  Future<PendingAlbumInvite?> read() async => null;
  @override
  Future<void> write(PendingAlbumInvite? value) async {}
}

class _Referrals extends PendingReferralStore {
  @override
  Future<PendingReferral?> read() async => null;
  @override
  Future<void> write(PendingReferral? value) async {}
}

class _Print extends Mock implements PrintPaymentService {}

/// No Firebase browser plugin or service worker is needed to test navigation.
/// Keep the real app's background FCM calls deterministic and explicitly
/// unsupported rather than leaving a browser plugin initialization in flight.
class _Firebase extends FirebasePlatform {
  final fixtureApp = FirebaseAppPlatform(
    '[DEFAULT]',
    const FirebaseOptions(
      apiKey: 'fixture',
      appId: 'fixture-navigation',
      messagingSenderId: 'fixture',
      projectId: 'fixture-navigation',
    ),
  );
  @override
  List<FirebaseAppPlatform> get apps => [fixtureApp];
  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) => fixtureApp;
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async => fixtureApp;
}

class _Messaging extends FirebaseMessagingPlatform {
  @override
  FirebaseMessagingPlatform delegateFor({FirebaseApp? app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  @override
  bool get isAutoInitEnabled => false;
  @override
  Future<bool> isSupported() async => false;
  @override
  Future<void> deleteToken() async {}
}

Future<void> _setOwner(String owner) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final jwt =
      '${base64Url.encode(utf8.encode('{"alg":"none"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry, 'role': 'authenticated'})))}.fixture';
  await Supabase.instance.client.auth.setInitialSession(
    jsonEncode({
      'access_token': jwt,
      'token_type': 'bearer',
      'refresh_token': 'fixture-refresh-$owner',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': owner,
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {},
      },
    }),
  );
}

Future<void> _frames(WidgetTester tester, {int count = 12}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
}

void _request(WidgetTester tester, WebAppLocation destination) => tester
    .widget<WebNavigationScope>(find.byType(WebNavigationScope).first)
    .onPublicNavigate!(destination);

void _diagnose(
  WidgetTester tester,
  String stage,
  Object error,
  StackTrace stack,
) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp).first);
  final router = app.routerDelegate;
  final location = router is WebAppRouter
      ? '${router.currentConfiguration.uri} / observed=${router.observedLocation.uri}'
      : '${router.runtimeType}';
  debugPrint(
    'Web auth navigation failure at $stage: $error\n'
    'location=$location SDK=${Supabase.instance.client.auth.currentUser?.id} '
    'visible home=${find.byType(WebAlbumLibraryScreen).evaluate().length} '
    'profile=${find.byType(SocialProfileScreen).evaluate().length} '
    'store=${find.byType(StoreHubScreen).evaluate().length} '
    'login=${find.byType(LoginScreen).evaluate().length}\n$stack',
  );
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  var finished = false;
  var stage = 'join outgoing FCM synchronization';
  Object? failure;
  StackTrace? failureStack;
  // FCM is process-wide, while each widget case owns a different fake clock.
  // Join the old work and establish new queue tails in the real async zone.
  await tester.runAsync(() async {
    unawaited(
      (() async {
        await FcmNotificationService.syncSession();
        stage = 'synchronize FCM in the real async zone';
        await FcmNotificationService.syncSession();
        stage = 'read fixture notification preferences';
        await FcmNotificationService.loadSettings(refresh: true);
      })().then(
        (_) => finished = true,
        onError: (Object error, StackTrace stack) {
          failure = error;
          failureStack = stack;
          finished = true;
        },
      ),
    );
  });
  // Advance the outgoing fake clock too: a zero-duration pump never resolves
  // an SDK backoff or an FCM deadline created by a mounted account/profile.
  for (var step = 0; step < 120 && !finished; step++) {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(
    finished,
    isTrue,
    reason: 'Navigation fixture cleanup stalled: $stage',
  );
  if (failure != null) {
    debugPrint(
      'Web auth navigation cleanup failed at $stage: $failure\n$failureStack',
    );
    Error.throwWithStackTrace(failure!, failureStack!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  late _Print printing;
  late FirebasePlatform previousFirebase;
  late FirebaseMessagingPlatform previousMessaging;

  setUpAll(() async {
    if (!kIsWeb) return;
    SharedPreferences.setMockInitialValues({'snapfit_first_visit_v1': 3});
    previousFirebase = FirebasePlatform.instance;
    previousMessaging = FirebaseMessagingPlatform.instance;
    FirebasePlatform.instance = _Firebase();
    FirebaseMessagingPlatform.instance = _Messaging();
    await Supabase.initialize(
      url: 'https://web-auth-navigation-fixture.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '[]',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    // The FCM service subscribes once for the entire process. Register that
    // subscription outside any case's fake clock, or later SDK owner changes
    // would start work in the already-finished first case's async zone.
    await FcmNotificationService.initialize();
    await FcmNotificationService.syncSession();
  });

  setUp(() async {
    if (!kIsWeb) return;
    await _setOwner(_ownerA);
    CatalogFavorites.instance = CatalogFavorites();
    printing = _Print();
    when(() => printing.busy).thenReturn(false);
    when(
      () => printing.recover(),
    ).thenAnswer((_) async => const PrintPaymentOutcome());
  });

  tearDown(() {
    if (!kIsWeb) return;
    CatalogFavorites.instance.dispose();
    expect(
      requests.every(
        (request) => request.url.host == 'web-auth-navigation-fixture.invalid',
      ),
      isTrue,
      reason: 'No real account, API, purchase or album is used by this test.',
    );
  });

  tearDownAll(() async {
    if (!kIsWeb) return;
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await FcmNotificationService.syncSession();
    await Supabase.instance.dispose();
    FirebaseMessagingPlatform.instance = previousMessaging;
    FirebasePlatform.instance = previousFirebase;
  });

  Future<_Auth> mountStore(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 1000);
    addTearDown(tester.view.reset);
    final auth = _Auth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authViewModelProvider.overrideWith(() => auth),
          tokenStorageProvider.overrideWithValue(_Tokens()),
          homeViewModelProvider.overrideWith(_Home.new),
          pendingAlbumInviteStoreProvider.overrideWithValue(_Invites()),
          pendingReferralStoreProvider.overrideWithValue(_Referrals()),
          albumCreationDraftProvider.overrideWith((_) async => null),
          homeNewsCurrentOwnerProvider.overrideWithValue(null),
          notificationUnreadCountProvider.overrideWith((_) async => 0),
          mockTemplateList(() async => const []),
          pointShopCatalogProvider.overrideWith((_) async => const []),
          ownedPointShopKeysProvider.overrideWith(
            (_) async => const <String>{},
          ),
          printPaymentServiceProvider.overrideWithValue(printing),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const application.MoaEditorApp(),
        ),
      ),
    );
    await _frames(tester);
    // Browser route state can outlive a preceding test. Use the real router to
    // return to the validated root before interacting with its actual menu.
    _request(tester, WebAppLocation.home);
    await _frames(tester);
    expect(find.byType(WebAlbumLibraryScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('web-navigation-designs')));
    await _frames(tester);
    expect(find.byType(StoreHubScreen), findsOneWidget);
    return auth;
  }

  for (final target in [WebAppLocation.albums, WebAppLocation.myProfile]) {
    testWidgets(
      'actual web app reveals pending authentication above the public store before opening ${target.page.name}',
      (tester) async {
        var stage = 'mount store';
        try {
          final auth = await mountStore(tester);
          stage = 'public store remains visible during pending verification';
          auth.waitForVerification();
          await _frames(tester, count: 3);
          expect(find.byType(StoreHubScreen), findsOneWidget);
          await tester.tap(
            find.byKey(
              ValueKey(
                'web-navigation-${target == WebAppLocation.albums ? 'albums' : 'myProfile'}',
              ),
            ),
          );
          await _frames(tester);
          stage = 'private menu reveals account loading';
          expect(find.byType(StoreHubScreen), findsNothing);
          expect(find.byType(SocialProfileScreen), findsNothing);
          expect(find.byType(WebAlbumLibraryScreen), findsNothing);
          expect(find.text('로그인한 계정을 확인하고 있어요.'), findsOneWidget);
          auth.failVerification();
          await _frames(tester);
          stage = 'account timeout reveals retry';
          expect(find.byType(LoginScreen), findsOneWidget);
          expect(
            find.byKey(const ValueKey('auth-retry-session')).hitTestable(),
            findsOneWidget,
          );
          await tester.tap(find.byKey(const ValueKey('auth-retry-session')));
          await _frames(tester);
          stage = 'retry restores requested ${target.page.name}';
          expect(auth.retries, 1);
          expect(find.byType(LoginScreen), findsNothing);
          expect(find.byType(StoreHubScreen), findsNothing);
          expect(
            find.byType(
              target == WebAppLocation.albums
                  ? WebAlbumLibraryScreen
                  : SocialProfileScreen,
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } catch (error, stack) {
          _diagnose(tester, stage, error, stack);
          rethrow;
        } finally {
          await _close(tester);
        }
      },
      skip: !kIsWeb,
    );
  }

  testWidgets(
    'a different SDK account discards the private destination captured before auth recovery',
    (tester) async {
      var stage = 'mount store';
      try {
        final auth = await mountStore(tester);
        stage = 'reveal failed account above public store';
        auth.failVerification();
        await _frames(tester, count: 3);
        await tester.tap(
          find.byKey(const ValueKey('web-navigation-myProfile')),
        );
        await _frames(tester);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(StoreHubScreen), findsNothing);
        stage = 'switch SDK owner while account verification failed';
        await tester.runAsync(() => _setOwner(_ownerB));
        await _frames(tester);
        auth.recover(_ownerB);
        await _frames(tester);
        stage = 'new account cannot resume previous account destination';
        expect(find.byType(SocialProfileScreen), findsNothing);
        expect(find.byType(WebAlbumLibraryScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(tester.takeException(), isNull);
      } catch (error, stack) {
        _diagnose(tester, stage, error, stack);
        rethrow;
      } finally {
        await _close(tester);
      }
    },
    skip: !kIsWeb,
  );
}
