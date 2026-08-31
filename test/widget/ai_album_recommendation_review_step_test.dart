import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_recommendation_review_step.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows editable AI draft summary before album creation', (
    tester,
  ) async {
    var accepted = false;
    var back = false;
    final draft = AlbumRecommendationDraft(
      theme: AlbumTheme.travel,
      title: '여행의 장면들',
      pageCount: 10,
      templateTone: '날짜 흐름이 보이는 따뜻한 여행 기록 템플릿',
      recommendedPhotos: [
        RecommendedPhoto(
          candidate: PhotoCandidate(
            assetId: 'a',
            createdAt: DateTime(2026, 8, 20),
            width: 4000,
            height: 3000,
            orientation: PhotoOrientation.landscape,
          ),
          score: 0.9,
          reasons: const ['여행 앨범에 어울리는 장소감'],
        ),
      ],
      excludedPhotos: [
        PhotoCandidate(
          assetId: 'screenshot',
          createdAt: DateTime(2026, 8, 20),
          width: 1170,
          height: 2532,
          orientation: PhotoOrientation.portrait,
          isScreenshot: true,
        ),
      ],
      storySections: const [
        StorySection(
          title: '여행의 시작',
          description: '앨범의 첫 인상이 되는 대표 장면이에요.',
          photoAssetIds: ['a'],
        ),
      ],
      summary: '날짜별 흐름을 살려 대표 장면만 남겼어요.',
    );

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        AiAlbumRecommendationReviewStep(
          draft: draft,
          onAcceptDraft: () => accepted = true,
          onBack: () => back = true,
        ),
      ),
    );

    expect(find.text('이런 앨범 초안을 준비했어요'), findsNothing);
    expect(find.text('여행의 장면들'), findsOneWidget);
    expect(find.text('추천 사진 1장'), findsOneWidget);
    expect(find.text('잠시 빼둔 사진 1장'), findsOneWidget);
    expect(find.text('여행의 시작'), findsOneWidget);
    expect(find.text('편집 시작'), findsOneWidget);
    expect(find.textContaining('사진과 문구는'), findsNothing);

    await tester.tap(find.text('편집 시작'));
    await tester.pump();
    expect(accepted, isTrue);

    await tester.tap(find.text('이전'));
    await tester.pump();
    expect(back, isTrue);
  });
}
