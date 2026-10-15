import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/creation_workspace.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_completion_confirmation.dart';
import 'package:snap_fit/features/store/presentation/widgets/material_original_preview.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/point_shop/presentation/point_shop_purchase_sheet.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';

class _Stage extends StatefulWidget {
  const _Stage({super.key});
  @override
  State<_Stage> createState() => _StageState();
}

class _StageState extends State<_Stage> {
  int page = 7;
  @override
  Widget build(BuildContext context) => Text('page $page');
}

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets('frame originals keep their catalog proportions in any stage', (
    tester,
  ) async {
    viewport(tester, const Size(844, 390));
    for (final size in [const Size(360, 150), const Size(200, 280)]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MaterialOriginalPreview(
                productKey: 'frame:materialLinenOval',
                child: Container(key: const Key('frame-artwork')),
              ),
            ),
          ),
        ),
      );
      final art = tester.getSize(find.byKey(const Key('frame-artwork')));
      expect(art.width, art.height);
      expect(art.width, lessThanOrEqualTo(size.shortestSide));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'tall landscape keyboard leaves an editable field and preserves book state',
    (tester) async {
      viewport(tester, const Size(844, 390));
      final stage = GlobalKey<_StageState>();
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(toolbarHeight: 48),
            body: Builder(
              builder: (context) => CreationWorkspace(
                keyboardOpen: creationKeyboardIsOpen(context),
                stage: _Stage(key: stage),
                fields: Column(
                  children: [
                    const Text('앨범 제목'),
                    TextField(key: const Key('title'), controller: controller),
                    const SizedBox(height: 200),
                  ],
                ),
                actions: FilledButton(
                  key: const Key('continue'),
                  onPressed: () {},
                  child: const Text('다음'),
                ),
              ),
            ),
          ),
        ),
      );
      final originalStage = stage.currentState;
      await tester.enterText(find.byKey(const Key('title')), 'my album');
      final input = tester.state<EditableTextState>(find.byType(EditableText));
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('continue')), findsNothing);
      final rect = tester.getRect(find.byType(EditableText));
      expect(rect.height, greaterThanOrEqualTo(20));
      expect(rect.top, greaterThanOrEqualTo(48));
      expect(rect.bottom, lessThanOrEqualTo(390 - 220));
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(input),
      );
      expect(stage.currentState, same(originalStage));
      expect(controller.text, 'my album');
      tester.view.viewInsets = const FakeViewPadding();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('continue')).hitTestable(), findsOneWidget);
      expect(stage.currentState, same(originalStage));
      expect(find.text('page 7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final complete in [false, true]) {
      testWidgets('purchase frame proportions $size complete=$complete', (
        tester,
      ) async {
        viewport(tester, size);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PointShopPurchaseSheet(
                title: '리넨 자수 타원',
                access: const PointShopAccess(
                  productKey: 'frame:materialLinenOval',
                  pointPrice: 300,
                  available: true,
                  isFree: false,
                  owned: false,
                  remainingBalance: 12000,
                ),
                purchase: complete
                    ? const PointShopPurchase(
                        productKey: 'frame:materialLinenOval',
                        owned: true,
                        isFree: false,
                        chargedPoints: 300,
                        remainingBalance: 11700,
                        alreadyOwned: false,
                      )
                    : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rect = tester.getRect(find.byType(ImageFramePreview));
        expect(rect.width, closeTo(rect.height, .01));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final size in [
    const Size(320, 568),
    const Size(648, 320),
    const Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'completion confirmation fits $size dark=$dark at large type',
        (tester) async {
          viewport(tester, size);
          bool? confirmed;
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => confirmed =
                        await showAlbumCompletionConfirmation(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final dialog = tester.getRect(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(dialog.width, lessThanOrEqualTo(520));
          final confirm = find.byKey(
            const ValueKey('album-completion-confirm'),
          );
          await tester.ensureVisible(confirm);
          await tester.pumpAndSettle();
          expect(confirm.hitTestable(), findsOneWidget);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(confirmed, isTrue);
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('취소'));
          await tester.pumpAndSettle();
          expect(confirmed, isFalse);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
