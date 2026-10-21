import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as bitmap;
import 'package:photo_manager/photo_manager.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/data/gallery/browser_photo_asset.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/cover_size_picker.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/print_cover_type_picker.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';

import 'ai_album_start_step_test.dart' show wrapCreation;

Widget _reduced(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

BrowserPhotoAsset _photo() {
  // A tiny in-memory original makes this behavior test independent of browser
  // asset IO. No original, preview, or other image is exported to a file.
  final pixels = bitmap.Image(width: 8, height: 8);
  bitmap.fill(pixels, color: bitmap.ColorRgb8(86, 129, 119));
  final bytes = Uint8List.fromList(bitmap.encodePng(pixels));
  return BrowserPhotoAsset.fromStored(
    ownerId: 'fixture-owner',
    id: 'browser_feedback_fixture',
    name: 'feedback-fixture.png',
    width: 8,
    height: 8,
    createdAtSecond: 0,
    originalBytes: bytes,
    previewBytes: bytes,
    contentSha256: sha256.convert(bytes).toString(),
  );
}

List<List<LayerModel>> _pages({AssetEntity? photo}) => [
  [
    LayerModel(
      id: 'photo-slot',
      type: LayerType.image,
      position: const Offset(30, 30),
      width: 200,
      height: 200,
      asset: photo,
    ),
  ],
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final photoFixture = _photo();

  testWidgets(
    'size and binding selection retain keyboard and selected semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var cover = defaultCoverSize;
      await tester.pumpWidget(
        wrapCreation(
          StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                children: [
                  CoverSizePicker(
                    selectedCover: cover,
                    onSelected: (value) => setState(() => cover = value),
                  ),
                  PrintCoverTypePicker(
                    selected: cover.coverType,
                    onSelected: (type) =>
                        setState(() => cover = cover.withCoverType(type)),
                  ),
                ],
              ),
            ),
          ),
          showShell: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('print-size-selected-REDP_200_SOFT')),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(cover.sizeProductId, coverSizes[1].sizeProductId);
      final size = tester.getSemantics(
        find.byKey(ValueKey('print-size-${coverSizes[1].productId}')),
      );
      expect(size.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(size.hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup), isTrue);

      final hard = find.byKey(const ValueKey('print-cover-hard'));
      await tester.ensureVisible(hard);
      await tester.tap(hard);
      await tester.pumpAndSettle();
      expect(cover.coverType, PrintCoverType.hard);
      expect(
        find.byKey(const ValueKey('print-cover-selected-hard')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(hard).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'choice feedback uses accepted values and respects unavailable sizes',
    (tester) async {
      var requests = 0;
      await tester.pumpWidget(
        wrapCreation(
          CoverSizePicker(
            selectedCover: defaultCoverSize,
            availableCovers: coverSizes.take(2).toList(),
            onSelected: (_) => requests++,
          ),
        ),
      );
      await tester.tap(
        find.byKey(ValueKey('print-size-${coverSizes[1].productId}')),
      );
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.byKey(const ValueKey('print-size-selected-REDP_200_SOFT')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('print-size-selected-${coverSizes[1].productId}')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ValueKey('print-size-${coverSizes[2].productId}')),
      );
      expect(requests, 1);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('current settings update without moving focus: dark=$dark', (
      tester,
    ) async {
      var cover = defaultCoverSize;
      var pageCount = 20;
      late StateSetter updateHost;
      await tester.pumpWidget(
        wrapCreation(
          StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return AlbumCreateStep1(
                albumTitle: '선택 확인',
                sourceLabel: 'AI 템플릿',
                selectedCover: cover,
                selectedPageCount: pageCount,
                onTitleChanged: (_) {},
                onCoverSelected: (value) => setState(() => cover = value),
                onPageCountChanged: (value) =>
                    setState(() => pageCount = value),
                onNext: () {},
              );
            },
          ),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      final summary = find.byKey(const ValueKey('creation-selection-summary'));
      expect(
        tester.widget<Semantics>(summary).properties.label,
        contains('AI 템플릿 선택. 정사각형 20 × 20cm, 소프트커버 선택됨'),
      );
      final hard = find.byKey(const ValueKey('print-cover-hard'));
      await tester.ensureVisible(hard);
      await tester.tap(hard);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('페이지 늘리기'));
      await tester.tap(find.byTooltip('페이지 늘리기'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Semantics>(summary).properties.label,
        contains('하드커버 선택됨. 내지 22쪽.'),
      );
      // An accepted value can also arrive during title editing. The status
      // update must keep that input's focus instead of focusing its message.
      final titleFocus = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      titleFocus.requestFocus();
      await tester.pump();
      updateHost(() => pageCount = 24);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, titleFocus);
      expect(
        tester.widget<Semantics>(summary).properties.label,
        contains('내지 24쪽.'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'large text and reduced motion preserve selection layout $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          wrapCreation(
            _reduced(
              AlbumCreateStep1(
                albumTitle: '선택 확인',
                selectedCover: defaultCoverSize,
                selectedPageCount: 20,
                onTitleChanged: (_) {},
                onCoverSelected: (_) {},
                onPageCountChanged: (_) {},
                onNext: () {},
              ),
            ),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final layoutException = tester.takeException();
        if (layoutException != null) {
          debugPrint('Selection feedback layout $size: $layoutException');
        }
        expect(layoutException, isNull);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('creation-paper-content')))
              .height,
          greaterThan(0),
        );
        final option = find.byKey(const ValueKey('print-cover-hard'));
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        expect(option.hitTestable(), findsOneWidget);
        final material = tester.widget<Material>(
          find.ancestor(of: option, matching: find.byType(Material)).first,
        );
        expect(material.animationDuration, Duration.zero);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'photo completion waits for the parent document and undo clears it',
    (tester) async {
      final photo = photoFixture;
      var pages = _pages();
      var calls = 0;
      final selection = Completer<AssetEntity?>();
      await tester.pumpWidget(
        wrapCreation(
          StatefulBuilder(
            builder: (context, setState) => TemplatePhotoFillStep(
              pages: pages,
              cover: defaultCoverSize,
              onChanged: (value) => setState(() => pages = value),
              onContinue: () {},
              pickPhoto: () {
                calls++;
                return selection.future;
              },
            ),
          ),
        ),
      );
      final add = find.byKey(const ValueKey('fill-add-photos'));
      await tester.tap(add);
      await tester.pump();
      expect(calls, 1);
      expect(tester.widget<FilledButton>(add).onPressed, isNull);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('fill-continue')))
            .onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('fill-all-photos-placed')),
        findsNothing,
      );
      selection.complete(photo);
      await tester.pumpAndSettle();
      expect(pages.single.single.asset, same(photo));
      expect(find.text('모두 배치됨'), findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.byKey(const ValueKey('fill-progress-status')),
            )
            .properties
            .label,
        '사진 1장 모두 배치됨. 표지를 확인해주세요.',
      );
      await tester.tap(find.byKey(const ValueKey('photo-fill-undo')));
      await tester.pumpAndSettle();
      expect(pages.single.single.hasImageSource, isFalse);
      expect(find.text('모두 배치됨'), findsNothing);
      expect(find.text('나중에 채우기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a parent that declines a photo never shows completed feedback', (
    tester,
  ) async {
    final photo = photoFixture;
    var proposed = 0;
    await tester.pumpWidget(
      wrapCreation(
        TemplatePhotoFillStep(
          pages: _pages(),
          cover: defaultCoverSize,
          onChanged: (_) => proposed++,
          onContinue: () {},
          pickPhoto: () async => photo,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
    await tester.pumpAndSettle();
    expect(proposed, 1);
    expect(find.text('0 / 1'), findsOneWidget);
    expect(find.text('모두 배치됨'), findsNothing);
    expect(find.text('나중에 채우기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final fails in [false, true]) {
    testWidgets(
      'cancelled or failed selection has no success: failure=$fails',
      (tester) async {
        var proposed = 0;
        await tester.pumpWidget(
          wrapCreation(
            TemplatePhotoFillStep(
              pages: _pages(),
              cover: defaultCoverSize,
              onChanged: (_) => proposed++,
              onContinue: () {},
              pickPhoto: () async {
                if (fails) throw StateError('fixture photo read failed');
                return null;
              },
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('fill-add-photos')));
        await tester.pumpAndSettle();
        expect(proposed, 0);
        expect(find.text('모두 배치됨'), findsNothing);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('fill-add-photos')),
              )
              .onPressed,
          isNotNull,
        );
        if (fails) {
          expect(find.text('사진을 가져오지 못했어요. 다시 선택해주세요.'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
