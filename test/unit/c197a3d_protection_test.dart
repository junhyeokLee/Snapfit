import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SnapfitImage keeps supabase storage URI resolver path protected', () {
    final source = File('lib/shared/snapfit_image.dart').readAsStringSync();

    expect(
      source,
      contains("import '../core/utils/storage_url_resolver.dart';"),
    );
    expect(source, contains('resolveStorageImageUrl(urlOrGs)'));
    expect(source, contains('parseSupabaseStorageUri(urlOrGs)'));
    expect(
      source,
      isNot(contains('FirebaseStorage.instance.refFromURL(urlOrGs)')),
    );
  });

  test('cover renderer does not reintroduce automatic image tone overlay', () {
    final coverSource = File(
      'lib/features/album/presentation/widgets/cover/cover.dart',
    ).readAsStringSync();
    final editorSource = File(
      'lib/features/album/presentation/viewmodels/album_editor_view_model.dart',
    ).readAsStringSync();

    expect(coverSource, isNot(contains('_BackdropSolidTone')));
    expect(coverSource, isNot(contains('backgroundImageUrl')));
    expect(coverSource, isNot(contains('extractBackdropToneFromImageUrl')));
    expect(
      editorSource,
      isNot(contains('_syncPageBackgroundColorFromImageTone')),
    );
    expect(
      editorSource,
      isNot(contains('unawaited(_syncPageBackgroundColorFromImageTone')),
    );
  });

  test(
    'album storage repair migration covers signed and legacy upload paths',
    () {
      final sql = File(
        'supabase/migrations/20260825113929_repair_album_assets_storage_policies.sql',
      ).readAsStringSync();

      expect(sql, contains("bucket_id = 'album-assets'"));
      expect(sql, contains('(storage.foldername(name))[1] = auth.uid()::text'));
      expect(sql, contains("(storage.foldername(name))[1] = 'albums'"));
      expect(sql, contains('album_assets_legacy_authenticated_insert'));
    },
  );
}
