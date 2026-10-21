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
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/core/templates/studio_decoration_catalog.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/features/album/data/bundled_creation_templates.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_cover_frame.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/domain/account_deletion_request.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/point_shop/data/point_shop_provider.dart';
import 'package:snap_fit/features/point_shop/domain/point_shop_template_key.dart';
import 'package:snap_fit/features/profile/presentation/views/account_settings_screen.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/material_catalog_screen.dart';
import 'package:snap_fit/features/store/presentation/widgets/template_page_renderer.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/image_frame_style_picker.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

const _user = UserInfo(
  id: 'qa',
  name: '스냅핏 사용자',
  email: 'snapfit@example.com',
  provider: 'EMAIL',
);

class _PaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Auth extends AuthViewModel {
  _Auth({this.user = _user});
  final UserInfo user;
  int logouts = 0, deletes = 0;
  final resetEmails = <String>[];
  Future<void>? pendingDelete;
  bool failDelete = false, failReset = false;
  @override
  FutureOr<UserInfo?> build() => user;
  void switchAccount() => state = AsyncData(user.copyWith(id: 'other'));
  @override
  Future<void> logout() async {
    logouts++;
  }

  @override
  Future<AccountDeletionRequest> requestAccountDeletion() async {
    deletes++;
    if (failDelete) throw Exception('탈퇴 처리에 실패했어요. 다시 시도해 주세요.');
    await pendingDelete;
    return const AccountDeletionRequest(
      reference: 'DEL-1',
      alreadyRequested: false,
    );
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    resetEmails.add(email);
    if (failReset) throw Exception('메일을 보내지 못했어요.');
  }
}

Widget _app(
  Widget page, {
  bool dark = false,
  _Auth? auth,
  Future<Set<String>> Function()? owned,
  Future<List<PremiumTemplate>> Function()? templates,
  double? textScale,
}) => ProviderScope(
  key: UniqueKey(),
  retry: (_, __) => null,
  overrides: [
    authViewModelProvider.overrideWith(() => auth ?? _Auth()),
    ownedPointShopKeysProvider.overrideWith(
      (_) => owned?.call() ?? Future.value(<String>{}),
    ),
    pointShopCatalogProvider.overrideWith((_) async => []),
    templateListProvider.overrideWith(
      (_) => templates?.call() ?? Future.value(publishedCreationTemplates),
    ),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(
            textScale ?? (MediaQuery.sizeOf(context).width == 320 ? 1.3 : 1),
          ),
        ),
        child: child!,
      ),
      home: page,
    ),
  ),
);

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    bottom: 24,
    right: size.width > size.height ? 32 : 0,
  );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

Future<void> _paintArtwork(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('ACCOUNT_LIBRARY_QA')) return;
  await _paintArtwork(tester);
  await tester.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('output/account-library-qa')
      ..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Widget _accountHost(
  _Auth auth,
  ValueChanged<AccountSettingsResult?> onResult,
) => _app(
  Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async => onResult(
            await Navigator.push<AccountSettingsResult>(
              context,
              MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
            ),
          ),
          child: const Text('계정 열기'),
        ),
      ),
    ),
  ),
  auth: auth,
);

Future<void> _openAccount(
  WidgetTester tester,
  _Auth auth,
  ValueChanged<AccountSettingsResult?> onResult,
) async {
  _viewport(tester, const Size(390, 844));
  await tester.pumpWidget(_accountHost(auth, onResult));
  await tester.pumpAndSettle();
  await tester.tap(find.text('계정 열기'));
  await tester.pumpAndSettle();
}

void main() {
  _PaintBinding();
  setUpAll(() async {
    await loadCreationFonts();
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
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
      final id = '${size.width.toInt()}-${dark ? 'dark' : 'light'}';
      testWidgets('account profile, photo and safe deletion sheet $id', (
        tester,
      ) async {
        _viewport(tester, size);
        final key = GlobalKey();
        var photoChanges = 0;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: _app(
              AccountSettingsScreen(
                onChangePhoto: (_, __, ___) async => photoChanges++,
              ),
              dark: dark,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('snapfit@example.com'), findsOneWidget);
        await _capture(tester, key, 'account-$id');
        await tester.tap(find.byTooltip('프로필 사진 변경'));
        await tester.pumpAndSettle();
        expect(photoChanges, 1);
        await tester.ensureVisible(find.text('회원 탈퇴'));
        await tester.tap(find.text('회원 탈퇴'));
        await tester.pumpAndSettle();
        final delete = find.widgetWithText(FilledButton, '삭제 요청 접수');
        expect(tester.widget<FilledButton>(delete).onPressed, isNull);
        await _capture(tester, key, 'delete-$id');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(delete).onPressed, isNotNull);
        await tester.ensureVisible(find.text('취소'));
        expect(
          tester.getBottomRight(find.text('취소')).dy,
          lessThan(size.height - 24),
        );
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('owned library is themed and bounded $id', (tester) async {
        _viewport(tester, size);
        final spec = studioDecorations.first;
        final frame = imageFrameStyles.firstWhere(
          (item) => item.key.isNotEmpty,
        );
        final key = GlobalKey();
        final template = publishedCreationTemplates.firstWhere(
          (item) => item.id == -9501,
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: _app(
              const MaterialCatalogScreen(library: true),
              dark: dark,
              owned: () async => {
                'sticker:${spec.id}',
                'frame:${frame.key}',
                pointShopTemplateKey(template),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MaterialCatalogScreen));
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, SnapFitColors.backgroundOf(context));
        expect(find.text('3개 항목'), findsOneWidget);
        final title = tester.widget<Text>(find.text(spec.label).first);
        expect(title.style!.color, ExperienceFormStyle.ink(context));
        await _paintArtwork(tester);
        await _capture(tester, key, 'library-$id');
        expect(find.byType(HomeCoverFrame), findsWidgets);
        expect(find.byType(TemplatePageRenderer), findsNothing);
        expect(
          tester
              .widgetList<HomeCoverFrame>(find.byType(HomeCoverFrame))
              .every((cover) => cover.bindingArtwork != null),
          isTrue,
        );
        expect(
          find.byKey(const ValueKey('library-sidebar')),
          size.width > size.height ? findsOneWidget : findsNothing,
        );
        if (size.width > size.height) {
          for (final product in [
            pointShopTemplateKey(template),
            'sticker:${spec.id}',
            'frame:${frame.key}',
          ]) {
            await tester.ensureVisible(
              find.byKey(ValueKey('material-item-$product')),
            );
            await tester.pumpAndSettle();
            expect(
              tester
                  .getBottomRight(
                    find.byKey(ValueKey('material-item-$product')),
                  )
                  .dy,
              lessThanOrEqualTo(size.height - 24),
            );
          }
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('library name order is explicit and preserves ownership', (
    tester,
  ) async {
    _viewport(tester, const Size(844, 390));
    final first = studioDecorations[0], second = studioDecorations[1];
    final firstKey = 'sticker:${first.id}', secondKey = 'sticker:${second.id}';
    await CatalogFavorites.instance.toggle(
      CatalogFavoriteKeys.decoration(second.insertionValue),
    );
    var ownershipCalls = 0;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          const MaterialCatalogScreen(library: true),
          owned: () async {
            ownershipCalls++;
            return {firstKey, secondKey};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    Finder card(String product) =>
        find.byKey(ValueKey('material-item-$product'));
    expect(
      tester.getTopLeft(card(secondKey)).dx,
      lessThan(tester.getTopLeft(card(firstKey)).dx),
    );
    await tester.tap(find.byKey(const ValueKey('library-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-name')));
    await tester.pumpAndSettle();
    final expected = [(firstKey, first.label), (secondKey, second.label)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    expect(
      tester.getTopLeft(card(expected.first.$1)).dx,
      lessThan(tester.getTopLeft(card(expected.last.$1)).dx),
    );
    expect(find.text('구매 완료'), findsNWidgets(2));
    expect(ownershipCalls, 1);
    await _capture(tester, key, 'library-name-order');
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(card(firstKey), findsNothing);
    expect(card(secondKey), findsOneWidget);
    expect(find.text('이름순'), findsOneWidget);
    expect(ownershipCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library query, type and order survive rotation', (tester) async {
    _viewport(tester, const Size(390, 844));
    final spec = studioDecorations.firstWhere(
      (spec) => spec.category == StudioDecorationCategory.sticker,
    );
    await tester.pumpWidget(
      _app(
        const MaterialCatalogScreen(library: true),
        owned: () async => {'sticker:${spec.id}'},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-type-스티커')));
    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), spec.label);
    await tester.pumpAndSettle();
    await tester.tap(find.text('검색 접기'));
    await tester.tap(find.byKey(const ValueKey('library-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('library-sort-name')));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(844, 390);
    tester.view.padding = const FakeViewPadding(
      left: 44,
      right: 24,
      bottom: 24,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-sidebar')), findsOneWidget);
    expect(find.text('검색: ${spec.label}'), findsOneWidget);
    expect(find.text('이름순'), findsOneWidget);
    expect(find.text('1개 항목'), findsOneWidget);
    final scroll = find.byKey(const ValueKey('material-catalog-scroll'));
    final sidebar = tester.getRect(
      find.byKey(const ValueKey('library-sidebar')),
    );
    expect(sidebar.width, inInclusiveRange(136, 172));
    expect(tester.getTopLeft(scroll).dx, closeTo(sidebar.right + 1, .01));
    await tester.ensureVisible(find.byTooltip('검색 지우기'));
    await tester.tap(find.byTooltip('검색 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('검색: ${spec.label}'), findsNothing);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = const FakeViewPadding(bottom: 24);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-sidebar')), findsNothing);
    expect(find.text('이름순'), findsOneWidget);
    expect(find.text('1개 항목'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unlisted paid favorite is never labeled free', (tester) async {
    _viewport(tester, const Size(390, 844));
    final template = publishedCreationTemplates.firstWhere(
      (t) => t.id == -9501,
    );
    expect(template.isPremium, isTrue);
    await CatalogFavorites.instance.toggle(
      CatalogFavoriteKeys.template(template.id),
    );
    await tester.pumpWidget(_app(const MaterialCatalogScreen(library: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('판매 준비 중'), findsOneWidget);
    expect(find.text('무료'), findsNothing);
    expect(find.text('구매 완료'), findsNothing);
    expect(find.text('최근 즐겨찾기순'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('library batches and large text remain safe $size', (
      tester,
    ) async {
      _viewport(tester, size);
      if (size.width > size.height)
        tester.view.padding = const FakeViewPadding(
          left: 44,
          right: 24,
          bottom: 24,
        );
      final keys = {
        for (final spec in studioDecorations.take(36)) 'sticker:${spec.id}',
      };
      await tester.pumpWidget(
        _app(
          const MaterialCatalogScreen(library: true),
          owned: () async => keys,
          textScale: 1.5,
        ),
      );
      await tester.pumpAndSettle();
      int count() =>
          (tester.widget<SliverGrid>(find.byType(SliverGrid)).delegate
                  as SliverChildBuilderDelegate)
              .childCount!;
      final scroll = tester
          .widget<CustomScrollView>(
            find.byKey(const ValueKey('material-catalog-scroll')),
          )
          .controller!;
      expect(count(), 12);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(count(), 24);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(count(), 36);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-sort-name')));
      await tester.pumpAndSettle();
      expect(count(), 12);
      expect(scroll.offset, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('logout confirms once and returns the route result', (
    tester,
  ) async {
    final auth = _Auth();
    AccountSettingsResult? result;
    await _openAccount(tester, auth, (value) => result = value);
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 0);
    await tester.tap(find.widgetWithText(FilledButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(auth.logouts, 1);
    expect(result, AccountSettingsResult.signedOut);
    expect(find.byType(AccountSettingsScreen), findsNothing);
  });

  testWidgets(
    'deletion request reports failure and acceptance while retaining the session',
    (tester) async {
      final auth = _Auth()..failDelete = true;
      AccountSettingsResult? result;
      await _openAccount(tester, auth, (value) => result = value);
      Future<void> confirm() async {
        await tester.ensureVisible(find.text('회원 탈퇴'));
        await tester.tap(find.text('회원 탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '삭제 요청 접수'));
        await tester.pump();
      }

      await confirm();
      await tester.pumpAndSettle();
      expect(auth.deletes, 1);
      expect(result, isNull);
      expect(find.textContaining('탈퇴 처리에 실패'), findsOneWidget);
      final pending = Completer<void>();
      auth
        ..failDelete = false
        ..pendingDelete = pending.future;
      await confirm();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        await tester.state<NavigatorState>(find.byType(Navigator)).maybePop(),
        true,
      );
      await tester.pump();
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AccountSettingsScreen), findsOneWidget);
      expect(find.textContaining('접수번호 DEL-1'), findsOneWidget);
      expect(auth.logouts, 0);
      expect(auth.deletes, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('changed account cannot be deleted through an old confirmation', (
    tester,
  ) async {
    final auth = _Auth();
    await _openAccount(tester, auth, (_) {});
    await tester.tap(find.text('회원 탈퇴'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    auth.switchAccount();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제 요청 접수'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 0);
    expect(find.textContaining('로그인 계정이 변경'), findsOneWidget);
  });

  testWidgets(
    'password reset uses the current email and social accounts hide it',
    (tester) async {
      final auth = _Auth()..failReset = true;
      await _openAccount(tester, auth, (_) {});
      Future<void> send() async {
        await tester.tap(find.text('비밀번호 재설정'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('재설정 메일 보내기'));
        await tester.pumpAndSettle();
      }

      await send();
      expect(auth.resetEmails, ['snapfit@example.com']);
      expect(find.text('메일을 보내지 못했어요.'), findsOneWidget);
      auth.failReset = false;
      await send();
      expect(find.textContaining('재설정 메일을 보냈어요'), findsOneWidget);
      await tester.pumpWidget(
        _app(
          const AccountSettingsScreen(),
          auth: _Auth(user: _user.copyWith(provider: 'KAKAO')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('비밀번호 재설정'), findsNothing);
      expect(find.textContaining('카카오 계정의 비밀번호'), findsOneWidget);
    },
  );

  testWidgets('library loading and retry never imply no purchases', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final pending = Completer<Set<String>>();
    final key = GlobalKey();
    var calls = 0;
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(
          const MaterialCatalogScreen(library: true),
          dark: true,
          owned: () {
            calls++;
            return calls == 1
                ? pending.future
                : Future.value({'sticker:${studioDecorations.first.id}'});
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('보관함을 불러오고 있어요'), findsOneWidget);
    expect(find.text('0개 항목'), findsNothing);
    await _capture(tester, key, 'library-loading');
    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.text('보관함을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('아직 보관한 항목이 없어요.'), findsNothing);
    await _capture(tester, key, 'library-error');
    await tester.tap(find.text('보관함 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('1개 항목'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('material ownership does not depend on failed templates', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final frame = imageFrameStyles.firstWhere((item) => item.key.isNotEmpty);
    await tester.pumpWidget(
      _app(
        const MaterialCatalogScreen(library: true),
        owned: () async => {'frame:${frame.key}'},
        templates: () async => throw Exception('template unavailable'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('보관함을 불러오지 못했어요'), findsOneWidget);
    await tester.tap(find.text('프레임'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('material-item-frame:${frame.key}')),
      findsOneWidget,
    );
    expect(find.text('보관함을 불러오지 못했어요'), findsNothing);
  });

  testWidgets(
    'refresh keeps purchased artwork visible and is safe after leaving',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final productKey = 'sticker:${studioDecorations.first.id}';
      final pending = Completer<Set<String>>();
      var calls = 0;
      await tester.pumpWidget(
        _app(
          const MaterialCatalogScreen(library: true),
          owned: () =>
              ++calls == 1 ? Future.value({productKey}) : pending.future,
        ),
      );
      await tester.pumpAndSettle();
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(find.byKey(ValueKey('material-item-$productKey')), findsOneWidget);
      expect(find.text('아직 보관한 항목이 없어요.'), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      pending.complete({productKey});
      await tester.runAsync(() => refresh);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty library is distinct from a network failure', (
    tester,
  ) async {
    _viewport(tester, const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: _app(const MaterialCatalogScreen(library: true)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('아직 보관한 항목이 없어요.'), findsOneWidget);
    expect(find.text('구매한 템플릿과 소재가 여기에 모여요.'), findsOneWidget);
    await _capture(tester, key, 'library-empty');
    await tester.tap(find.text('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾는 항목이 없어요.'), findsOneWidget);
    expect(find.text('구매한 템플릿과 소재가 여기에 모여요.'), findsNothing);
    await _capture(tester, key, 'favorites-empty');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'refresh updates ownership; latest favorites and search survive',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final first = studioDecorations[0], second = studioDecorations[1];
      final firstKey = 'sticker:${first.id}',
          secondKey = 'sticker:${second.id}';
      var owned = {firstKey};
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.decoration(first.insertionValue),
      );
      await CatalogFavorites.instance.toggle(
        CatalogFavoriteKeys.decoration(second.insertionValue),
      );
      await tester.pumpWidget(
        _app(
          const MaterialCatalogScreen(library: true),
          owned: () async => owned,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('material-item-$secondKey')), findsNothing);
      owned = {firstKey, secondKey};
      await tester.runAsync(
        tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('material-item-$secondKey')), findsOneWidget);
      await tester.tap(find.text('즐겨찾기'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(ValueKey('material-item-$secondKey'))).dx,
        lessThan(
          tester.getTopLeft(find.byKey(ValueKey('material-item-$firstKey'))).dx,
        ),
      );
      await tester.tap(find.text('검색'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '존재하지 않는 소재');
      await tester.pumpAndSettle();
      expect(find.text('조건에 맞는 항목이 없어요.'), findsOneWidget);
      await tester.tap(find.text('필터 초기화'));
      await tester.pumpAndSettle();
      expect(find.text('2개 항목'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
