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
import 'package:snap_fit/shared/snapfit_image.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/memory_moment_publication_repository.dart';

final _today = DateTime.utc(2026, 11, 12);
const _asset = 'assets/frame_preview/ocean_shore.jpg';
final _record = MomentRecord(
  id: 'loading-record',
  recordDate: _today,
  caption: '저장 중에도 보존할 순간',
  revision: 1,
  photos: const [
    MomentPhoto(
      id: 'loading-photo',
      path: 'owner/moments/loading-record/photo.jpg',
      url: 'asset:$_asset',
      width: 1000,
      height: 665,
    ),
  ],
);

class _Repository extends Fake implements MomentsRepository {
  final changes = StreamController<String?>.broadcast();
  final pending = Completer<MomentRecord>();
  int saves = 0;

  @override
  String get currentUserId => 'owner';
  @override
  Stream<String?> get authChanges => changes.stream;
  @override
  Future<MomentJournal> listMonth(DateTime? month) async => MomentJournal(
    today: _today,
    month: month ?? momentMonth(_today),
    weekStart: momentWeekStart(_today),
    records: [_record],
    weekPhotoCount: 1,
  );
  @override
  Future<MomentRecord> save({
    required String id,
    required DateTime recordDate,
    required String caption,
    required List<MomentPhoto> existingPhotos,
    required List<MomentUpload> uploads,
    List<MomentPhoto> originalPhotos = const [],
    int? expectedRevision,
  }) {
    saves++;
    return pending.future;
  }
}

class _Publication extends MemoryMomentPublicationRepository {
  final pending = Completer<void>();

  @override
  Future<void> makePrivate(String recordId) async {
    privateCalls.add(recordId);
    await pending.future;
  }
}

Future<Future<void> Function()> _mount(
  WidgetTester tester,
  _Repository repository,
  _Publication publication,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      momentsRepositoryProvider.overrideWithValue(repository),
      momentDraftStoreProvider.overrideWithValue(MemoryMomentDraftStore()),
      momentPublicationRepositoryProvider.overrideWithValue(publication),
    ],
  );
  var closed = false;
  Future<void> close() async {
    if (closed) return;
    closed = true;
    // Provider의 날짜 갱신 타이머도 테스트 본문이 끝나기 전에 해제한다.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await repository.changes.close();
    tester.view.reset();
    await tester.pump();
  }

  addTearDown(close);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: SnapFitTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      MomentComposeScreen(record: _record, today: _today),
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
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      for (final image in tester.widgetList<SnapfitImage>(
        find.byType(SnapfitImage),
      )) {
        for (final source in [image.urlOrGs, ...image.fallbackSources]) {
          if (source.startsWith('asset:')) {
            await precacheImage(
              ResizeImage.resizeIfNeeded(
                image.memCacheWidth,
                image.memCacheHeight,
                AssetImage(source.substring(6)),
              ),
              tester.element(find.byType(SnapfitImage).first),
            );
          }
        }
      }
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(
          image.image,
          tester.element(find.byType(Image).first),
        );
      }
    });
  }
  await tester.pumpAndSettle();
  return close;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('moment-compose-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  if (target.evaluate().isEmpty) {
    // ListView는 화면 밖의 입력·저장 버튼을 아직 만들지 않을 수 있다.
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pump();
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _startSave(WidgetTester tester) async {
  final save = find.byKey(const ValueKey('moment-save'));
  await _reveal(tester, save);
  await tester.tap(save);
  // 보류된 저장의 로딩 표시에는 종료되지 않는 진행 애니메이션이 있다.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets(
    'pending save blocks the whole route and restores input on error',
    (tester) async {
      final repository = _Repository();
      final publication = _Publication();
      final close = await _mount(tester, repository, publication);
      try {
        await _startSave(tester);

        final overlay = find.byKey(const ValueKey('moment-save-overlay'));
        expect(overlay, findsOneWidget);
        expect(
          tester.getRect(overlay),
          tester.getRect(find.byType(MaterialApp)),
        );
        expect(find.byTooltip('뒤로가기').hitTestable(), findsNothing);
        final scroll = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('moment-compose-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final offset = scroll.position.pixels;
        await tester.drag(
          find.byKey(const ValueKey('moment-compose-scroll')),
          const Offset(0, 200),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(scroll.position.pixels, offset);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(MomentComposeScreen), findsOneWidget);
        expect(repository.saves, 1);

        repository.pending.completeError(const MomentException('다시 저장해 주세요.'));
        await tester.pumpAndSettle();
        expect(overlay, findsNothing);
        expect(find.text('다시 저장해 주세요.'), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('moment-caption')));
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('moment-caption')))
              .controller!
              .text,
          _record.caption,
        );
        await _reveal(tester, find.byKey(const ValueKey('moment-save')));
        expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('moment-save')))
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await close();
      }
    },
  );

  testWidgets('loading stays until the saved record privacy check finishes', (
    tester,
  ) async {
    final repository = _Repository();
    final publication = _Publication();
    final close = await _mount(tester, repository, publication);
    try {
      await _startSave(tester);
      repository.pending.complete(_record);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('moment-save-overlay')), findsOneWidget);
      expect(publication.privateCalls, [_record.id]);
      expect(find.byType(MomentComposeScreen), findsOneWidget);
      publication.pending.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('moment-save-overlay')), findsNothing);
      expect(find.byType(MomentComposeScreen), findsNothing);
      expect(find.text('기록 열기'), findsOneWidget);
      expect(repository.saves, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await close();
    }
  });
}
