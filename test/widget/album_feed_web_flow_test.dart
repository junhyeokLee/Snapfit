@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/utils/saved_album_experience.dart';
import 'package:snap_fit/features/album/presentation/views/album_saved_experience_screen.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/moments/presentation/views/moments_screen.dart';
import 'package:snap_fit/features/moments/presentation/widgets/moment_book_cover.dart';
import 'package:snap_fit/features/social/data/social_album_snapshot.dart';
import 'package:snap_fit/features/social/data/social_repository.dart';
import 'package:snap_fit/features/social/domain/social_models.dart';
import 'package:snap_fit/features/social/presentation/providers/social_providers.dart';
import 'package:snap_fit/features/social/presentation/views/social_saved_works_screen.dart';
import 'package:snap_fit/features/social/presentation/widgets/social_template_start_card.dart';
import 'package:snap_fit/shared/web/web_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SocialWork _work(String id) => SocialWork(
  id: id,
  title: '큰 사진으로 다시 보는 $id',
  author: const SocialProfile(
    userId: 'creator',
    displayName: '나의 사진 기록',
    handle: 'photo.archive',
  ),
  createdAt: DateTime(2026, 10, 26),
  aspectRatio: 1.5,
);

class _SavedRepository extends SocialRepository {
  _SavedRepository(this.owner)
    : super(
        SupabaseClient(
          'https://fixture.invalid',
          'test-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final String? Function() owner;
  Completer<SocialWorkPage>? pending;
  @override
  Future<SocialWorkPage> fetchSavedWorksPage({
    int offset = 0,
    int limit = 12,
  }) async {
    final wait = pending;
    pending = null;
    if (wait != null) return wait.future;
    return SocialWorkPage(
      items: [_work('${owner()}-one'), _work('${owner()}-two')],
      hasMore: false,
      nextOffset: 2,
    );
  }
}

Album _savedAlbum() => Album(
  id: 88,
  userId: 'owner',
  title: '내가 선택한 한 장',
  ratio: '1:1',
  updatedAt: 'saved-revision-1',
  targetPages: 2,
  coverLayersJson: jsonEncode({
    'pages': [
      for (final entry in <int>[0xff913945, 0xff297263, 0xff314d8c].indexed)
        {
          'index': entry.$1,
          'isCover': entry.$1 == 0,
          'backgroundColor': entry.$2,
          'layers': [],
        },
    ],
  }),
);

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(
  Widget child, {
  List<Override> overrides = const [],
  List<WebSection>? routes,
  double scale = 1,
  bool dark = false,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: SnapFitWebTheme.from(
      dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
    ),
    builder: (context, child) => WebNavigationScope(
      onNavigate: routes?.add ?? (_) {},
      onNotifications: () {},
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    ),
    home: child,
  ),
);

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      'web journal offers first photo and actual square book compact=$compact',
      (tester) async {
        await _size(
          tester,
          compact ? const Size(320, 720) : const Size(1440, 1000),
        );
        final today = momentToday();
        final journal = MomentJournal(
          today: today,
          weekStart: momentWeekStart(today),
          month: momentMonth(today),
          records: const [],
          weekPhotoCount: 0,
        );
        await tester.pumpWidget(
          _app(
            const MomentsScreen(),
            dark: compact,
            scale: compact ? 2.2 : 1,
            overrides: [
              momentsCurrentUserIdProvider.overrideWith((_) => 'owner'),
              momentsSessionProvider.overrideWith((_) => Stream.value('owner')),
              momentsMonthProvider.overrideWith((ref, month) async => journal),
              momentDraftSummariesForOwnerProvider.overrideWith(
                (ref, owner) async => const [],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('web-utility-header')),
          findsOneWidget,
        );
        final start = find.byKey(const ValueKey('moments-first-photo'));
        await tester.ensureVisible(start);
        await tester.pumpAndSettle();
        expect(start.hitTestable(), findsOneWidget);
        expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
        final book = find.byType(MomentBookCover);
        expect(book, findsOneWidget);
        expect(tester.getSize(book).aspectRatio, closeTo(1, .001));
        expect(find.text('정사각형 20 × 20cm'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'web gallery keeps the unified shell, large columns and owner isolation',
    (tester) async {
      await _size(tester, const Size(1440, 1000));
      String? owner = 'first';
      final repository = _SavedRepository(() => owner);
      final routes = <WebSection>[];
      await tester.pumpWidget(
        _app(
          const SocialSavedWorksScreen(),
          routes: routes,
          overrides: [
            socialCurrentUserIdProvider.overrideWith((_) => owner),
            socialAuthStateProvider.overrideWith((_) => const Stream.empty()),
            socialRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('web-global-header')), findsOneWidget);
      expect(find.byKey(const ValueKey('web-desktop-sidebar')), findsOneWidget);
      final first = find.byKey(const ValueKey('social-saved-card-first-one'));
      final second = find.byKey(const ValueKey('social-saved-card-first-two'));
      expect(tester.getSize(first).width, greaterThan(460));
      expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
      await tester.tap(find.byKey(const ValueKey('web-navigation-myProfile')));
      expect(routes, [WebSection.myProfile]);
      final response = Completer<SocialWorkPage>();
      repository.pending = response;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SocialSavedWorksScreen)),
      );
      owner = 'second';
      container.invalidate(socialCurrentUserIdProvider);
      expect(container.read(socialCurrentUserIdProvider), 'second');
      await tester.pump();
      expect(first, findsNothing);
      response.complete(
        SocialWorkPage(
          items: [_work('second-only')],
          hasMore: false,
          nextOffset: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('social-saved-card-second-only')),
        findsOneWidget,
      );
      expect(first, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'browser result shares only the explicitly selected saved page after fresh access checks',
    (tester) async {
      await _size(tester, const Size(1440, 1000));
      final saved = _savedAlbum();
      final original = saved.coverLayersJson;
      final fixturePng = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      Uint8List? output;
      String? filename;
      var reads = 0;
      final rendered = <int>[];
      await tester.pumpWidget(
        _app(
          const AlbumSavedExperienceScreen(albumId: 88, ownerId: 'owner'),
          overrides: [
            albumEditorOwnerReaderProvider.overrideWithValue(() => 'owner'),
            albumEditorOwnerChangesProvider.overrideWith(
              (_) => const Stream.empty(),
            ),
            savedAlbumLoaderProvider.overrideWithValue((_) async {
              reads++;
              return saved;
            }),
            savedAlbumPageRendererProvider.overrideWithValue((
              page,
              theme,
            ) async {
              rendered.add(page.index);
              return fixturePng;
            }),
            savedAlbumImageWriterProvider.overrideWithValue((
              bytes,
              name,
              origin,
            ) async {
              output = bytes;
              filename = name;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('saved-album-thumbnail-1')));
      await tester.pumpAndSettle();
      final export = find.byKey(const ValueKey('saved-album-export'));
      await tester.ensureVisible(export);
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(rendered, [1]);
      expect(reads, 3);
      expect(filename, 'snapfit-album-88-page-1.png');
      expect(output!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(output, same(fixturePng));
      expect(saved.coverLayersJson, original);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'browser real artwork renderer keeps selected saved page pixels and geometry',
    () async {
      final saved = _savedAlbum();
      final original = saved.coverLayersJson;
      final snapshot = SocialAlbumSnapshot.fromAlbum(saved);
      final page = snapshot.pages[1];
      final renderer = SocialSnapshotRenderer(
        loader: (_) async => throw StateError('No other page assets may load'),
      );
      // No text or font asset is present in this selected page. Font loading
      // is covered by native tests; browser PNG/JPEG photo codecs have their
      // own real-source tests alongside this geometry/pixel assertion.
      final png = await renderer.renderPage(page, theme: SnapFitTheme.light());
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(saved.coverLayersJson, original);
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.width > image.height ? image.width : image.height, 1440);
        expect(
          image.width / image.height,
          closeTo(page.canvasSize.aspectRatio, .002),
        );
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final center =
            ((image.height ~/ 2) * image.width + image.width ~/ 2) * 4;
        final pixels = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        expect(pixels.sublist(center, center + 4), [41, 114, 99, 255]);
      } finally {
        image.dispose();
        codec.dispose();
      }
    },
  );

  testWidgets(
    'browser account change during image preparation never opens the output writer',
    (tester) async {
      await _size(tester, const Size(390, 844));
      String? owner = 'owner';
      final changes = StreamController<String?>();
      addTearDown(changes.close);
      final pending = Completer<Uint8List>();
      var writes = 0;
      await tester.pumpWidget(
        _app(
          const AlbumSavedExperienceScreen(albumId: 88, ownerId: 'owner'),
          overrides: [
            albumEditorOwnerReaderProvider.overrideWithValue(() => owner),
            albumEditorOwnerChangesProvider.overrideWith((_) => changes.stream),
            savedAlbumLoaderProvider.overrideWithValue(
              (_) async => _savedAlbum(),
            ),
            savedAlbumPageRendererProvider.overrideWithValue(
              (_, _) => pending.future,
            ),
            savedAlbumImageWriterProvider.overrideWithValue((_, _, _) async {
              writes++;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('saved-album-open')).hitTestable(),
        findsOneWidget,
      );
      final export = find.byKey(const ValueKey('saved-album-export'));
      await tester.ensureVisible(export);
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pump();
      owner = 'other';
      changes.add(owner);
      await tester.pump();
      pending.complete(Uint8List.fromList([1]));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.textContaining('계정이 변경되었어요'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'template start remains readable and operable in compact web at large text',
    (tester) async {
      await _size(tester, const Size(320, 720));
      var starts = 0;
      await tester.pumpWidget(
        _app(
          SnapFitWebShell(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SocialTemplateStartCard(
                source: const SocialTemplateSource(
                  productKey: 'template:official-summer',
                  title: '공식 여름 기록 템플릿',
                ),
                onPressed: () => starts++,
              ),
            ),
          ),
          scale: 2.2,
        ),
      );
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('social-template-start-button'));
      await tester.ensureVisible(start);
      await tester.pumpAndSettle();
      await tester.tap(start);
      expect(starts, 1);
      expect(find.textContaining('작가가 사용한 공식 디자인'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
