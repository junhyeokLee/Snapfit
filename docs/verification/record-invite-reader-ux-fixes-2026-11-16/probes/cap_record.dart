// 실제 기록 작성 위젯을 사용하되 날짜 응답과 임시 저장은 메모리로 격리한다.
// 수정 후 중복 제거 차단과 실행 취소 화면을 확인한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_publication_providers.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moment_compose_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moments_widgets.dart';

import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/memory_moment_draft_store.dart';
import 'file:///Users/devsheep/SnapFit/SnapFit/test/helpers/memory_moment_publication_repository.dart';
import 'capture_support.dart';

const _owner = 'isolated-record-removal-audit';
const _recordId = 'record-removal-audit';
const _firstId = 'audit-ocean-first';
const _secondId = 'audit-forest-second';
const _thirdId = 'audit-flowers-third';
const _caption = '바다, 숲, 꽃을 함께 남긴 하루. 이 글은 그대로 보관해요.';
final _day = DateTime.utc(2026, 11, 16);

class _AssetPhoto extends MomentPhoto {
  const _AssetPhoto({required super.id, required this.asset})
    : super(
        path: '$_owner/moments/$_recordId/local-photo.jpg',
        width: 1000,
        height: 667,
      );

  final String asset;

  // 저장소 URL 해석이나 네트워크 접근 없이 실제 번들 사진을 표시한다.
  @override
  String get storageUri => 'asset:$asset';
}

final _record = MomentRecord(
  id: _recordId,
  recordDate: _day,
  caption: _caption,
  photos: const [
    _AssetPhoto(id: _firstId, asset: 'assets/frame_preview/ocean_shore.jpg'),
    _AssetPhoto(id: _secondId, asset: 'assets/frame_preview/forest_trail.jpg'),
    _AssetPhoto(id: _thirdId, asset: 'assets/frame_preview/spring_flowers.jpg'),
  ],
  revision: 1,
);

class _Repository extends Fake implements MomentsRepository {
  final pendingDates = <Completer<MomentJournal>>[];
  bool delayDateChecks = false;
  int reads = 0;

  @override
  String get currentUserId => _owner;

  @override
  Stream<String?> get authChanges => const Stream.empty();

  MomentJournal get journal => MomentJournal(
    today: _day,
    weekStart: momentWeekStart(_day),
    month: momentMonth(_day),
    records: [_record],
    weekPhotoCount: 3,
  );

  @override
  Future<MomentJournal> listMonth(DateTime? month) {
    reads++;
    if (!delayDateChecks) return Future.value(journal);
    final request = Completer<MomentJournal>();
    pendingDates.add(request);
    return request.future;
  }
}

// 이미지 디코딩은 실제 엔진 시간을 사용하므로 짧고 유한한 대기만 허용한다.
Future<void> _frames(WidgetTester tester, {int count = 10}) async {
  for (var frame = 0; frame < count; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 40));
  }
  expect(tester.takeException(), isNull);
}

List<String> _photoIds(WidgetTester tester) => tester
    .widgetList<MomentPhotoView>(find.byType(MomentPhotoView))
    .where((view) => view.photo != null)
    .map((view) => view.photo!.id)
    .toList(growable: false);

void main() {
  setUpAll(auditFonts);
  testWidgets('capture safe photo removal and undo', (tester) async {
    auditViewport(tester);
    final repository = _Repository();
    final drafts = MemoryMomentDraftStore();
    final publications = MemoryMomentPublicationRepository();
    final container = ProviderContainer(overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentDraftStoreProvider.overrideWithValue(drafts),
      momentPublicationRepositoryProvider.overrideWithValue(publications),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(debugShowCheckedModeBanner: false,
          theme: SnapFitTheme.light(), builder: (_, child) => auditFrame(child!),
          home: MomentComposeScreen(record: _record, today: _day)),
      ));
      await _frames(tester);
      final remove = find.descendant(of: find.byKey(const ValueKey(_firstId)),
        matching: find.byTooltip('이 사진 빼기')).first;
      await tester.ensureVisible(remove); await _frames(tester);
      repository.delayDateChecks = true;
      await tester.tap(remove); await tester.pump();
      await tester.tap(remove); await tester.pump();
      expect(repository.pendingDates, hasLength(1));
      expect(_photoIds(tester), [_firstId, _secondId, _thirdId]);
      await tester.ensureVisible(find.byKey(const ValueKey('moment-photo-change-status')));
      await tester.pump();
      await auditCapture(tester, '01-record-date-check-blocks-repeat', settle: false);
      repository.delayDateChecks = false;
      repository.pendingDates.single.complete(repository.journal);
      await _frames(tester);
      expect(_photoIds(tester), [_secondId, _thirdId]);
      final undo = find.byKey(const ValueKey('moment-undo-photo-removal'));
      await tester.ensureVisible(undo); await _frames(tester);
      await auditCapture(tester, '02-record-removed-with-undo');
      await tester.tap(undo); await _frames(tester);
      expect(_photoIds(tester), [_firstId, _secondId, _thirdId]);
      expect((await drafts.list(_owner)).single.existingPhotos.length, 3);
      await tester.ensureVisible(find.byKey(const ValueKey(_firstId)));
      await _frames(tester);
      await auditCapture(tester, '03-record-undo-restores-all-photos');
      expect(publications.publications, isEmpty);
      expect(publications.privateCalls, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink()); await _frames(tester,count:3);
      container.dispose(); await tester.pump();
    }
  });
}
