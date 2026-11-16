import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_feed_screen.dart';
import 'package:snap_fit/features/social/presentation/views/social_profile_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _owner = '11111111-1111-4111-8111-111111111111';
const _other = '22222222-2222-4222-8222-222222222222';
const _deadline = Duration(seconds: 25);

class _Auth extends Mock implements GoTrueClient {}

// The fixture supplies public social identity, never native secure storage.
class _NoPrivateAccount extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => null;
}

class _Client extends SupabaseClient {
  _Client(this.fixtureAuth, http.Client transport)
    : super(
        'https://fixture.invalid',
        'fixture-public-key',
        httpClient: transport,
        accessToken: () async => 'fixture-token',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  final GoTrueClient fixtureAuth;
  @override
  GoTrueClient get auth => fixtureAuth;
}

class _ReadFixture {
  _ReadFixture(this.action) {
    final auth = _Auth();
    when(() => auth.currentUser).thenReturn(
      User(
        id: _owner,
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        createdAt: '2026-11-02',
      ),
    );
    client = _Client(
      auth,
      MockClient((request) async {
        if (!request.url.path.endsWith('/rpc/social_api')) {
          throw StateError('Unexpected fixture endpoint');
        }
        final body = jsonDecode(request.body) as Map;
        final currentAction = body['p_action'] as String;
        if (currentAction == action) {
          reads++;
          if (reads == 1) {
            firstRequest = request;
            return first.future;
          }
        }
        return response(request, currentAction);
      }),
    );
    repository = SocialRepository(client);
  }

  final String action;
  final first = Completer<http.Response>();
  late http.Request firstRequest;
  late final _Client client;
  late final SocialRepository repository;
  int reads = 0;
  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await client.dispose();
  }

  http.Response response(http.Request request, String action) {
    final Object value = action == 'profile'
        ? {
            'userId': _other,
            'displayName': '새로 확인한 프로필',
            'handle': 'fresh.profile',
            'bio': '',
          }
        : action == 'blockedProfiles'
        ? <dynamic>[]
        : {'items': <dynamic>[], 'hasMore': false, 'nextOffset': 0};
    return http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  Widget app(Widget screen) => ProviderScope(
    // Keep ProviderScope's real default retry policy. The production providers
    // must opt out themselves; a fixture override would conceal the bug.
    overrides: [
      socialRepositoryProvider.overrideWithValue(repository),
      authViewModelProvider.overrideWith(_NoPrivateAccount.new),
      socialCurrentUserIdProvider.overrideWith((_) => _owner),
      socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
    ],
    child: MaterialApp(theme: SnapFitTheme.light(), home: screen),
  );

  void finishOldRead() => first.complete(response(firstRequest, action));
}

void main() {
  testWidgets(
    'feed exposes manual retry at its deadline with default ProviderScope',
    (tester) async {
      final fixture = (await tester.runAsync(
        () async => _ReadFixture('feed'),
      ))!;
      addTearDown(() async {
        await tester.runAsync(fixture.dispose);
      });
      await tester.pumpWidget(fixture.app(const SocialFeedScreen()));
      await tester.pump();
      expect(fixture.reads, 1);
      expect(find.text('공개한 기록을 불러오고 있어요.'), findsOneWidget);

      await tester.pump(_deadline);
      await tester.pumpAndSettle();
      expect(find.text('기록을 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('공개한 기록을 불러오고 있어요.'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(fixture.reads, 1, reason: 'Only an explicit retry may read again');

      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(fixture.reads, 2);
      expect(find.text('오늘의 첫 장면을 남겨보세요.'), findsOneWidget);
      fixture.finishOldRead();
      await tester.pumpAndSettle();
      expect(find.text('오늘의 첫 장면을 남겨보세요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    },
  );

  testWidgets(
    'profile exposes manual retry at its deadline with default ProviderScope',
    (tester) async {
      final fixture = (await tester.runAsync(
        () async => _ReadFixture('profile'),
      ))!;
      addTearDown(() async {
        await tester.runAsync(fixture.dispose);
      });
      await tester.pumpWidget(
        fixture.app(const SocialProfileScreen(userId: _other)),
      );
      await tester.pump();
      expect(fixture.reads, 1);
      expect(find.text('프로필을 불러오고 있어요.'), findsOneWidget);

      await tester.pump(_deadline);
      await tester.pumpAndSettle();
      expect(find.text('프로필을 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('프로필을 불러오고 있어요.'), findsNothing);
      await tester.pump(const Duration(seconds: 30));
      expect(fixture.reads, 1);

      await tester.tap(find.widgetWithText(OutlinedButton, '다시 시도'));
      await tester.pumpAndSettle();
      expect(fixture.reads, 2);
      expect(find.text('새로 확인한 프로필'), findsOneWidget);
      fixture.finishOldRead();
      await tester.pumpAndSettle();
      expect(find.text('새로 확인한 프로필'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(fixture.dispose);
    },
  );
}
