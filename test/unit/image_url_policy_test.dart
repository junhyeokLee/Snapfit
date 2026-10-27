import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/utils/image_url_policy.dart';
import 'package:snap_fit/core/utils/storage_url_resolver.dart';

void main() {
  const momentPath =
      '11111111-1111-4111-8111-111111111111/moments/'
      '22222222-2222-4222-8222-222222222222/'
      '33333333-3333-4333-8333-333333333333.png';

  for (final variant in ImageVariant.values) {
    test(
      '${variant.name} preserves the exact private photo object to sign',
      () {
        const source = 'supabase://album-assets/$momentPath';
        final transformed = imageUrlByVariant(source, variant: variant);
        expect(transformed, source);
        final reference = parseSupabaseStorageUri(transformed)!;
        expect(reference.bucket, 'album-assets');
        expect(reference.path, momentPath);
        expect(reference.path, isNot(contains('?')));
      },
    );

    test('${variant.name} leaves non-HTTP image references unchanged', () {
      for (final source in [
        'gs://snapfit.appspot.com/users/user/photo.jpg',
        'asset:assets/photos/photo.jpg',
        'assets/photos/photo.jpg',
        'blob:https://snapfit.test/upload-id',
        'data:image/png;base64,aW1hZ2U=',
      ]) {
        expect(imageUrlByVariant(source, variant: variant), source);
      }
    });

    test('${variant.name} does not rewrite Supabase storage URL parameters', () {
      for (final source in [
        'https://project.supabase.co/storage/v1/object/sign/album-assets/$momentPath?token=signed-token',
        'https://project.supabase.co/storage/v1/object/public/templates/photo.jpg',
        'https://media.snapfit.test/storage/v1/object/authenticated/album-assets/$momentPath',
        'https://media.snapfit.test/storage/v1/render/image/sign/album-assets/$momentPath?token=signed-token&width=800&quality=80',
      ]) {
        expect(imageUrlByVariant(source, variant: variant), source);
      }
    });
  }

  test(
    'Unsplash detail variants retain source parameters and use CDN sizing',
    () {
      final result = Uri.parse(
        imageUrlByVariant(
          'https://images.unsplash.com/photo-example?ixid=source&w=200&q=40',
          variant: ImageVariant.detail,
        ),
      );
      expect(result.queryParameters, {
        'ixid': 'source',
        'w': '1400',
        'q': '85',
        'auto': 'format',
        'fit': 'crop',
      });
      final thumb = Uri.parse(
        imageUrlByVariant('https://images.unsplash.com/photo-example'),
      );
      expect(thumb.queryParameters['w'], '480');
      expect(thumb.queryParameters['q'], '72');
    },
  );

  test('Firebase signed URLs and empty inputs keep their existing behavior', () {
    const source =
        'https://firebasestorage.googleapis.com/v0/b/bucket/o/photo.jpg?alt=media&token=access';
    expect(imageUrlByVariant(source), source);
    expect(imageUrlByVariant('   '), '');
    expect(
      imageUrlByVariant('  supabase://album-assets/$momentPath  '),
      'supabase://album-assets/$momentPath',
    );
  });
}
