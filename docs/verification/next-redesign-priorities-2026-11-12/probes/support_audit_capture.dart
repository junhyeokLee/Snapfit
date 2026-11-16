// 현재 고객센터 진입·작성·접수·재방문을 가상 계정으로 확인한다.
// 실제 문의나 외부 메시지는 보내지 않는다.
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
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/home_news/data/admin_home_news_repository.dart';
import 'package:snap_fit/features/profile/data/support_inquiry_repository.dart';
import 'package:snap_fit/features/profile/presentation/views/admin_point_shop_management_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/my_page_screen.dart';
import 'package:snap_fit/features/profile/presentation/views/support_inquiry_screen.dart';

class _Binding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _Auth extends AuthViewModel {
  @override
  FutureOr<UserInfo?> build() => const UserInfo(
    id: 'support-audit-owner',
    name: '검토용 계정',
    provider: 'EMAIL',
    email: 'support-review@example.test',
  );
}

class _Support extends Fake implements SupportInquiryRepository {
  final requests = <Map<String, String>>[];

  @override
  Future<void> createInquiry({
    required String category,
    required String subject,
    required String message,
  }) async {
    requests.add({
      'category': category,
      'subject': subject,
      'message': message,
    });
  }
}

void _repaint(RenderObject object) {
  object.visitChildren(_repaint);
  if (object.attached) object.markNeedsPaint();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String file) async {
  for (final view in tester.binding.renderViews) {
    _repaint(view);
  }
  await tester.pump(const Duration(milliseconds: 32));
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = File(
        '${Platform.environment['NEXT_AUDIT_DIR']}/$file.png',
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  _Binding();
  testWidgets('capture current support entry submission and return', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 48);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetPadding);
    // testWidgets로 실행하는 검토용 테스트를 docs에 보존한 파일이다.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    for (final (family, assets) in [
      (
        'NotoSans',
        [
          'assets/fonts/NotoSansKR-Regular.ttf',
          'assets/fonts/NotoSansKR-SemiBold.ttf',
          'assets/fonts/NotoSansKR-Bold.ttf',
        ],
      ),
      ('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']),
    ]) {
      final loader = FontLoader(family);
      for (final asset in assets) {
        loader.addFont(rootBundle.load(asset));
      }
      await loader.load();
    }
    final key = GlobalKey();
    final support = _Support();
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authViewModelProvider.overrideWith(_Auth.new),
          pointShopAdminAccessProvider.overrideWithValue(false),
          adminHomeNewsAccessProvider.overrideWithValue(false),
          supportInquiryRepositoryProvider.overrideWithValue(support),
        ],
        child: ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: SnapFitTheme.light().copyWith(
              splashFactory: NoSplash.splashFactory,
            ),
            builder: (_, child) => RepaintBoundary(key: key, child: child!),
            home: const MyPageScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final entry = find.text('고객센터');
    await tester.ensureVisible(entry);
    await tester.pumpAndSettle();
    await _capture(tester, key, '01-settings-entry');
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(SupportInquiryScreen), findsOneWidget);
    await _capture(tester, key, '02-inquiry-form');
    await tester.enterText(
      find.byKey(const ValueKey('support-subject')),
      '사진을 프레임에 넣을 때 문의드려요',
    );
    await tester.enterText(
      find.byKey(const ValueKey('support-message')),
      '앨범을 편집하며 사진을 프레임에 넣었는데 적용되지 않아요. 어떤 부분을 확인하면 될까요?',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final submit = find.byKey(const ValueKey('support-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await _capture(tester, key, '03-inquiry-draft');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(support.requests.length, 1);
    expect(find.byType(SupportInquiryScreen), findsNothing);
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(find.text('문의가 접수되었습니다. 빠르게 답변드릴게요.'), findsOneWidget);
    await _capture(tester, key, '04-submitted-settings');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('고객센터'));
    await tester.tap(find.text('고객센터'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('support-subject')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('사진을 프레임에 넣을 때 문의드려요'), findsNothing);
    await _capture(tester, key, '05-return-empty-form');
    await tester.runAsync(() async {
      await File(
        '${Platform.environment['NEXT_AUDIT_DIR']}/observations.json',
      ).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'logicalSize': [390, 844],
          'pixelRatio': 2,
          'fakeSubmissionCount': support.requests.length,
          'returnedToSettingsAfterSubmit': true,
          'reentryShowsNewBlankForm': true,
          'contactedLiveServer': false,
        }),
      );
    });
  });
}
