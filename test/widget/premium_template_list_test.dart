import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/widgets/premium_template_list.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  testWidgets('shows loading indicator while templates load', (tester) async {
    final completer = Completer<List<PremiumTemplate>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async {
            return completer.future;
          }),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows error text when templates fail to load', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async {
            throw Exception('fail');
          }),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('템플릿을 불러올 수 없습니다.'), findsOneWidget);
  });

  testWidgets('renders nothing when templates are empty', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith(
            (ref) async => const <PremiumTemplate>[],
          ),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('showcase card connects to detail lookbook language', (
    tester,
  ) async {
    final templates = [
      const PremiumTemplate(
        id: 1,
        title: '제주의 기록',
        subTitle: '여행 사진을 한 권의 룩북처럼 정리해요.',
        coverImageUrl: 'https://example.com/cover.png',
        previewImages: [],
        pageCount: 24,
        userCount: 1,
        category: '여행',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async => templates),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('룩북 보기'), findsOneWidget);
    expect(find.text('24쪽'), findsOneWidget);
    expect(find.text('사진 38~52장'), findsOneWidget);
    expect(find.text('여행'), findsOneWidget);
  });

  testWidgets('showcase lookbook CTA and photo meta fit phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final templates = [
      const PremiumTemplate(
        id: 1,
        title: '제주의 기록',
        subTitle: '여행 사진을 한 권의 룩북처럼 정리해요.',
        coverImageUrl: 'https://example.com/cover.png',
        previewImages: [],
        pageCount: 24,
        userCount: 1,
        category: '여행',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          templateListProvider.overrideWith((ref) async => templates),
        ],
        child: _wrap(const PremiumTemplateList()),
      ),
    );

    await tester.pumpAndSettle();

    final ctaRect = tester.getRect(find.text('룩북 보기'));
    final photoMetaRect = tester.getRect(find.text('사진 38~52장'));

    expect(ctaRect.right, lessThanOrEqualTo(390));
    expect(photoMetaRect.right, lessThanOrEqualTo(390));
    expect(ctaRect.top, lessThan(360));
    expect(photoMetaRect.top, lessThan(360));
  });
}
