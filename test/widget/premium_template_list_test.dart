import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
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

// The store showcase card scales vertically with the phone canvas, so its CTA
// and key metadata should stay in the upper card area by ratio instead of by a
// fixed pixel value. The clamp keeps small phones from using an unrealistically
// tiny limit and large Galaxy Ultra/iPhone Max screens from accepting content
// that drifts too far down the card.
double _upperLookbookCardContentLimit(Size viewport) {
  return (viewport.height * 0.42).clamp(320, 430).toDouble();
}

Future<void> _loadGoldenFonts() async {
  final robotoLoader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await robotoLoader.load();
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

  testWidgets('store lookbook cards fit iPhone and Galaxy viewports', (
    tester,
  ) async {
    const viewports = [
      ('iPhone SE', Size(320, 568)),
      ('iPhone 13 mini', Size(375, 812)),
      ('iPhone 15', Size(393, 852)),
      ('iPhone 15 Pro Max', Size(430, 932)),
      ('Galaxy compact', Size(360, 780)),
      ('Galaxy standard', Size(412, 915)),
      ('Galaxy Ultra', Size(480, 1040)),
    ];

    final templates = [
      const PremiumTemplate(
        id: 1,
        title: '제주 가족 여행의 아주 길고 따뜻한 여름 기록 포토북 템플릿',
        subTitle: '부모님과 아이들의 긴 여행 사진을 감성적인 한 권의 룩북처럼 정리해요.',
        coverImageUrl: 'https://example.com/cover.png',
        previewImages: [],
        pageCount: 24,
        userCount: 1,
        category: '가족여행프리미엄에디토리얼',
      ),
    ];

    for (final viewport in viewports) {
      tester.view.physicalSize = viewport.$2;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            templateListProvider.overrideWith((ref) async => templates),
          ],
          child: _wrap(const PremiumTemplateList()),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: viewport.$1);

      final width = viewport.$2.width;
      final ctaRect = tester.getRect(find.text('룩북 보기'));
      final photoMetaRect = tester.getRect(find.text('사진 38~52장'));
      final pageMetaRect = tester.getRect(find.text('24쪽'));

      expect(ctaRect.left, greaterThanOrEqualTo(0), reason: viewport.$1);
      expect(ctaRect.right, lessThanOrEqualTo(width), reason: viewport.$1);
      expect(
        photoMetaRect.right,
        lessThanOrEqualTo(width),
        reason: viewport.$1,
      );
      expect(pageMetaRect.right, lessThanOrEqualTo(width), reason: viewport.$1);
      final upperCardLimit = _upperLookbookCardContentLimit(viewport.$2);
      expect(ctaRect.top, lessThan(upperCardLimit), reason: viewport.$1);
      expect(photoMetaRect.top, lessThan(upperCardLimit), reason: viewport.$1);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('store lookbook card golden captures CTA and meta placement', (
    tester,
  ) async {
    await _loadGoldenFonts();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final templates = [
      const PremiumTemplate(
        id: 1,
        title: '제주 가족 여행의 아주 길고 따뜻한 여름 기록 포토북 템플릿',
        subTitle: '부모님과 아이들의 긴 여행 사진을 감성적인 한 권의 룩북처럼 정리해요.',
        coverImageUrl: 'https://example.com/cover.png',
        previewImages: [],
        pageCount: 24,
        userCount: 1,
        category: '가족여행프리미엄에디토리얼',
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

    await expectLater(
      find.byType(PremiumTemplateList),
      matchesGoldenFile('goldens/store_lookbook_card_390x844.png'),
    );
  });
}
