import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:snap_fit/features/album/data/album_creation_draft_store.dart';
import 'package:snap_fit/features/album/domain/entities/layer.dart';
import 'package:snap_fit/features/album/presentation/providers/album_edit_session_provider.dart';
import 'package:snap_fit/features/album/presentation/views/page_editor_screen.dart';
import 'package:snap_fit/features/album/presentation/viewmodels/album_editor_view_model.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_album_point_confirmation_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/core/navigation/web_app_location.dart';
import '../fixtures/ai_template_v3_fixture.dart';
import '../helpers/creation_draft_fixtures.dart' show MemoryCreationDraftStore;
import '../helpers/unified_creation_fixtures.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';

class _MockTokenStorage extends Mock implements TokenStorage {}

// 웹 /create/ai 전용: 네이티브 AI 진입 미제공으로 각 테스트를 명시적으로 건너뛴다.
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
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · canceling request edits restores the same active draft and format',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · new generation keeps an old result comparison only after success',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · failed regeneration retains old artwork without offering its expired acceptance',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · local paper and copy edits reach the unified editor and one original billing draft',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = _ControlledTemplateProvider(
        immediate: true,
        paperBackgrounds: true,
      );
      final charged = <String>[];
      final albums = RecordingCreationAlbums(owner: 'user-1');
      final creationStore = MemoryCreationDraftStore();
      await tester.pumpWidget(
        _controlledFlow(provider, ({
          required draftId,
          required pointCost,
        }) async {
          charged.add(draftId);
          return _pointSuccess;
        }, albums: albums, creationStore: creationStore),
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
      final container = await _continueToEditor(tester);
      final vm = container.read(albumEditorViewModelProvider.notifier);
      expect(find.byType(PageEditorScreen), findsOneWidget);
      expect(find.byType(TemplatePhotoFillStep), findsNothing);
      expect(vm.pages.first.layers.any((layer) => layer.text == '함께'), isTrue);
      final hex =
          '#${expectedBackground.toARGB32().toRadixString(16).substring(2)}';
      expect(vm.pages[1].layers.first.decorationFillColor, hex);
      expect(vm.selectedCover.productId, provider.briefs.single.printProductId);
      expect(albums.creates, 1);
      expect(albums.requestedOwners, ['user-1']);
      expect(vm.editingAlbumId, albums.albumId);
      final linked = creationStore.draft!;
      final editor = tester.widget<PageEditorScreen>(
        find.byType(PageEditorScreen),
      );
      expect(linked.createdAlbumId, albums.albumId);
      expect(editor.creationDraftId, linked.id);
      expect(editor.creationDraftOwner, 'user-1');
      expect(linked.editorCheckpoint!.sourceOwnerId, 'user-1');
      expect(linked.editorCheckpoint!.pages, hasLength(vm.pages.length));
      expect(
        linked.editorCheckpoint!.pages.first.layers.any(
          (layer) => layer.text == '함께',
        ),
        isTrue,
      );
      expect(
        linked.editorCheckpoint!.pages[1].layers.first.decorationFillColor,
        hex,
      );
      expect(charged, ['retained-draft-1']);
      expect(provider.briefs, hasLength(1));
      expect(tester.takeException(), isNull);
    },
    skip: !kIsWeb,
  );

  testWidgets('웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · a late old point operation cannot replace a new account draft', (
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
    await _openGeneratedReview(tester, reopen: true);
    expect(provider.briefs, hasLength(2));
    final previousBalanceReads = balanceReads;
    operation.complete(_pointSuccess);
    await tester.pumpAndSettle();
    expect(find.text('이 디자인 사용'), findsOneWidget);
    expect(find.byType(AlbumCreateStep1), findsNothing);
    expect(balanceReads, previousBalanceReads);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · account change discards a late generated design and its request',
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
      await _openAiBrief(tester);
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · account change ignores late point success without showing old state',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · SDK owner change blocks late point success before cached profile updates',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · pending generation cannot be resent and failure preserves the request',
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
      await _openAiBrief(tester);
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · point timeout keeps one operation and consumes its late success',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · point response failure retries the same draft without generation',
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · template flow sends only the brief and returns to it after failure',
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
                  initialAiMode: true,
                ),
              ),
            ),
          ),
        ),
      );

      await _openAiBrief(tester);
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
    skip: !kIsWeb,
  );

  testWidgets(
    '웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · template flow does not ask for photo preview consent even in advanced mode',
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
                  initialAiMode: true,
                ),
              ),
            ),
          ),
        ),
      );

      await _openAiBrief(tester);
      await _submitBrief(tester);
      expect(find.textContaining('개인 메모와 사진은 보내지 않아요'), findsOneWidget);
      expect(find.textContaining('작은 미리보기 이미지를 서버에서 참고해'), findsNothing);
    },
    skip: !kIsWeb,
  );

  testWidgets('웹 /create/ai 전용 · 네이티브 AI 진입 미제공 · AI template flow applies slot draft to real album setup step', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tokenStorage = _MockTokenStorage();
    when(() => tokenStorage.getUserId()).thenAnswer((_) async => 'user-1');
    final albums = RecordingCreationAlbums(owner: 'user-1');
    final creationStore = MemoryCreationDraftStore();
    final billedDraftIds = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...unifiedCreationBackendOverrides(albums: albums),
          authViewModelProvider.overrideWith(_FlowAuth.new),
          albumEditorOwnerReaderProvider.overrideWith((ref) {
            var owner = ref.read(authViewModelProvider).asData?.value?.id;
            ref.listen(authViewModelProvider, (_, next) {
              owner = next.asData?.value?.id;
            });
            // dispose 중에도 Ref에 접근하지 않는 계정 상태 스냅샷을 읽는다.
            return () => owner;
          }),
          albumEditorOwnerChangesProvider.overrideWith(
            (ref) =>
                Stream.value(ref.watch(authViewModelProvider).asData?.value?.id),
          ),
          albumCreationDraftStoreProvider.overrideWithValue(creationStore),
          myPointBalanceProvider.overrideWith((_) async => 1000),
          billingRepositoryProvider.overrideWithValue(
            BillingRepository(
              tokenStorage: tokenStorage,
              recordAiAlbumDraftSuccessRpc:
                  ({required draftId, required pointCost}) async {
                    expect(draftId, 'slot-draft-1');
                    billedDraftIds.add(draftId);
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
              body: AlbumCreateFlowScreen(
                usesServerDraftProvider: true,
                initialAiMode: true,
              ),
            ),
          ),
        ),
      ),
    );

    await _openAiBrief(tester);
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
    final container = await _continueToEditor(tester);
    final vm = container.read(albumEditorViewModelProvider.notifier);
    expect(find.byType(PageEditorScreen), findsOneWidget);
    expect(find.byType(TemplatePhotoFillStep), findsNothing);
    expect(vm.currentPageIndex, 0);
    expect(vm.selectedCover.productId, 'REDP_250X200_HARD');
    expect(vm.selectedCover.ratio, 1.25);
    expect(vm.selectedCover.realSize, const Size(25, 20));
    expect(vm.innerPageCount, 20);
    expect(
      vm.pages.first.layers.any(
        (layer) => layer.type == LayerType.image && !layer.hasImageSource,
      ),
      isTrue,
    );
    final linked = creationStore.draft!;
    final editor = tester.widget<PageEditorScreen>(
      find.byType(PageEditorScreen),
    );
    expect(albums.creates, 1);
    expect(vm.editingAlbumId, albums.albumId);
    expect(linked.createdAlbumId, albums.albumId);
    expect(editor.creationDraftId, linked.id);
    expect(editor.creationDraftOwner, 'user-1');
    expect(linked.editorCheckpoint!.pages, hasLength(21));
    expect(linked.editorCheckpoint!.sourceOwnerId, 'user-1');
    expect(linked.cover.productId, 'REDP_250X200_HARD');
    expect(billedDraftIds, ['slot-draft-1']);
    expect(find.text('사진 추가'), findsWidgets);
    expect(find.text('AI가 이렇게 골랐어요'), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);
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
  MemoryCreationDraftStore? creationStore,
  RecordingCreationAlbums? albums,
}) => ProviderScope(
  overrides: [
    ...unifiedCreationBackendOverrides(
      albums: albums ?? RecordingCreationAlbums(owner: 'user-1'),
    ),
    authViewModelProvider.overrideWith(() => auth ?? _FlowAuth()),
    albumEditorOwnerReaderProvider.overrideWith((ref) {
      var owner = ref.read(authViewModelProvider).asData?.value?.id;
      ref.listen(authViewModelProvider, (_, next) {
        owner = next.asData?.value?.id;
      });
      // dispose 중에도 Ref에 접근하지 않는 계정 상태 스냅샷을 읽는다.
      return () => owner;
    }),
    albumEditorOwnerChangesProvider.overrideWith(
      (ref) => Stream.value(ref.watch(authViewModelProvider).asData?.value?.id),
    ),
    albumCreationDraftStoreProvider.overrideWithValue(
      creationStore ?? MemoryCreationDraftStore(),
    ),
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
        body: AlbumCreateFlowScreen(
          usesServerDraftProvider: true,
          initialAiMode: true,
        ),
      ),
    ),
  ),
);

Future<ProviderContainer> _continueToEditor(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(AlbumCreateStep1)),
  );
  final next = find.byKey(const ValueKey('creation-setup-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  // 서버 생성과 연결된 체크포인트 저장이 끝난 실제 편집기까지 기다린다.
  for (var frame = 0; frame < 160; frame++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 32));
    if (find.byType(PageEditorScreen).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return container;
    }
  }
  fail('Accepted AI design did not enter the unified editor.');
}

Future<void> _openAiBrief(
  WidgetTester tester, {
  bool reopen = false,
}) async {
  if (reopen) {
    // 계정 변경 뒤에는 실제 웹 /create/ai 경로로 새 요청 화면을 연다.
    final navigation = Navigator.of(
      tester.element(find.byType(AlbumCreateFlowScreen)),
    );
    unawaited(
      navigation.pushReplacement<void, void>(
        MaterialPageRoute<void>(
          settings: const WebAppRouteSettings(WebAppLocation.aiCreate),
          builder: (_) => const AlbumCreateFlowScreen(
            usesServerDraftProvider: true,
            initialAiMode: true,
          ),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  expect(find.byType(AiTemplateBriefStep), findsOneWidget);
}

Future<void> _openGeneratedReview(
  WidgetTester tester, {
  bool reopen = false,
}) async {
  await _openAiBrief(tester, reopen: reopen);
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
