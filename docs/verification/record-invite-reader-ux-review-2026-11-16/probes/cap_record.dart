// 실제 기록 작성 위젯을 사용하되 날짜 응답과 임시 저장은 메모리로 격리한다.
// 이 probe는 현재의 연속 제거 문제를 재현한다. 제품의 정상 동작 테스트가 아니다.
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
import 'audit_support.dart';

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
  testWidgets('capture record double removal while the same button waits', (
    tester,
  ) async {
    auditViewport(tester);
    final repository = _Repository();
    final drafts = MemoryMomentDraftStore();
    final publications = MemoryMomentPublicationRepository();
    final container = ProviderContainer(
      overrides: [
        momentsRepositoryProvider.overrideWithValue(repository),
        momentDraftStoreProvider.overrideWithValue(drafts),
        momentPublicationRepositoryProvider.overrideWithValue(publications),
      ],
    );
    var containerDisposed = false;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      if (!containerDisposed) {
        container.dispose();
        containerDisposed = true;
      }
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: SnapFitTheme.light(),
          builder: (context, child) => auditFrame(child!),
          home: MomentComposeScreen(record: _record, today: _day),
        ),
      ),
    );
    await _frames(tester);
    expect(_photoIds(tester), [_firstId, _secondId, _thirdId]);
    expect(drafts.drafts, isEmpty);
    await auditCapture(tester, 'record-01-three-photos-before-removal');

    final firstTile = find.byKey(const ValueKey(_firstId));
    final firstRemove = find.descendant(
      of: firstTile,
      matching: find.byTooltip('이 사진 빼기'),
    );
    expect(firstRemove, findsOneWidget);
    await tester.ensureVisible(firstRemove);
    await tester.pump();
    final originalButtonElement = tester.element(firstRemove);
    final readsBeforeTaps = repository.reads;
    repository.delayDateChecks = true;

    // 첫 응답이 오기 전에 같은 첫 사진의 같은 제거 버튼을 연속 탭한다.
    // 첫 사진을 지운 뒤 새로 올라온 두 번째 버튼을 누르는 시나리오가 아니다.
    await tester.tap(firstRemove);
    await tester.pump();
    expect(repository.pendingDates, hasLength(1));
    expect(_photoIds(tester), [_firstId, _secondId, _thirdId]);
    expect(tester.element(firstRemove), same(originalButtonElement));
    await tester.tap(firstRemove);
    await tester.pump();
    expect(repository.pendingDates, hasLength(2));
    expect(repository.reads - readsBeforeTaps, 2);
    expect(_photoIds(tester), [_firstId, _secondId, _thirdId]);
    expect(tester.element(firstRemove), same(originalButtonElement));
    await auditCapture(tester, 'record-02-same-button-two-date-checks-pending');

    // 두 요청에 같은 오늘 날짜를 동시에 돌려주면 두 콜백이 removeAt(0)을 실행한다.
    repository.delayDateChecks = false;
    for (final request in repository.pendingDates) {
      request.complete(repository.journal);
    }
    await _frames(tester);

    // 현재 버그의 관측값: 선택하지 않은 두 번째 사진까지 사라지고 세 번째만 남는다.
    expect(repository.reads - readsBeforeTaps, 2);
    expect(_photoIds(tester), [_thirdId]);
    expect(find.byKey(const ValueKey(_firstId)), findsNothing);
    expect(find.byKey(const ValueKey(_secondId)), findsNothing);
    expect(find.byKey(const ValueKey(_thirdId)), findsOneWidget);
    final remaining = tester.widget<MomentPhotoView>(
      find.byKey(const ValueKey('moment-existing-photo-0')),
    );
    expect(remaining.photo, same(_record.photos[2]));
    final caption = tester.widget<TextField>(
      find.byKey(const ValueKey('moment-caption')),
    );
    expect(caption.controller!.text, _caption);
    final savedDraft = (await drafts.list(_owner)).single;
    expect(savedDraft.existingPhotos.map((photo) => photo.id), [_thirdId]);
    expect(savedDraft.caption, _caption);
    expect(savedDraft.originalRecord!.photos.map((photo) => photo.id), [
      _firstId,
      _secondId,
      _thirdId,
    ]);
    expect(publications.publications, isEmpty);
    expect(publications.privateCalls, isEmpty);
    await auditCapture(tester, 'record-03-only-third-photo-remains');

    debugPrint(
      'RECORD_REMOVE_AUDIT same_button_taps=2 date_requests=2 '
      'before=[$_firstId,$_secondId,$_thirdId] after=[$_thirdId] '
      'draft_photos=${savedDraft.existingPhotos.length} caption_retained=true '
      'remaining_photo_identity_retained=true remote_writes=0',
    );

    // 외부 컨테이너의 날짜 갱신 타이머도 Flutter의 종료 검사 전에 해제한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await _frames(tester, count: 3);
    container.dispose();
    containerDisposed = true;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
