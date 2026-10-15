import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';

import '../helpers/mock_repositories.dart';
import 'browser_photo_import_test.dart' show browserPhotoFixture;

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

class _Buckets extends Mock implements SupabaseStorageClient {}

class _Files extends Mock implements StorageFileApi {}

class _Storage extends Mock implements StorageService {}

User _user(String id) => User(
  id: id,
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-10-15',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Client client;
  late _Auth auth;
  late _Files files;
  late List<({String path, Uint8List bytes, FileOptions options})> uploads;
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(const FileOptions());
    registerFallbackValue(
      AssetEntity(id: 'native', typeInt: 1, width: 10, height: 10),
    );
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
  });
  setUp(() {
    client = _Client();
    auth = _Auth();
    files = _Files();
    final buckets = _Buckets();
    uploads = [];
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(_user('owner-a'));
    when(() => client.storage).thenReturn(buckets);
    when(() => buckets.from(any())).thenReturn(files);
    when(
      () => files.uploadBinary(
        any(),
        any(),
        fileOptions: any(named: 'fileOptions'),
      ),
    ).thenAnswer((call) async {
      uploads.add((
        path: call.positionalArguments[0] as String,
        bytes: call.positionalArguments[1] as Uint8List,
        options: call.namedArguments[#fileOptions] as FileOptions,
      ));
      return call.positionalArguments[0] as String;
    });
    when(() => files.getPublicUrl(any())).thenAnswer(
      (call) => 'https://fixture.test/${call.positionalArguments[0]}',
    );
    when(() => files.remove(any())).thenAnswer((_) async => []);
  });

  test(
    'browser upload sends original unchanged and JPEG preview under current user scope',
    () async {
      final original = browserPhotoFixture();
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-a',
        name: 'source.png',
        bytes: original,
      );
      final result = await StorageService(
        supabase: client,
      ).uploadImageVariants(photo);
      expect(uploads.length, 2);
      expect(uploads[0].bytes, orderedEquals(original));
      expect(uploads[0].options.contentType, 'image/png');
      expect(uploads[0].path, startsWith('owner-a/albums/images/'));
      expect(uploads[0].path, endsWith('_orig.png'));
      expect(uploads[1].options.contentType, 'image/jpeg');
      expect(uploads[1].bytes.take(2), [0xff, 0xd8]);
      expect(result.originalGsPath, endsWith('_orig.png'));
      expect(result.previewGsPath, endsWith('_preview.jpg'));
    },
  );

  test(
    'account mismatch cannot upload another account local browser photo',
    () async {
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-b',
        name: 'source.png',
        bytes: browserPhotoFixture(),
      );
      await expectLater(
        StorageService(supabase: client).uploadImageVariants(photo),
        throwsStateError,
      );
      expect(uploads, isEmpty);
    },
  );

  test(
    'failed preview removes its partial pair and never returns a successful original-only result',
    () async {
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-a',
        name: 'source.png',
        bytes: browserPhotoFixture(),
      );
      when(
        () => files.uploadBinary(
          any(),
          any(),
          fileOptions: any(named: 'fileOptions'),
        ),
      ).thenAnswer((call) async {
        final path = call.positionalArguments[0] as String;
        if (path.endsWith('_preview.jpg'))
          throw const StorageException('fixture failure');
        return path;
      });
      await expectLater(
        StorageService(supabase: client).uploadImageVariants(photo),
        throwsA(isA<StorageException>()),
      );
      final removed =
          verify(() => files.remove(captureAny())).captured.single as List;
      expect(removed.single, endsWith('_orig.png'));
    },
  );

  test(
    'AI preview uses the same browser bytes and private owner-scoped bucket path',
    () async {
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-a',
        name: 'source.png',
        bytes: browserPhotoFixture(),
      );
      final results = await StorageService(
        supabase: client,
      ).uploadAiAlbumPreviews(draftId: 'chosen-draft', assets: [photo]);
      expect(uploads.single.path, startsWith('owner-a/chosen-draft/'));
      expect(uploads.single.options.contentType, 'image/jpeg');
      expect(
        results.single.storageUri,
        startsWith('supabase://ai-album-previews/owner-a/'),
      );
    },
  );

  test(
    'browser photo incomplete upload cannot persist an album or be swallowed as a successful save',
    () async {
      final photo = await BrowserPhotoAsset.fromBytes(
        ownerId: 'owner-a',
        name: 'source.png',
        bytes: browserPhotoFixture(),
      );
      final storage = _Storage(), albums = MockAlbumRepository();
      when(() => storage.uploadImageVariants(any())).thenAnswer(
        (_) async => const UploadedUrls(
          previewGsPath: 'supabase://album-assets/owner-a/preview.jpg',
        ),
      );
      final service = AlbumPersistenceService(storage, albums);
      await expectLater(
        service.performBackgroundUpload(
          albumId: 1,
          canvasSize: const Size(300, 300),
          currentLayers: [
            LayerModel(
              id: 'browser-layer',
              type: LayerType.image,
              position: Offset.zero,
              asset: photo,
            ),
          ],
          coverImageBytes: null,
          themeLabel: 'classic',
          title: 'browser album',
          coverRatio: 1,
          targetPages: 20,
        ),
        throwsStateError,
      );
      verifyNever(() => albums.updateAlbum(any(), any()));
    },
  );
}
