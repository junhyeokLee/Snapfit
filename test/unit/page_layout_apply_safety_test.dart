import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/core/constants/page_templates.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';

import '../helpers/mock_repositories.dart';
import 'album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;

const _canvas = Size(500, 500);
const _owner = 'layout-owner';
const _template = PageTemplate(
  id: 'layout-safety-fixture',
  name: '사진과 기록',
  backgroundColor: Color(0xFFF8F7F3),
  slots: [
    PageTemplateSlot(
      type: 'image',
      left: .08,
      top: .08,
      width: .84,
      height: .66,
    ),
    PageTemplateSlot(
      type: 'text',
      left: .08,
      top: .8,
      width: .84,
      height: .12,
      defaultText: '짧은 기록',
    ),
  ],
);

class _Owner {
  String? value = _owner;
}

LayerModel _personalText([String text = '현재 쪽의 소중한 기록']) => LayerModel(
  id: 'personal-caption',
  type: LayerType.text,
  position: const Offset(30, 45),
  width: 350,
  height: 90,
  text: text,
  textStyle: const TextStyle(fontSize: 14),
);

String _savedDocument() => jsonEncode({
  'pages': [
    {
      'index': 0,
      'isCover': true,
      'backgroundColor': 0xFFFFF9EE,
      'layers': [
        LayerExportMapper.toJson(
          _personalText(),
          canvasSize: _canvas,
          isCover: true,
        ),
      ],
    },
    for (var index = 1; index <= 20; index++)
      {'index': index, 'isCover': false, 'layers': []},
  ],
});

class _Fixture {
  _Fixture(this.container, this.vm, this.repo, this.owner, this.album);
  final ProviderContainer container;
  final AlbumEditorViewModel vm;
  final MockAlbumRepository repo;
  final _Owner owner;
  final Album album;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    container.dispose();
  }
}

Future<_Fixture> _boot({String role = 'OWNER'}) async {
  final owner = _Owner();
  final repository = MockAlbumRepository();
  final album = Album(
    id: 7,
    userId: _owner,
    memberRole: role,
    title: '레이아웃 검증',
    ratio: '1.0',
    targetPages: 20,
    coverLayersJson: _savedDocument(),
    updatedAt: '2026-11-02T00:00:00Z',
  );
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => owner.value),
      albumEditorOwnerChangesProvider.overrideWith((_) => const Stream.empty()),
      albumRepositoryProvider.overrideWithValue(repository),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(
        FakeAlbumPersistenceService(),
      ),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
    ],
  );
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  final fixture = _Fixture(container, vm, repository, owner, album);
  addTearDown(fixture.dispose);
  await vm.prepareAlbumForEdit(album);
  vm.loadPendingEditAlbumIfNeeded(_canvas);
  return fixture;
}

void _assertUnchanged(_Fixture fixture, String before) {
  expect(fixture.vm.exportFullAlbumLayersJson(null), before);
  expect(fixture.vm.layers.single.text, '현재 쪽의 소중한 기록');
  expect(
    fixture.container.read(albumEditorViewModelProvider).requireValue.canUndo,
    isFalse,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1.0',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
  });

  test('a view-only album cannot be replaced by a layout apply', () async {
    final fixture = await _boot(role: 'VIEWER');
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    expect(fixture.vm.editingAllowed, isFalse);
    expect(fixture.vm.applyTemplateToCurrentPage(_template, _canvas), isFalse);
    _assertUnchanged(fixture, before);
    expect(fixture.vm.hasUnsavedChanges, isFalse);
  });

  test('revoked access prevents layout changes and new undo entries', () async {
    final fixture = await _boot();
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    fixture.container
        .read(albumEditSyncStatusProvider.notifier)
        .update(7, AlbumEditSyncKind.accessRevoked);
    expect(fixture.vm.editingAllowed, isFalse);
    expect(fixture.vm.applyTemplateToCurrentPage(_template, _canvas), isFalse);
    _assertUnchanged(fixture, before);
  });

  test('a changed live owner cannot apply to the old owner document', () async {
    final fixture = await _boot();
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    // No provider event is delivered: the live owner reader itself must guard
    // the mutation while an auth notification is still in transit.
    fixture.owner.value = 'different-owner';
    expect(fixture.vm.applyTemplateToCurrentPage(_template, _canvas), isFalse);
    _assertUnchanged(fixture, before);
  });

  test(
    'an in-flight account save keeps its visible layout immutable',
    () async {
      final fixture = await _boot();
      final submitted = Completer<CreateAlbumRequest>();
      final reply = Completer<Album>();
      when(
        () => fixture.repo.updateAlbum(
          7,
          any(),
          expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
          requestId: any(named: 'requestId'),
          expectedUserId: any(named: 'expectedUserId'),
        ),
      ).thenAnswer((call) {
        submitted.complete(call.positionalArguments[1] as CreateAlbumRequest);
        return reply.future;
      });
      final before = fixture.vm.exportFullAlbumLayersJson(null);
      final saving = fixture.vm.saveFullAlbum();
      final request = await submitted.future;
      expect(
        fixture.vm.applyTemplateToCurrentPage(_template, _canvas),
        isFalse,
      );
      _assertUnchanged(fixture, before);
      expect(request.coverLayersJson, before);

      reply.complete(
        fixture.album.copyWith(
          coverLayersJson: request.coverLayersJson,
          updatedAt: '2026-11-02T00:01:00Z',
        ),
      );
      expect(await saving, isTrue);
      expect(fixture.vm.applyTemplateToCurrentPage(_template, _canvas), isTrue);
      expect(fixture.vm.layers, hasLength(2));
      expect(
        fixture.vm.layers.every((l) => l.isTemplateContent == true),
        isTrue,
      );
      fixture.vm.undo();
      expect(fixture.vm.exportFullAlbumLayersJson(null), before);
    },
  );

  for (final signedIn in [true, false]) {
    test(
      'local creation still accepts layouts (signed in: $signedIn)',
      () async {
        final fixture = await _boot();
        fixture.owner.value = signedIn ? _owner : null;
        fixture.vm.resetForCreate();
        expect(
          fixture.vm.applyTemplateToCurrentPage(_template, _canvas),
          isTrue,
        );
        expect(fixture.vm.editingAlbumId, isNull);
        expect(fixture.vm.layers, hasLength(2));
        expect(
          fixture.vm.layers.every((l) => l.isTemplateContent == true),
          isTrue,
        );
        expect(fixture.vm.currentPage!.backgroundColor, 0xFFF8F7F3);
        fixture.vm.undo();
        expect(fixture.vm.layers, isEmpty);
      },
    );
  }

  test('a disposed editor ignores a delayed layout apply', () async {
    final fixture = await _boot();
    final before = fixture.vm.exportFullAlbumLayersJson(null);
    fixture.dispose();
    expect(fixture.vm.applyTemplateToCurrentPage(_template, _canvas), isFalse);
    expect(fixture.vm.exportFullAlbumLayersJson(null), before);
  });
}
