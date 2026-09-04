import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_photo_range_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_recommendation_review_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_start_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_theme_step.dart';

Future<void> _setPhoneSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _loadGoldenFonts() async {
  final robotoLoader = FontLoader('Roboto')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Bold.ttf'));
  await robotoLoader.load();
}

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    builder: (_, __) => MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  setUp(() async {
    await _loadGoldenFonts();
  });

  testWidgets('AI start split flow golden', (tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      _wrap(AiAlbumStartStep(onAiStart: () {}, onManualStart: () {})),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AiAlbumStartStep),
      matchesGoldenFile('goldens/ai_album_start_split_390x844.png'),
    );
  });

  testWidgets('AI theme split flow golden', (tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      _wrap(AiAlbumThemeStep(onThemeSelected: (_) {}, onBack: () {})),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AiAlbumThemeStep),
      matchesGoldenFile('goldens/ai_album_theme_split_390x844.png'),
    );
  });

  testWidgets('AI photo range split flow golden', (tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      _wrap(
        AiAlbumPhotoRangeStep(
          theme: AlbumTheme.travel,
          onRangeSelected: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AiAlbumPhotoRangeStep),
      matchesGoldenFile('goldens/ai_album_range_split_390x844.png'),
    );
  });

  testWidgets('AI point split flow golden', (tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      _wrap(
        AiAlbumPointConfirmationStep(
          theme: AlbumTheme.travel,
          range: AiPhotoRange.recent30Days,
          pointCost: 300,
          balance: 1200,
          onConfirm: () {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AiAlbumPointConfirmationStep),
      matchesGoldenFile('goldens/ai_album_point_split_390x844.png'),
    );
  });

  testWidgets('AI review split flow golden', (tester) async {
    await _setPhoneSurface(tester);
    await tester.pumpWidget(
      _wrap(
        AiAlbumRecommendationReviewStep(
          draft: _draft(),
          onAcceptDraft: (_) {},
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AiAlbumRecommendationReviewStep),
      matchesGoldenFile('goldens/ai_album_review_split_390x844.png'),
    );
  });
}

AlbumRecommendationDraft _draft() {
  return AlbumRecommendationDraft(
    theme: AlbumTheme.travel,
    title: '제주 여름 기록',
    pageCount: 10,
    templateTone: '따뜻한 여행 기록',
    recommendedPhotos: [
      RecommendedPhoto(
        candidate: _candidate('a'),
        score: 0.9,
        reasons: const [
          AiCurationReason(
            type: AiCurationReasonType.highResolution,
            message: '크게 넣어도 선명한 사진이에요',
          ),
          AiCurationReason(
            type: AiCurationReasonType.timeClusterRepresentative,
            message: '비슷한 시간대 사진 중 대표로 골랐어요',
          ),
        ],
      ),
      RecommendedPhoto(
        candidate: _candidate('b'),
        score: 0.8,
        reasons: const [
          AiCurationReason(
            type: AiCurationReasonType.themeOrientation,
            message: '풍경과 장소감이 잘 살아나는 컷이에요',
          ),
        ],
      ),
    ],
    excludedPhotos: [
      ExcludedPhoto(
        candidate: _candidate('screenshot'),
        reasons: const [
          AiCurationReason(
            type: AiCurationReasonType.screenshotExcluded,
            message: '스크린샷이라 사진 앨범 초안에서는 잠시 빼뒀어요',
          ),
        ],
      ),
    ],
    storySections: const [
      StorySection(title: '첫날', description: '바다와 산책 장면', photoAssetIds: ['a']),
      StorySection(
        title: '둘째 날',
        description: '카페와 저녁 풍경',
        photoAssetIds: ['b'],
      ),
    ],
    summary: '기기 안에서만 사진 정보를 살펴봤어요. 대표 컷 중심으로 10쪽 초안을 만들었어요.',
  );
}

PhotoCandidate _candidate(String id) {
  return PhotoCandidate(
    assetId: id,
    createdAt: DateTime(2026, 8, 20),
    width: 4000,
    height: 3000,
    orientation: PhotoOrientation.landscape,
  );
}
