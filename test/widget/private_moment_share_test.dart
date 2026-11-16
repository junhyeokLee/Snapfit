import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';
import 'package:snap_fit/shared/sharing/feed_share_sheet.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/data/moment_photo_share_exporter.dart';
import 'package:snap_fit/features/moments/data/moment_engagement_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/domain/moment_photo_format.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_engagement_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_saved_preview_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_share_sheet.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

import '../helpers/memory_moment_publication_repository.dart';

MomentPhoto _photo(String id) => MomentPhoto(
  id: id,
  path: 'owner/moments/$id.png',
  url: 'asset:assets/snapfit_home_square.jpg',
  width: 200,
  height: 200,
);

MomentRecord _record() => MomentRecord(
  id: 'record',
  recordDate: DateTime.utc(2026, 11, 5),
  caption: '사진 아래에 보관한 한 줄',
  photos: [_photo('first'), _photo('second')],
  revision: 3,
);

class _Repository extends Fake implements MomentsRepository {
  String? owner = 'owner';
  final changes = StreamController<String?>.broadcast(sync: true);
  List<MomentRecord> records = [_record()];
  int reads = 0;
  Future<void>? waiting;
  @override
  String? get currentUserId => owner;
  @override
  Stream<String?> get authChanges => changes.stream;
  void change(String? next) {
    owner = next;
    changes.add(next);
  }

  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? DateTime.utc(2026, 11);
    reads++;
    await waiting;
    return MomentJournal(
      today: DateTime.utc(2026, 11, 5),
      weekStart: DateTime.utc(2026, 11, 2),
      month: month,
      records: records,
      weekPhotoCount: 2,
    );
  }
}

class _Exporter extends MomentPhotoShareExporter {
  final selected = <String>[];
  final png = Uint8List.fromList(img.encodePng(img.Image(width: 2, height: 2)));
  @override
  Future<MomentShareImage> export({
    required MomentPhoto photo,
    required ThemeData theme,
    bool Function()? isActive,
  }) async {
    selected.add(photo.id);
    if (isActive?.call() == false) throw const MomentShareExportCancelled();
    return MomentShareImage(bytes: png, width: 2, height: 2);
  }
}

class _Engagement extends Fake implements MomentEngagementRepository {
  @override
  Future<bool> recordActivity(
    MomentActivity activity, {
    DateTime? month,
  }) async => false;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Fixture {
  final repository = _Repository();
  final exporter = _Exporter();
  final publications = MemoryMomentPublicationRepository(recordRevision: 3);
  final navigator = GlobalKey<NavigatorState>();
  int sent = 0, links = 0;
  Future<void>? sharing;
  bool _closed = false;
  Future<void> mount(WidgetTester tester, {bool savedPreview = false}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() async {
      if (_closed) return;
      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(repository.changes.close());
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          momentsRepositoryProvider.overrideWithValue(repository),
          momentPhotoShareExporterProvider.overrideWithValue(exporter),
          momentPublicationRepositoryProvider.overrideWithValue(publications),
          momentEngagementRepositoryProvider.overrideWithValue(_Engagement()),
          feedImageShareWriterProvider.overrideWithValue((
            bytes,
            filename,
            origin,
          ) async {
            sent++;
            expect(bytes, orderedEquals(exporter.png));
            expect(filename, 'snapfit-moment.png');
            expect(origin.width, greaterThan(0));
            return const ShareResult('test', ShareResultStatus.dismissed);
          }),
          feedLinkShareWriterProvider.overrideWithValue((uri, origin) async {
            links++;
            return const ShareResult('test', ShareResultStatus.dismissed);
          }),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          home: savedPreview
              ? MomentSavedPreviewScreen(
                  record: _record(),
                  journal: MomentJournal(
                    today: DateTime.utc(2026, 11, 5),
                    weekStart: DateTime.utc(2026, 11, 2),
                    month: DateTime.utc(2026, 11),
                    weekPhotoCount: 3,
                    records: [
                      _record(),
                      MomentRecord(
                        id: 'other-day',
                        recordDate: DateTime.utc(2026, 11, 4),
                        caption: '다른 날의 비공개 기록',
                        photos: [_photo('other-day-photo')],
                        revision: 1,
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => sharing = showMomentShareSheet(
                          context,
                          record: _record(),
                          initialPhotoId: 'second',
                        ),
                        child: const Text('공유 열기'),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    await _settle(tester);
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('공유 열기'));
    await _settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    navigator.currentState?.popUntil((route) => route.isFirst);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    var completed = sharing == null;
    sharing?.then((_) => completed = true);
    for (var i = 0; i < 10 && !completed; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(
      completed,
      isTrue,
      reason: 'Closing the sheet releases its private session.',
    );
    expect(find.byKey(const ValueKey('feed-share-close')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    unawaited(repository.changes.close());
    _closed = true;
  }
}

void main() {
  testWidgets(
    'private share starts on the selected photo and sends only PNG after revalidation',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      expect(fixture.exporter.selected, ['second']);
      expect(find.byKey(const ValueKey('feed-share-link')), findsNothing);
      expect(find.text('사진만 공유해요. 기록의 공개 범위는 바뀌지 않아요.'), findsOneWidget);
      final send = find.byKey(const ValueKey('feed-share-image'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await _settle(tester);
      expect(fixture.sent, 1);
      expect(fixture.links, 0);
      expect(fixture.repository.reads, 2);
      expect(fixture.publications.publications, isEmpty);
      await fixture.close(tester);
    },
  );

  for (final change in ['revision', 'caption', 'source', 'design', 'order']) {
    testWidgets('changed private $change cannot reach the exporter', (
      tester,
    ) async {
      final fixture = _Fixture();
      final before = _record();
      fixture.repository.records = [
        MomentRecord(
          id: before.id,
          recordDate: before.recordDate,
          revision: change == 'revision' ? 4 : 3,
          caption: change == 'caption' ? '수정된 문구' : before.caption,
          photos: change == 'order'
              ? before.photos.reversed.toList()
              : [
                  before.photos.first,
                  change == 'source'
                      ? MomentPhoto(
                          id: 'second',
                          path: 'owner/moments/replaced.png',
                          width: 200,
                          height: 200,
                        )
                      : change == 'design'
                      ? before.photos.last.withDesign(
                          newMomentPhotoDesign(photoSize: const Size(200, 200)),
                        )
                      : before.photos.last,
                ],
        ),
      ];
      await fixture.mount(tester);
      await fixture.open(tester);
      expect(fixture.exporter.selected, isEmpty);
      expect(find.byKey(const ValueKey('feed-share-error')), findsOneWidget);
      expect(fixture.sent, 0);
      expect(fixture.links, 0);
      await fixture.close(tester);
    });
  }

  testWidgets(
    'a prepared private image is rechecked before the final handoff',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester);
      await fixture.open(tester);
      fixture.repository.records = [];
      final send = find.byKey(const ValueKey('feed-share-image'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await _settle(tester);
      expect(fixture.exporter.selected, ['second']);
      expect(fixture.sent, 0);
      expect(find.byKey(const ValueKey('feed-share-error')), findsOneWidget);
      await fixture.close(tester);
    },
  );

  testWidgets('private account A to B to A invalidates a pending share', (
    tester,
  ) async {
    final fixture = _Fixture();
    final pending = Completer<void>();
    fixture.repository.waiting = pending.future;
    await fixture.mount(tester);
    await fixture.open(tester);
    fixture.repository.change('other');
    fixture.repository.change('owner');
    pending.complete();
    await _settle(tester);
    expect(fixture.exporter.selected, isEmpty);
    expect(fixture.sent, 0);
    expect(find.byKey(const ValueKey('feed-share-close')), findsNothing);
    await fixture.close(tester);
  });

  testWidgets(
    'saved preview offers only the saved record and excludes its other-day cover photos',
    (tester) async {
      final fixture = _Fixture();
      await fixture.mount(tester, savedPreview: true);
      final share = find.byKey(const ValueKey('moment-saved-share'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('feed-share-photo-first')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feed-share-photo-second')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('feed-share-photo-other-day-photo')),
        findsNothing,
      );
      expect(fixture.publications.publications, isEmpty);
      await fixture.close(tester);
    },
  );

  testWidgets(
    'record share action passes the visible photo and keeps editing separate',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      String? selected;
      var edits = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: SingleChildScrollView(
                  child: MomentRecordCard(
                    record: _record(),
                    onEdit: () => edits++,
                    onShare: (photo) => selected = photo.id,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('moment-record-toggle-record')),
      );
      await _settle(tester);
      final pages = find.byKey(const ValueKey('moment-photos-record'));
      await tester.drag(pages, const Offset(-320, 0));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final shareAction = find.byKey(const ValueKey('moment-share-record'));
      await tester.ensureVisible(shareAction);
      await tester.tap(shareAction);
      expect(selected, 'second');
      expect(edits, 0);
      await tester.tap(find.byKey(const ValueKey('moment-edit-record')));
      expect(edits, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'record cards without a share callback expose editing only after expansion',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MomentRecordCard(record: _record(), onEdit: () {}),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('moment-share-record')), findsNothing);
      expect(find.byKey(const ValueKey('moment-edit-record')), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('moment-record-toggle-record')),
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('moment-edit-record')), findsOneWidget);
      expect(find.text('기록 다듬기'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
