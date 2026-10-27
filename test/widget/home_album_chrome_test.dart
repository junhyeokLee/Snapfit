import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_header.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/shared/widgets/catalog_cover_skeleton.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';

class _GuestMoments extends Fake implements MomentsRepository {
  @override
  String? get currentUserId => null;
  @override
  Stream<String?> get authChanges => const Stream.empty();
}

void main() {
  testWidgets('album header opens the real private journal destination', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          momentsRepositoryProvider.overrideWithValue(_GuestMoments()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HomeAlbumHeader(collection: false)),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('home-moments-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(MomentsScreen), findsOneWidget);
    expect(find.text('로그인한 뒤 사진 한 장부터 시작할 수 있어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 1.8]) {
    testWidgets(
      'shared header keeps a plain plus and notifications at $scale',
      (tester) async {
        var collection = false;
        var created = 0;
        var resumed = 0;
        int? destination;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: ExperienceNavigationScope(
                  onNavigate: (index) => destination = index,
                  onBack: () {},
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      child: StatefulBuilder(
                        builder: (_, setState) => HomeAlbumHeader(
                          collection: collection,
                          onToggleView: () =>
                              setState(() => collection = !collection),
                          onCreateAlbum: () => created++,
                          onResumeDraft: () => resumed++,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final plus = find.byKey(const ValueKey('home-create-album'));
        final moments = find.byKey(const ValueKey('home-moments-entry'));
        expect(moments.hitTestable(), findsOneWidget);
        expect(tester.widget<IconButton>(moments).onPressed, isNotNull);
        expect(find.byTooltip('나의 기록'), findsOneWidget);
        expect(find.text('나의 기록'), findsNothing);
        expect(tester.getSize(moments), const Size(44, 44));
        final title = find.text('내 앨범');
        expect(
          tester.renderObject<RenderParagraph>(title).didExceedMaxLines,
          isFalse,
        );
        expect(tester.widget<IconButton>(plus).style?.backgroundColor, isNull);
        await tester.tap(plus);
        expect(created, 1);
        final notifications = find.byKey(
          const ValueKey('home-album-notifications'),
        );
        final position = tester.getTopLeft(notifications);
        await tester.tap(find.byTooltip('앨범 목록'));
        await tester.pump();
        expect(find.byTooltip('표지로 보기'), findsOneWidget);
        expect(find.byTooltip('알림'), findsOneWidget);
        expect(tester.getTopLeft(notifications), position);
        await tester.tap(notifications);
        expect(destination, 3);
        await tester.tap(find.text('이어서 만들기'));
        expect(resumed, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('journal stays in the compact header action row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 390,
              child: HomeAlbumHeader(
                collection: false,
                onToggleView: () {},
                onCreateAlbum: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final header = find.byType(HomeAlbumHeader);
    final journal = find.byKey(const ValueKey('home-moments-entry'));
    final view = find.byKey(const ValueKey('home-album-view-toggle'));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(tester.getCenter(journal).dy, tester.getCenter(view).dy);
      expect(tester.getSize(header).height, lessThan(100));
      expect(
        tester.getTopLeft(find.text('내 앨범')).dx,
        closeTo(tester.getTopLeft(header).dx + 24, .01),
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.getSemantics(journal).getSemanticsData().tooltip, '나의 기록');
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'empty state keeps album creation separate from the resume card',
    (tester) async {
      var created = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HomeEmptyState(onCreate: () => created++)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('아직 만든 앨범이 없어요'), findsOneWidget);
      expect(find.text('이어서 만들기'), findsNothing);
      await tester.ensureVisible(find.text('앨범 만들기'));
      await tester.tap(find.text('앨범 만들기'));
      expect(created, 1);
    },
  );

  for (final side in [0.0, 40.0, 200.0]) {
    testWidgets('cover skeleton is bounded and needs no ticker at $side', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: side,
              child: const CatalogCoverSkeleton(),
            ),
          ),
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
