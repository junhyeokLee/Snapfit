import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_draft_failure_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_empty_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_error_state.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/editor_bottom_menu.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../fixtures/ai_template_design_fixture.dart';
import 'ai_album_start_step_test.dart' show wrapCreation, loadCreationFonts;

void main() {
  setUpAll(loadCreationFonts);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  testWidgets('topic, price and favorite filters combine and can be cleared', (
    tester,
  ) async {
    final templates = [
      for (var i = 1; i <= 3; i++)
        PremiumTemplate(
          id: i,
          title: '디자인 $i',
          category: i < 3 ? '여행' : '웨딩',
          coverImageUrl: '',
          previewImages: [],
          pageCount: 20,
          userCount: 0,
          isPremium: false,
        ),
    ];
    await CatalogFavorites.instance.toggle(CatalogFavoriteKeys.template(2));
    await tester.pumpWidget(
      wrapCreation(
        AiAlbumStartStep(
          onManualStart: () {},
          onAiStart: () {},
          templates: AsyncData(templates),
        ),
        shopProducts: const [
          PointShopProduct(
            productKey: 'template:server-2',
            kind: 'template',
            assetId: 'server-2',
            title: '디자인 2',
            pointPrice: 120,
            isActive: true,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creation-topic-여행')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creation-template-3')), findsNothing);
    await tester.tap(find.text('유료').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creation-template-1')), findsNothing);
    expect(find.byKey(const ValueKey('creation-template-2')), findsOneWidget);
    await tester.tap(find.byTooltip('즐겨찾기만 보기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creation-template-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('creation-topic-웨딩')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('creation-template-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('creation-template-3')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeout is retryable, never a misleading empty album state', (
    tester,
  ) async {
    var retries = 0;
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      await tester.pumpWidget(
        wrapCreation(
          HomeErrorState(
            error: DioException(
              requestOptions: RequestOptions(path: '/albums'),
              type: type,
            ),
            onRetry: () => retries++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HomeEmptyState), findsNothing);
      expect(find.text('앨범을 불러오지 못했어요'), findsOneWidget);
      expect(find.textContaining('anon key'), findsNothing);
      await tester.tap(find.text('다시 불러오기'));
    }
    expect(retries, 4);
  });

  testWidgets('empty home create and AI recovery actions remain functional', (
    tester,
  ) async {
    var created = 0, retry = 0, manual = 0;
    await tester.pumpWidget(
      wrapCreation(HomeEmptyState(onCreate: () => created++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('empty-home-create')));
    expect(created, 1);
    await tester.pumpWidget(
      wrapCreation(
        AiAlbumDraftFailureStep(
          message: '연결을 확인해주세요.',
          primaryActionLabel: '다시 시도하기',
          isTemplateDesign: true,
          onRetryRange: () => retry++,
          onManualStart: () => manual++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('포인트는 차감되지 않았어요.'), findsOneWidget);
    expect(find.textContaining('사진첩에 접근하거나'), findsOneWidget);
    await tester.tap(find.text('다시 시도하기'));
    await tester.tap(find.text('직접 구성하기'));
    expect(retry, 1);
    expect(manual, 1);
  });

  testWidgets('photo position keeps the exact selected page through rotation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final design = templateDesignDraft().design!;
    await tester.pumpWidget(
      wrapCreation(
        TemplatePhotoFillStep(
          pages: design.buildLayers(
            targetSize: coverCanvasBaseSize(design.coverSize),
          ),
          cover: design.coverSize,
          onChanged: (_) {},
          onContinue: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-page-2')));
    await tester.pumpAndSettle();
    final position = find.byKey(const ValueKey('fill-current-page'));
    expect(tester.widget<Text>(position).data, startsWith('2쪽'));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(position).data, startsWith('1–2쪽'));
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(position).data, startsWith('2쪽'));
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('creation tools keep every action available at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var mode = EditorMode.none;
      var photos = 0;
      await tester.pumpWidget(
        wrapCreation(
          StatefulBuilder(
            builder: (context, setState) => Center(
              child: EditorBottomMenu(
                currentMode: mode,
                isCover: true,
                showCoverMenuItem: false,
                useCreationStyle: true,
                onModeChanged: (value) => setState(() => mode = value),
                onAddPhoto: () => photos++,
              ),
            ),
          ),
          dark: true,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      for (final action in ['글', '사진', '레이아웃', '템플릿', '레이어', '꾸미기', '배경']) {
        await tester.ensureVisible(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }
      expect(photos, 1);
      expect(mode, EditorMode.backgroundColor);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'creation state screens with large text and system insets $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(
          top: 24,
          bottom: 24,
          left: 12,
          right: 12,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        for (final screen in [
          HomeEmptyState(onCreate: () {}),
          HomeErrorState(
            error: StateError('Private backend detail'),
            onRetry: () {},
          ),
          const AiTemplateGeneratingStep(),
          AiAlbumDraftFailureStep(
            title: 'AI 템플릿을 만들지 못했어요',
            message: '디자인 요청을 처리하지 못했어요. 네트워크 연결을 확인하고 다시 시도해주세요.',
            primaryActionLabel: '디자인 요청 다시 보내기',
            isTemplateDesign: true,
            onRetryRange: () {},
            onManualStart: () {},
          ),
        ]) {
          await tester.pumpWidget(
            wrapCreation(screen, dark: true, textScale: 1.5),
          );
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            tester.takeException(),
            isNull,
            reason: screen.runtimeType.toString(),
          );
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
