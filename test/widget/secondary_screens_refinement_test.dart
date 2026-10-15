import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/theme/snapfit_theme.dart';
import 'package:snap_fit/core/constants/snapfit_colors.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/dto/response/invite_link_response.dart';
import 'package:snap_fit/features/album/domain/entities/album.dart';
import 'package:snap_fit/features/album/domain/repositories/album_member_repository.dart';
import 'package:snap_fit/features/album/presentation/views/album_invite_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/home/home_album_cover_thumbnail.dart';
import 'package:snap_fit/features/album/presentation/widgets/reader/album_frozen_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/editor/text_style_picker_sheet.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/notification/domain/entities/app_notification_item.dart';
import 'package:snap_fit/features/notification/presentation/providers/notification_provider.dart';
import 'package:snap_fit/features/notification/presentation/views/notification_screen.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';
import 'package:snap_fit/features/profile/presentation/widgets/my_point_balance_card.dart';
import 'package:snap_fit/shared/widgets/experience_form_style.dart';
import 'package:snap_fit/shared/widgets/image_template_picker.dart';
import 'package:snap_fit/shared/widgets/catalog_favorite_widgets.dart';
import 'package:snap_fit/shared/widgets/experience_style.dart';
import 'ai_album_start_step_test.dart' show loadCreationFonts;

class _Members extends Mock implements AlbumMemberRepository {}

class _Support extends Mock implements SupportInquiryRepository {}

Widget _app(Widget screen, {bool dark = false, double scale = 1}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: dark ? SnapFitTheme.dark() : SnapFitTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    );

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = size.width > size.height
      ? const FakeViewPadding(left: 32, right: 48, bottom: 24)
      : const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

void main() {
  setUpAll(loadCreationFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'customer header status bar follows its light and dark background',
    (tester) async {
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          _app(
            const Scaffold(
              appBar: ExperienceHeader(title: '확인', themeAware: true),
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final header = find.byType(ExperienceHeader);
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: header,
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
        expect(
          region.value.statusBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
        expect(
          region.value.statusBarColor,
          SnapFitColors.backgroundOf(tester.element(header)),
        );
        expect(region.value.systemStatusBarContrastEnforced, false);
      }
    },
  );

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    for (final ratio in [.75, 1.0, 4 / 3]) {
      testWidgets(
        'completion shows real $ratio album and reachable actions at $size',
        (tester) async {
          _viewport(tester, size);
          var orders = 0;
          var closes = 0;
          final album = Album(
            id: 7,
            title: '내가 만든 앨범',
            ratio: '$ratio',
            coverTheme: 'classic',
            totalPages: 24,
            userId: 'qa',
            createdAt: '2026-10-07',
          );
          await tester.pumpWidget(
            ProviderScope(
              child: _app(
                AlbumFrozenScreen(
                  album: album,
                  onClose: () => closes++,
                  onOrder: () => orders++,
                ),
                dark: true,
                scale: 1.3,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final cover = tester.widget<HomeAlbumCoverThumbnail>(
            find.byKey(const ValueKey('completed-album-cover')),
          );
          expect(cover.album, same(album));
          final dimensions = tester.getSize(
            find.byKey(const ValueKey('completed-album-cover')),
          );
          expect(dimensions.width / dimensions.height, closeTo(ratio, .001));
          expect(find.text('FREEZE'), findsNothing);
          await tester.ensureVisible(find.text('책으로 주문 준비하기'));
          await tester.tap(find.text('책으로 주문 준비하기'));
          await tester.ensureVisible(find.text('완료'));
          await tester.tap(find.text('완료'));
          expect(orders, 1);
          expect(closes, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'photo ratio picker scrolls and returns final choice with large text $size',
      (tester) async {
        _viewport(tester, size);
        String? result;
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () async =>
                        result = await ImageTemplatePicker.show(
                          context,
                          currentKey: '1:1',
                        ),
                    child: const Text('사진 크기 선택'),
                  ),
                ),
              ),
            ),
            dark: true,
            scale: 1.6,
          ),
        );
        await tester.tap(find.text('사진 크기 선택'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('2:3'),
          160,
          scrollable: find
              .descendant(
                of: find.byType(GridView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
          tester.element(find.text('2:3')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.text('2:3')).bottom,
          lessThanOrEqualTo(size.height - (size.width > size.height ? 24 : 34)),
        );
        await tester.tap(find.text('2:3'));
        await tester.pumpAndSettle();
        expect(result, '2:3');
        expect(find.byType(ImageTemplatePicker), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'text style sheet keeps chrome and scroll within safe height $size',
      (tester) async {
        _viewport(tester, size);
        await tester.pumpWidget(
          ProviderScope(
            child: _app(
              Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(
                      onPressed: () =>
                          TextStylePickerSheet.show(context, currentKey: ''),
                      child: const Text('문구 선택'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('문구 선택'));
        await tester.pumpAndSettle();
        expect(find.text('텍스트 및 스티커'), findsOneWidget);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -450),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'full text style selection closes only picker, not underlying editor route',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          child: _app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        appBar: AppBar(title: const Text('편집 화면 유지')),
                        body: TextButton(
                          onPressed: () async =>
                              result = await TextStylePickerSheet.show(
                                context,
                                currentKey: '',
                              ),
                          child: const Text('문구 도구'),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('편집 열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('편집 열기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('문구 도구'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('모두 보기').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('모두 보기').first);
      await tester.pumpAndSettle();
      final choice = find.byWidgetPredicate(
        (widget) =>
            widget is CatalogFavoriteTile &&
            widget.itemKey == CatalogFavoriteKeys.textStyle('bubble'),
      );
      await tester.tap(
        find.descendant(of: choice, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      expect(result, 'bubble');
      expect(find.text('편집 화면 유지'), findsOneWidget);
      expect(find.text('문구 도구'), findsOneWidget);
      expect(find.byType(TextStylePickerSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invite role cannot change while link is being created; next link uses new role',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final members = _Members();
      final first = Completer<InviteLinkResponse>();
      when(
        () => members.invite(7, role: 'EDITOR'),
      ).thenAnswer((_) => first.future);
      when(() => members.invite(7, role: 'VIEWER')).thenAnswer(
        (_) async => const InviteLinkResponse(
          albumId: 7,
          token: 'viewer',
          link: 'https://snapfit.example/viewer',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [albumMemberRepositoryProvider.overrideWithValue(members)],
          child: _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범')),
        ),
      );
      await tester.pump();
      final toggle = find.byType(Switch).first;
      expect(tester.widget<Switch>(toggle).onChanged, isNull);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      first.complete(
        const InviteLinkResponse(
          albumId: 7,
          token: 'editor',
          link: 'https://snapfit.example/editor',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      verify(() => members.invite(7, role: 'EDITOR')).called(1);
      verify(() => members.invite(7, role: 'VIEWER')).called(1);
      expect(find.text('https://snapfit.example/editor'), findsNothing);
      expect(find.text('https://snapfit.example/viewer'), findsOneWidget);
    },
  );

  testWidgets('failed invite is retryable without copying stale link', (
    tester,
  ) async {
    final members = _Members();
    var requests = 0;
    when(() => members.invite(7, role: 'EDITOR')).thenAnswer((_) async {
      if (requests++ == 0) throw Exception('temporary failure');
      return const InviteLinkResponse(
        albumId: 7,
        token: 'ok',
        link: 'https://snapfit.example/retry',
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [albumMemberRepositoryProvider.overrideWithValue(members)],
        child: _app(const AlbumInviteScreen(albumId: 7, albumTitle: '우리 앨범')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('초대 링크 다시 만들기'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('https://snapfit.example/retry'), findsOneWidget);
    expect(find.byTooltip('링크 복사하기'), findsOneWidget);
  });

  testWidgets('support identifies missing fields without sending inquiry', (
    tester,
  ) async {
    _viewport(tester, const Size(844, 390));
    final support = _Support();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supportInquiryRepositoryProvider.overrideWithValue(support),
        ],
        child: _app(const SupportInquiryScreen(), dark: true, scale: 1.3),
      ),
    );
    await tester.ensureVisible(find.text('문의 보내기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('문의 보내기'));
    await tester.pumpAndSettle();
    expect(find.text('제목을 입력해주세요.'), findsOneWidget);
    expect(find.text('문의 내용을 입력해주세요.'), findsOneWidget);
    verifyNever(
      () => support.createInquiry(
        category: any(named: 'category'),
        subject: any(named: 'subject'),
        message: any(named: 'message'),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'support preserves draft and focused input through rotation and keyboard',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      addTearDown(tester.view.resetViewInsets);
      final support = _Support();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportInquiryRepositoryProvider.overrideWithValue(support),
          ],
          child: _app(const SupportInquiryScreen(), dark: true, scale: 1.5),
        ),
      );
      final subject = find.byKey(const ValueKey('support-subject'));
      final message = find.byKey(const ValueKey('support-message'));
      await tester.ensureVisible(subject);
      await tester.enterText(subject, '앨범 문의 초안');
      await tester.ensureVisible(message);
      await tester.enterText(message, '회전해도 작성한 내용을 유지해야 합니다.');
      tester.view.physicalSize = const Size(648, 320);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 24,
        bottom: 24,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 140);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-wide-form')), findsOneWidget);
      expect(
        tester.widget<TextFormField>(subject).controller!.text,
        '앨범 문의 초안',
      );
      expect(
        tester.widget<TextFormField>(message).controller!.text,
        '회전해도 작성한 내용을 유지해야 합니다.',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: message, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.ensureVisible(message);
      expect(tester.getBottomRight(message).dy, lessThanOrEqualTo(180));
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-wide-form')), findsNothing);
      expect(
        tester.widget<TextFormField>(message).controller!.text,
        '회전해도 작성한 내용을 유지해야 합니다.',
      );
      verifyNever(
        () => support.createInquiry(
          category: any(named: 'category'),
          subject: any(named: 'subject'),
          message: any(named: 'message'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark notification titles and point balance use readable ink', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationInboxProvider.overrideWith(
            (ref) async => [
              AppNotificationItem(
                id: 1,
                title: '함께 남긴 기록',
                body: '새 소식',
                type: 'album_invite',
                createdAt: DateTime(2026),
                isRead: false,
              ),
            ],
          ),
          notificationRetentionDaysProvider.overrideWith((ref) async => 90),
          myPointBalanceProvider.overrideWith((ref) async => 2400),
        ],
        child: _app(
          Scaffold(
            body: Column(
              children: [
                MyPointBalanceCard(onCharge: () {}),
                const Expanded(child: NotificationScreen()),
              ],
            ),
          ),
          dark: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final value in ['함께 남긴 기록', '새로운 소식', '2,400 P']) {
      final finder = find.text(value);
      final context = tester.element(finder);
      expect(
        tester.widget<Text>(finder).style!.color,
        ExperienceFormStyle.ink(context),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification failure offers a working retry', (tester) async {
    var requests = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        overrides: [
          notificationInboxProvider.overrideWith((ref) async {
            if (requests++ == 0) throw Exception('offline');
            return <AppNotificationItem>[];
          }),
          notificationRetentionDaysProvider.overrideWith((ref) async => 90),
        ],
        child: _app(const NotificationScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('다시 불러오기'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('알림이 없습니다.'), findsOneWidget);
  });
}
