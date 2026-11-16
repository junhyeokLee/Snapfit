import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import '../helpers/creation_draft_fixtures.dart';
import '../helpers/mock_repositories.dart';
import '../helpers/unified_creation_fixtures.dart';
import '../support/store_detail_loading.dart';
import 'ai_album_start_step_test.dart' show wrapCreation;

const _owner = 'creation-test-owner';

PremiumTemplate _catalogTemplate(bool premium) => PremiumTemplate(
  id: 99001,
  title: '여행 디자인',
  coverImageUrl: '',
  previewImages: [],
  pageCount: 2,
  userCount: 0,
  isPremium: premium,
  templateJson: jsonEncode({
    'designWidth': 500,
    'designHeight': 500,
    'cover': {
      'layers': [
        {
          'id': 'cover-photo',
          'type': 'IMAGE',
          'x': .1,
          'y': .1,
          'width': .8,
          'height': .8,
          'payload': {'imageUrl': 'asset:assets/snapfit_home_square.jpg'},
        },
      ],
    },
    'pages': List.generate(
      2,
      (i) => {
        'layers': [
          {
            'id': 'photo-$i',
            'type': 'IMAGE',
            'x': .1,
            'y': .1,
            'width': .8,
            'height': .8,
          },
        ],
      },
    ),
  }),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  for (final premium in [false, true]) {
    storeDetailTestWidgets(
      'allowed catalog selection premium=$premium uses price-neutral source copy',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final template = _catalogTemplate(premium);
        final repo = MockTemplateRepository();
        stubGetTemplates(repo, [template]);
        final albums = RecordingCreationAlbums(owner: _owner);
        final store = MemoryCreationDraftStore();
        final accessRequests = <String>[];
        final card = find.byKey(const ValueKey('creation-template-99001'));
        Future<void> revealCard() async {
          final open = find.byKey(const ValueKey('creation-open-catalog'));
          if (open.evaluate().isNotEmpty) {
            await tester.ensureVisible(open);
            await tester.tap(open);
            await tester.pumpAndSettle();
          }
          final catalogue = find.byKey(
            const PageStorageKey('albumCreationHub'),
          );
          expect(catalogue, findsOneWidget);
          await tester.scrollUntilVisible(
            card,
            300,
            scrollable: find
                .descendant(of: catalogue, matching: find.byType(Scrollable))
                .first,
          );
          await tester.pumpAndSettle();
          expect(card.hitTestable(), findsOneWidget);
        }

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumCreationCatalogProvider.overrideWith(
                (ref) => Stream.value([template]),
              ),
              templateRepositoryProvider.overrideWithValue(repo),
              ...unifiedCreationBackendOverrides(albums: albums),
              albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
              albumEditorOwnerChangesProvider.overrideWith(
                (_) => const Stream.empty(),
              ),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: _owner, name: '테스트', provider: 'email'),
                ),
              ),
              albumCreationDraftStoreProvider.overrideWithValue(store),
            ],
            child: wrapCreation(
              const AlbumCreateFlowScreen(),
              pointShopGate:
                  (context, ref, {required productKey, required title}) async {
                    accessRequests.add(productKey);
                    expect(title, template.title);
                    return true;
                  },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          MediaQuery.sizeOf(tester.element(find.byType(AlbumCreateFlowScreen))),
          const Size(390, 844),
        );
        await revealCard();
        await tester.tap(card);
        await settleStoreDetail(tester);
        final preview = tester.widget<CreationTemplatePreview>(
          find.byType(CreationTemplatePreview),
        );
        expect(preview.pages.length, 3);
        expect(preview.pages.first.single.id, 'cover-photo');
        await tester.tap(find.text('이 디자인 선택'));
        await tester.pumpAndSettle();
        expect(accessRequests, ['template:server-99001']);
        expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
        final setup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(setup.sourceLabel, '선택한 템플릿');
        expect(setup.minPageCount, 20);
        expect(setup.selectedPageCount, 20);
        expect(setup.templatePageCount, 2);
        expect(
          setup.coverLayers!
              .where((l) => l.type == LayerType.image)
              .single
              .imageUrl,
          isNull,
        );
        final hard = find.byKey(const ValueKey('print-cover-hard'));
        await tester.ensureVisible(hard);
        await tester.tap(hard);
        await tester.pumpAndSettle();
        final changeDesign = find.byKey(
          const ValueKey('creation-change-design'),
        );
        await tester.ensureVisible(changeDesign);
        await tester.tap(changeDesign);
        await tester.pumpAndSettle();
        expect(find.text('디자인을 변경할까요?'), findsNothing);
        await revealCard();
        await tester.tap(card);
        await settleStoreDetail(tester);
        await tester.tap(find.text('이 디자인 선택'));
        await tester.pumpAndSettle();
        expect(accessRequests, [
          'template:server-99001',
          'template:server-99001',
        ]);
        final selectedSetup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(selectedSetup.selectedCover!.coverType, PrintCoverType.hard);
        expect(selectedSetup.documentPages!.length, 3);
        expect(selectedSetup.documentPages![1].single.id, 'photo-0');
        expect(selectedSetup.documentPages![2].single.id, 'photo-1');
        expect(selectedSetup.coverLayers!.single.imageUrl, isNull);
        final selectedCover = selectedSetup.selectedCover!;
        final coverLayers = selectedSetup.coverLayers!;
        final container = ProviderScope.containerOf(
          tester.element(find.byType(AlbumCreateFlowScreen)),
          listen: false,
        );
        final next = find.byKey(const ValueKey('creation-setup-next'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.byType(PageEditorScreen), findsOneWidget);
        final vm = container.read(albumEditorViewModelProvider.notifier);
        expect(albums.creates, 1);
        expect(albums.requestedOwners, [_owner]);
        expect(albums.requests.single.targetPages, 20);
        expect(vm.editingAlbumId, albums.albumId);
        expect(vm.selectedCover.productId, selectedCover.productId);
        expect(vm.selectedCover.coverType, PrintCoverType.hard);
        expect(vm.pages.length, 21);
        expect(vm.pages.first.layers.single.id, 'cover-photo');
        expect(vm.pages[1].layers.single.id, 'photo-0');
        expect(vm.pages[2].layers.single.id, 'photo-1');
        expect(vm.pages.skip(3).every((page) => page.layers.isEmpty), isTrue);
        final cover = vm.pages.first.layers.single;
        expect(cover.imageUrl, isNull);
        expect(cover.imageZoom, coverLayers.single.imageZoom);
        expect(cover.imageOffset, coverLayers.single.imageOffset);
        expect(cover.width / cover.height, closeTo(1, .0001));
        final linked = store.draft!;
        expect(linked.createdAlbumId, albums.albumId);
        expect(linked.cover.productId, selectedCover.productId);
        expect(linked.creationAttempt!.requestId, albums.requestIds.single);
        final checkpoint = linked.editorCheckpoint!;
        expect(checkpoint.sourceUpdatedAt, RecordingCreationAlbums.revision);
        expect(checkpoint.pages.length, 21);
        expect(checkpoint.pages[1].layers.single.id, 'photo-0');
        expect(checkpoint.pages[2].layers.single.id, 'photo-1');
        expect(checkpoint.pages.first.layers.single.imageUrl, isNull);
        expect(checkpoint.pages.first.layers.single.imageZoom, cover.imageZoom);
        expect(
          checkpoint.pages.first.layers.single.imageOffset,
          cover.imageOffset,
        );
        expect(checkpoint.coverCanvas, const Size(500, 500));
        expect(checkpoint.innerCanvas, const Size(500, 500));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
