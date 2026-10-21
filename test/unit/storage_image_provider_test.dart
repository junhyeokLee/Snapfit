import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/storage_url_resolver.dart';

void main() {
  for (final source in [
    'supabase://album-assets/owner/albums/images/photo_preview.jpg',
    'gs://legacy-albums/photo.jpg',
  ]) {
    test('saved photo fill resolves $source before network decoding', () async {
      final requested = <String>[];
      final provider = await resolveStorageImageProvider(
        source,
        resolveStorageUrl: (value) async {
          requested.add(value);
          return 'https://fixture.invalid/authorized-photo.jpg';
        },
      );
      expect(requested, [source]);
      expect(provider, isA<NetworkImage>());
      expect(
        (provider as NetworkImage).url,
        'https://fixture.invalid/authorized-photo.jpg',
      );
    });
  }

  test('external photo fill retains its original network URL', () async {
    const source = 'https://fixture.invalid/external-photo.jpg';
    final provider = await resolveStorageImageProvider(source);
    expect((provider as NetworkImage).url, source);
  });

  test('bundled photo fill never signs or downloads a local asset', () async {
    final provider = await resolveStorageImageProvider(
      'asset:assets/template_photos/summer.jpg',
      resolveStorageUrl: (_) => throw StateError('must not resolve asset'),
    );
    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).assetName,
      'assets/template_photos/summer.jpg',
    );
  });

  test('unauthorized photo fill is not decoded as a private marker', () async {
    await expectLater(
      resolveStorageImageProvider(
        'supabase://album-assets/other-owner/photo.jpg',
        resolveStorageUrl: (_) async => throw StateError('access denied'),
      ),
      throwsStateError,
    );
  });
}
