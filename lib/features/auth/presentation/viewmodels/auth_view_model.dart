import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/env.dart';
import '../../../../core/interceptors/token_storage.dart';
import '../../../../core/supabase/supabase_provider.dart';
import '../../data/dto/auth_response.dart';
import '../../domain/auth_service.dart';
import '../../domain/native_kakao_login.dart';
import '../../domain/account_deletion_request.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    tokenStorage: ref.read(tokenStorageProvider),
    supabase: ref.read(supabaseClientProvider),
  );
});

final authUserIdProvider = FutureProvider<String?>((ref) async {
  return ref.read(tokenStorageProvider).getResolvedUserId();
});

/// 홈 상단 로그인 상태 표시용
final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, UserInfo?>(
  AuthViewModel.new,
  // A bounded account check must expose its retry UI after one deadline.
  // Riverpod's automatic build retries would keep that failure loading.
  retry: (_, _) => null,
);

/// Bounds both browser session verification and platform storage reads.
final authStateLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 25),
);

class AuthViewModel extends AsyncNotifier<UserInfo?> {
  Future<void>? _googleInitializeFuture;
  int _sessionSyncRevision = 0;
  Future<void>? _sessionSyncFuture;
  ({bool sdk, String? token})? _sessionSyncKey;
  Completer<UserInfo?>? _initialUser;

  String? get _sdkOwner {
    try {
      return ref.read(supabaseClientProvider).auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String? get _sdkToken {
    try {
      return ref.read(supabaseClientProvider).auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  @override
  FutureOr<UserInfo?> build() {
    final initial = Completer<UserInfo?>();
    _initialUser = initial;
    StreamSubscription<AuthState>? subscription;
    try {
      final client = ref.read(supabaseClientProvider);
      var observedOwner = client.auth.currentUser?.id;
      subscription = client.auth.onAuthStateChange.listen((event) {
        final next = event.session?.user.id;
        if (next == observedOwner)
          return; // token refresh is not an account swap.
        observedOwner = next;
        final revision = ++_sessionSyncRevision;
        _sessionSyncFuture = null;
        _sessionSyncKey = null;
        // Invalidate immediately, before a rapid A → B → A can be coalesced.
        if (initial.isCompleted) state = const AsyncLoading();
        scheduleMicrotask(() {
          if (ref.mounted && revision == _sessionSyncRevision) {
            unawaited(_loadSession(fromSdk: kIsWeb));
          }
        });
      }, onError: (Object _, StackTrace __) {});
    } catch (_) {
      // A fixture without an SDK session cannot gain private account data.
    }
    ref.onDispose(() {
      unawaited(subscription?.cancel());
      _sessionSyncRevision++;
      _sessionSyncFuture = null;
      _sessionSyncKey = null;
      if (!initial.isCompleted) initial.complete(null);
    });
    // Only the newest session operation resolves build's future. Otherwise a
    // delayed initial A response could overwrite a newer signed-out/B state.
    unawaited(_loadSession(fromSdk: kIsWeb, initial: true));
    return initial.future;
  }

  Future<void> refresh() => _loadSession(fromSdk: kIsWeb);

  /// Called after the SDK exchanges/restores its session. Matching validated
  /// accounts remain mounted while background verification is in progress.
  Future<void> synchronizeSupabaseSession() => _loadSession(fromSdk: true);

  Future<void> _loadSession({required bool fromSdk, bool initial = false}) {
    final key = (sdk: fromSdk, token: _sdkToken);
    final pending = _sessionSyncFuture;
    if (pending != null && _sessionSyncKey == key) return pending;
    final revision = ++_sessionSyncRevision;
    final owner = _sdkOwner;
    final previous = initial ? null : state.asData?.value;
    final retain = previous != null && previous.id == owner;
    if (!initial && !retain) state = const AsyncLoading();
    final timeout = ref.read(authStateLoadTimeoutProvider);
    final initialUser = _initialUser;

    bool current() => ref.mounted && revision == _sessionSyncRevision;
    void data(UserInfo? user) {
      if (initialUser != null && !initialUser.isCompleted) {
        initialUser.complete(user);
      } else {
        state = AsyncData(user);
      }
    }

    late final Future<void> request;
    request =
        () async {
          try {
            final user =
                await (fromSdk
                        ? ref
                              .read(authServiceProvider)
                              .synchronizeSupabaseSession()
                              .then((auth) => auth?.user)
                        : ref.read(tokenStorageProvider).getUserInfo())
                    .timeout(timeout);
            if (!current()) return;
            if (owner != _sdkOwner) {
              data(null);
              return;
            }
            // Native secure storage is not an authenticated SDK session by itself.
            data(user?.id == owner ? user : null);
            ref.invalidate(authUserIdProvider);
            if (fromSdk && user != null) {
              // Consent sync must not hold navigation or the login state hostage.
              unawaited(
                syncConsentIfPresent()
                    .timeout(timeout)
                    .catchError((Object _) {}),
              );
            }
          } catch (error, stack) {
            if (!current()) return;
            if (owner != _sdkOwner) {
              data(null);
              return;
            }
            final transient =
                error is TimeoutException ||
                error is AuthRetryableFetchException ||
                error is SocketException;
            if (retain &&
                transient &&
                previous != null &&
                previous.id == _sdkOwner) {
              data(previous);
            } else if (initialUser != null && !initialUser.isCompleted) {
              initialUser.completeError(error, stack);
            } else {
              state = AsyncError(error, stack);
            }
          }
        }().whenComplete(() {
          if (identical(_sessionSyncFuture, request)) {
            _sessionSyncFuture = null;
            _sessionSyncKey = null;
          }
        });
    _sessionSyncKey = key;
    return _sessionSyncFuture = request;
  }

  /// Web photo pickers provide bytes rather than a dart:io File.
  Future<void> updateProfileImageBytes(
    Uint8List bytes, {
    String fileName = 'profile.jpg',
  }) async {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
      throw Exception('프로필 사진은 20MB 이하 이미지로 선택해주세요.');
    }
    final storage = ref.read(tokenStorageProvider);
    final current = await storage.getUserInfo();
    final client = ref.read(supabaseClientProvider);
    if (current == null || current.id != client.auth.currentUser?.id) {
      throw Exception('로그인한 계정을 확인한 뒤 사진을 변경해주세요.');
    }
    final owner = current.id;
    void sameOwner() {
      if (client.auth.currentUser?.id != owner) {
        throw Exception('로그인 계정이 변경되었어요. 사진 변경을 다시 시작해주세요.');
      }
    }

    var normalized = bytes;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1920,
        minHeight: 1920,
        quality: 88,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty && compressed.length < bytes.length) {
        normalized = compressed;
      }
    } catch (_) {
      // Some browser codecs have no plugin encoder. Keep the selected image
      // bytes and their actual MIME type; never label PNG/WebP as JPEG.
    }
    sameOwner();
    final extension = _imageBytesExtension(normalized);
    if (extension == null || normalized.length > 10 * 1024 * 1024) {
      throw Exception('10MB 이하의 JPG, PNG, WebP 사진으로 다시 선택해주세요.');
    }
    final path =
        '$owner/profile_${DateTime.now().microsecondsSinceEpoch}.$extension';
    await client.storage
        .from('avatars')
        .uploadBinary(
          path,
          normalized,
          fileOptions: FileOptions(
            contentType: _profileImageContentType(extension),
            upsert: false,
          ),
        );
    sameOwner();
    final url = client.storage.from('avatars').getPublicUrl(path);
    await client.from('profiles').upsert({
      'id': owner,
      'email': current.email,
      'name': current.name,
      'provider': current.provider,
      'avatar_url': url,
    });
    sameOwner();
    await storage.saveUserInfo(current.copyWith(profileImageUrl: url));
    sameOwner();
    final updated = await storage.getUserInfo();
    sameOwner();
    if (ref.mounted) state = AsyncData(updated);
  }

  String? _imageBytesExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff)
      return 'jpg';
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a)
      return 'png';
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP')
      return 'webp';
    return null;
  }

  /// 프로필 이미지를 Supabase Storage에 업로드하고 로컬 유저 정보 갱신
  Future<void> updateProfileImage(File image) async {
    final fileToUpload = await _normalizeImageForUpload(image);
    final storage = ref.read(tokenStorageProvider);
    final current = await storage.getUserInfo();
    if (current == null) {
      throw Exception('로그인 후 프로필 이미지를 변경할 수 있습니다.');
    }
    final userId = current.id.trim();
    if (userId.isEmpty) {
      throw Exception('로그인 후 프로필 이미지를 변경할 수 있습니다.');
    }

    final supabase = ref.read(supabaseClientProvider);
    try {
      final ext = _profileImageExtension(fileToUpload.path);
      final objectPath =
          '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supabase.storage
          .from('avatars')
          .upload(
            objectPath,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: _profileImageContentType(ext),
              upsert: true,
            ),
          );
      final publicUrl = supabase.storage
          .from('avatars')
          .getPublicUrl(objectPath);
      await supabase.from('profiles').upsert({
        'id': userId,
        'email': current.email,
        'name': current.name,
        'provider': current.provider,
        'avatar_url': publicUrl,
      });
      await storage.saveUserInfo(current.copyWith(profileImageUrl: publicUrl));
      state = AsyncData(await storage.getUserInfo());
    } catch (e) {
      throw Exception('Supabase 프로필 이미지 업로드에 실패했습니다: $e');
    }
  }

  String _profileImageExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    return 'jpg';
  }

  String _profileImageContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<File> _normalizeImageForUpload(File image) async {
    final tmpDir = await getTemporaryDirectory();
    File result = image;
    int quality = 88;
    int minWidth = 1920;
    int minHeight = 1920;
    final targetSize = 900 * 1024;

    for (int i = 0; i < 4; i++) {
      final targetPath =
          '${tmpDir.path}/${DateTime.now().millisecondsSinceEpoch}_profile_$i.jpg';
      try {
        final compressed = await FlutterImageCompress.compressAndGetFile(
          result.absolute.path,
          targetPath,
          quality: quality,
          minWidth: minWidth,
          minHeight: minHeight,
          format: CompressFormat.jpeg,
        );
        if (compressed == null) break;
        result = File(compressed.path);
        if (await result.length() <= targetSize) {
          break;
        }
        quality = (quality - 14).clamp(45, 95).toInt();
        minWidth = (minWidth * 0.82).toInt();
        minHeight = (minHeight * 0.82).toInt();
      } catch (_) {
        break;
      }
    }
    return result;
  }

  Future<void> logout() async {
    _sessionSyncRevision++;
    final initial = _initialUser;
    if (initial != null && !initial.isCompleted) initial.complete(null);
    state = const AsyncData(null);
    unawaited(ref.read(authServiceProvider).logout());
  }

  Future<void> deleteAccount() async {
    await ref.read(authServiceProvider).deleteAccount();
  }

  Future<AccountDeletionRequest> requestAccountDeletion() =>
      ref.read(authServiceProvider).requestAccountDeletion();

  Future<void> loginWithKakao() async {
    if (kIsWeb) {
      await ref
          .read(authServiceProvider)
          .loginWithWebProvider(OAuthProvider.kakao);
      return;
    }
    if (Env.kakaoNativeAppKey.isEmpty) {
      throw Exception('KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.');
    }
    final OAuthToken token = await ensureNativeKakaoEmailConsent(
      await loginWithNativeKakao(),
    );

    final accessToken = token.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('카카오 로그인 토큰을 가져올 수 없습니다.');
    }
    final idToken = token.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException(
        '카카오 ID 토큰을 가져올 수 없습니다. Kakao Developers에서 OpenID Connect를 활성화하고 Supabase Kakao Provider 설정을 확인해주세요.',
        code: 'kakao_oidc_unavailable',
      );
    }

    await ref
        .read(authServiceProvider)
        .loginWithKakaoToken(accessToken, idToken: idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitializeFuture ??= GoogleSignIn.instance.initialize(
      clientId: Env.googleIosClientId.isEmpty ? null : Env.googleIosClientId,
      serverClientId: Env.googleWebClientId,
    );
  }

  Future<void> loginWithGoogle() async {
    if (kIsWeb) {
      await ref
          .read(authServiceProvider)
          .loginWithWebProvider(OAuthProvider.google);
      return;
    }
    if (Env.googleWebClientId.isEmpty) {
      throw Exception('GOOGLE_WEB_CLIENT_ID가 설정되지 않았습니다.');
    }
    await _ensureGoogleInitialized();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw Exception(
        '구글 ID 토큰을 가져올 수 없습니다. GOOGLE_WEB_CLIENT_ID가 Supabase Google Provider의 Web Client ID와 일치하는지, Android SHA-1/SHA-256 및 iOS client ID 설정이 등록되어 있는지 확인해주세요.',
      );
    }

    await ref.read(authServiceProvider).loginWithGoogleIdToken(idToken);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    await ref
        .read(authServiceProvider)
        .loginWithEmail(email: email, password: password);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
    await syncConsentIfPresent();
  }

  Future<void> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required bool marketingOptIn,
  }) async {
    final auth = await ref
        .read(authServiceProvider)
        .signUpWithEmail(name: name, email: email, password: password);
    if (auth != null) {
      state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
      await syncConsentIfPresent();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await ref.read(authServiceProvider).requestPasswordReset(email);
  }

  Future<void> resendEmailConfirmation(String email) async {
    await ref.read(authServiceProvider).resendEmailConfirmation(email);
  }

  Future<void> verifyEmailConfirmation({
    required String email,
    required String token,
  }) async {
    final auth = await ref
        .read(authServiceProvider)
        .verifyEmailConfirmation(email: email, token: token);
    if (!ref.mounted) return;
    // The explicit verification already checked getUser. A slower restore that
    // started before it must not replace this result with an old login error.
    _sessionSyncRevision++;
    state = AsyncData(auth.user);
    ref.invalidate(authUserIdProvider);
    unawaited(syncConsentIfPresent().catchError((Object _) {}));
  }

  Future<String?> handleAuthCallback(Uri uri) async {
    final redirectType = await ref
        .read(authServiceProvider)
        .handleAuthCallback(uri);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
    await syncConsentIfPresent();
    return redirectType;
  }

  Future<void> updatePassword(String password) async {
    await ref.read(authServiceProvider).updatePassword(password);
    state = AsyncData(await ref.read(tokenStorageProvider).getUserInfo());
  }

  Future<void> syncConsentIfPresent() async {
    // Legal consent is retained locally and retried on the next login. A
    // bookkeeping outage must not keep an already authenticated route loading.
    try {
      await ref
          .read(authServiceProvider)
          .syncConsentIfPresent()
          .timeout(ref.read(authStateLoadTimeoutProvider));
    } catch (_) {}
  }
}
