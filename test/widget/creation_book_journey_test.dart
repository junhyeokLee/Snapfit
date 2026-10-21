import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/templates/data_template_engine.dart';
import 'package:snap_fit/core/templates/template_document_pages.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_document_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_template_preview.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';

import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

late List<List<LayerModel>> _pages;
final _canvas = coverCanvasBaseSize(defaultCoverSize);

class _Photo extends Mock implements AssetEntity {}

Widget _app(
  Widget body, {
  bool dark = false,
  double scale = 1,
  GlobalKey? capture,
}) => ProviderScope(
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SnapFitTheme.light(),
      darkTheme: SnapFitTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: body is CreationTemplatePreview
          ? body
          : Scaffold(
              backgroundColor: dark ? const Color(0xFF111111) : Colors.white,
              appBar: AppBar(
                title: const Text('앨범 만들기', style: TextStyle(fontSize: 18)),
              ),
              body: body,
            ),
    ),
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 44, right: 24, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _paint(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CREATION_BOOK_QA')) return;
  await _paint(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('output/editor-flow-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

List<List<LayerModel>> _withMissingPhotos(Set<int> indices) => [
  for (final (index, page) in _pages.indexed)
    if (!indices.contains(index))
      page
    else
      [
        for (final layer in page)
          if (layer.type != LayerType.image)
            layer
          else
            layer.copyWith(clearImage: true),
      ],
];

void main() {
  _PaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    final template = publishedCreationTemplates.firstWhere(
      (item) => item.id == -9501,
    );
    final document = jsonDecode(template.templateJson!) as Map<String, dynamic>;
    _pages = [
      for (final page in templateDocumentPages(document))
        DataTemplateEngine.buildLayersFromJson({
          'strictLayout': true,
          'designWidth': 500,
          'designHeight': 500,
          'layers': page['layers'],
        }, _canvas),
    ].take(25).toList(growable: false);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'book surfaces, missing-page repair and source safety $size dark=$dark',
        (tester) async {
          _size(tester, size);
          final key = GlobalKey();
          final suffix = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
          await tester.pumpWidget(
            _app(
              CreationTemplatePreview(
                title: '약속을 묶은 책',
                isPremium: true,
                pages: _pages,
                canvas: _canvas,
                preserveTypography: true,
                onUse: () {},
                onRetry: () {},
                accessBadge: const Text('템플릿'),
              ),
              dark: dark,
              capture: key,
            ),
          );
          await _paint(tester);
          final stage = find.byKey(const ValueKey('creation_document_stage'));
          final frame = tester.widget<HomeCoverFrame>(
            find
                .descendant(of: stage, matching: find.byType(HomeCoverFrame))
                .first,
          );
          expect(frame.bindingArtwork, isNotNull);
          expect(frame.showBookDepth, isTrue);
          final list = tester.widget<ListView>(
            find.byKey(const ValueKey('creation_document_rail')),
          );
          expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
          await _capture(tester, key, 'creation-book-preview-$suffix');
          await tester.tap(find.byTooltip('다음 페이지'));
          await _paint(tester);
          await _capture(tester, key, 'creation-book-inner-$suffix');
          expect(tester.takeException(), isNull);

          final waiting = _withMissingPhotos({0});
          await tester.pumpWidget(
            _app(
              AlbumCreateStep1(
                albumTitle: '우리의 결혼 기록',
                templateTitle: '약속을 묶은 책',
                sourceLabel: '선택한 템플릿',
                coverLayers: waiting.first,
                preserveTypography: true,
                selectedCover: defaultCoverSize,
                selectedPageCount: 24,
                templatePageCount: 24,
                onTitleChanged: (_) {},
                onCoverSelected: (_) {},
                onPageCountChanged: (_) {},
                onNext: () {},
              ),
              dark: dark,
              capture: key,
            ),
          );
          await _paint(tester);
          expect(find.textContaining('사진 추가 전'), findsOneWidget);
          expect(find.byType(HomeCoverFrame), findsOneWidget);
          await _capture(tester, key, 'creation-book-setup-$suffix');

          final missingIndices = _pages
              .asMap()
              .entries
              .where(
                (entry) =>
                    entry.key > 1 &&
                    entry.value.any((layer) => layer.type == LayerType.image),
              )
              .map((entry) => entry.key)
              .skip(2)
              .take(2)
              .toSet();
          final review = _withMissingPhotos(missingIndices);
          var changed = 0;
          await tester.pumpWidget(
            _app(
              TemplatePhotoFillStep(
                pages: review,
                cover: defaultCoverSize,
                preserveTypography: true,
                onChanged: (_) => changed++,
                onContinue: () {},
                pickPhoto: () async => null,
              ),
              dark: dark,
              capture: key,
            ),
          );
          await _paint(tester);
          await _capture(tester, key, 'creation-book-fill-$suffix');
          final firstInner = find.byKey(const ValueKey('fill-page-1'));
          await tester.ensureVisible(firstInner);
          await tester.pumpAndSettle();
          expect(firstInner.hitTestable(), findsOneWidget);
          await tester.tap(firstInner);
          await _paint(tester);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('fill-current-page')))
                .data,
            startsWith(size.width > size.height ? '1–2쪽' : '1쪽'),
          );
          await _capture(tester, key, 'creation-book-fill-inner-$suffix');
          final photo = review[1].firstWhere(
            (layer) => layer.type == LayerType.image,
          );
          final interactivePage = find.byWidgetPredicate(
            (widget) =>
                widget is TemplatePageRenderer &&
                widget.onLayerTap != null &&
                identical(widget.layers, review[1]),
          );
          final pageRect = tester.getRect(interactivePage);
          await tester.tapAt(
            pageRect.topLeft +
                Offset(
                  (photo.position.dx + photo.width / 2) /
                      _canvas.width *
                      pageRect.width,
                  (photo.position.dy + photo.height / 2) /
                      _canvas.height *
                      pageRect.height,
                ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TemplatePageRenderer>(interactivePage)
                .selectedLayerId,
            photo.id,
          );
          expect(changed, 0);

          int? chosen;
          await tester.pumpWidget(
            _app(
              Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () async =>
                        chosen = await showAlbumCreationReview(
                          context,
                          pages: review,
                          innerPageCount: 24,
                          canvasSize: _canvas,
                        ),
                    child: const Text('전체 확인'),
                  ),
                ),
              ),
              dark: dark,
              capture: key,
            ),
          );
          await tester.tap(find.text('전체 확인'));
          await _paint(tester);
          await _capture(tester, key, 'creation-book-review-$suffix');
          await tester.tap(
            find.byKey(const ValueKey('creation-review-missing-filter')),
          );
          await _paint(tester);
          final grid = tester.widget<GridView>(
            find.byKey(const ValueKey('creation-review-pages')),
          );
          expect(
            (grid.childrenDelegate as SliverChildBuilderDelegate).childCount,
            missingIndices.length,
          );
          expect(
            find.byKey(const ValueKey('creation-review-page-0')),
            findsNothing,
          );
          await _capture(tester, key, 'creation-book-missing-$suffix');
          await tester.tap(
            find.byKey(ValueKey('creation-review-page-${missingIndices.last}')),
          );
          await tester.pumpAndSettle();
          expect(chosen, missingIndices.last);
          await tester.tap(find.text('전체 확인'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('creation-review-first-missing')),
          );
          await tester.pumpAndSettle();
          expect(chosen, missingIndices.first);
          expect(
            _pages.first.any(
              (layer) => layer.type == LayerType.image && layer.hasImageSource,
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('creation books and repair actions fit large type $size', (
      tester,
    ) async {
      _size(tester, size);
      await tester.pumpWidget(
        _app(
          CreationTemplatePreview(
            title: '약속을 묶은 책',
            isPremium: true,
            pages: _pages,
            canvas: _canvas,
            onUse: () {},
            onRetry: () {},
          ),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('이 디자인 선택').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      final missingPage = _pages.indexWhere(
        (page) => page.any((layer) => layer.type == LayerType.image),
        1,
      );
      final pages = _withMissingPhotos({missingPage});
      await tester.pumpWidget(
        _app(
          TemplatePhotoFillStep(
            pages: pages,
            cover: defaultCoverSize,
            onChanged: (_) {},
            onContinue: () {},
            pickPhoto: () async => null,
          ),
          scale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('사진 추가').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAlbumCreationReview(
                context,
                pages: pages,
                innerPageCount: 24,
                canvasSize: _canvas,
              ),
              child: const Text('전체 확인'),
            ),
          ),
          scale: 1.5,
        ),
      );
      await tester.tap(find.text('전체 확인'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('creation-review-start')).hitTestable(),
        findsOneWidget,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('creation-review-start')))
            .bottom,
        lessThanOrEqualTo(size.height - 24),
      );
      await tester.tap(
        find.byKey(const ValueKey('creation-review-missing-filter')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('creation-review-page-$missingPage')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    '80-page inspection keeps offscreen thumbnails lazy and selection on rotation',
    (tester) async {
      _size(tester, const Size(390, 844));
      final longBook = [
        for (var index = 0; index < 81; index++) _pages[index % _pages.length],
      ];
      await tester.pumpWidget(
        _app(
          CreationDocumentPreview(
            pages: longBook,
            canvas: _canvas,
            showBookMaterial: true,
            initialPage: 78,
            preserveTypography: true,
          ),
        ),
      );
      await _paint(tester);
      expect(find.byType(TemplatePageRenderer).evaluate().length, lessThan(16));
      expect(
        find.byKey(const ValueKey('creation_preview_page_78')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('creation_preview_page_0')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('다음 페이지'));
      await tester.pumpAndSettle();
      expect(find.text('79 / 80쪽'), findsOneWidget);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 24,
        bottom: 24,
      );
      await tester.pumpAndSettle();
      expect(find.text('79–80 / 80쪽'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('creation_preview_page_79')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing-only filter recovers when supplied photos are completed',
    (tester) async {
      _size(tester, const Size(390, 844));
      final key = GlobalKey();
      Widget review(List<List<LayerModel>> pages) => SizedBox(
        height: 700,
        child: AlbumCreationReviewSheet(
          key: key,
          pages: pages,
          innerPageCount: 24,
          canvasSize: _canvas,
        ),
      );
      final missingPage = _pages
          .asMap()
          .entries
          .firstWhere(
            (entry) =>
                entry.key > 0 &&
                entry.value.any((layer) => layer.type == LayerType.image),
          )
          .key;
      await tester.pumpWidget(_app(review(_withMissingPhotos({missingPage}))));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('creation-review-missing-filter')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('creation-review-missing-filter')),
            )
            .selected,
        isTrue,
      );
      await tester.pumpWidget(_app(review(_pages)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('creation-review-missing-filter')),
        findsNothing,
      );
      expect(find.text('사진 채움 완료'), findsOneWidget);
      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('creation-review-pages')),
      );
      expect(
        (grid.childrenDelegate as SliverChildBuilderDelegate).childCount,
        25,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final preview in [false, true])
    testWidgets(
      'late photo-file lookup cannot overwrite a replacement in ${preview ? 'document preview' : 'review'}',
      (tester) async {
        _size(tester, const Size(390, 844));
        final pending = Completer<File?>();
        final old = _Photo(), replacement = _Photo();
        await tester.pumpWidget(_app(const SizedBox()));
        await tester.runAsync(
          () => precacheImage(
            ResizeImage(
              FileImage(File('assets/snapfit_home_square.jpg')),
              width: 320,
            ),
            tester.element(find.byType(Scaffold)),
          ),
        );
        when(() => old.file).thenAnswer((_) => pending.future);
        when(
          () => replacement.file,
        ).thenAnswer((_) async => File('assets/snapfit_home_square.jpg'));
        var photo = old;
        late StateSetter update;
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final photoPages = [
                  [
                    LayerModel(
                      id: 'photo',
                      type: LayerType.image,
                      position: Offset.zero,
                      width: 500,
                      height: 500,
                      asset: photo,
                    ),
                  ],
                ];
                return SizedBox(
                  height: 650,
                  child: preview
                      ? CreationDocumentPreview(
                          pages: photoPages,
                          canvas: const Size(500, 500),
                          showBookMaterial: true,
                          showThumbnails: false,
                        )
                      : AlbumCreationReviewSheet(
                          pages: photoPages,
                          innerPageCount: 0,
                          canvasSize: const Size(500, 500),
                        ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => photo = replacement);
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
        pending.complete(File('assets/snapfit_home_portrait.jpg'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
        final rendered = tester.widgetList<TemplatePageRenderer>(
          find.byType(TemplatePageRenderer),
        );
        expect(rendered, isNotEmpty);
        expect(
          rendered.every(
            (page) =>
                page.localFiles?['photo']?.path ==
                'assets/snapfit_home_square.jpg',
          ),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );
}
