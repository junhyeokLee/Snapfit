import 'dart:async';
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
import 'package:snap_fit/core/templates/studio_phrase_catalog.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/controllers/text_editor_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/photo_crop_sheet.dart';
import 'package:snap_fit/features/album/service/album_editor_service.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_access.dart';
import 'package:snap_fit/shared/widgets/color_palette_list.dart';
import 'package:snap_fit/shared/widgets/edit_text_overlay.dart';
import 'package:snap_fit/shared/widgets/font_picker_list.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';

import '../helpers/mock_repositories.dart';
import '../unit/album_editor_view_model_test.dart'
    show FakeAlbumPersistenceService, FakeStorageService;
import 'photo_crop_sheet_test.dart' show waitForCropPhoto;

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const _text = '여름의 한 장면\n오래 기억하고 싶은 순간';
const _style = TextStyle(
  fontFamily: 'NotoSans',
  fontSize: 24,
  color: Color(0xFF222A2B),
  fontWeight: FontWeight.w600,
  height: 1.4,
);

LayerModel _textLayer({TextStyle style = _style}) => LayerModel(
  id: 'dialog-text',
  type: LayerType.text,
  position: const Offset(20, 40),
  width: 300,
  height: 80,
  text: _text,
  textStyle: style,
  textAlign: TextAlign.center,
);

LayerModel _photo({bool missing = false}) => LayerModel(
  id: 'dialog-photo',
  type: LayerType.image,
  position: const Offset(30, 60),
  width: 280,
  height: 350,
  rotation: .12,
  opacity: .9,
  previewUrl: missing ? null : 'asset:assets/frame_preview/ocean_shore.jpg',
  imageBackground: 'polaroid',
  imageZoom: 1.2,
  imageOffset: const Offset(12, 16),
);

void main() {
  _PaintBinding();
  final boundary = GlobalKey();
  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List)
        loader.addFont(rootBundle.load(asset['asset'] as String));
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void metrics(WidgetTester tester, Size size, {double keyboard = 0}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = size.width > size.height
        ? FakeViewPadding(left: 32, right: 48, bottom: keyboard > 0 ? 0 : 24)
        : FakeViewPadding(top: 24, bottom: keyboard > 0 ? 0 : 34);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  }

  void reset(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewInsets);
  }

  Future<ProviderContainer> host(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1.3,
    TextStyle style = _style,
    bool missingPhoto = false,
    ValueChanged<LayerModel?>? onCrop,
    PointShopAccessGate? gate,
  }) async {
    await tester.pumpWidget(const SizedBox());
    final container = ProviderContainer(
      retry: (_, __) => null,
      overrides: [
        albumRepositoryProvider.overrideWithValue(MockAlbumRepository()),
        albumEditorServiceProvider.overrideWithValue(
          const AlbumEditorService(),
        ),
        albumPersistenceServiceProvider.overrideWithValue(
          FakeAlbumPersistenceService(),
        ),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        pointShopCatalogProvider.overrideWith(
          (ref) async => <PointShopProduct>[],
        ),
        ownedPointShopKeysProvider.overrideWith((ref) async => <String>{}),
        pointShopAccessGateProvider.overrideWithValue(
          gate ??
              (context, ref, {required productKey, required title}) async =>
                  true,
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(albumEditorViewModelProvider.future);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    vm.resetForCreate();
    vm.updatePageLayers([_textLayer(style: style)], recordHistory: false);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundary, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('open-text'),
                        tooltip: '문구 열기',
                        icon: const Icon(Icons.text_fields),
                        onPressed: () => TextEditorManager(
                          context,
                          vm,
                        ).openForExisting(vm.layers.single),
                      ),
                      IconButton(
                        key: const ValueKey('open-new-text'),
                        tooltip: '새 문구 열기',
                        icon: const Icon(Icons.add),
                        onPressed: () => TextEditorManager(
                          context,
                          vm,
                        ).openAndCreateNew(const Size(500, 500)),
                      ),
                      IconButton(
                        key: const ValueKey('open-crop'),
                        tooltip: '사진 구도 열기',
                        icon: const Icon(Icons.crop),
                        onPressed: () async {
                          final result = await showPhotoCropSheet(
                            context,
                            layer: _photo(missing: missingPhoto),
                          );
                          onCrop?.call(result);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  void safe(
    WidgetTester tester,
    Finder finder,
    Size size, {
    double keyboard = 0,
  }) {
    final rect = tester.getRect(finder);
    final wide = size.width > size.height;
    expect(rect.height, greaterThanOrEqualTo(44));
    expect(rect.left, greaterThanOrEqualTo(wide ? 32 : 0));
    expect(rect.right, lessThanOrEqualTo(size.width - (wide ? 48 : 0)));
    expect(
      rect.bottom,
      lessThanOrEqualTo(
        size.height -
            (keyboard > 0
                ? keyboard
                : wide
                ? 24
                : 34),
      ),
    );
  }

  Future<void> capture(
    WidgetTester tester,
    String name,
    Size size,
    bool dark,
  ) async {
    expect(tester.takeException(), isNull, reason: name);
    if (!const bool.fromEnvironment('EDITOR_DIALOGS_QA')) return;
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('output/all-screens-qa')
        ..createSync(recursive: true);
      File(
        '${dir.path}/$name-${size.width.toInt()}-${dark ? 'dark' : 'light'}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(648, 320),
    const Size(740, 360),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'native text and crop dialogs remain bounded at $size dark=$dark',
        (tester) async {
          reset(tester);
          metrics(tester, size);
          final container = await host(tester, dark: dark);
          await tap(tester, key('open-text'));
          safe(tester, key('text-edit-cancel'), size);
          safe(tester, key('text-edit-done'), size);
          await capture(tester, 'tools-text-font', size, dark);
          final keyboard = size.width > size.height ? 140.0 : 260.0;
          metrics(tester, size, keyboard: keyboard);
          await tester.pumpAndSettle();
          safe(tester, key('text-edit-done'), size, keyboard: keyboard);
          expect(
            tester.getSize(key('text-edit-input')).height,
            greaterThan(32),
          );
          await capture(tester, 'tools-text-keyboard', size, dark);
          metrics(tester, size);
          await tester.pumpAndSettle();
          expect(find.byType(EditTextOverlay), findsOneWidget);
          await tap(tester, key('text-edit-color-tool'));
          await tap(tester, find.byTooltip('#FFFFFF').first);
          await capture(tester, 'tools-text-color', size, dark);
          await tap(tester, key('text-edit-outline-tool'));
          await capture(tester, 'tools-text-outline', size, dark);
          await tap(tester, key('studio-phrase-tool'));
          await capture(tester, 'tools-text-phrases', size, dark);
          await tap(tester, find.byTooltip('소재 검색'));
          await tester.enterText(key('editor-material-search'), '없는 검색 결과');
          metrics(tester, size, keyboard: keyboard);
          await tester.pumpAndSettle();
          await tester.ensureVisible(key('editor-material-search'));
          await tester.pumpAndSettle();
          safe(tester, key('editor-material-search'), size, keyboard: keyboard);
          await capture(tester, 'tools-phrase-search', size, dark);
          metrics(tester, size);
          await tester.pumpAndSettle();
          await tap(tester, find.byTooltip('검색 지우기'));
          await tap(tester, find.text(studioPhrases.first.text));
          await tester.enterText(key('text-edit-input'), '회전해도 이어지는 문구');
          await tap(tester, key('text-edit-done'));
          expect(
            container
                .read(albumEditorViewModelProvider.notifier)
                .layers
                .single
                .text,
            '회전해도 이어지는 문구',
          );
          expect(find.byType(EditTextOverlay), findsNothing);
          await tester.tap(key('open-crop'));
          await waitForCropPhoto(tester);
          safe(tester, key('photo-crop-apply'), size);
          safe(tester, key('photo-crop-cancel'), size);
          await capture(tester, 'tools-photo-crop', size, dark);
          await tap(tester, key('photo-crop-cancel'));
          await host(tester, dark: dark, missingPhoto: true);
          await tap(tester, key('open-crop'));
          expect(
            tester.widget<ElevatedButton>(key('photo-crop-apply')).onPressed,
            isNull,
          );
          await capture(tester, 'tools-photo-error', size, dark);
          await tap(tester, key('photo-crop-cancel'));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    testWidgets(
      'large text with keyboard preserves draft and controls at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        final container = await host(tester, dark: true, scale: 1.8);
        await tap(tester, key('open-text'));
        await tester.enterText(
          key('text-edit-input'),
          '다섯 줄의 초안\n둘째 줄\n셋째 줄\n넷째 줄\n마지막 기록',
        );
        final keyboard = size.width > size.height ? 140.0 : 260.0;
        metrics(tester, size, keyboard: keyboard);
        await tester.pumpAndSettle();
        safe(tester, key('text-edit-done'), size, keyboard: keyboard);
        safe(tester, key('text-edit-cancel'), size, keyboard: keyboard);
        metrics(tester, size);
        await tester.pumpAndSettle();
        await tap(tester, key('text-edit-font-tool'));
        final pick = tester.widget<FontPickerList>(find.byType(FontPickerList));
        pick.onPick('Eulyoo');
        await tester.pumpAndSettle();
        final slider = tester.widget<Slider>(key('text-edit-size'));
        slider.onChanged!(34);
        await tester.pumpAndSettle();
        await tap(tester, key('text-edit-done'));
        final saved = container
            .read(albumEditorViewModelProvider.notifier)
            .layers
            .single;
        expect(saved.text, contains('마지막 기록'));
        expect(saved.textStyle!.fontFamily, 'Eulyoo');
        expect(saved.textStyle!.fontSize, 34);
        await tester.tap(key('open-crop'));
        await waitForCropPhoto(tester);
        safe(tester, key('photo-crop-apply'), size);
        safe(tester, key('photo-crop-cancel'), size);
        await tap(tester, key('photo-crop-cancel'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'keyboard hiding and rotation cannot discard text or rescale saved typography',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final container = await host(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.layers.single;
      await tap(tester, key('open-text'));
      await tester.enterText(key('text-edit-input'), '손으로 쓰고 남긴 문장');
      await tap(tester, key('text-edit-color-tool'));
      tester
          .widget<ColorPaletteList>(find.byType(ColorPaletteList))
          .onPick(Colors.teal);
      await tester.pumpAndSettle();
      await tap(tester, key('text-edit-font-tool'));
      tester
          .widget<FontPickerList>(find.byType(FontPickerList))
          .onPick('Eulyoo');
      await tester.pumpAndSettle();
      tester.widget<Slider>(key('text-edit-size')).onChanged!(36);
      await tester.pumpAndSettle();
      await tap(tester, key('text-edit-align-tool'));
      metrics(tester, const Size(390, 844), keyboard: 260);
      await tester.pumpAndSettle();
      metrics(tester, const Size(648, 320), keyboard: 140);
      await tester.pumpAndSettle();
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      expect(find.byType(EditTextOverlay), findsOneWidget);
      final input = tester.widget<TextField>(key('text-edit-input'));
      expect(input.controller!.text, '손으로 쓰고 남긴 문장');
      expect(input.style!.fontSize, 36);
      expect(input.style!.fontFamily, 'Eulyoo');
      expect(input.style!.color, Colors.teal);
      expect(input.textAlign, TextAlign.right);
      expect(vm.layers.single.text, before.text);
      final confirm = tester
          .widget<TextButton>(key('text-edit-done'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(vm.layers.single.text, '손으로 쓰고 남긴 문장');
      expect(vm.layers.single.position, before.position);
      expect(vm.layers.single.textStyle!.fontSize, 36);
      expect(vm.layers.single.textStyle!.color, Colors.teal);
      vm.undo();
      expect(vm.layers.single.text, before.text);
      expect(vm.layers.single.textStyle!.fontSize, before.textStyle!.fontSize);
      vm.redo();
      expect(vm.layers.single.text, '손으로 쓰고 남긴 문장');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel, empty creation and late callbacks do not mutate the album or close its page',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      final container = await host(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      final before = vm.layers.single;
      await tap(tester, key('open-text'));
      await tester.enterText(key('text-edit-input'), '취소할 초안');
      final late = tester.widget<TextButton>(key('text-edit-done')).onPressed!;
      await tap(tester, key('text-edit-cancel'));
      late();
      await tester.pumpAndSettle();
      expect(vm.layers.single.text, before.text);
      expect(key('open-text'), findsOneWidget);
      await tap(tester, key('open-new-text'));
      await tap(tester, key('text-edit-done'));
      expect(vm.layers.length, 1);
      expect(vm.layers.single.text, before.text);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'existing large font size is not silently rewritten by viewport or slider bounds',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final container = await host(
        tester,
        style: _style.copyWith(fontSize: 96),
      );
      await tap(tester, key('open-text'));
      metrics(tester, const Size(844, 390));
      await tester.pumpAndSettle();
      await tap(tester, key('text-edit-done'));
      expect(
        container
            .read(albumEditorViewModelProvider.notifier)
            .layers
            .single
            .textStyle!
            .fontSize,
        96,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'crop drag, rotation and reset keep frame geometry; apply only returns one draft',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(390, 844));
      final results = <LayerModel?>[];
      await host(tester, onCrop: results.add);
      await tester.tap(key('open-crop'));
      await waitForCropPhoto(tester);
      await tap(tester, find.byTooltip('사진 확대'));
      await tester.drag(key('photo-crop-preview'), const Offset(20, -24));
      await tester.pumpAndSettle();
      final before = tester
          .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .layers
          .single;
      metrics(tester, const Size(648, 320));
      await tester.pumpAndSettle();
      final rotated = tester
          .widget<TemplatePageRenderer>(find.byType(TemplatePageRenderer))
          .layers
          .single;
      expect(rotated.imageOffset, before.imageOffset);
      expect(rotated.imageZoom, before.imageZoom);
      await tap(tester, find.byTooltip('구도 초기화'));
      await tap(tester, find.byTooltip('사진 확대'));
      final confirm = tester
          .widget<ElevatedButton>(key('photo-crop-apply'))
          .onPressed!;
      confirm();
      confirm();
      await tester.pumpAndSettle();
      expect(results.length, 1);
      final saved = results.single!;
      expect(saved.position, _photo().position);
      expect(saved.rotation, _photo().rotation);
      expect(saved.opacity, _photo().opacity);
      expect(saved.width, _photo().width);
      expect(saved.imageBackground, 'polaroid');
      expect(saved.imageOffset, Offset.zero);
      expect(saved.imageZoom, closeTo(1.1, .001));
      await tester.tap(key('open-crop'));
      await waitForCropPhoto(tester);
      final late = tester
          .widget<ElevatedButton>(key('photo-crop-apply'))
          .onPressed!;
      await tap(tester, key('photo-crop-cancel'));
      late();
      await tester.pumpAndSettle();
      expect(results.length, 2);
      expect(results.last, isNull);
      expect(key('open-crop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(648, 320), const Size(844, 390)]) {
    testWidgets(
      'phrase search stays reachable above landscape keyboard at $size',
      (tester) async {
        reset(tester);
        metrics(tester, size);
        await host(tester);
        await tap(tester, key('open-text'));
        await tap(tester, key('studio-phrase-tool'));
        await tap(tester, find.byTooltip('소재 검색'));
        await tester.enterText(key('editor-material-search'), '없는 검색 결과');
        metrics(tester, size, keyboard: 140);
        await tester.pumpAndSettle();
        safe(tester, key('editor-material-search'), size, keyboard: 140);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('phrase query and focus survive rotation with large text', (
    tester,
  ) async {
    reset(tester);
    metrics(tester, const Size(390, 844));
    await host(tester, dark: true, scale: 1.8);
    await tap(tester, key('open-text'));
    await tap(tester, key('studio-phrase-tool'));
    await tap(tester, find.byTooltip('소재 검색'));
    await tester.enterText(key('editor-material-search'), '기억하고 싶은 문구');
    final controller = tester
        .widget<TextField>(key('editor-material-search'))
        .controller;
    final editable = find.descendant(
      of: key('editor-material-search'),
      matching: find.byType(EditableText),
    );
    final focus = tester.widget<EditableText>(editable).focusNode;
    metrics(tester, const Size(390, 844), keyboard: 260);
    await tester.pumpAndSettle();
    metrics(tester, const Size(648, 320), keyboard: 140);
    await tester.pumpAndSettle();
    await tester.ensureVisible(key('editor-material-search'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(key('editor-material-search')).controller,
      same(controller),
    );
    expect(controller!.text, '기억하고 싶은 문구');
    expect(tester.widget<EditableText>(editable).focusNode, same(focus));
    expect(focus.hasFocus, isTrue);
    safe(
      tester,
      key('editor-material-search'),
      const Size(648, 320),
      keyboard: 140,
    );
    metrics(tester, const Size(648, 320));
    await tester.pumpAndSettle();
    await tap(tester, find.byTooltip('닫기'));
    expect(find.byType(EditTextOverlay), findsOneWidget);
    expect(
      tester.widget<TextField>(key('text-edit-input')).controller!.text,
      _text,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dismissed phrase chooser cannot apply a late permission result or pop the text editor',
    (tester) async {
      reset(tester);
      metrics(tester, const Size(648, 320));
      final permission = Completer<bool>();
      var requests = 0;
      final container = await host(
        tester,
        gate: (context, ref, {required productKey, required title}) {
          requests++;
          return permission.future;
        },
      );
      await tap(tester, key('open-text'));
      await tap(tester, key('studio-phrase-tool'));
      await tester.tap(find.text(studioPhrases.first.text));
      await tester.pump();
      await tester.tap(find.text(studioPhrases.first.text));
      await tester.pump();
      expect(requests, 1);
      final close = tester
          .widget<IconButton>(key('phrase-sheet-close'))
          .onPressed!;
      close();
      close();
      await tester.pumpAndSettle();
      permission.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(EditTextOverlay), findsOneWidget);
      expect(
        tester.widget<TextField>(key('text-edit-input')).controller!.text,
        _text,
      );
      expect(
        container
            .read(albumEditorViewModelProvider.notifier)
            .layers
            .single
            .text,
        _text,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
