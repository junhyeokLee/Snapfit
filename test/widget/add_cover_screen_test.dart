import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/views/add_cover_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/album/presentation/controllers/layer_interaction_manager.dart';
import 'package:snap_fit/features/album/presentation/controllers/text_editor_manager.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/layer_action_panel.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (_, __) => MaterialApp(home: child),
    ),
  );
}

void main() {
  test('create flow layer action panel clears restored cover tools', () {
    double scaledBase(double value) => value;

    expect(
      coverLayerActionPanelBottom(
        isCreateFlow: true,
        scaleBaseOffset: scaledBase,
      ),
      greaterThanOrEqualTo(200),
    );
    expect(
      coverLayerActionPanelBottom(
        isCreateFlow: true,
        scaleBaseOffset: scaledBase,
        safeAreaBottom: 34,
      ),
      greaterThanOrEqualTo(238),
    );
    expect(
      coverLayerActionPanelBottom(
        isCreateFlow: false,
        scaleBaseOffset: scaledBase,
      ),
      100,
    );
    expect(
      coverLayerActionPanelBottom(
        isCreateFlow: true,
        scaleBaseOffset: (value) => value * 0.8,
        safeAreaBottom: 34,
      ),
      closeTo(204 + 34, 0.01),
    );
  });

  testWidgets(
    'create flow layer action offset clears measured dock with safe area',
    (tester) async {
      const viewport = Size(390, 760);
      const safeBottom = 34.0;
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              padding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: AddCoverScreen(
              isFromCreateFlow: true,
              initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
              albumTitle: '제주 여름 기록',
              targetPages: 24,
              onAlbumCreated: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dockTop = tester
          .getTopLeft(find.byKey(const Key('coverAtelierActionBar')))
          .dy;
      final layerPanelBottomY =
          viewport.height -
          coverLayerActionPanelBottom(
            isCreateFlow: true,
            scaleBaseOffset: (value) => value.h,
            safeAreaBottom: safeBottom,
          );

      expect(layerPanelBottomY, lessThanOrEqualTo(dockTop - 8));
    },
  );

  testWidgets(
    'create flow selected layer panel render box clears measured dock',
    (tester) async {
      const viewport = Size(390, 760);
      const safeBottom = 34.0;
      const layerId = 'selected-layer';
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              padding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: AddCoverScreen(
              isFromCreateFlow: true,
              initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
              albumTitle: '제주 여름 기록',
              targetPages: 24,
              initialTemplateCoverLayers: [
                LayerModel(
                  id: layerId,
                  type: LayerType.text,
                  position: const Offset(120, 120),
                  width: 180,
                  height: 52,
                  text: '표지 제목',
                ),
              ],
              debugInitialSelectedLayerId: layerId,
              onAlbumCreated: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LayerActionPanel), findsOneWidget);
      final dockTop = tester
          .getTopLeft(find.byKey(const Key('coverAtelierActionBar')))
          .dy;
      final panelBottom = tester
          .getBottomLeft(find.byType(LayerActionPanel))
          .dy;

      expect(panelBottom, lessThanOrEqualTo(dockTop - 8));
    },
  );

  testWidgets(
    'create flow selected image layer panel stays scrollable above dock',
    (tester) async {
      const viewport = Size(390, 760);
      const safeBottom = 34.0;
      const layerId = 'selected-image-layer';
      final imageLayer = LayerModel(
        id: layerId,
        type: LayerType.image,
        position: const Offset(90, 120),
        width: 220,
        height: 160,
      );
      await tester.binding.setSurfaceSize(viewport);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      LayerInteractionManager? interaction;

      await tester.pumpWidget(
        _wrap(
          MediaQuery(
            data: const MediaQueryData(
              size: viewport,
              padding: EdgeInsets.only(bottom: safeBottom),
            ),
            child: Consumer(
              builder: (context, ref, _) {
                return StatefulBuilder(
                  builder: (context, setState) {
                    interaction ??= LayerInteractionManager(
                      ref: ref,
                      coverKey: GlobalKey(),
                      setState: setState,
                      getCoverSize: () => const Size(500, 500),
                      onEditText: (_) {},
                    );
                    return Stack(
                      children: [
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: coverLayerActionPanelBottom(
                            isCreateFlow: true,
                            scaleBaseOffset: (value) => value.h,
                            safeAreaBottom: safeBottom,
                          ),
                          child: LayerActionPanel(
                            layers: [imageLayer],
                            interaction: interaction!,
                            textEditor: TextEditorManager(
                              context,
                              ref.read(albumEditorViewModelProvider.notifier),
                            ),
                            onRefresh: () => setState(() {}),
                          ),
                        ),
                        Positioned(
                          key: const Key('coverAtelierActionBar'),
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SizedBox(height: 204.h + safeBottom),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      interaction!.setSelectedLayer(layerId);
      await tester.pump();

      expect(find.byType(LayerActionPanel), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.open_with), findsOneWidget);
      expect(find.byIcon(Icons.opacity), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LayerActionPanel),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );

      final dockTop = tester
          .getTopLeft(find.byKey(const Key('coverAtelierActionBar')))
          .dy;
      final panelBottom = tester
          .getBottomLeft(find.byType(LayerActionPanel))
          .dy;

      expect(panelBottom, lessThanOrEqualTo(dockTop - 8));
    },
  );

  testWidgets(
    'create flow cover atelier focuses cover and contextual actions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AddCoverScreen(
            isFromCreateFlow: true,
            initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
            albumTitle: '제주 여름 기록',
            targetPages: 24,
            onAlbumCreated: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('표지 도구'), findsOneWidget);
      expect(find.text('글'), findsOneWidget);
      expect(find.text('사진'), findsOneWidget);
      expect(find.text('레이아웃'), findsOneWidget);
      expect(find.text('템플릿'), findsOneWidget);
      expect(find.text('레이어'), findsOneWidget);
      expect(find.text('스티커'), findsOneWidget);
      expect(find.text('배경'), findsOneWidget);
      expect(find.text('표지 완성'), findsOneWidget);
      expect(find.textContaining('함께 볼 사람'), findsNothing);
      expect(find.textContaining('초대'), findsNothing);
      expect(find.byType(EditorBottomMenu), findsOneWidget);
    },
  );

  testWidgets(
    'create flow cover atelier uses motion wrappers for premium entry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AddCoverScreen(
            isFromCreateFlow: true,
            initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
            albumTitle: '제주 여름 기록',
            targetPages: 24,
            onAlbumCreated: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('coverAtelierEntryFade')), findsOneWidget);
      expect(find.byKey(const Key('coverAtelierEntrySlide')), findsOneWidget);
      expect(
        find.byKey(const Key('coverAtelierPrimaryPressScale')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'create flow cover preview has focus reveal motion before controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          AddCoverScreen(
            isFromCreateFlow: true,
            initialCoverSize: coverSizes.firstWhere((s) => s.name == '정사각형'),
            albumTitle: '제주 여름 기록',
            targetPages: 24,
            onAlbumCreated: (_) {},
          ),
        ),
      );

      expect(find.byKey(const Key('coverFocusRevealFade')), findsOneWidget);
      expect(find.byKey(const Key('coverFocusRevealSlide')), findsOneWidget);
      expect(find.byKey(const Key('coverFocusRevealScale')), findsOneWidget);
    },
  );
}
