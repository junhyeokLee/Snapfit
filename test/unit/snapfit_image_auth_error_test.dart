import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/shared/snapfit_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = '11111111-1111-4111-8111-111111111111';
const _ownerB = '22222222-2222-4222-8222-222222222222';

class _ImageCache extends Mock implements BaseCacheManager {}

Future<void> _setOwner(String owner) async {
  final expiry = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  final token =
      '${base64UrlEncode(utf8.encode('{"alg":"none"}'))}.'
      '${base64UrlEncode(utf8.encode(jsonEncode({'sub': owner, 'exp': expiry})))}.fixture';
  await Supabase.instance.client.auth.setInitialSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': expiry,
      'user': {
        'id': owner,
        'aud': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-11-01T00:00:00Z',
      },
    }),
  );
  await Future<void>.delayed(Duration.zero);
}

void _refreshError() {
  // Exercise the same broadcast error delivered by an offline SDK refresh.
  // ignore: invalid_use_of_internal_member
  Supabase.instance.client.auth.notifyException(
    AuthRetryableFetchException(message: 'isolated offline refresh'),
    StackTrace.current,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  final cache = _ImageCache();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://image-auth-fixture.invalid',
      anonKey: 'fixture',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('', 204, request: request);
      }),
    );
  });

  setUp(() async {
    SnapfitImage.storageOwnerForTesting = null;
    requests.clear();
    await _setOwner(_ownerA);
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    await Supabase.instance.dispose();
  });

  test(
    'a refresh error preserves this owner and its reusable signed URL',
    () async {
      var signed = 0;
      final image = SnapfitImage(
        urlOrGs:
            'supabase://album-assets/$_ownerA/moments/auth-error/photo.jpg',
        cacheManager: cache,
        resolveStorageUrlForTesting: (_) async {
          signed++;
          return 'https://image-fixture.invalid/authorized-photo.jpg';
        },
      );
      final before = await image.resolveImageProvider();
      expect(before, isA<CachedNetworkImageProvider>());
      _refreshError();
      await Future<void>.delayed(Duration.zero);
      final after = await image.resolveImageProvider();
      expect(
        (after as CachedNetworkImageProvider).url,
        (before as CachedNetworkImageProvider).url,
      );
      expect(signed, 1);
      expect(Supabase.instance.client.auth.currentUser?.id, _ownerA);
      expect(
        requests,
        isEmpty,
        reason: 'No logout or network fallback is allowed.',
      );
    },
  );

  test('a refresh error cannot relax the A to B to A signing fence', () async {
    final pending = Completer<String>();
    final image = SnapfitImage(
      urlOrGs: 'supabase://album-assets/$_ownerA/moments/auth-cycle/photo.jpg',
      cacheManager: cache,
      resolveStorageUrlForTesting: (_) => pending.future,
    );
    final resolved = image.resolveImageProvider();
    final rejected = expectLater(resolved, throwsStateError);
    _refreshError();
    await Future<void>.delayed(Duration.zero);
    await _setOwner(_ownerB);
    await _setOwner(_ownerA);
    pending.complete(
      'https://image-fixture.invalid/obsolete-private-photo.jpg',
    );
    await rejected;
    expect(Supabase.instance.client.auth.currentUser?.id, _ownerA);
    expect(requests, isEmpty);
  });
}
