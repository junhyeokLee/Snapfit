import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_design.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_photo_design_view.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';

final _day = DateTime.utc(2026, 11, 3);
final _bytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 2, height: 2)),
);

class _Picker extends ImagePicker {
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async => [
    XFile.fromData(_bytes, path: 'new-photo.png', name: 'new-photo.png'),
  ];
}

MomentPhotoDesign _design(String text) => MomentPhotoDesign.fromLayers(
  canvasSize: const Size(400, 500),
  backgroundColor: const Color(0xFFF6EFE6),
  photoSource: momentPhotoOriginalSource,
  layers: [
    LayerModel(
      id: 'original',
      type: LayerType.image,
      position: Offset.zero,
      width: 400,
      height: 500,
      originalUrl: momentPhotoOriginalSource,
      previewUrl: momentPhotoOriginalSource,
      imageUrl: momentPhotoOriginalSource,
      imageTemplate: 'free',
    ),
    LayerModel(
      id: 'overlay',
      type: LayerType.text,
      position: const Offset(20, 430),
      width: 350,
      height: 50,
      text: text,
      textStyle: const TextStyle(fontSize: 24, fontFamily: 'NotoSans'),
      zIndex: 1,
    ),
  ],
);

class _Repository extends Fake implements MomentsRepository {
  String? actor = 'owner';
  final changes = StreamController<String?>.broadcast();
  List<MomentUpload>? savedUploads;
  String? savedCaption;

  @override
  String? get currentUserId => actor;
  @override
  Stream<String?> get authChanges => changes.stream;

  @override
  Future<MomentJournal> listMonth(DateTime? month) async => MomentJournal(
    today: _day,
    weekStart: momentWeekStart(_day),
    month: month ?? momentMonth(_day),
    records: const [],
    weekPhotoCount: 0,
  );

  void change(String? next) {
    actor = next;
    changes.add(next);
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
    savedUploads = uploads;
    savedCaption = caption;
    return MomentRecord(
      id: id,
      recordDate: recordDate,
      caption: caption,
      revision: 1,
      photos: [
        ...existingPhotos,
        for (final upload in uploads)
          MomentPhoto(
            id: upload.id,
            path: 'owner/moments/$id/${upload.id}.png',
            width: 2,
            height: 2,
            design: upload.design,
          ),
      ],
    );
  }
}

MemoryMomentDraftStore _drafts({MomentPhotoDesign? design}) {
  final store = MemoryMomentDraftStore();
  store.seed(
    MomentDraft(
      ownerId: 'owner',
      recordId: 'draft',
      recordDate: _day,
      caption: '사진 아래의 별도 이야기',
      existingPhotos: [],
      uploads: [
        MomentDraftUpload(
          id: 'photo',
          filename: 'photo.png',
          bytes: _bytes,
          design: design,
        ),
      ],
      updatedAt: _day,
    ),
  );
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  // The image codec completes on the real engine clock.
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (i >= 5 &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty &&
        !tester.binding.hasScheduledFrame)
      break;
  }
  await tester.pump();
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repository,
  MemoryMomentDraftStore drafts,
  MomentPhotoEditorCallback edit, {
  bool narrow = false,
  ImagePicker? imagePicker,
  String? draftRecordId = 'draft',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = narrow
      ? const Size(320, 568)
      : const Size(390, 844);
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await repository.changes.close();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        momentsRepositoryProvider.overrideWithValue(repository),
        momentDraftStoreProvider.overrideWithValue(drafts),
        momentPublicationRepositoryProvider.overrideWithValue(
          MemoryMomentPublicationRepository(),
        ),
      ],
      child: MaterialApp(
        theme: narrow ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(narrow ? 1.8 : 1)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => MomentComposeScreen(
                    today: _day,
                    draftRecordId: draftRecordId,
                    photoEditor: edit,
                    imagePicker: imagePicker,
                  ),
                ),
              ),
              child: const Text('기록 열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('기록 열기'));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final action = find.byKey(ValueKey(key));
  if (action.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      action,
      180,
      scrollable: find
          .descendant(
            of: find.byType(MomentComposeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(action);
  await _settle(tester);
  await tester.tap(action);
  await _settle(tester);
}

void main() {
  testWidgets(
    'new photo saves the default album format without opening decoration',
    (tester) async {
      final repository = _Repository();
      await _mount(
        tester,
        repository,
        MemoryMomentDraftStore(),
        (_, {photo, upload}) async {
          fail(
            'No decoration should be required to preserve the selected format.',
          );
        },
        imagePicker: _Picker(),
        draftRecordId: null,
      );
      await _tap(tester, 'moment-pick-photos');
      await _tap(tester, 'moment-save');
      final saved = repository.savedUploads!.single;
      expect(saved.bytes, orderedEquals(_bytes));
      expect(saved.design!.canvasSize, coverCanvasBaseSize(defaultCoverSize));
      expect(
        momentCoverForDesign(saved.design)?.productId,
        defaultCoverSize.productId,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new photo format affects later picks and leaves restored artwork unchanged',
    (tester) async {
      final repository = _Repository();
      final legacy = _design('예전 문구와 원본 비율');
      final drafts = _drafts(design: legacy);
      await _mount(
        tester,
        repository,
        drafts,
        (_, {photo, upload}) async => null,
        narrow: true,
        imagePicker: _Picker(),
      );
      await _tap(tester, 'moment-new-photo-format');
      expect(find.text('새 사진의 앨범 규격'), findsOneWidget);
      for (final cover in coverSizes) {
        expect(
          find.byKey(ValueKey('print-size-${cover.productId}')),
          findsOneWidget,
        );
      }
      await _tap(tester, 'print-size-${coverSizes[2].productId}');
      expect(
        drafts.drafts[('owner', 'draft')]!.uploads.single.design!.toJson(),
        legacy.toJson(),
      );
      await _tap(tester, 'moment-pick-photos');
      await _tap(tester, 'moment-save');
      expect(repository.savedUploads, hasLength(2));
      expect(repository.savedUploads!.first.design!.toJson(), legacy.toJson());
      expect(
        repository.savedUploads!.last.design!.canvasSize,
        coverCanvasBaseSize(coverSizes[2]),
      );
      expect(repository.savedUploads!.last.bytes, orderedEquals(_bytes));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    're-editing one photo updates its durable draft without changing original pixels or caption',
    (tester) async {
      final repository = _Repository();
      final drafts = _drafts();
      final first = _design('첫 꾸밈');
      final second = _design('다시 다듬은 꾸밈');
      var opens = 0;
      await _mount(tester, repository, drafts, (
        context, {
        photo,
        upload,
      }) async {
        expect(photo, isNull);
        expect(upload!.id, 'photo');
        expect(upload.bytes, orderedEquals(_bytes));
        if (opens++ == 0) return first;
        expect(upload.design!.toJson(), first.toJson());
        return second;
      });
      await _tap(tester, 'moment-decorate-photo');
      expect(
        drafts.drafts[('owner', 'draft')]!.uploads.single.design!.toJson(),
        first.toJson(),
      );
      await _tap(tester, 'moment-decorate-photo');
      expect(
        drafts.drafts[('owner', 'draft')]!.uploads.single.design!.toJson(),
        second.toJson(),
      );
      expect(find.byType(MomentPhotoDesignView), findsWidgets);
      expect(drafts.drafts[('owner', 'draft')]!.caption, '사진 아래의 별도 이야기');
      await _tap(tester, 'moment-save');
      expect(repository.savedUploads!.single.design!.toJson(), second.toJson());
      expect(repository.savedUploads!.single.bytes, orderedEquals(_bytes));
      expect(repository.savedCaption, '사진 아래의 별도 이야기');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelling decoration leaves the draft unchanged on a narrow large-text screen',
    (tester) async {
      final repository = _Repository();
      final original = _design('보관한 꾸밈');
      final drafts = _drafts(design: original);
      final version = drafts.drafts[('owner', 'draft')]!.version;
      await _mount(tester, repository, drafts, (
        context, {
        photo,
        upload,
      }) async {
        expect(upload!.design!.toJson(), original.toJson());
        return null;
      }, narrow: true);
      await _tap(tester, 'moment-decorate-photo');
      expect(drafts.drafts[('owner', 'draft')]!.version, version);
      expect(
        drafts.drafts[('owner', 'draft')]!.uploads.single.design!.toJson(),
        original.toJson(),
      );
      expect(find.text('꾸밈 수정하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a completed photo edit after an account change cannot enter another account draft',
    (tester) async {
      final repository = _Repository();
      final drafts = _drafts();
      final completion = Completer<MomentPhotoDesign?>();
      await _mount(
        tester,
        repository,
        drafts,
        (context, {photo, upload}) => completion.future,
      );
      await _tap(tester, 'moment-decorate-photo');
      repository.change('other');
      await tester.pumpAndSettle();
      completion.complete(_design('다른 계정에 남으면 안 되는 꾸밈'));
      await _settle(tester);
      expect(find.text('계정이 변경되었어요'), findsOneWidget);
      expect(drafts.drafts[('owner', 'draft')]!.uploads.single.design, isNull);
      expect(drafts.drafts.keys.any((key) => key.$1 == 'other'), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
