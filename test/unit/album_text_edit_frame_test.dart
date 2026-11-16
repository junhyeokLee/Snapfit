import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/api/storage_service.dart';
import 'package:snap_fit/features/album/data/dto/request/create_album_request.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/album/service/album_persistence_service.dart';

import '../helpers/mock_repositories.dart';

const _canvas = Size(500, 500);
const _titleId = 'catalog_small-days_square_0_signature_title';
const _edited = '테스트\n앨범';

// Exact square cover lettering from the published small-days design. Use its
// real font, not Flutter's test font, to exercise the observed width expansion.
LayerModel _originalTitle({TextAlign align = TextAlign.right}) => LayerModel(
  id: _titleId,
  type: LayerType.text,
  position: const Offset(250, 305),
  width: 222.5,
  height: 160,
  text: '작은 날의\n기록',
  textAlign: align,
  textStyleType: TextStyleType.none,
  textFillMode: 'solid',
  textStyle: const TextStyle(
    fontFamily: 'Maker',
    fontSize: 65.96,
    fontWeight: FontWeight.w800,
    fontStyle: FontStyle.normal,
    color: Color(0xFF4D3549),
    letterSpacing: 0,
    height: 1.12,
  ),
);

String _document(LayerModel title) => jsonEncode({
  'sourceTemplate': {'productKey': 'template:-9303'},
  'pages': [
    {
      'index': 0,
      'isCover': true,
      'layers': [
        LayerExportMapper.toJson(title, canvasSize: _canvas, isCover: true),
      ],
    },
    for (var index = 1; index <= 20; index++)
      {'index': index, 'isCover': false, 'layers': []},
  ],
});

class _Storage extends Fake implements StorageService {}

class _Persistence extends Fake implements AlbumPersistenceService {}

Future<({AlbumEditorViewModel vm, List<Album> saved})> _editor(
  LayerModel title,
) async {
  final repository = MockAlbumRepository();
  final saved = <Album>[];
  when(
    () => repository.updateAlbum(
      any(),
      any(),
      expectedUpdatedAt: any(named: 'expectedUpdatedAt'),
      requestId: any(named: 'requestId'),
      expectedUserId: any(named: 'expectedUserId'),
    ),
  ).thenAnswer((call) async {
    final request = call.positionalArguments[1] as CreateAlbumRequest;
    final result = Album(
      id: 109,
      userId: 'fixture-owner',
      memberRole: 'OWNER',
      ratio: request.ratio,
      title: request.title,
      targetPages: request.targetPages,
      coverLayersJson: request.coverLayersJson,
      updatedAt: '2026-11-02T01:00:00Z',
    );
    saved.add(result);
    return result;
  });
  final container = ProviderContainer(
    overrides: [
      albumEditorOwnerReaderProvider.overrideWithValue(() => 'fixture-owner'),
      albumRepositoryProvider.overrideWithValue(repository),
      albumEditorServiceProvider.overrideWithValue(const AlbumEditorService()),
      albumPersistenceServiceProvider.overrideWithValue(_Persistence()),
      storageServiceProvider.overrideWithValue(_Storage()),
    ],
  );
  addTearDown(container.dispose);
  await container.read(albumEditorViewModelProvider.future);
  final vm = container.read(albumEditorViewModelProvider.notifier);
  await vm.prepareAlbumForEdit(
    Album(
      id: 109,
      userId: 'fixture-owner',
      memberRole: 'OWNER',
      ratio: '1.0',
      title: '테스트 앨범',
      targetPages: 20,
      updatedAt: '2026-11-02T00:00:00Z',
      coverLayersJson: _document(title),
    ),
  );
  vm.loadPendingEditAlbumIfNeeded(_canvas);
  return (vm: vm, saved: saved);
}

void _sameHorizontalFrame(LayerModel actual, LayerModel expected) {
  expect(actual.position.dx, closeTo(expected.position.dx, .00001));
  expect(actual.position.dy, closeTo(expected.position.dy, .00001));
  expect(actual.width, closeTo(expected.width, .00001));
  expect(actual.scale, expected.scale);
  expect(actual.rotation, expected.rotation);
  expect(actual.textAlign, expected.textAlign);
  expect(actual.position.dx + actual.width, closeTo(472.5, .00001));
  expect(actual.textStyle!.fontFamily, expected.textStyle!.fontFamily);
  expect(actual.textStyle!.fontSize, closeTo(65.96, .00001));
  expect(actual.textStyle!.fontWeight, expected.textStyle!.fontWeight);
  expect(actual.textStyle!.height, expected.textStyle!.height);
  expect(actual.textStyle!.color, expected.textStyle!.color);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(
      const CreateAlbumRequest(
        ratio: '1.0',
        coverLayersJson: '{}',
        coverImageUrl: '',
        coverThumbnailUrl: '',
      ),
    );
    await (FontLoader(
      'Maker',
    )..addFont(rootBundle.load('assets/fonts/Maker.ttf'))).load();
  });

  for (final align in [TextAlign.right, TextAlign.center]) {
    test(
      'editing a $align Maker cover title preserves its authored frame',
      () async {
        final original = _originalTitle(align: align);
        final vm = (await _editor(original)).vm;
        final loaded = vm.layers.single;
        _sameHorizontalFrame(loaded, original);
        expect(loaded.height, closeTo(original.height, .00001));

        // This is the short title that overflowed in the actual logged-in test.
        vm.updateLayer(loaded.copyWith(text: _edited));
        final edited = vm.layers.single;
        _sameHorizontalFrame(edited, original);
        expect(edited.text, _edited);
        final painter = TextPainter(
          text: TextSpan(text: edited.text, style: edited.textStyle),
          textDirection: TextDirection.ltr,
          textAlign: align,
        )..layout(maxWidth: original.width);
        expect(edited.height, greaterThanOrEqualTo(painter.height));
        expect(painter.width, lessThanOrEqualTo(original.width));
        painter.dispose();
      },
    );
  }

  test(
    'long Korean text wraps and grows down without widening or moving its anchor',
    () async {
      final original = _originalTitle();
      final vm = (await _editor(original)).vm;
      vm.updateLayer(
        vm.layers.single.copyWith(text: '우리가 함께 남긴 오래도록 기억하고 싶은 여름의 기록'),
      );
      final edited = vm.layers.single;
      _sameHorizontalFrame(edited, original);
      final painter = TextPainter(
        text: TextSpan(text: edited.text, style: edited.textStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: original.width);
      expect(painter.computeLineMetrics().length, greaterThan(2));
      expect(edited.height, greaterThan(original.height));
      expect(edited.height, greaterThanOrEqualTo(painter.height));
      painter.dispose();
    },
  );

  test(
    'cover text frame survives undo redo whole-album save and reopening',
    () async {
      final original = _originalTitle();
      final fixture = await _editor(original);
      final vm = fixture.vm;
      vm.updateLayer(vm.layers.single.copyWith(text: _edited));
      final editedHeight = vm.layers.single.height;
      vm.undo();
      _sameHorizontalFrame(vm.layers.single, original);
      expect(vm.layers.single.text, original.text);
      expect(vm.layers.single.height, closeTo(original.height, .00001));
      vm.redo();
      _sameHorizontalFrame(vm.layers.single, original);
      expect(vm.layers.single.text, _edited);
      expect(vm.layers.single.height, editedHeight);

      expect(await vm.saveFullAlbum(), isTrue);
      expect(fixture.saved, hasLength(1));
      final saved = fixture.saved.single;
      await vm.prepareAlbumForEdit(saved);
      vm.loadPendingEditAlbumIfNeeded(_canvas);
      _sameHorizontalFrame(vm.layers.single, original);
      expect(vm.layers.single.text, _edited);
      expect(vm.layers.single.height, closeTo(editedHeight, .00001));
    },
  );

  test(
    'loading intentionally oversized saved text does not rewrite its geometry',
    () async {
      final oversized = _originalTitle().copyWith(width: 323.753, height: 180);
      final vm = (await _editor(oversized)).vm;
      expect(vm.layers.single.width, closeTo(323.753, .00001));
      expect(vm.layers.single.height, closeTo(180, .00001));
      expect(
        vm.layers.single.position.dx,
        closeTo(oversized.position.dx, .00001),
      );
      expect(
        vm.layers.single.position.dy,
        closeTo(oversized.position.dy, .00001),
      );
      final saved = jsonDecode(vm.exportFullAlbumLayersJson(null)) as Map;
      final cover = (saved['pages'] as List).first as Map;
      final encoded = (cover['layers'] as List).single as Map;
      final restored = LayerExportMapper.fromJson(
        Map<String, dynamic>.from(encoded),
        canvasSize: _canvas,
        isCover: true,
      );
      expect(restored.width, closeTo(323.753, .00001));
      expect(restored.position.dx, closeTo(oversized.position.dx, .00001));
      expect(restored.position.dy, closeTo(oversized.position.dy, .00001));
    },
  );
}
