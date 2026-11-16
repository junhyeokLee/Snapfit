import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';

const _owner = 'owner';
const _recordId = 'removal-record';
const _caption = '사진과 함께 보관할 하루의 글';
final _day = DateTime.utc(2026, 11, 16);
final _bytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2)),
);

MomentPhotoDesign _design(String text) => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(400, 400),
  backgroundColor: const Color(0xFFF6EFE6),
  photoSource: momentPhotoOriginalSource,
  layers: [
    LayerModel(
      id: 'original',
      type: LayerType.image,
      position: Offset.zero,
      width: 400,
      height: 400,
      originalUrl: momentPhotoOriginalSource,
      imageTemplate: 'free',
    ),
    LayerModel(
      id: 'caption',
      type: LayerType.text,
      position: const Offset(20, 340),
      width: 350,
      height: 50,
      text: text,
      textStyle: const TextStyle(fontSize: 24),
      zIndex: 1,
    ),
  ],
);

class _AssetPhoto extends MomentPhoto {
  const _AssetPhoto({required super.id, super.design})
    : super(
        path: 'owner/moments/removal-record/photo.jpg',
        width: 1000,
        height: 667,
      );

  // 사진 제거의 회귀 검증에 외부 이미지 저장소가 영향을 주지 않게 한다.
  @override
  String get storageUri => 'asset:assets/frame_preview/ocean_shore.jpg';
}

MomentRecord _record() => MomentRecord(
  id: _recordId,
  recordDate: _day,
  caption: _caption,
  revision: 1,
  photos: [
    _AssetPhoto(id: 'first', design: _design('첫 사진 꾸밈')),
    _AssetPhoto(id: 'second', design: _design('가운데 사진 꾸밈')),
    _AssetPhoto(id: 'third', design: _design('마지막 사진 꾸밈')),
  ],
);

class _Repository extends Fake implements MomentsRepository {
  _Repository(this.record);
  final MomentRecord record;
  final changes = StreamController<String?>.broadcast();
  final pendingDates = <Completer<MomentJournal>>[];
  String? actor = _owner;
  DateTime today = _day;
  bool delayDateChecks = false;
  Object? dateError;
  int writes = 0;

  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;

  MomentJournal get journal => MomentJournal(
    today: today,
    weekStart: momentWeekStart(today),
    month: momentMonth(today),
    records: [record],
    weekPhotoCount: 3,
  );

  @override
  Future<MomentJournal> listMonth(DateTime? month) {
    if (dateError case final error?) return Future.error(error);
    if (!delayDateChecks) return Future.value(journal);
    final request = Completer<MomentJournal>();
    pendingDates.add(request);
    return request.future;
  }

  void change(String? next) {
    actor = next;
    changes.add(next);
  }

  void releaseDates() {
    delayDateChecks = false;
    for (final pending in pendingDates) {
      if (!pending.isCompleted) pending.complete(journal);
    }
  }

  @override
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  }) async {
    writes++;
    return record;
  }

  @override
  Future<void> delete(MomentRecord record) async => writes++;
}

Future<void> _frames(WidgetTester tester) async {
  // 이미지 디코딩은 실제 엔진 시계에서 완료되므로 유한한 프레임만 기다린다.
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(tester.takeException(), isNull);
}

Future<
  ({
    MemoryMomentPublicationRepository publications,
    Future<void> Function() close,
  })
>
_mount(
  WidgetTester tester,
  _Repository repository,
  MemoryMomentDraftStore drafts, {
  String? draftRecordId,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final publications = MemoryMomentPublicationRepository();
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentDraftStoreProvider.overrideWithValue(drafts),
      momentPublicationRepositoryProvider.overrideWithValue(publications),
    ],
  );
  var closed = false;
  Future<void> close() async {
    if (closed) return;
    closed = true;
    repository.releaseDates();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await repository.changes.close();
    await tester.pump();
  }

  addTearDown(close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        home: MomentComposeScreen(
          record: draftRecordId == null ? repository.record : null,
          today: _day,
          draftRecordId: draftRecordId,
        ),
      ),
    ),
  );
  await _frames(tester);
  return (publications: publications, close: close);
}

Finder _remove(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byTooltip('이 사진 빼기'),
);

List<MomentPhoto> _photos(WidgetTester tester) => tester
    .widgetList<MomentPhotoView>(find.byType(MomentPhotoView))
    .where((view) => view.photo != null)
    .map((view) => view.photo!)
    .toList();

Future<void> _tap(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _frames(tester);
}

void _expectLocalOnly(
  _Repository repository,
  MemoryMomentPublicationRepository publications,
) {
  expect(repository.writes, 0);
  expect(publications.publications, isEmpty);
  expect(publications.privateCalls, isEmpty);
}

void main() {
  testWidgets('duplicate removal taps keep every unselected photo', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      final firstRemove = _remove('first');
      final originalButton = tester.element(firstRemove);
      repository.delayDateChecks = true;

      await tester.tap(firstRemove);
      await tester.pump();
      expect(repository.pendingDates, hasLength(1));
      expect(
        find.byKey(const ValueKey('moment-photo-change-status')),
        findsOneWidget,
      );
      expect(find.text('사진을 확인하고 있어요'), findsOneWidget);
      expect(tester.element(firstRemove), same(originalButton));
      await tester.tap(firstRemove);
      await tester.pump();
      repository.releaseDates();
      await _frames(tester);

      expect(_photos(tester).map((photo) => photo.id), ['second', 'third']);
      expect(_photos(tester)[0], same(repository.record.photos[1]));
      expect(_photos(tester)[1], same(repository.record.photos[2]));
      expect(repository.pendingDates, hasLength(1));
      expect(
        find.byKey(const ValueKey('moment-photo-change-status')),
        findsNothing,
      );
      final saved = (await drafts.list(_owner)).single;
      expect(saved.existingPhotos.map((photo) => photo.id), [
        'second',
        'third',
      ]);
      expect(saved.caption, _caption);
      expect(saved.originalRecord, same(repository.record));
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('undo restores an existing photo order artwork and draft', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      await _tap(tester, _remove('second'));
      expect(_photos(tester).map((photo) => photo.id), ['first', 'third']);

      await _tap(
        tester,
        find.byKey(const ValueKey('moment-undo-photo-removal')),
      );

      expect(_photos(tester).map((photo) => photo.id), [
        'first',
        'second',
        'third',
      ]);
      for (var i = 0; i < 3; i++) {
        expect(_photos(tester)[i], same(repository.record.photos[i]));
      }
      final saved = (await drafts.list(_owner)).single;
      expect(saved.existingPhotos.map((photo) => photo.id), [
        'first',
        'second',
        'third',
      ]);
      expect(
        saved.existingPhotos[1].design!.toJson(),
        repository.record.photos[1].design!.toJson(),
      );
      expect(saved.caption, _caption);
      expect(
        find.byKey(const ValueKey('moment-undo-photo-removal')),
        findsNothing,
      );
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('undo restores upload bytes filename artwork and cached draft', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final uploads = [
      for (final id in ['upload-first', 'upload-second', 'upload-third'])
        MomentDraftUpload(
          id: id,
          filename: '$id.png',
          bytes: _bytes,
          design: _design('$id 꾸밈'),
        ),
    ];
    drafts.seed(
      MomentDraft(
        ownerId: _owner,
        recordId: 'upload-draft',
        recordDate: _day,
        caption: _caption,
        existingPhotos: [],
        uploads: uploads,
        updatedAt: _day,
      ),
    );
    final fixture = await _mount(
      tester,
      repository,
      drafts,
      draftRecordId: 'upload-draft',
    );
    try {
      await _tap(tester, _remove('upload-second'));
      expect(
        (await drafts.list(_owner)).single.uploads.map((photo) => photo.id),
        ['upload-first', 'upload-third'],
      );

      await _tap(
        tester,
        find.byKey(const ValueKey('moment-undo-photo-removal')),
      );

      final saved = (await drafts.list(_owner)).single;
      expect(saved.uploads.map((photo) => photo.id), [
        'upload-first',
        'upload-second',
        'upload-third',
      ]);
      for (var i = 0; i < 3; i++) {
        expect(saved.uploads[i].filename, uploads[i].filename);
        expect(saved.uploads[i].bytes, orderedEquals(uploads[i].bytes));
        expect(saved.uploads[i].design!.toJson(), uploads[i].design!.toJson());
        expect(saved.uploads[i], same(uploads[i]));
      }
      expect(saved.caption, _caption);
      expect(find.byKey(const ValueKey('upload-second')), findsOneWidget);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('pending removal cannot cross an account A B A change', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      repository.delayDateChecks = true;
      await tester.tap(_remove('first'));
      await tester.pump();
      repository.change('other');
      await _frames(tester);
      repository.change(_owner);
      await _frames(tester);
      repository.releaseDates();
      await _frames(tester);

      expect(find.text('계정이 변경되었어요'), findsOneWidget);
      expect(drafts.drafts, isEmpty);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('pending removal cannot change a record after the day changes', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      repository.delayDateChecks = true;
      await tester.tap(_remove('first'));
      await tester.pump();
      repository.today = DateTime.utc(2026, 11, 17);
      repository.releaseDates();
      await _frames(tester);

      expect(_photos(tester).map((photo) => photo.id), [
        'first',
        'second',
        'third',
      ]);
      expect(drafts.drafts, isEmpty);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('failed undo date check retains recovery for a later retry', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      await _tap(tester, _remove('second'));
      repository.dateError = StateError('offline');
      await _tap(
        tester,
        find.byKey(const ValueKey('moment-undo-photo-removal')),
      );
      expect(_photos(tester).map((photo) => photo.id), ['first', 'third']);
      expect(
        find.byKey(const ValueKey('moment-undo-photo-removal')),
        findsOneWidget,
      );
      repository.dateError = null;
      await _tap(
        tester,
        find.byKey(const ValueKey('moment-undo-photo-removal')),
      );

      expect(_photos(tester).map((photo) => photo.id), [
        'first',
        'second',
        'third',
      ]);
      expect((await drafts.list(_owner)).single.caption, _caption);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('pending undo cannot restore a photo after the day changes', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      await _tap(tester, _remove('second'));
      repository.delayDateChecks = true;
      final undo = find.byKey(const ValueKey('moment-undo-photo-removal'));
      expect(undo, findsOneWidget);
      await tester.tap(undo);
      await tester.pump();
      repository.today = DateTime.utc(2026, 11, 17);
      repository.releaseDates();
      await _frames(tester);

      expect(_photos(tester).map((photo) => photo.id), ['first', 'third']);
      final saved = (await drafts.list(_owner)).single;
      expect(saved.existingPhotos.map((photo) => photo.id), ['first', 'third']);
      expect(saved.caption, _caption);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });

  testWidgets('an older date response cannot reopen next day photo removal', (
    tester,
  ) async {
    final repository = _Repository(_record());
    final drafts = MemoryMomentDraftStore();
    final fixture = await _mount(tester, repository, drafts);
    try {
      final earlierJournal = repository.journal;
      repository.delayDateChecks = true;
      await tester.tap(_remove('first'));
      await tester.pump();
      expect(repository.pendingDates, hasLength(1));

      // 복귀 시 최신 날짜를 먼저 확인해도 지연된 이전 응답이 편집을 다시 열면 안 된다.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester);
      expect(repository.pendingDates.length, greaterThan(1));
      repository.today = DateTime.utc(2026, 11, 17);
      for (final pending in repository.pendingDates.skip(1)) {
        pending.complete(repository.journal);
      }
      await _frames(tester);
      expect(find.textContaining('지난 날짜의 사진은 바꿀 수 없어요'), findsOneWidget);

      repository.pendingDates.first.complete(earlierJournal);
      await _frames(tester);

      expect(_photos(tester).map((photo) => photo.id), [
        'first',
        'second',
        'third',
      ]);
      final removeButton = find.descendant(
        of: find.byKey(const ValueKey('first')),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == '이 사진 빼기',
        ),
      );
      expect(tester.widget<IconButton>(removeButton).onPressed, isNull);
      expect(drafts.drafts, isEmpty);
      _expectLocalOnly(repository, fixture.publications);
    } finally {
      await fixture.close();
    }
  });
}
