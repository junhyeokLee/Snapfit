import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/core/utils/storage_url_resolver.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

class _Buckets extends Mock implements SupabaseStorageClient {}

class _Files extends Mock implements StorageFileApi {}

class _Asset extends Mock implements AssetEntity {}

class _Cache extends Mock implements BaseCacheManager {}

class _Codec extends UnsupportedFlutterImageCompress {
  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
  }) async => image;
}

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-25',
);

String _url(ImageProvider provider) =>
    (provider as CachedNetworkImageProvider).url;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Auth auth;
  late _Files files;
  late String? actor;
  late List<String> uploads;
  late List<List<String>> removals;
  late FlutterImageCompressPlatform originalCodec;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
  });
  setUp(() {
    client = _Client();
    auth = _Auth();
    files = _Files();
    final buckets = _Buckets();
    actor = 'owner-a';
    uploads = [];
    removals = [];
    when(() => client.auth).thenReturn(auth);
    when(
      () => auth.currentUser,
    ).thenAnswer((_) => actor == null ? null : _user(actor!));
    when(() => client.storage).thenReturn(buckets);
    when(() => buckets.from('album-assets')).thenReturn(files);
    when(
      () => files.uploadBinary(
        any(),
        any(),
        fileOptions: any(named: 'fileOptions'),
      ),
    ).thenAnswer((call) async {
      uploads.add(call.positionalArguments.first as String);
      return call.positionalArguments.first as String;
    });
    when(() => files.remove(any())).thenAnswer((call) async {
      removals.add(List<String>.from(call.positionalArguments.first as List));
      return [];
    });
    originalCodec = FlutterImageCompressPlatform.instance;
    FlutterImageCompressPlatform.instance = _Codec();
    SnapfitImage.storageOwnerForTesting = () => actor;
  });
  tearDown(() {
    actor = null;
    SnapfitImage.storageOwnerForTesting = null;
    FlutterImageCompressPlatform.instance = originalCodec;
  });

  test('saved album paths bind the uploader and exact album', () {
    expect(
      StorageService.userScopedAlbumAssetPath(
        userId: 'editor-b',
        albumId: 42,
        relativePath: 'albums/images/photo.jpg',
      ),
      'editor-b/albums/42/images/photo.jpg',
    );
    for (final path in [
      'albums/../secret.jpg',
      'albums//photo.jpg',
      r'albums\photo.jpg',
    ]) {
      expect(
        () => StorageService.userScopedAlbumAssetPath(
          userId: 'editor-b',
          albumId: 42,
          relativePath: path,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => StorageService.userScopedAlbumAssetPath(
        userId: 'editor-b',
        albumId: 0,
        relativePath: 'albums/images/photo.jpg',
      ),
      throwsArgumentError,
    );
  });

  test(
    'cover pairs return private markers scoped to the shared album',
    () async {
      final result = await StorageService(
        supabase: client,
      ).uploadCoverVariants(Uint8List.fromList([1, 2, 3]), albumId: 42);
      expect(uploads, hasLength(2));
      expect(
        uploads.every((path) => path.startsWith('owner-a/albums/42/covers/')),
        isTrue,
      );
      expect(result.originalUrl, 'supabase://album-assets/${uploads.first}');
      expect(result.previewUrl, 'supabase://album-assets/${uploads.last}');
      expect(result.originalUrl, result.originalGsPath);
    },
  );

  test(
    'failed cover preview rejects the whole pair and cleans its exact original',
    () async {
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((call) async {
        final path = call.positionalArguments.first as String;
        if (path.endsWith('_preview.jpg'))
          throw const StorageException('fixture failure');
        uploads.add(path);
        return path;
      });
      await expectLater(
        StorageService(
          supabase: client,
        ).uploadCoverVariants(Uint8List.fromList([1, 2, 3]), albumId: 42),
        throwsA(isA<StorageException>()),
      );
      expect(removals.single, uploads);
    },
  );

  test(
    'native photo preview failure cannot return an original-only success',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'snapfit-collaboration-photo-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/sample.jpg',
      ).writeAsBytes([1, 2, 3]);
      final asset = _Asset();
      when(() => asset.file).thenAnswer((_) async => file);
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((call) async {
        final path = call.positionalArguments.first as String;
        if (path.endsWith('_preview.jpg'))
          throw const StorageException('fixture failure');
        uploads.add(path);
        return path;
      });
      await expectLater(
        StorageService(
          supabase: client,
        ).uploadImageVariants(asset, albumId: 42),
        throwsA(isA<StorageException>()),
      );
      expect(uploads.single, startsWith('owner-a/albums/42/images/'));
      expect(removals.single, uploads);
    },
  );

  test(
    'account change during upload prevents preview and cleanup with a new actor',
    () async {
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((call) async {
        final path = call.positionalArguments.first as String;
        uploads.add(path);
        actor = 'owner-b';
        return path;
      });
      await expectLater(
        StorageService(
          supabase: client,
        ).uploadCoverVariants(Uint8List.fromList([1, 2, 3]), albumId: 42),
        throwsStateError,
      );
      expect(uploads, hasLength(1));
      expect(removals, isEmpty);
    },
  );

  test(
    'private album links are short-lived and late signatures reject account changes',
    () async {
      final signing = Completer<String>();
      when(
        () => files.createSignedUrl('owner-a/albums/42/covers/photo.jpg', 60),
      ).thenAnswer((_) => signing.future);
      final request = resolveStorageImageUrl(
        'supabase://album-assets/owner-a/albums/42/covers/photo.jpg',
        supabase: client,
      );
      final rejected = expectLater(request, throwsStateError);
      actor = 'owner-b';
      signing.complete('https://fixture.invalid/signed-photo.jpg');
      await rejected;
      verify(
        () => files.createSignedUrl('owner-a/albums/42/covers/photo.jpg', 60),
      ).called(1);
    },
  );

  test(
    'legacy URLs from this project renew private authorization and reject foreign hosts',
    () async {
      const base = 'https://project.supabase.co/storage/v1';
      const path = 'owner-a/albums/images/photo.jpg';
      for (final kind in ['public', 'sign', 'authenticated']) {
        final parsed = parseLegacyAlbumAssetUrl(
          '$base/object/$kind/album-assets/$path?token=expired',
          storageBaseUrl: base,
        );
        expect(parsed?.bucket, 'album-assets');
        expect(parsed?.path, path);
      }
      expect(
        parseLegacyAlbumAssetUrl(
          'https://other.supabase.co/storage/v1/object/public/album-assets/$path',
          storageBaseUrl: base,
        ),
        isNull,
      );
      expect(
        parseLegacyAlbumAssetUrl(
          '$base/object/public/avatars/$path',
          storageBaseUrl: base,
        ),
        isNull,
      );
    },
  );

  test('legacy private public URLs request a fresh authorized signature', () async {
    final buckets = client.storage;
    when(
      () => buckets.url,
    ).thenReturn('https://project.supabase.co/storage/v1');
    when(
      () => files.createSignedUrl('owner-a/albums/images/photo.jpg', 60),
    ).thenAnswer(
      (_) async =>
          'https://project.supabase.co/storage/v1/object/sign/album-assets/photo?token=fresh',
    );
    final result = await resolveStorageImageUrl(
      'https://project.supabase.co/storage/v1/object/public/album-assets/owner-a/albums/images/photo.jpg',
      supabase: client,
    );
    expect(result, endsWith('token=fresh'));
    verify(
      () => files.createSignedUrl('owner-a/albums/images/photo.jpg', 60),
    ).called(1);
  });

  test(
    'cleanup preserves referenced files and never deletes another owner path',
    () async {
      when(
        () => files.remove(['owner-a/albums/42/referenced.jpg']),
      ).thenThrow(const StorageException('referenced object'));
      await StorageService(supabase: client).removeUnreferencedAlbumUploads([
        'supabase://album-assets/owner-a/albums/42/referenced.jpg',
        'supabase://album-assets/owner-b/albums/42/foreign.jpg',
        'supabase://album-assets/owner-a/albums/42/orphan.jpg',
      ], expectedOwner: 'owner-a');
      expect(removals, [
        ['owner-a/albums/42/orphan.jpg'],
      ]);
      verifyNever(() => files.remove(['owner-b/albums/42/foreign.jpg']));
    },
  );

  test('cleanup does nothing after account changes', () async {
    actor = 'owner-b';
    await StorageService(supabase: client).removeUnreferencedAlbumUploads([
      'supabase://album-assets/owner-a/albums/42/orphan.jpg',
    ], expectedOwner: 'owner-a');
    verifyNever(() => files.remove(any()));
  });

  test('a new account cannot reuse a previous account signing cache', () async {
    final requested = <String?>[];
    final image = SnapfitImage(
      cacheManager: _Cache(),
      urlOrGs: 'supabase://album-assets/owner-a/albums/42/photo.jpg',
      resolveStorageUrlForTesting: (_) async {
        requested.add(actor);
        return 'https://fixture.invalid/$actor.jpg';
      },
    );
    expect(_url(await image.resolveImageProvider()), endsWith('/owner-a.jpg'));
    actor = 'owner-b';
    expect(_url(await image.resolveImageProvider()), endsWith('/owner-b.jpg'));
    expect(requested, ['owner-a', 'owner-b']);
  });

  test(
    'new account signing does not join an old pending request or accept its late response',
    () async {
      final first = Completer<String>();
      var calls = 0;
      final image = SnapfitImage(
        cacheManager: _Cache(),
        urlOrGs: 'supabase://album-assets/owner-a/albums/43/photo.jpg',
        resolveStorageUrlForTesting: (_) {
          calls++;
          return actor == 'owner-a'
              ? first.future
              : Future.value('https://fixture.invalid/b.jpg');
        },
      );
      final old = image.resolveImageProvider();
      final rejected = expectLater(old, throwsStateError);
      actor = 'owner-b';
      expect(_url(await image.resolveImageProvider()), endsWith('/b.jpg'));
      first.complete('https://fixture.invalid/a.jpg');
      await rejected;
      expect(_url(await image.resolveImageProvider()), endsWith('/b.jpg'));
      expect(calls, 2);
    },
  );
}
