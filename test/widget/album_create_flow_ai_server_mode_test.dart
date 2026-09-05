import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';

void main() {
  testWidgets(
    'server AI flow shows server privacy copy before and after failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAlbumDraftGenerationServiceProvider.overrideWithValue(
              AiAlbumDraftGenerationService(
                collectCandidates: (_) async => [
                  _candidate(
                    'photo-1',
                    DateTime(2026, 8, 20),
                    PhotoOrientation.landscape,
                  ),
                  _candidate(
                    'photo-2',
                    DateTime(2026, 8, 21),
                    PhotoOrientation.portrait,
                  ),
                  _candidate(
                    'photo-3',
                    DateTime(2026, 8, 22),
                    PhotoOrientation.square,
                  ),
                ],
                draftProvider: const _FailingDraftProvider(),
                minimumPhotoCount: 3,
              ),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, __) => const MaterialApp(
              home: Scaffold(
                body: AlbumCreateFlowScreen(usesServerDraftProvider: true),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('AI 초안').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('여행'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('선택한 사진의 날짜·크기 같은 정보가 서버로 전송돼요'),
        findsOneWidget,
      );
      expect(find.textContaining('원본 사진은 서버로 보내지 않고'), findsNothing);

      await tester.tap(find.text('최근 30일'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('무료로 초안 만들기'), 120);
      await tester.tap(find.text('무료로 초안 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('초안을 만들지 못했어요'), findsOneWidget);
      expect(find.textContaining('선택한 사진 정보가 서버로 전송됐을 수 있어요'), findsOneWidget);
      expect(find.text('포인트는 차감되지 않았어요.'), findsOneWidget);
      expect(find.textContaining('편집 시작'), findsNothing);
    },
  );

  testWidgets(
    'advanced server AI flow shows preview consent before generation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiAlbumDraftGenerationServiceProvider.overrideWithValue(
              AiAlbumDraftGenerationService(
                collectCandidates: (_) async => [
                  _candidate(
                    'photo-1',
                    DateTime(2026, 8, 20),
                    PhotoOrientation.landscape,
                  ),
                  _candidate(
                    'photo-2',
                    DateTime(2026, 8, 21),
                    PhotoOrientation.portrait,
                  ),
                  _candidate(
                    'photo-3',
                    DateTime(2026, 8, 22),
                    PhotoOrientation.square,
                  ),
                ],
                draftProvider: const _FailingDraftProvider(),
                minimumPhotoCount: 3,
              ),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (_, __) => const MaterialApp(
              home: Scaffold(
                body: AlbumCreateFlowScreen(
                  usesServerDraftProvider: true,
                  usesAdvancedServerAnalysis: true,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('AI 초안').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('여행'));
      await tester.pumpAndSettle();

      expect(find.textContaining('작은 미리보기 이미지를 서버에서 살펴봐요'), findsOneWidget);

      await tester.tap(find.text('최근 30일'));
      await tester.pumpAndSettle();

      expect(find.text('고급 AI 확인'), findsOneWidget);
      expect(find.textContaining('작은 미리보기 이미지를 서버에서 살펴보고'), findsOneWidget);
      expect(find.textContaining('초안은 바로 확정되지 않아요'), findsOneWidget);
    },
  );
}

PhotoCandidate _candidate(
  String id,
  DateTime createdAt,
  PhotoOrientation orientation,
) {
  return PhotoCandidate(
    assetId: id,
    createdAt: createdAt,
    width: orientation == PhotoOrientation.portrait ? 3000 : 4000,
    height: orientation == PhotoOrientation.landscape ? 3000 : 4000,
    orientation: orientation,
  );
}

class _FailingDraftProvider extends AiAlbumDraftProvider {
  const _FailingDraftProvider();

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async {
    throw Exception('server unavailable');
  }
}
