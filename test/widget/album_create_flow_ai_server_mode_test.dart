import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_paper_tone.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import '../fixtures/ai_template_v3_fixture.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Eulyoo',
    )..addFont(rootBundle.load('assets/fonts/Eulyoo1945-Regular.ttf'))).load();
    await (FontLoader(
      'NotoSans',
    )..addFont(rootBundle.load('assets/fonts/NotoSansKR-Regular.ttf'))).load();
  });

  testWidgets(
    'canceling request edits restores the same active draft and format',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final charged = <String>[];
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charged.add(draftId);
          return _pointSuccess;
        }),
      );
      await _openGeneratedReview(tester);
      final original = tester
          .widget<AiTemplateDesignReview>(find.byType(AiTemplateDesignReview))
          .design;
      await tester.tap(find.byTooltip('디자인 요청 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ai_template_brief')),
        '다른 요청',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(provider.briefs, hasLength(1));
      await tester.tap(find.byKey(const ValueKey('ai-return-to-result')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AiTemplateDesignReview>(find.byType(AiTemplateDesignReview))
            .design,
        same(original),
      );
      expect(charged, isEmpty);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pumpAndSettle();
      expect(charged, ['retained-draft-1']);
      expect(provider.briefs, hasLength(1));
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new generation keeps an old result comparison only after success',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final charged = <String>[];
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charged.add(draftId);
          return _pointSuccess;
        }),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.byTooltip('디자인 요청 수정'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      expect(provider.briefs, hasLength(1));
      expect(find.text('새 생성을 시작하면 이전 결과는 비교용으로 남아요.'), findsOneWidget);
      await tester.ensureVisible(find.text('템플릿 만들기'));
      await tester.tap(find.text('템플릿 만들기'));
      await tester.pumpAndSettle();
      expect(provider.briefs, hasLength(2));
      await tester.tap(find.byKey(const ValueKey('ai-design-compare')));
      await tester.pumpAndSettle();
      expect(find.text('이전 결과 · 비교 전용'), findsOneWidget);
      expect(find.text('이 디자인 사용'), findsNothing);
      await tester.tap(find.text('현재 결과로 돌아가기'));
      await tester.pumpAndSettle();
      expect(charged, isEmpty);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pumpAndSettle();
      expect(charged, ['retained-draft-2']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed regeneration retains old artwork without offering its expired acceptance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _FailSecondTemplateProvider();
      var charges = 0;
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charges++;
          return _pointSuccess;
        }),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.byTooltip('디자인 요청 수정'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      await tester.ensureVisible(find.text('템플릿 만들기'));
      await tester.tap(find.text('템플릿 만들기'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-return-to-result')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('ai-open-previous-result')));
      await tester.pumpAndSettle();
      expect(find.text('이전 결과 · 비교 전용'), findsOneWidget);
      expect(find.text('이 디자인 사용'), findsNothing);
      expect(find.byTooltip('문구 수정'), findsNothing);
      expect(find.byTooltip('종이 톤 조절'), findsNothing);
      await tester.tap(find.text('비교 닫기'));
      await tester.pumpAndSettle();
      expect(find.text('AI 템플릿을 만들지 못했어요'), findsOneWidget);
      expect(charges, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'local paper and copy edits reach actual photo-fill layers and one original billing draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(
        immediate: true,
        paperBackgrounds: true,
      );
      final charged = <String>[];
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charged.add(draftId);
          return _pointSuccess;
        }),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.byTooltip('종이 톤 조절'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ai-paper-tone-warm')));
      await tester.pumpAndSettle();
      final design = tester
          .widget<AiTemplateDesignReview>(find.byType(AiTemplateDesignReview))
          .design;
      final expectedBackground = design.pages[1].background;
      expect(expectedBackground, isNot(const Color(0xFFF7FAF8)));
      await tester.tap(find.byTooltip('문구 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('ai-text-edit-input')),
        '함께',
      );
      await tester.tap(find.byKey(const ValueKey('ai-text-apply')));
      await tester.pumpAndSettle();
      expect(provider.briefs, hasLength(1));
      expect(charged, isEmpty);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pumpAndSettle();
      expect(charged, ['retained-draft-1']);
      await tester.tap(find.text('사진 채우기'));
      await tester.pumpAndSettle();
      final fill = tester.widget<TemplatePhotoFillStep>(
        find.byType(TemplatePhotoFillStep),
      );
      expect(fill.pages.first.any((layer) => layer.text == '함께'), isTrue);
      final hex =
          '#${expectedBackground.toARGB32().toRadixString(16).substring(2)}';
      expect(fill.pages[1].first.decorationFillColor, hex);
      expect(fill.cover.productId, provider.briefs.single.printProductId);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a late old point operation cannot replace a new account draft', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = _ControlledTemplateProvider(immediate: true);
    final auth = _FlowAuth();
    final operation = Completer<Map<String, dynamic>>();
    var calls = 0;
    var balanceReads = 0;
    await tester.pumpWidget(
      _controlledFlow(
        provider,
        ({required draftId, required pointCost}) {
          calls++;
          return operation.future;
        },
        auth: auth,
        onBalanceRead: () => balanceReads++,
      ),
    );
    await _openGeneratedReview(tester);
    await tester.tap(find.text('이 디자인 사용'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AlbumCreateFlowScreen)),
    );
    container.read(orderSessionOwnerProvider.notifier).observe('other-user');
    auth.switchAccount('other-user');
    await tester.pumpAndSettle();
    await tester.tap(find.text('처음으로'));
    await tester.pumpAndSettle();
    await _openGeneratedReview(tester);
    expect(provider.briefs, hasLength(2));
    final previousBalanceReads = balanceReads;
    operation.complete(_pointSuccess);
    await tester.pumpAndSettle();
    expect(find.text('이 디자인 사용'), findsOneWidget);
    expect(find.byType(AlbumCreateStep1), findsNothing);
    expect(balanceReads, previousBalanceReads);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account change discards a late generated design and its request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider();
      final auth = _FlowAuth();
      var charges = 0;
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charges++;
          return _pointSuccess;
        }, auth: auth),
      );
      await tester.tap(find.text('AI 템플릿'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      tester
          .widget<AiAlbumPointConfirmationStep>(
            find.byType(AiAlbumPointConfirmationStep),
          )
          .onConfirm();
      await tester.pump(const Duration(milliseconds: 250));
      auth.switchAccount('other-user');
      await tester.pumpAndSettle();
      expect(find.text('로그인 상태가 바뀌었어요.'), findsOneWidget);
      provider.pending.single.complete(
        originalTemplateDraft(
          provider.briefs.single,
        ).copyWith(draftId: 'old-owner-draft'),
      );
      await tester.pumpAndSettle();
      expect(find.text('제주의 느린 오후'), findsNothing);
      expect(find.text('제주 바다 사진집'), findsNothing);
      expect(
        find.byKey(const ValueKey('ai-failure-point-status')),
        findsNothing,
      );
      expect(find.text('이 디자인 사용'), findsNothing);
      expect(charges, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account change ignores late point success without showing old state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final auth = _FlowAuth();
      final operation = Completer<Map<String, dynamic>>();
      var calls = 0;
      var balanceReads = 0;
      await tester.pumpWidget(
        _controlledFlow(
          provider,
          ({required draftId, required pointCost}) {
            calls++;
            return operation.future;
          },
          auth: auth,
          onBalanceRead: () => balanceReads++,
        ),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pump();
      auth.switchAccount(null);
      await tester.pumpAndSettle();
      final previousBalanceReads = balanceReads;
      operation.complete(_pointSuccess);
      await tester.pumpAndSettle();
      expect(find.text('로그인 상태가 바뀌었어요.'), findsOneWidget);
      expect(find.byType(AlbumCreateStep1), findsNothing);
      expect(find.text('제주의 느린 오후'), findsNothing);
      expect(
        find.byKey(const ValueKey('ai-failure-point-status')),
        findsNothing,
      );
      expect(find.text('같은 디자인으로 다시 확인'), findsNothing);
      expect(balanceReads, previousBalanceReads);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SDK owner change blocks late point success before cached profile updates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final auth = _FlowAuth();
      final operation = Completer<Map<String, dynamic>>();
      var calls = 0;
      var balanceReads = 0;
      await tester.pumpWidget(
        _controlledFlow(
          provider,
          ({required draftId, required pointCost}) {
            calls++;
            return operation.future;
          },
          auth: auth,
          onBalanceRead: () => balanceReads++,
        ),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AlbumCreateFlowScreen)),
      );
      container.read(orderSessionOwnerProvider.notifier).observe('other-user');
      expect(container.read(authViewModelProvider).asData?.value?.id, 'user-1');
      expect(container.read(visibleOrderOwnerProvider), isNull);
      await tester.pumpAndSettle();
      final previousBalanceReads = balanceReads;
      operation.complete(_pointSuccess);
      await tester.pumpAndSettle();
      expect(find.text('로그인 상태가 바뀌었어요.'), findsOneWidget);
      expect(find.byType(AlbumCreateStep1), findsNothing);
      expect(find.text('제주의 느린 오후'), findsNothing);
      expect(
        find.byKey(const ValueKey('ai-failure-point-status')),
        findsNothing,
      );
      expect(find.text('같은 디자인으로 다시 확인'), findsNothing);
      expect(balanceReads, previousBalanceReads);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending generation cannot be resent and failure preserves the request',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider();
      var charges = 0;
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charges++;
          return _pointSuccess;
        }),
      );
      await tester.tap(find.text('AI 템플릿'));
      await tester.pumpAndSettle();
      await _submitBrief(
        tester,
        productId: 'REDP_250X200_SOFT',
        hardcover: true,
      );
      final confirmation = tester.widget<AiAlbumPointConfirmationStep>(
        find.byType(AiAlbumPointConfirmationStep),
      );
      confirmation.onConfirm();
      confirmation.onConfirm();
      await tester.pump(const Duration(milliseconds: 250));
      expect(provider.briefs, hasLength(1));
      expect(find.byType(AiTemplateGeneratingStep), findsOneWidget);
      await tester.tap(find.byTooltip('뒤로가기'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AiTemplateGeneratingStep), findsOneWidget);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('응답이 늦어지고 있어요'), findsOneWidget);
      expect(provider.briefs, hasLength(1));
      expect(charges, 0);

      provider.pending.single.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(find.text('보낸 요청 확인'), findsOneWidget);
      final retry = find.byKey(const ValueKey('ai-failure-primary'));
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      final restored = tester
          .widget<AiTemplateBriefStep>(find.byType(AiTemplateBriefStep))
          .initialBrief!;
      expect(restored.prompt, '제주 바다 사진집');
      expect(
        provider.briefs.single.prompt,
        restored.safeOptions.publicDescription,
      );
      expect(provider.briefs.single.prompt, isNot(contains(restored.prompt)));
      expect(
        provider.briefs.single.toSafeDesignJson(),
        restored.toSafeDesignJson(),
      );
      expect(restored.pageCount, provider.briefs.single.pageCount);
      expect(
        restored.coverSize.productId,
        provider.briefs.single.coverSize.productId,
      );
      await tester.ensureVisible(
        find.byKey(const Key('ai_template_brief_continue')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai_template_brief_continue')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ai_template_brief_continue')));
      await tester.pumpAndSettle();
      tester
          .widget<AiAlbumPointConfirmationStep>(
            find.byType(AiAlbumPointConfirmationStep),
          )
          .onConfirm();
      await tester.pump(const Duration(milliseconds: 250));
      expect(provider.briefs, hasLength(2));
      expect(provider.briefs.last.prompt, provider.briefs.first.prompt);
      expect(charges, 0);
      provider.pending.last.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'point timeout keeps one operation and consumes its late success',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final pointOperation = Completer<Map<String, dynamic>>();
      final pointDraftIds = <String>[];
      await tester.pumpWidget(
        _controlledFlow(provider, ({required draftId, required pointCost}) {
          pointDraftIds.add(draftId);
          return pointOperation.future;
        }),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('포인트 처리 결과를 확인하지 못했어요'), findsOneWidget);
      expect(find.text('포인트는 차감되지 않았어요.'), findsNothing);
      expect(find.textContaining('차감되지 않았어요'), findsNothing);
      expect(find.text('직접 구성하기'), findsNothing);
      expect(pointDraftIds, ['retained-draft-1']);
      expect(provider.briefs, hasLength(1));

      var primary = find.byKey(const ValueKey('ai-failure-primary'));
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pump();
      final confirming = tester.widget<FilledButton>(primary);
      expect(confirming.onPressed, isNull);
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(pointDraftIds, ['retained-draft-1']);
      pointOperation.complete(_pointSuccess);
      await tester.pump();
      primary = find.byKey(const ValueKey('ai-failure-primary'));
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      expect(pointDraftIds, ['retained-draft-1']);
      expect(provider.briefs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'point response failure retries the same draft without generation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(immediate: true);
      final pointDraftIds = <String>[];
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          pointDraftIds.add(draftId);
          if (pointDraftIds.length == 1) {
            throw const AiAlbumDraftPointUsageException(
              AiAlbumDraftPointUsageFailure.unavailable,
            );
          }
          return _pointSuccess;
        }),
      );
      await _openGeneratedReview(tester);
      await tester.tap(find.text('이 디자인 사용'));
      await tester.pumpAndSettle();
      expect(find.textContaining('차감되지 않았어요'), findsNothing);
      final primary = find.byKey(const ValueKey('ai-failure-primary'));
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      expect(pointDraftIds, ['retained-draft-1', 'retained-draft-1']);
      expect(provider.briefs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'template flow sends only the brief and returns to it after failure',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authViewModelProvider.overrideWith(_FlowAuth.new),
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

      await tester.tap(find.text('AI 템플릿'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      expect(find.textContaining('개인 메모와 사진은 보내지 않아요'), findsOneWidget);
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
            authViewModelProvider.overrideWith(_FlowAuth.new),
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

      await tester.tap(find.text('AI 템플릿'));
      await tester.pumpAndSettle();
      await _submitBrief(tester);
      expect(find.textContaining('개인 메모와 사진은 보내지 않아요'), findsOneWidget);
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
          authViewModelProvider.overrideWith(_FlowAuth.new),
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

    await tester.tap(find.text('AI 템플릿'));
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
    expect(setup.selectedPageCount, 20);
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
  Future<AlbumRecommendationDraft> createTemplate(AiTemplateBrief brief) async {
    final draft = originalTemplateDraft(
      brief,
    ).copyWith(draftId: 'slot-draft-1');
    return draft;
  }

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

const _pointSuccess = <String, dynamic>{
  'used_free_credit': false,
  'charged_points': 500,
  'remaining_balance': 1500,
};

Widget _controlledFlow(
  _ControlledTemplateProvider provider,
  RecordAiAlbumDraftSuccessRpc onRecord, {
  _FlowAuth? auth,
  VoidCallback? onBalanceRead,
}) => ProviderScope(
  overrides: [
    authViewModelProvider.overrideWith(() => auth ?? _FlowAuth()),
    myPointBalanceProvider.overrideWith((_) async {
      onBalanceRead?.call();
      return 2000;
    }),
    isFirstAiDraftFreeProvider.overrideWith((_) async => false),
    albumCreationCatalogProvider.overrideWith((_) => Stream.value(const [])),
    billingRepositoryProvider.overrideWithValue(
      BillingRepository(
        tokenStorage: _MockTokenStorage(),
        recordAiAlbumDraftSuccessRpc: onRecord,
      ),
    ),
    aiAlbumDraftGenerationServiceProvider.overrideWithValue(
      AiAlbumDraftGenerationService(
        collectCandidates: (_) async =>
            throw StateError('Template generation must not read photos'),
        templateProvider: provider,
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
);

Future<void> _openGeneratedReview(WidgetTester tester) async {
  await tester.tap(find.text('AI 템플릿'));
  await tester.pumpAndSettle();
  await _submitBrief(tester);
  await tester.ensureVisible(find.text('템플릿 만들기'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('템플릿 만들기'));
  await tester.pumpAndSettle();
  expect(find.text('이 디자인 사용'), findsOneWidget);
}

class _ControlledTemplateProvider extends AiAlbumDraftProvider {
  _ControlledTemplateProvider({
    this.immediate = false,
    this.paperBackgrounds = false,
  });
  final bool immediate;
  final bool paperBackgrounds;
  final briefs = <AiTemplateBrief>[];
  final pending = <Completer<AlbumRecommendationDraft>>[];

  @override
  Future<AlbumRecommendationDraft> createTemplate(AiTemplateBrief brief) {
    briefs.add(brief);
    if (immediate) {
      var draft = originalTemplateDraft(
        brief,
      ).copyWith(draftId: 'retained-draft-${briefs.length}');
      if (paperBackgrounds) {
        final design = draft.design!;
        draft = withAiTemplateDesign(
          draft,
          copyAiTemplateDesign(
            design,
            pages: [
              design.pages.first,
              for (final page in design.pages.skip(1))
                AiTemplateDesignPage(
                  background: const Color(0xFFF7FAF8),
                  purpose: page.purpose,
                  elements: page.elements,
                ),
            ],
          ),
        );
      }
      return Future.value(draft);
    }
    final operation = Completer<AlbumRecommendationDraft>();
    pending.add(operation);
    return operation.future;
  }

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async => throw StateError('Only the design brief should be sent');
}

class _FlowAuth extends AuthViewModel {
  @override
  UserInfo? build() =>
      const UserInfo(id: 'user-1', name: 'Tester', provider: 'test');

  void switchAccount(String? id) {
    state = AsyncData(
      id == null ? null : UserInfo(id: id, name: 'Other', provider: 'test'),
    );
  }
}

class _FailSecondTemplateProvider extends _ControlledTemplateProvider {
  _FailSecondTemplateProvider() : super(immediate: true);

  @override
  Future<AlbumRecommendationDraft> createTemplate(AiTemplateBrief brief) {
    if (briefs.isNotEmpty) {
      briefs.add(brief);
      return Future.error(StateError('fixture regeneration failure'));
    }
    return super.createTemplate(brief);
  }
}
