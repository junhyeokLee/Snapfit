import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/moments/domain/moment_draft.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/widgets/first_book_next_step_card.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_draft_recovery_card.dart';

import '../helpers/memory_moment_draft_store.dart';
import '../helpers/moment_draft_fixtures.dart';
import '../helpers/load_moment_capture_fonts.dart';

Album _book({int id = 1, String owner = 'owner-a', bool complete = false}) =>
    Album(
      id: id,
      userId: owner,
      memberRole: 'OWNER',
      title: '바람이 머문 제주',
      updatedAt: '2026-10-26T09:00:00Z',
      targetPages: 1,
      coverLayersJson: jsonEncode({
        'pages': [
          {'isCover': true, 'layers': []},
          {
            'isCover': false,
            'layers': complete
                ? [
                    {
                      'type': 'TEXT',
                      'templateContent': false,
                      'payload': {
                        'text': '우리가 남긴 하루',
                        'templateContent': false,
                      },
                    },
                  ]
                : [],
          },
        ],
      }),
    );

Future<void> _mount(
  WidgetTester tester,
  Widget child, {
  MemoryMomentDraftStore? store,
  bool dark = false,
  double scale = 1,
  Size size = const Size(390, 844),
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        momentDraftStoreProvider.overrideWithValue(
          store ?? MemoryMomentDraftStore(),
        ),
      ],
      child: MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: RepaintBoundary(
            key: capture,
            child: ColoredBox(
              color: (dark ? SnapFitTheme.dark() : SnapFitTheme.light())
                  .scaffoldBackgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (Platform.environment['FIRST_BOOK_CAPTURE_DIR'] != null) {
      await loadMomentCaptureFonts();
    }
  });
  testWidgets('local record recovery wins over creation and saved album', (
    tester,
  ) async {
    final store = MemoryMomentDraftStore()..seed(momentDraftFixture());
    String? destination;
    await _mount(
      tester,
      FirstBookNextStepCard(
        ownerId: 'owner-a',
        albums: [_book()],
        creationDraftTitle: '새 앨범',
        onResumeCreation: () => destination = 'creation',
        onDraft: (draft) => destination = draft.recordId,
        onMoments: () => destination = 'moments',
        onContinueAlbum: (_) => destination = 'album',
      ),
      store: store,
    );
    expect(find.text('남기던 순간 이어 쓰기'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first-book-next-step')));
    expect(destination, 'new-record');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only owned editable unfinished album is offered and its callback opens it',
    (tester) async {
      Album? destination;
      final own = _book();
      await _mount(
        tester,
        FirstBookNextStepCard(
          ownerId: 'owner-a',
          albums: [
            _book(id: 2, owner: 'another-owner'),
            _book(id: 3).copyWith(memberRole: 'VIEWER'),
            own,
          ],
          onMoments: () {},
          onDraft: (_) {},
          onContinueAlbum: (album) => destination = album,
        ),
      );
      expect(find.text('남은 1쪽부터 이어 만들어요.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('first-book-next-step')));
      expect(destination, same(own));
    },
  );

  testWidgets('a newer completed book does not hide an older unfinished book', (
    tester,
  ) async {
    Album? destination;
    final older = _book(
      id: 1,
    ).copyWith(title: '마저 만들던 여행', updatedAt: '2026-10-24T09:00:00Z');
    final newer = _book(
      id: 2,
      complete: true,
    ).copyWith(title: '완성한 하루', updatedAt: '2026-10-26T09:00:00Z');
    await _mount(
      tester,
      FirstBookNextStepCard(
        ownerId: 'owner-a',
        albums: [older, newer],
        onMoments: () => fail('unfinished book should be offered'),
        onDraft: (_) {},
        onContinueAlbum: (album) => destination = album,
      ),
    );
    expect(find.text('마저 만들던 여행'), findsOneWidget);
    expect(find.text('남은 1쪽부터 이어 만들어요.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('first-book-next-step')));
    expect(destination, same(older));
  });

  testWidgets(
    'completed book returns to the moments flow without claiming an unfinished page',
    (tester) async {
      var moments = 0;
      await _mount(
        tester,
        FirstBookNextStepCard(
          ownerId: 'owner-a',
          albums: [_book(complete: true)],
          onMoments: () => moments++,
          onDraft: (_) {},
          onContinueAlbum: (_) => fail('completed album'),
        ),
      );
      expect(find.text('다음 한 권의 시작'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('first-book-next-step')));
      expect(moments, 1);
    },
  );

  testWidgets('switching owner never paints the previous local draft', (
    tester,
  ) async {
    final store = MemoryMomentDraftStore()..seed(momentDraftFixture());
    Widget card(String owner) => FirstBookNextStepCard(
      ownerId: owner,
      albums: const [],
      onMoments: () {},
      onDraft: (_) {},
      onContinueAlbum: (_) {},
    );
    await _mount(tester, card('owner-a'), store: store);
    expect(find.text('남기던 순간 이어 쓰기'), findsOneWidget);
    await _mount(tester, card('owner-b'), store: store);
    expect(find.text('남기던 순간 이어 쓰기'), findsNothing);
    expect(find.text('한 장에서 나의 첫 한 권까지'), findsOneWidget);
  });

  testWidgets('all sibling drafts remain accessible in recovery chooser', (
    tester,
  ) async {
    final first = momentDraftFixture(caption: '첫 기록');
    final second = momentDraftFixture(recordId: 'second', caption: '두 번째 기록');
    String? resumed;
    await _mount(
      tester,
      MomentDraftRecoveryCard(
        drafts: [first, second]
            .map(
              (draft) => MomentDraftSummary.fromMetadata(
                draft.copyWith(version: 'fixture').toMetadata(),
              ),
            )
            .toList(),
        onResume: (draft) => resumed = draft.recordId,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('moments-all-drafts')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('두 번째 기록'));
    await tester.pumpAndSettle();
    expect(resumed, 'second');
  });

  for (final dark in [false, true]) {
    for (final size in [const Size(320, 844), const Size(1180, 900)]) {
      testWidgets(
        'next action handles large text dark=$dark width=${size.width}',
        (tester) async {
          await _mount(
            tester,
            FirstBookNextStepCard(
              compact: size.width < 600,
              ownerId: 'owner-a',
              albums: [_book()],
              onMoments: () {},
              onDraft: (_) {},
              onContinueAlbum: (_) {},
            ),
            dark: dark,
            size: size,
            scale: 2,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  final captureDir = Platform.environment['FIRST_BOOK_CAPTURE_DIR'];
  if (captureDir != null) {
    for (final dark in [false, true]) {
      testWidgets('capture recovery and next step dark=$dark', (tester) async {
        final draft = momentDraftFixture().copyWith(version: 'fixture');
        final key = GlobalKey();
        await _mount(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '내 앨범',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              FirstBookNextStepCard(
                ownerId: 'owner-a',
                albums: [_book()],
                onMoments: () {},
                onDraft: (_) {},
                onContinueAlbum: (_) {},
              ),
              const SizedBox(height: 32),
              Text(
                '나의 기록',
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              MomentDraftRecoveryCard(
                drafts: [MomentDraftSummary.fromMetadata(draft.toMetadata())],
                onResume: (_) {},
              ),
            ],
          ),
          dark: dark,
          capture: key,
        );
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '$captureDir/journey-${dark ? 'dark' : 'light'}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      });
    }
  }
}
