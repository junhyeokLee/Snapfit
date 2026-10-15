import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/constants/cover_size.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/views/home_screen.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_draft_failure_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_creation_review_sheet.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step2.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_launch_pricing.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_product.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/auth/presentation/views/login_screen.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import '../fixtures/ai_template_design_fixture.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts, wrapCreation;
import 'login_screen_test.dart' show FakeAuthViewModel, FakeTokenStorage;
import 'home_screen_test.dart' as home_fixture;
import '../helpers/mock_repositories.dart';

class _ConsentStorage extends FakeTokenStorage {
  bool saved = false;
  @override
  Future<bool> hasRequiredConsent({
    required String termsVersion,
    required String privacyVersion,
  }) async => saved;
  @override
  Future<void> saveConsent({
    required String termsVersion,
    required String privacyVersion,
    required bool marketingOptIn,
    required String agreedAtIso,
  }) async => saved = true;
}

class _ConsentAuth extends FakeAuthViewModel {
  @override
  Future<void> syncConsentIfPresent() async {}
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  bool settle = true,
}) async {
  if (!const bool.fromEnvironment('JOURNEY_QA')) return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    const revision = String.fromEnvironment(
      'JOURNEY_REVISION',
      defaultValue: 'after',
    );
    Directory('output/creation-journey-qa').createSync(recursive: true);
    File(
      'output/creation-journey-qa/$name-$revision.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
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
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    CatalogFavorites.instance = CatalogFavorites();
    await CatalogFavorites.instance.load();
  });
  tearDown(() => CatalogFavorites.instance.dispose());

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('real home to album creation route at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final repo = MockAlbumRepository();
      stubFetchMyAlbums(repo, []);
      final catalog = MockTemplateRepository();
      stubGetTemplates(catalog, publishedCreationTemplates);
      final products = [
        for (final template in publishedCreationTemplates)
          PointShopProduct(
            productKey: pointShopTemplateKey(template),
            kind: 'template',
            assetId: pointShopTemplateKey(template).split(':').last,
            title: template.title,
            pointPrice:
                pointShopLaunchPrices[pointShopTemplateKey(template)]!.points,
            isActive: true,
          ),
      ];
      final key = GlobalKey();
      final width = size.width.toInt();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              albumRepositoryProvider.overrideWithValue(repo),
              authViewModelProvider.overrideWith(
                () => home_fixture.FakeAuthViewModel(
                  const UserInfo(id: 'test', name: '우리', provider: 'kakao'),
                ),
              ),
              notificationUnreadCountProvider.overrideWith((ref) async => 0),
              albumCreationCatalogProvider.overrideWith(
                (ref) => Stream.value(publishedCreationTemplates),
              ),
              templateRepositoryProvider.overrideWithValue(catalog),
            ],
            child: wrapCreation(
              const HomeScreen(),
              showShell: false,
              shopProducts: products,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'home-empty-$width');
      await tester.ensureVisible(
        find.byKey(const ValueKey('empty-home-create')),
      );
      await tester.tap(find.byKey(const ValueKey('empty-home-create')));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateFlowScreen), findsOneWidget);
      expect(find.text('앨범 만들기'), findsOneWidget);
      await _capture(tester, key, 'flow-start-$width');
      final hubScroll = find
          .descendant(
            of: find.byKey(const PageStorageKey('albumCreationHub')),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('creation-template--9301')),
        180,
        scrollable: hubScroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('creation-template--9301')));
      await tester.pumpAndSettle();
      await _capture(tester, key, 'flow-preview-$width');
      await tester.tap(find.text('이 디자인 선택'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      await _capture(tester, key, 'flow-setup-$width');
      await tester.tap(find.text('사진 채우기').last);
      await tester.pumpAndSettle();
      expect(find.byType(TemplatePhotoFillStep), findsOneWidget);
      await _capture(tester, key, 'flow-photos-$width');
      final innerPage = find.byKey(const ValueKey('fill-page-1'));
      await tester.scrollUntilVisible(
        innerPage,
        90,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('photo-fill-page-rail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(innerPage);
      await tester.pumpAndSettle();
      await _capture(tester, key, 'flow-photos-inner-$width');
      await tester.tap(find.text('나중에 채우기'));
      await tester.pumpAndSettle();
      await _capture(tester, key, 'flow-cover-$width');
      await tester.tap(find.text('전체 확인').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreationReviewSheet), findsOneWidget);
      expect(find.text('편집 시작'), findsOneWidget);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('AI wait and recovery native screens at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final key = GlobalKey();
      final width = size.width.toInt();
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: wrapCreation(
              const AiTemplateGeneratingStep(),
              dark: dark,
              textScale: dark ? 1.5 : 1,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));
        await _capture(
          tester,
          key,
          'generating${dark ? '-dark' : ''}-$width',
          settle: false,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: wrapCreation(
              AiAlbumDraftFailureStep(
                message: '연결이 지연되고 있어요. 네트워크 연결을 확인한 뒤 다시 시도해주세요.',
                primaryActionLabel: '디자인 요청 다시 보내기',
                isTemplateDesign: true,
                onRetryRange: () {},
                onManualStart: () {},
              ),
              dark: dark,
              textScale: dark ? 1.5 : 1,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, key, 'failure${dark ? '-dark' : ''}-$width');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets(
      'consent stays usable with large text and system insets at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(
          top: 24,
          bottom: 24,
          right: size.width > size.height ? 24 : 0,
        );
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final storage = _ConsentStorage();
        final auth = _ConsentAuth();
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                authViewModelProvider.overrideWith(() => auth),
                tokenStorageProvider.overrideWithValue(storage),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, __) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: SnapFitTheme.dark(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.5)),
                    child: child!,
                  ),
                  home: const LoginScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('카카오로 계속하기'));
        await tester.tap(find.text('카카오로 계속하기'));
        await tester.pumpAndSettle();
        expect(auth.kakaoCalled, isFalse);
        expect(
          tester
              .widget<ElevatedButton>(
                find.ancestor(
                  of: find.text('동의하고 계속'),
                  matching: find.byType(ElevatedButton),
                ),
              )
              .onPressed,
          isNull,
        );
        await _capture(tester, key, 'consent-${size.width.toInt()}');
        for (var i = 0; i < 2; i++) {
          await tester.ensureVisible(find.byType(Checkbox).at(i));
          await tester.tap(find.byType(Checkbox).at(i));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('동의하고 계속'));
        await tester.tap(find.text('동의하고 계속'));
        await tester.pump();
        expect(storage.saved, isTrue);
        expect(auth.kakaoCalled, isTrue);
        auth.completeKakao();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AI request retains input with keyboard and system insets at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewInsets = const FakeViewPadding(bottom: 200);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewInsets);
        AiTemplateBrief? result;
        await tester.pumpWidget(
          wrapCreation(
            AiTemplateBriefStep(
              onContinue: (brief) => result = brief,
              onBack: () {},
            ),
            dark: true,
            textScale: 1.5,
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('ai_template_brief')));
        await tester.enterText(
          find.byKey(const Key('ai_template_brief')),
          '우리 가족의 여름 기록',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ai_template_brief_continue')));
        expect(result?.prompt, '우리 가족의 여름 기록');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('account and album creation journey at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final width = size.width.toInt();

      Future<void> account(
        String name,
        List<String> actions, {
        bool passwordReset = false,
      }) async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              key: UniqueKey(),
              overrides: [
                authViewModelProvider.overrideWith(() => FakeAuthViewModel()),
                tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
              ],
              child: ScreenUtilInit(
                designSize: const Size(390, 844),
                builder: (_, __) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: SnapFitTheme.light(),
                  home: LoginScreen(startInPasswordReset: passwordReset),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final action in actions) {
          await tester.ensureVisible(find.text(action));
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: name);
        expect(
          tester
              .widget<SingleChildScrollView>(
                find.byType(SingleChildScrollView).first,
              )
              .controller
              ?.offset,
          0,
          reason: '$name starts at the top',
        );
        await _capture(tester, key, '$name-$width');
      }

      await account('login', []);
      await account('signup', ['이메일로 새 계정 만들기']);
      await tester.enterText(
        find.widgetWithText(TextFormField, '앨범에 표시할 이름'),
        '우리앨범',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'album@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '8자 이상'),
        'album1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '한 번 더 입력'),
        'album1234',
      );
      await _capture(tester, key, 'signup-filled-$width');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byType(Checkbox).at(i));
        await tester.tap(find.byType(Checkbox).at(i));
        await tester.pump();
      }
      await tester.ensureVisible(find.text('계정 만들기'));
      await tester.tap(find.text('계정 만들기'));
      await tester.pumpAndSettle();
      await _capture(tester, key, 'signup-confirmation-$width');
      expect(tester.takeException(), isNull);
      await account('email', ['이메일로 로그인']);
      await account('reset', ['이메일로 로그인', '비밀번호를 잊으셨나요?']);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'snapfit@example.com'),
        'album@example.com',
      );
      await tester.ensureVisible(find.text('재설정 메일 보내기'));
      await tester.tap(find.text('재설정 메일 보내기'));
      await tester.pumpAndSettle();
      await _capture(tester, key, 'reset-sent-$width');
      expect(tester.takeException(), isNull);
      await account('password-reset', [], passwordReset: true);

      final design = templateDesignDraft().design!;
      final pages = design.buildLayers(
        targetSize: coverCanvasBaseSize(design.coverSize),
      );
      final screens = <String, Widget>{
        'start': AiAlbumStartStep(
          onManualStart: () {},
          onAiStart: () {},
          templates: AsyncData(publishedCreationTemplates.take(6).toList()),
        ),
        'setup': AlbumCreateStep1(
          albumTitle: '오래 기억할 우리의 여름',
          selectedCover: coverSizes.first,
          selectedPageCount: 24,
          onTitleChanged: (_) {},
          onCoverSelected: (_) {},
          onPageCountChanged: (_) {},
          onNext: () {},
          onChangeDesign: () {},
        ),
        'photos': TemplatePhotoFillStep(
          pages: pages,
          cover: design.coverSize,
          onChanged: (_) {},
          onContinue: () {},
        ),
        'invite': AlbumCreateStep2(
          albumTitle: '오래 기억할 우리의 여름',
          selectedCover: coverSizes.first,
          selectedPageCount: 24,
          onNext: () {},
          onBack: () {},
        ),
        'brief': AiTemplateBriefStep(onContinue: (_) {}, onBack: () {}),
        'confirmation': AiAlbumPointConfirmationStep(
          designBrief: AiTemplateBrief(
            prompt: '제주 바다의 짙은 초록, 넓은 여백. 풍경은 크게, 작은 장면은 리듬감 있게. 글은 짧게.',
            pageCount: 24,
            aspect: AiTemplateAspect.square,
            printProductId: defaultCoverSize.productId,
          ),
          theme: AlbumTheme.custom,
          range: AiPhotoRange.manualSelection,
          pointCost: 300,
          balance: 2400,
          onConfirm: () {},
          onBack: () {},
        ),
      };
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: wrapCreation(entry.value)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.key);
        await _capture(tester, key, '${entry.key}-$width');
      }
    });
  }
}
