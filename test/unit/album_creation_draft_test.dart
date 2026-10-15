import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/constants/cover_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album_page.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/album_creation_draft.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';

AlbumCreationDraft creationDraftFixture({
  String id = 'draft-a',
  String title = '여행의 조각',
  List<List<LayerModel>>? pages,
  int step = 1,
  bool showPhotoFill = true,
}) {
  final photo = AssetEntity(
    id: 'local-photo-1',
    typeInt: 1,
    width: 2400,
    height: 1600,
  );
  final content =
      pages ??
      [
        [
          LayerModel(
            id: 'photo',
            type: LayerType.image,
            position: const Offset(24, 42),
            width: 300,
            height: 210,
            asset: photo,
            imageOffset: const Offset(12, -16),
            imageZoom: 1.7,
            imageBackground: 'archSoft',
            frameBaseWidth: 290,
            frameBaseHeight: 200,
            frameBasePosition: const Offset(22, 40),
            zIndex: 2,
          ),
          LayerModel(
            id: 'title',
            type: LayerType.text,
            position: const Offset(40, 310),
            width: 210,
            height: 40,
            text: '우리의 여름',
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pretendard',
              color: Colors.teal,
            ),
            textBackground: 'tag',
            textAlign: TextAlign.center,
          ),
        ],
        [
          LayerModel(
            id: 'empty',
            type: LayerType.image,
            position: const Offset(24, 42),
            width: 300,
            height: 210,
          ),
        ],
      ];
  return AlbumCreationDraft(
    id: id,
    updatedAt: DateTime.utc(2026, 10, 8, 9),
    title: title,
    cover: coverSizes[1].withCoverType(PrintCoverType.hard),
    pageCount: 24,
    step: step,
    showPhotoFill: showPhotoFill,
    hasSelectedMode: true,
    sourceLabel: '선택한 템플릿',
    usesPhysicalCanvas: true,
    preserveTypography: true,
    pages: content,
    basePages: content,
    variants: {'landscape': content},
    canvasSizes: {'landscape': const Size(500, 375)},
    baseCanvasSize: const Size(500, 375),
    templateTitle: '여름 여행',
    currentPage: 1,
    pendingPhotos: [photo],
    selectedPhotoId: photo.id,
    selectedSlot: (page: 1, id: 'empty'),
    editedCover: content.first,
    editedCoverCanvasSize: const Size(500, 375),
  );
}

void main() {
  AlbumCreationEditorCheckpoint checkpoint() {
    final source = creationDraftFixture();
    return AlbumCreationEditorCheckpoint(
      pages: List.generate(
        source.pages!.length,
        (index) => AlbumPage(
          id: 'page-$index',
          pageIndex: index,
          isCover: index == 0,
          layers: List.of(source.pages![index]),
          backgroundColor: index == 0 ? 0xFFAA4433 : null,
        ),
      ),
      pageIndex: 1,
      coverCanvas: const Size(500, 375),
      innerCanvas: const Size(300, 225),
      theme: CoverTheme.nature1,
    );
  }

  test(
    'editor checkpoint roundtrip preserves exact pages, backgrounds, canvases and local photos',
    () {
      final source = creationDraftFixture();
      final saved = source.withEditorCheckpoint(
        checkpoint(),
        cover: source.cover,
      );
      final restored = AlbumCreationDraft.fromJson(
        jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
      );
      final editor = restored.editorCheckpoint!;
      expect(editor.pageIndex, 1);
      expect(editor.theme, CoverTheme.nature1);
      expect(editor.coverCanvas, const Size(500, 375));
      expect(editor.innerCanvas, const Size(300, 225));
      expect(editor.pages.first.backgroundColor, 0xFFAA4433);
      expect(editor.pages.last.backgroundColor, isNull);
      expect(editor.pages.first.id, 'page-0');
      expect(editor.pages.first.layers.first.asset!.id, 'local-photo-1');
      expect(editor.pages.first.layers.first.imageZoom, 1.7);
      expect(
        editor.pages.first.layers.first.frameBasePosition,
        const Offset(22, 40),
      );
      expect(editor.pages.first.layers.last.text, '우리의 여름');
      expect(restored.templateTitle, source.templateTitle);
      expect(restored.pendingPhotos.single.id, source.pendingPhotos.single.id);
      expect(source.editorCheckpoint, isNull);
      expect(restored.updatedAt, saved.updatedAt);
    },
  );

  test(
    'checkpoint is isolated from later in-memory edits and rejects invalid serialized geometry',
    () {
      final input = [
        AlbumPage(id: 'page', pageIndex: 0, isCover: true, layers: []),
      ];
      final saved = AlbumCreationEditorCheckpoint(
        pages: input,
        pageIndex: 0,
        coverCanvas: const Size(500, 375),
        innerCanvas: const Size(300, 225),
        theme: CoverTheme.classic,
      );
      input.single.layers.add(creationDraftFixture().pages!.first.first);
      input.clear();
      expect(saved.pages.single.layers, isEmpty);
      expect(() => saved.pages.clear(), throwsUnsupportedError);
      for (final json in [
        saved.toJson()..['pageIndex'] = 2,
        saved.toJson()..['innerCanvas'] = {'width': 0, 'height': 225},
        saved.toJson()..['pages'] = [],
      ]) {
        expect(
          () => AlbumCreationEditorCheckpoint.fromJson(json),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'draft roundtrip preserves album, workspace, local photo, crop and typography',
    () {
      final source = creationDraftFixture();
      final restored = AlbumCreationDraft.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
      );
      expect(restored.id, source.id);
      expect(restored.updatedAt, source.updatedAt);
      expect(restored.cover.productId, source.cover.productId);
      expect(restored.cover.realSize, source.cover.realSize);
      expect(restored.pageCount, 24);
      expect(restored.currentPage, 1);
      expect(restored.selectedSlot, (page: 1, id: 'empty'));
      expect(restored.selectedPhotoId, 'local-photo-1');
      final image = restored.pages!.first.first;
      expect(image.asset!.id, 'local-photo-1');
      expect(image.asset!.width, 2400);
      expect(image.asset!.height, 1600);
      expect(image.position, const Offset(24, 42));
      expect(image.imageOffset, const Offset(12, -16));
      expect(image.imageZoom, 1.7);
      expect(image.frameBasePosition, const Offset(22, 40));
      expect(image.imageBackground, 'archSoft');
      expect(image.zIndex, 2);
      final text = restored.pages!.first.last;
      expect(text.text, '우리의 여름');
      expect(text.textStyle!.fontSize, 22);
      expect(text.textStyle!.fontWeight, FontWeight.w600);
      expect(text.textStyle!.color!.toARGB32(), Colors.teal.toARGB32());
      expect(restored.variants!['landscape']!.length, 2);
      expect(restored.canvasSizes['landscape'], const Size(500, 375));
      expect(restored.editedCover!.first.asset!.id, 'local-photo-1');
    },
  );

  test('unrecognized draft versions are never applied', () {
    final json = creationDraftFixture().toJson()..['version'] = 9;
    expect(() => AlbumCreationDraft.fromJson(json), throwsFormatException);
  });

  test(
    'invalid album dimensions and linked ids cannot enter the creation flow',
    () {
      for (final value in [0, -1]) {
        final dimensions = creationDraftFixture().toJson();
        (dimensions['cover'] as Map)['ratio'] = value;
        expect(
          () => AlbumCreationDraft.fromJson(dimensions),
          throwsFormatException,
        );
        final linked = creationDraftFixture().toJson()
          ..['createdAlbumId'] = value;
        expect(
          () => AlbumCreationDraft.fromJson(linked),
          throwsFormatException,
        );
      }
    },
  );

  group('local drafts', () {
    late Directory root;
    late LocalAlbumCreationDraftStore store;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('snapfit-creation-draft-');
      store = LocalAlbumCreationDraftStore(directory: () async => root);
    });
    tearDown(() async => root.delete(recursive: true));

    test(
      'no existing draft returns null',
      () async => expect(await store.load('user'), isNull),
    );
    test(
      'persists across repository instances and isolates accounts',
      () async {
        await store.save('user-a', creationDraftFixture());
        await store.save('../user-b', creationDraftFixture(id: 'draft-b'));
        final reopened = LocalAlbumCreationDraftStore(
          directory: () async => root,
        );
        expect((await reopened.load('user-a'))!.id, 'draft-a');
        expect((await reopened.load('../user-b'))!.id, 'draft-b');
        expect(await reopened.load('user-c'), isNull);
        expect(
          await Directory('${root.path}/album_creation_drafts').list().length,
          2,
        );
      },
    );
    test('queued saves and reads retain the newest draft', () async {
      final first = store.save('user', creationDraftFixture(id: 'first'));
      final second = store.save('user', creationDraftFixture(id: 'second'));
      final read = store.load('user');
      await first;
      await second;
      expect((await read)!.id, 'second');
    });
    test(
      'linked updates are atomic and cannot overwrite another draft or revive a removed draft',
      () async {
        final linked = AlbumCreationDraft.fromJson(
          creationDraftFixture().toJson()..['createdAlbumId'] = 7,
        );
        AlbumCreationDraft update(AlbumCreationDraft value) =>
            value.withEditorCheckpoint(checkpoint(), cover: value.cover);
        await store.save('user', linked);
        expect(await store.updateLinked('user', 'draft-a', 8, update), isFalse);
        expect(
          await store.updateLinked('other', 'draft-a', 7, update),
          isFalse,
        );
        expect(await store.updateLinked('user', 'draft-a', 7, update), isTrue);
        expect((await store.load('user'))!.editorCheckpoint!.pageIndex, 1);
        final remove = store.remove('user', 'draft-a');
        final lateUpdate = store.updateLinked('user', 'draft-a', 7, update);
        await remove;
        expect(await lateUpdate, isFalse);
        expect(await store.load('user'), isNull);
        await store.save('user', creationDraftFixture(id: 'new'));
        expect(await store.updateLinked('user', 'draft-a', 7, update), isFalse);
        expect((await store.load('user'))!.id, 'new');
      },
    );
    test(
      'failed linked update preserves content and leaves subsequent operations usable',
      () async {
        final linked = AlbumCreationDraft.fromJson(
          creationDraftFixture().toJson()..['createdAlbumId'] = 7,
        );
        await store.save('user', linked);
        await expectLater(
          store.updateLinked(
            'user',
            'draft-a',
            7,
            (_) => throw StateError('fail'),
          ),
          throwsStateError,
        );
        expect((await store.load('user'))!.editorCheckpoint, isNull);
        await expectLater(
          store.updateLinked(
            'user',
            'draft-a',
            7,
            (_) => creationDraftFixture(id: 'other'),
          ),
          throwsArgumentError,
        );
        expect((await store.load('user'))!.id, 'draft-a');
      },
    );
    test('cleanup for an old album cannot remove a different draft', () async {
      await store.save('user', creationDraftFixture(id: 'new'));
      await store.remove('user', 'old');
      expect((await store.load('user'))!.id, 'new');
      await store.remove('user', 'new');
      expect(await store.load('user'), isNull);
    });
    test(
      'failed serialization preserves previous draft and the store remains usable',
      () async {
        await store.save('user', creationDraftFixture(id: 'good'));
        final invalid = creationDraftFixture(
          pages: [
            [
              LayerModel(
                id: 'bad',
                type: LayerType.image,
                position: Offset.zero,
                width: double.nan,
              ),
            ],
          ],
        );
        await expectLater(
          store.save('user', invalid),
          throwsA(isA<JsonUnsupportedObjectError>()),
        );
        expect((await store.load('user'))!.id, 'good');
        await store.save('user', creationDraftFixture(id: 'next'));
        expect((await store.load('user'))!.id, 'next');
      },
    );
    test('corrupt persisted content is reported without deleting it', () async {
      await store.save('user', creationDraftFixture());
      final file =
          (await Directory(
                '${root.path}/album_creation_drafts',
              ).list().toList()).single
              as File;
      await file.writeAsString('{broken');
      await expectLater(store.load('user'), throwsFormatException);
      expect(await file.readAsString(), '{broken');
    });
    test('empty account ids cannot read or write a shared draft', () async {
      await expectLater(store.load(''), throwsArgumentError);
      await expectLater(
        store.save(' ', creationDraftFixture()),
        throwsArgumentError,
      );
    });
  });
}
