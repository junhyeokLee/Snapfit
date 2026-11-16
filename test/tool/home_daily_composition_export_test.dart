import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/domain/entities/layer_export_mapper.dart';
import 'package:snap_fit/features/album/presentation/providers/home_ui_state_provider.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/home_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_shelf.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_slider.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_summary_card.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_moment_archive_shelf.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_bottom_navigation_bar.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/moments/data/moments_repository.dart';
import 'package:snap_fit/features/moments/domain/moment_record.dart';
import 'package:snap_fit/features/moments/presentation/providers/moment_entry_refresh_provider.dart';
import 'package:snap_fit/features/moments/presentation/providers/moments_providers.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/shared/snapfit_image.dart';

import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/fake_album.dart';
import '../helpers/memory_moment_draft_store.dart';
import '../helpers/mock_repositories.dart';
import '../widget/home_screen_test.dart' show FakeAuthViewModel;

class _Journal extends Fake implements MomentsRepository {
  int reads = 0;
  @override
  String? get currentUserId => '1';
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  Future<MomentJournal> listMonth(DateTime? requestedMonth) async {
    final month = requestedMonth ?? DateTime.utc(2026, 11);
    reads++;
    final today = DateTime.utc(2026, 11, 4);
    return MomentJournal(
      today: today,
      weekStart: momentWeekStart(today),
      month: month,
      weekPhotoCount: 3,
      records: [
        for (final day in [2, 3, 4])
          MomentRecord(
            id: '$day',
            recordDate: DateTime.utc(2026, 11, day),
            caption: day == 4
                ? '잠깐 멈춰 바라본, 오늘의 바다.'
                : day == 3
                ? '저녁빛이 길었던 날'
                : '천천히 걸었던 해변',
            revision: 1,
            photos: [
              MomentPhoto(
                id: 'photo-$day',
                path: '1/moments/$day.jpg',
                url:
                    'asset:assets/templates/jeju_travel/images/figma_small/${day == 4
                        ? 'jeju_ocean'
                        : day == 3
                        ? 'jeju_sunset'
                        : 'jeju_rocky_coast'}.jpg',
                width: 1200,
                height: 800,
              ),
            ],
          ),
        MomentRecord(
          id: 'note',
          recordDate: DateTime.utc(2026, 11, 1),
          caption: '창가에서 듣던 노래를 적었어요.',
          photos: const [],
          revision: 1,
        ),
      ],
    );
  }
}

Album _reviewAlbum(int id, double ratio, String title, String photo) {
  final canvas = Size(500, 500 / ratio);
  Map<String, dynamic> image(
    String id,
    double x,
    double width, {
    bool empty = false,
  }) => LayerExportMapper.toJson(
    LayerModel(
      id: id,
      type: LayerType.image,
      position: Offset(x, 0),
      width: width,
      height: canvas.height,
      imageUrl: empty ? null : 'asset:$photo',
    ),
    canvasSize: canvas,
  );
  return fakeAlbum(
    id: id,
    ratio: '$ratio',
    totalPages: 2,
    coverLayersJson: jsonEncode({
      'pages': [
        {
          'index': 0,
          'isCover': true,
          'layers': [image('cover', 0, 500)],
        },
        {
          'index': 1,
          'isCover': false,
          'layers': [
            image('photo', 0, 244),
            image('empty', 256, 244, empty: true),
          ],
        },
      ],
    }),
  ).copyWith(title: title, userId: '1', targetPages: 4);
}

Future<void> _loadReviewFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map>().where(
    (font) => ['NotoSans', 'Poppins', 'MaterialIcons'].contains(font['family']),
  )) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in entry['fonts'] as List) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _preparePhotos(WidgetTester tester) async {
  for (final element in find.byType(Image).evaluate()) {
    await precacheImage((element.widget as Image).image, element);
  }
  for (final element in find.byType(SnapfitImage).evaluate()) {
    final image = element.widget as SnapfitImage;
    if (!image.urlOrGs.startsWith('asset:')) continue;
    await precacheImage(
      ResizeImage.resizeIfNeeded(
        image.memCacheWidth,
        image.memCacheHeight,
        AssetImage(image.urlOrGs.substring(6)),
      ),
      element,
    );
  }
}

Future<void> _settleComposition(WidgetTester tester) async {
  // Covers deliberately enter a serial frame/isolate queue. Let real IO and
  // each queued cover finish instead of settling only the current fake frame.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(() async {
      await _preparePhotos(tester);
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
  }
  await tester.pumpAndSettle();
}

Future<void> _saveHome(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('EXPORT_HOME_DAILY_REVIEW')) return;
  if (const bool.fromEnvironment('HOME_ALBUM_ENTRY_ONLY') &&
      name != 'home-album-entry-390-light') {
    return;
  }
  await _settleComposition(tester);
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(key.currentContext!.findRenderObject()!);
  await tester.pump();
  await tester.runAsync(() async {
    const output = String.fromEnvironment('HOME_DAILY_REVIEW_OUTPUT');
    if (output.isEmpty) throw StateError('External review path required');
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$output/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadReviewFonts);
  for (final scene in [
    (size: const Size(390, 844), dark: false, scale: 1.0),
    (size: const Size(390, 844), dark: true, scale: 1.0),
    (size: const Size(320, 568), dark: false, scale: 2.0),
    (size: const Size(844, 390), dark: false, scale: 1.0),
  ]) {
    final dark = scene.dark;
    testWidgets(
      'home starts with the journal before albums ${scene.size.width.toInt()} ${dark ? 'dark' : 'light'} scale ${scene.scale}',
      (tester) async {
        await tester.binding.setSurfaceSize(scene.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({});
        final repository = MockAlbumRepository();
        final journal = _Journal();
        stubFetchMyAlbums(repository, [
          _reviewAlbum(701, .75, '둘만의 순간', 'assets/snapfit_home_portrait.jpg'),
          _reviewAlbum(702, 1, '우리의 느린 오후', 'assets/snapfit_home_square.jpg'),
          _reviewAlbum(
            703,
            4 / 3,
            '여름의 결',
            'assets/snapfit_home_landscape.jpg',
          ),
        ]);
        final key = GlobalKey();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              albumEditorOwnerReaderProvider.overrideWith(
                (_) =>
                    () => '1',
              ),
              homeUiStateProvider.overrideWith(
                () => HomeUiStateNotifier(initialIndex: 0),
              ),
              albumRepositoryProvider.overrideWithValue(repository),
              momentsRepositoryProvider.overrideWithValue(journal),
              momentEntryClockProvider.overrideWithValue(
                () => DateTime.utc(2026, 11, 4),
              ),
              momentDraftStoreProvider.overrideWithValue(
                MemoryMomentDraftStore(),
              ),
              albumCreationDraftStoreProvider.overrideWithValue(
                MemoryCreationDraftStore(),
              ),
              authViewModelProvider.overrideWith(
                () => FakeAuthViewModel(
                  const UserInfo(id: '1', name: '스냅핏', provider: 'email'),
                ),
              ),
              notificationUnreadCountProvider.overrideWith((_) async => 0),
              mockTemplateList(() async => const []),
            ],
            child: ScreenUtilInit(
              designSize: const Size(390, 844),
              builder: (_, __) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(scene.scale),
                  ),
                  child: RepaintBoundary(key: key, child: child!),
                ),
                home: const HomeScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(() async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(HomeScreen)),
            listen: false,
          );
          await container.read(homeViewModelProvider.future);
          await container.read(momentEntryJournalProvider.future);
          await _preparePhotos(tester);
        });
        await _settleComposition(tester);
        final scroll = tester
            .widget<SingleChildScrollView>(
              find.descendant(
                of: find.byType(HomeAlbumSlider),
                matching: find.byType(SingleChildScrollView),
              ),
            )
            .controller!;
        final shelf = find.byType(HomeAlbumShelf);
        final top = tester.getRect(find.byType(HomeAlbumSlider)).top;
        expect(scroll.offset, 0);
        expect(scroll.positions, hasLength(1));
        final today = find.byType(HomeMomentSummaryCard);
        final archive = find.byType(HomeMomentArchiveShelf);
        final nextTitle = find.byKey(
          const ValueKey('first-book-section-title'),
        );
        final next = find.byKey(const ValueKey('first-book-next-step'));
        final albumHeading = find.text('나의 앨범');
        final stage = find.byKey(const ValueKey('home-bookshelf-stage'));
        expect(tester.getRect(today).top, closeTo(top, .5));
        expect(
          tester.getRect(today).bottom,
          lessThanOrEqualTo(tester.getRect(archive).top),
        );
        expect(
          tester.getRect(archive).bottom,
          lessThan(tester.getRect(nextTitle).top),
        );
        expect(
          tester.getRect(next).bottom,
          lessThan(tester.getRect(albumHeading).top),
        );
        expect(
          tester.getRect(albumHeading).bottom,
          lessThan(tester.getRect(stage).top),
        );
        expect(find.text('11월 · 기록 4일 · 사진 3장'), findsOneWidget);
        expect(find.byType(HomeMomentArchiveShelf), findsOneWidget);
        expect(find.text('오늘의 기록').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final actionText = find.descendant(
          of: find.byKey(const ValueKey('home-monthly-feed-record')),
          matching: find.byType(Text),
        );
        final buttonRect = tester.getRect(
          find.byKey(const ValueKey('home-monthly-feed-record')),
        );
        final textRect = tester.getRect(actionText);
        expect(buttonRect.contains(textRect.topLeft), isTrue);
        expect(buttonRect.inflate(.5).contains(textRect.bottomRight), isTrue);
        if (scene.size.width == 390) {
          await _saveHome(
            tester,
            key,
            'home-journal-first-390-${dark ? 'dark' : 'light'}',
          );
        }
        final open = find.byKey(const ValueKey('home-focused-album-open'));
        scroll.jumpTo(
          (scroll.offset + tester.getTopLeft(albumHeading).dy - top)
              .clamp(0.0, scroll.position.maxScrollExtent)
              .toDouble(),
        );
        await _settleComposition(tester);
        if (open.hitTestable().evaluate().isEmpty) {
          await tester.ensureVisible(open);
          await tester.pumpAndSettle();
        }
        expect(open.hitTestable(), findsOneWidget);
        expect(tester.getSize(open).height, greaterThanOrEqualTo(44));
        if (scene.size.width == 390 && !dark) {
          await _saveHome(tester, key, 'home-album-entry-390-light');
          scroll.jumpTo(scroll.position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(
            tester.getRect(shelf).bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byType(HomeBottomNavigationBar)).top,
            ),
          );
        }
        expect(journal.reads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
