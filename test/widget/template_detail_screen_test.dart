import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:snap_fit/features/store/data/api/template_provider.dart';
import 'package:snap_fit/features/store/domain/entities/premium_template.dart';
import 'package:snap_fit/features/store/presentation/views/template_assembly_screen.dart';
import 'package:snap_fit/features/store/presentation/views/template_detail_screen.dart';

import '../helpers/mock_repositories.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: child),
  );
}

PremiumTemplate _template({int likeCount = 1, bool isLiked = false}) {
  return PremiumTemplate(
    id: 1,
    title: 'Template A',
    coverImageUrl: 'https://example.com/cover.png',
    previewImages: const [],
    pageCount: 2,
    userCount: 1,
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
  testWidgets('like button toggles count and calls repository', (tester) async {
    final mockRepo = MockTemplateRepository();
    final template = _template();

    when(() => mockRepo.getTemplate(1)).thenAnswer((_) async => template);
    when(() => mockRepo.likeTemplate(1)).thenAnswer((_) async {});

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
          child: _wrap(TemplateDetailScreen(template: template)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();

      expect(find.text('2'), findsOneWidget);
      verify(() => mockRepo.likeTemplate(1)).called(1);
    });
  });

  testWidgets('use button navigates to TemplateAssemblyScreen', (tester) async {
    final mockRepo = MockTemplateRepository();
    final template = _template();

    when(() => mockRepo.getTemplate(1)).thenAnswer((_) async => template);

    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [templateRepositoryProvider.overrideWithValue(mockRepo)],
          child: _wrap(TemplateDetailScreen(template: template)),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('이 템플릿 사용하기'));
      await tester.pumpAndSettle();

      expect(find.byType(TemplateAssemblyScreen), findsOneWidget);
    });
  });
}
