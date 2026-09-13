import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import '../fixtures/ai_template_design_fixture.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  testWidgets(
    'template flow sends only the brief and returns to it after failure',
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

      await tester.tap(find.text('AI 템플릿으로 시작'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      expect(find.textContaining('사진첩에 접근하거나 사진을 전송하지 않아요'), findsOneWidget);
      await tester.ensureVisible(find.text('템플릿 만들기'));
      await tester.tap(find.text('템플릿 만들기'));
      await tester.pumpAndSettle();

      expect(find.text('AI 템플릿을 만들지 못했어요'), findsOneWidget);
      expect(find.textContaining('사진첩에 접근하거나 사진을 전송하지 않았어요'), findsOneWidget);
      expect(find.text('포인트는 차감되지 않았어요.'), findsOneWidget);
      expect(find.textContaining('편집 시작'), findsNothing);
      await tester.ensureVisible(find.text('디자인 요청 다시 보기'));
      await tester.tap(find.text('디자인 요청 다시 보기'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '제주 바다 사진집'), findsOneWidget);
    },
  );

  testWidgets(
    'template flow does not ask for photo preview consent even in advanced mode',
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

      await tester.tap(find.text('AI 템플릿으로 시작'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      expect(find.textContaining('사진첩에 접근하거나 사진을 전송하지 않아요'), findsOneWidget);
      expect(find.textContaining('작은 미리보기 이미지를 서버에서 참고해'), findsNothing);
    },
  );

  testWidgets('AI template flow applies slot draft to real album setup step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tokenStorage = _MockTokenStorage();
    when(() => tokenStorage.getUserId()).thenAnswer((_) async => 'user-1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPointBalanceProvider.overrideWith((_) async => 1000),
          billingRepositoryProvider.overrideWithValue(
            BillingRepository(
              tokenStorage: tokenStorage,
              recordAiAlbumDraftSuccessRpc:
                  ({required draftId, required pointCost}) async {
                    expect(draftId, 'slot-draft-1');
                    return {
                      'used_free_credit': true,
                      'charged_points': 0,
                      'remaining_balance': 1000,
                    };
                  },
            ),
          ),
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
              draftProvider: const _SlotTemplateDraftProvider(),
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

    await tester.tap(find.text('AI 템플릿으로 시작'));
    await tester.pumpAndSettle();
    await _submitBrief(tester, productId: 'REDP_250X200_SOFT', hardcover: true);
    await tester.ensureVisible(find.text('템플릿 만들기'));
    await tester.tap(find.text('템플릿 만들기'));
    await tester.pumpAndSettle();

    expect(find.text('제주의 느린 오후'), findsWidgets);
    expect(find.text('추천 사진 0장'), findsNothing);
    expect(find.byKey(const Key('ai_design_page_0')), findsOneWidget);

    await tester.tap(find.text('이 디자인 사용'));
    await tester.pumpAndSettle();

    expect(find.text('제주의 느린 오후'), findsWidgets);
    expect(find.text('앨범 설정'), findsOneWidget);
    final setup = tester.widget<AlbumCreateStep1>(
      find.byType(AlbumCreateStep1),
    );
    expect(setup.selectedCover!.productId, 'REDP_250X200_HARD');
    expect(setup.selectedCover!.ratio, 1.25);
    expect(setup.selectedCover!.realSize, const Size(25, 20));
    await tester.tap(find.text('사진 채우기'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('fill-page-0')), findsOneWidget);
    expect(
      tester
          .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
          .cover
          .productId,
      'REDP_250X200_HARD',
    );
    expect(find.text('사진 추가'), findsOneWidget);
    expect(find.text('AI가 이렇게 골랐어요'), findsNothing);
  });
}

Future<void> _submitBrief(
  WidgetTester tester, {
  String? productId,
  bool hardcover = false,
}) async {
  await tester.enterText(
    find.byKey(const Key('ai_template_brief')),
    '제주 바다 사진집',
  );
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  if (hardcover) {
    final hard = find.byKey(const ValueKey('print-cover-hard'));
    await tester.ensureVisible(hard);
    await tester.tap(hard);
    await tester.pump();
  }
  if (productId != null) {
    final size = find.byKey(ValueKey('print-size-$productId'));
    await tester.ensureVisible(size);
    await tester.tap(size);
    await tester.pump();
  }
  await tester.ensureVisible(
    find.byKey(const Key('ai_template_brief_continue')),
  );
  await tester.tap(find.byKey(const Key('ai_template_brief_continue')));
  await tester.pumpAndSettle();
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

class _SlotTemplateDraftProvider extends AiAlbumDraftProvider {
  const _SlotTemplateDraftProvider();

  @override
  Future<AlbumRecommendationDraft> createTemplate(
    AiTemplateBrief brief,
  ) async => templateDesignDraft(brief: brief);

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async {
    return const AlbumRecommendationDraft(
      draftId: 'slot-draft-1',
      theme: AlbumTheme.travel,
      title: '제주의 느린 오후',
      pageCount: 6,
      templateTone: 'warm-film',
      recommendedPhotos: [],
      excludedPhotos: [],
      storySections: [
        StorySection(
          title: '여행의 시작',
          description: '첫 장에 넣을 장면을 직접 골라요.',
          photoAssetIds: [],
        ),
      ],
      summary: '사진은 직접 넣고, AI는 앨범 틀과 문구만 잡았어요.',
      templateSlots: [
        AiTemplateSlot(
          slotId: 'cover-main',
          pageIndex: 0,
          role: 'cover',
          hint: '대표 사진을 직접 넣어주세요',
        ),
        AiTemplateSlot(
          slotId: 'p1-landscape',
          pageIndex: 1,
          role: 'landscape',
          hint: '장소감이 보이는 사진을 넣어주세요',
        ),
      ],
      reviewCtaLabel: '이 템플릿으로 시작하기',
    );
  }
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
