import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/gallery/browser_gallery_repository.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_files.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/shared/widgets/browser_photo_selection_sheet.dart';

import '../fixtures/ai_template_design_fixture.dart';
import '../unit/browser_photo_import_test.dart' show browserPhotoFixture;
import 'ai_album_start_step_test.dart' show wrapCreation;

class _Owner extends Notifier<String?> {
  @override
  String? build() => 'owner-a';
  void change(String? owner) => state = owner;
}

final _ownerProvider = NotifierProvider<_Owner, String?>(_Owner.new);

void main() {
  testWidgets(
    'browser photo selection keeps an existing selection on chooser cancellation and hides it on account change',
    (tester) async {
      final bytes = browserPhotoFixture();
      final repository = BrowserGalleryRepository(
        currentOwner: () => 'owner-a',
      );
      await tester.runAsync(
        () => repository.importFiles([
          BrowserPhotoFile(
            name: 'chosen.png',
            size: bytes.length,
            readBytes: () async => bytes,
          ),
        ]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            galleryRepositoryProvider.overrideWithValue(repository),
            visibleOrderOwnerProvider.overrideWith(
              (ref) => ref.watch(_ownerProvider),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BrowserPhotoSelectionSheet(
                maxSelection: 10,
                selectFiles: () async => const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('browser-photo-${repository.photos.single.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1장 선택 완료'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('browser-photo-pick-files')));
      await tester.pumpAndSettle();
      expect(find.textContaining('파일 선택을 취소했어요'), findsOneWidget);
      expect(find.text('1장 선택 완료'), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(BrowserPhotoSelectionSheet)),
      );
      container.read(_ownerProvider.notifier).change('owner-b');
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.text('1장 선택 완료'), findsNothing);
      expect(find.textContaining('로그인한 계정이 변경됐어요'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'browser picker shows named failures and expandable import results',
    (tester) async {
      final repository = BrowserGalleryRepository(
        currentOwner: () => 'owner-a',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            galleryRepositoryProvider.overrideWithValue(repository),
            visibleOrderOwnerProvider.overrideWith(
              (ref) => ref.watch(_ownerProvider),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: BrowserPhotoSelectionSheet(
                maxSelection: 10,
                selectFiles: () async => [
                  BrowserPhotoFile(
                    name: 'empty.jpg',
                    size: 0,
                    readBytes: () => throw StateError('must not read'),
                  ),
                  BrowserPhotoFile(
                    name: 'too-big.jpg',
                    size: 50000001,
                    readBytes: () => throw StateError('must not read'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('browser-photo-pick-files')));
      await tester.pumpAndSettle();
      expect(find.textContaining('empty.jpg · 사진 한 장은 50MB'), findsOneWidget);
      expect(find.textContaining('too-big.jpg · 사진 한 장은 50MB'), findsOneWidget);
      expect(find.text('0장 선택 완료'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('browser-photo-import-results')),
      );
      await tester.tap(
        find.byKey(const ValueKey('browser-photo-import-results')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('browser-photo-import-file-list')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'browser bytes fill a template slot without a native file or photo-manager call',
    (tester) async {
      final photo = await tester.runAsync(
        () => BrowserPhotoAsset.fromBytes(
          ownerId: 'owner-a',
          name: 'web.png',
          bytes: browserPhotoFixture(),
        ),
      );
      final design = templateDesignDraft().design!;
      var pages = design.buildLayers(
        targetSize: coverCanvasBaseSize(design.coverSize),
      );
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: wrapCreation(
            StatefulBuilder(
              builder: (context, setState) => TemplatePhotoFillStep(
                pages: pages,
                cover: design.coverSize,
                onChanged: (value) => setState(() => pages = value),
                onContinue: () {},
                pickPhoto: () async => photo,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('사진 추가'));
      await tester.pumpAndSettle();
      expect(
        pages.first.where((layer) => layer.type.name == 'image').single.asset,
        same(photo),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
