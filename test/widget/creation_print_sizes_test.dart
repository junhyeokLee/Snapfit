import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_template.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';

import 'ai_album_start_step_test.dart' show wrapCreation;
import 'album_settings_redesign_test.dart' show openAlbumSettingsSection;
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/unified_creation_fixtures.dart';

const _owner = 'print-settings-owner';

class _Auth extends AuthViewModel {
  // A fixed owner permits the real create boundary without loading a session.
  @override
  FutureOr<UserInfo?> build() =>
      const UserInfo(id: _owner, name: '인쇄 설정 검증', provider: 'email');
}

Future<ProviderContainer> _mount(WidgetTester tester, Widget child) async {
  final albums = RecordingCreationAlbums(owner: _owner);
  final container = ProviderContainer(
    overrides: [
      authViewModelProvider.overrideWith(_Auth.new),
      albumEditorOwnerReaderProvider.overrideWithValue(() => _owner),
      albumEditorOwnerChangesProvider.overrideWith(
        (ref) => const Stream.empty(),
      ),
      albumCreationDraftStoreProvider.overrideWithValue(
        MemoryCreationDraftStore(),
      ),
      ...unifiedCreationBackendOverrides(albums: albums),
    ],
  );
  addTearDown(() async {
    // Unmount consumers before disposing their explicitly owned test container.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: wrapCreation(child)),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  for (final innerPages in [19, 21, 79, 81]) {
    testWidgets(
      'template $innerPages pages preserves content and print bounds',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _mount(
          tester,
          AlbumCreateFlowScreen(
            initialCreationTemplate: AlbumCreationTemplate(
              title: '쪽수 확인',
              previewUrl: '',
              isPremium: false,
              cover: defaultCoverSize,
              pages: List.generate(innerPages + 1, (_) => <LayerModel>[]),
            ),
          ),
        );
        final setup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(setup.templatePageCount, innerPages);
        expect(setup.selectedPageCount, innerPages + 1);
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        if (innerPages > 80) {
          expect(button.onPressed, isNull);
          await openAlbumSettingsSection(tester, 'pages');
          expect(find.textContaining('80쪽을 초과'), findsOneWidget);
        } else {
          expect(button.onPressed, isNotNull);
        }
      },
    );
  }

  testWidgets(
    'all five physical sizes survive template selection and unified editor handoff',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final sourceCover = coverSizeForProduct('REDP_200X150_SOFT')!;
      final source = coverCanvasBaseSize(sourceCover);
      final layer = LayerModel(
        id: 'ratio-proof',
        type: LayerType.image,
        position: const Offset(20, 10),
        width: 100,
        height: 50,
      );
      final container = await _mount(
        tester,
        AlbumCreateFlowScreen(
          initialCreationTemplate: AlbumCreationTemplate(
            title: '가로 템플릿',
            previewUrl: '',
            isPremium: false,
            cover: sourceCover,
            pages: [
              [layer],
              [layer],
            ],
            pagesCanvasSize: source,
          ),
        ),
      );
      for (final cover in coverSizes) {
        final option = find.byKey(ValueKey('print-size-${cover.productId}'));
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        final setup = tester.widget<AlbumCreateStep1>(
          find.byType(AlbumCreateStep1),
        );
        expect(setup.selectedCover!.productId, cover.productId);
        expect(setup.selectedCover!.realSize, cover.realSize);
        expect(setup.selectedPageCount, 20);
        expect(setup.minPageCount, 20);
        expect(
          setup.coverLayers!.single.width / setup.coverLayers!.single.height,
          2,
        );
      }
      final current = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      final layersBeforeBindingChange = current.coverLayers;
      final hard = find.byKey(const ValueKey('print-cover-hard'));
      await tester.ensureVisible(hard);
      await tester.tap(hard);
      await tester.pumpAndSettle();
      final hardcoverSetup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(hardcoverSetup.selectedCover!.coverType, PrintCoverType.hard);
      expect(hardcoverSetup.coverLayers, same(layersBeforeBindingChange));
      final target = coverSizeForProduct('REDP_250X200_HARD')!;
      await tester.ensureVisible(
        find.byKey(ValueKey('print-size-${target.sizeProductId}')),
      );
      await tester.tap(
        find.byKey(ValueKey('print-size-${target.sizeProductId}')),
      );
      await tester.pumpAndSettle();
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(setup.coverLayers!.single.width, closeTo(125, .0001));
      expect(setup.coverLayers!.single.height, closeTo(62.5, .0001));
      expect(setup.coverLayers!.single.position.dy, closeTo(25.4, .0001));
      final next = find.byKey(const ValueKey('creation-setup-next'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.byType(PageEditorScreen), findsOneWidget);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(vm.selectedCover.productId, target.productId);
      expect(vm.selectedCover.ratio, 1.25);
      final expectedWidth = 125 * 500 / coverCanvasBaseSize(target).width;
      expect(vm.pages[1].layers.single.width, closeTo(expectedWidth, .0001));
      expect(
        vm.pages[1].layers.single.width / vm.pages[1].layers.single.height,
        2,
      );
      final albums =
          container.read(albumRepositoryProvider) as RecordingCreationAlbums;
      expect(albums.creates, 1);
      expect(vm.editingAlbumId, albums.albumId);
      final draft = await container
          .read(albumCreationDraftStoreProvider)
          .load(_owner);
      expect(draft!.createdAlbumId, albums.albumId);
      expect(
        draft.editorCheckpoint!.pages[1].layers.single.width,
        closeTo(expectedWidth, .0001),
      );
      expect(draft.editorCheckpoint!.coverCanvas, const Size(500, 400));
      expect(draft.editorCheckpoint!.innerCanvas, const Size(500, 400));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new album with a legacy portrait template chooses a supported square',
    (tester) async {
      await _mount(
        tester,
        AlbumCreateFlowScreen(
          initialAlbumTitle: '이전 세로 템플릿',
          initialCoverSize: legacyCoverSizes.first,
          initialTemplatePages: const [[], []],
        ),
      );
      final setup = tester.widget<AlbumCreateStep1>(
        find.byType(AlbumCreateStep1),
      );
      expect(setup.selectedCover!.productId, defaultCoverSize.productId);
      expect(find.text('세로형'), findsNothing);
      expect(setup.availableCovers!.length, 5);
      expect(tester.takeException(), isNull);
    },
  );
}
