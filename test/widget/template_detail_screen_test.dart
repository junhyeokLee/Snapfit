import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';

import '../helpers/mock_repositories.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: child),
  );
}

PremiumTemplate _template({
  int likeCount = 1,
  bool isLiked = false,
  int pageCount = 2,
  String title = 'Template A',
  String? subTitle,
  String? category,
  List<String>? tags,
}) {
  return PremiumTemplate(
    id: 1,
    title: title,
    subTitle: subTitle,
    coverImageUrl: 'https://example.com/cover.png',
    previewImages: const [],
    pageCount: pageCount,
    userCount: 1,
    category: category,
    tags: tags,
    isPremium: false,
    likeCount: likeCount,
    isLiked: isLiked,
    templateJson: '''
    {
      "pages": [
        { "layers": [ { "id": "c1", "type": "TEXT", "x": 0.1, "y": 0.1, "width": 0.5, "height": 0.2, "rotation": 0.0, "opacity": 1.0, "scale": 1.0, "payload": { "text": "hi" } } ] },
        { "layers": [ { "id": "p1", "type": "IMAGE", "x": 0.2, "y": 0.2, "width": 0.5, "height": 0.5, "rotation": 0.0, "opacity": 1.0, "scale": 1.0, "payload": { "imageUrl": "x" } } ] }
      ]
    }
    ''',
  );
}

void main() {
  testWidgets('template detail loads repository-backed template', (
    tester,
  ) async {
    final mockRepo = MockTemplateRepository();
    final template = _template();
    final likedTemplate = _template(likeCount: 2, isLiked: true);
    var getTemplateCallCount = 0;

    when(() => mockRepo.getTemplate(1)).thenAnswer((invocation) async {
      getTemplateCallCount++;
      return getTemplateCallCount >= 2 ? likedTemplate : template;
    });
    when(() => mockRepo.likeTemplate(1)).thenAnswer((_) async {});

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
          child: _wrap(TemplateDetailScreen(template: template)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TemplateDetailScreen), findsOneWidget);
    });
  });

  testWidgets('template detail renders use flow entry state', (tester) async {
    final mockRepo = MockTemplateRepository();
    final template = _template();

    stubGetTemplates(mockRepo, [template]);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
          child: _wrap(TemplateDetailScreen(template: template)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(TemplateDetailScreen), findsOneWidget);
    });
  });

  testWidgets('template detail exposes lookbook hero and practical reasons', (
    tester,
  ) async {
    final mockRepo = MockTemplateRepository();
    final template = _template(
      title: '제주의 기록',
      subTitle: '여행 사진을 한 권의 룩북처럼 정리해요.',
      pageCount: 24,
      category: '여행',
      tags: const ['여행', '제주', '감성', '프리미엄'],
    );

    stubGetTemplates(mockRepo, [template]);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
          child: _wrap(TemplateDetailScreen(template: template)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('룩북 미리보기'), findsOneWidget);
      expect(find.text('추천 사진'), findsOneWidget);
      expect(find.text('38~52장'), findsOneWidget);
      expect(find.text('이 템플릿이 좋은 이유'), findsOneWidget);
      expect(find.text('사진만 넣으면 바로 완성'), findsOneWidget);
      expect(find.text('이 템플릿으로 시작하기'), findsOneWidget);
      expect(find.text('여행'), findsWidgets);
      expect(find.text('제주'), findsOneWidget);
      expect(find.text('감성'), findsOneWidget);
      expect(find.text('프리미엄'), findsNothing);
    });
  });

  testWidgets(
    'template detail keeps hero title meta and CTA in first viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockTemplateRepository();
      final template = _template(
        title: '제주의 기록',
        subTitle: '여행 사진을 한 권의 룩북처럼 정리해요.',
        pageCount: 24,
        category: '여행',
        tags: const ['여행', '제주', '감성'],
      );
      stubGetTemplates(mockRepo, [template]);

      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
            child: _wrap(TemplateDetailScreen(template: template)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        final titleRect = tester.getRect(find.text('제주의 기록').first);
        final heroMetaRect = tester.getRect(find.text('24쪽 · 사진 38~52장 추천'));
        final ctaRect = tester.getRect(find.text('이 템플릿으로 시작하기'));

        expect(titleRect.top, lessThan(560));
        expect(heroMetaRect.bottom, lessThan(520));
        expect(ctaRect.bottom, lessThanOrEqualTo(844));
        expect(ctaRect.top, greaterThan(700));
      });
    },
  );
}
