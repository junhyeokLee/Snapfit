import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snap_fit/core/interceptors/token_storage.dart';
import 'package:snap_fit/features/album/ai_album/data/ai_template_device_store.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_draft_generation_service.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_job.dart';
import 'package:snap_fit/features/album/data/api/album_provider.dart';
import 'package:snap_fit/features/album/data/album_creation_catalog_provider.dart';
import 'package:snap_fit/features/album/presentation/views/album_create_flow_screen.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_brief_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_design_review.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/ai_template_generating_step.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/album_create_step1.dart';
import 'package:snap_fit/features/album/presentation/widgets/create_flow/template_photo_fill_step.dart';
import 'package:snap_fit/features/auth/data/dto/auth_response.dart';
import 'package:snap_fit/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:snap_fit/features/billing/data/billing_provider.dart';
import 'package:snap_fit/features/billing/data/billing_repository.dart';
import 'package:snap_fit/features/profile/domain/order_visibility_owner.dart';
import '../fixtures/ai_template_v3_fixture.dart';

const _requestId = '01234567-89ab-4cde-8123-456789abcdef';
const _brief = AiTemplateBrief(
  prompt: '',
  pageCount: 20,
  printProductId: 'REDP_200_SOFT',
  safeOptions: AiTemplateSafeOptions(
    topic: AiDesignTopic.family,
    mood: AiDesignMood.warm,
  ),
);
AiTemplateJob _job(AiTemplateJobState state, {bool accepted = false}) =>
    AiTemplateJob(
      id: _requestId,
      state: state,
      stage: 'composition',
      completedStages: 2,
      brief: _brief,
      alreadyAccepted: accepted,
      draft: state == AiTemplateJobState.ready || accepted
          ? originalTemplateDraft(
              _brief.publicBrief,
            ).copyWith(draftId: 'same-billing-draft')
          : null,
      envelope: const {},
      nextAttemptAt: DateTime.now().add(const Duration(hours: 8)),
    );

class _RecordingStore extends AiTemplateDeviceStore {
  final writes = <Map<String, Object?>>[];
  @override
  Future<void> save(String owner, Map<String, Object?> value) {
    writes.add(value);
    return super.save(owner, value);
  }
}

class _TokenStorage extends Mock implements TokenStorage {}

class _Auth extends AuthViewModel {
  @override
  UserInfo? build() =>
      const UserInfo(id: 'owner-A', name: 'Tester', provider: 'test');
  void switchTo(String id) {
    state = AsyncData(UserInfo(id: id, name: 'Other', provider: 'test'));
  }
}

class _Jobs extends AiAlbumDraftProvider implements AiTemplateJobProvider {
  _Jobs(this.current);
  AiTemplateJob current;
  int creates = 0, statuses = 0, resumes = 0, cancels = 0;
  final started = Completer<void>();
  Completer<AiTemplateJob>? statusResult;
  AiTemplatePollingToken? observedToken;
  @override
  Future<AiTemplateJob?> latestTemplateJob() async => current;
  @override
  Future<AiTemplateJob> templateJobStatus(String id) async {
    statuses++;
    return statusResult == null ? current : await statusResult!.future;
  }

  @override
  Future<AiTemplateJob> cancelTemplateJob(String id) async {
    cancels++;
    return _job(AiTemplateJobState.canceled);
  }

  @override
  Future<AlbumRecommendationDraft> createTemplateJob(
    AiTemplateBrief brief, {
    required String requestId,
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    creates++;
    throw StateError('Recovery must not create another request');
  }

  @override
  Future<AlbumRecommendationDraft> resumeTemplateJob(
    AiTemplateJob job, {
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    resumes++;
    observedToken = token;
    onProgress?.call(job);
    if (!started.isCompleted) started.complete();
    if (job.usable) return job.draft!;
    await token!.wait(const Duration(hours: 1));
    throw StateError('Observation stopped');
  }

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async => throw StateError('No private photos');
}

Widget _flow(
  _Jobs jobs,
  AiTemplateDeviceStore store, {
  _Auth? auth,
  List<String>? accepted,
}) => ProviderScope(
  overrides: [
    authViewModelProvider.overrideWith(() => auth ?? _Auth()),
    aiTemplateDeviceStoreProvider.overrideWithValue(store),
    myPointBalanceProvider.overrideWith((_) async => 2000),
    isFirstAiDraftFreeProvider.overrideWith((_) async => false),
    albumCreationCatalogProvider.overrideWith((_) => Stream.value(const [])),
    billingRepositoryProvider.overrideWithValue(
      BillingRepository(
        tokenStorage: _TokenStorage(),
        recordAiAlbumDraftSuccessRpc:
            ({required draftId, required pointCost}) async {
              accepted?.add(draftId);
              return {
                'used_free_credit': false,
                'charged_points': 0,
                'remaining_balance': 2000,
              };
            },
      ),
    ),
    aiAlbumDraftGenerationServiceProvider.overrideWithValue(
      AiAlbumDraftGenerationService(
        collectCandidates: (_) async => throw StateError('No photo access'),
        templateProvider: jobs,
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
Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('AI 템플릿'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'Eulyoo': 'Eulyoo1945-Regular.ttf',
      'NotoSans': 'NotoSansKR-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'reopening restores private memo, preferences and actual text edits without a new generation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = _RecordingStore();
      final jobs = _Jobs(_job(AiTemplateJobState.consumed, accepted: true));
      final accepted = <String>[];
      final text = jobs.current.draft!.design!.pages.first.elements.firstWhere(
        (e) => e.kind == 'text',
      );
      await store.save('owner-A', {
        'memo': '  기기에만 있는 개인 메모  ',
        'safeDesign': _brief.toSafeDesignJson(),
        'requestId': _requestId,
        'edits': {
          'paperTone': 'original',
          'texts': [
            {'page': 0, 'id': text.id, 'text': '함께'},
          ],
        },
      });
      await tester.pumpWidget(_flow(jobs, store, accepted: accepted));
      await _open(tester);
      final brief = tester
          .widget<AiTemplateBriefStep>(find.byType(AiTemplateBriefStep))
          .initialBrief!;
      expect(brief.prompt, '  기기에만 있는 개인 메모  ');
      expect(brief.safeOptions.topic, AiDesignTopic.family);
      expect(brief.pageCount, 20);
      await tester.tap(find.text('이어서 편집'));
      await tester.pumpAndSettle();
      expect(jobs.statuses, 1);
      expect(jobs.creates, 0);
      for (final checkpoint in store.writes.where(
        (value) => value['requestId'] == _requestId,
      )) {
        expect((checkpoint['edits'] as Map)['texts'], isNotEmpty);
      }
      final review = tester.widget<AiTemplateDesignReview>(
        find.byType(AiTemplateDesignReview),
      );
      expect(review.alreadyAccepted, isTrue);
      expect(
        review.design.pages.first.elements.any((e) => e.text == '함께'),
        isTrue,
      );
      expect(find.textContaining('추가 차감 없이'), findsOneWidget);
      await tester.tap(find.text('이어서 편집'));
      await tester.pumpAndSettle();
      expect(accepted, ['same-billing-draft']);
      expect(find.byType(AlbumCreateStep1), findsOneWidget);
      await tester.tap(find.text('사진 채우기'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TemplatePhotoFillStep>(find.byType(TemplatePhotoFillStep))
            .pages
            .first
            .any((e) => e.text == '함께'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'server waiting can pause and dispose without a duplicate request or a live observer',
    (tester) async {
      final jobs = _Jobs(_job(AiTemplateJobState.waiting));
      final store = AiTemplateDeviceStore();
      await tester.pumpWidget(_flow(jobs, store));
      await _open(tester);
      await tester.tap(find.text('이어서 확인'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AiTemplateGeneratingStep), findsOneWidget);
      expect(find.text('다음 작업 시간을 기다리고 있어요'), findsOneWidget);
      final pause = find.byKey(const ValueKey('ai-generation-pause'));
      await tester.ensureVisible(pause);
      await tester.tap(pause);
      await tester.pumpAndSettle();
      expect(jobs.observedToken!.canceled, isTrue);
      expect(jobs.creates, 0);
      expect(find.byType(AiTemplateBriefStep), findsOneWidget);
      await tester.tap(find.text('이어서 확인'));
      await tester.pump(const Duration(milliseconds: 300));
      final token = jobs.observedToken!;
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(token.canceled, isTrue);
      expect(jobs.creates, 0);
    },
  );
  testWidgets(
    'returning to the app resumes the same job after background observation stops',
    (tester) async {
      final jobs = _Jobs(_job(AiTemplateJobState.waiting));
      await tester.pumpWidget(_flow(jobs, AiTemplateDeviceStore()));
      await _open(tester);
      await tester.tap(find.text('이어서 확인'));
      await tester.pump(const Duration(milliseconds: 300));
      final previous = jobs.observedToken!;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(previous.canceled, isTrue);
      jobs.current = _job(AiTemplateJobState.ready);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(AiTemplateDesignReview), findsOneWidget);
      expect(jobs.resumes, 2);
      expect(jobs.creates, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'fresh server state prevents a stale ready result from being reopened',
    (tester) async {
      final jobs = _Jobs(_job(AiTemplateJobState.ready));
      await tester.pumpWidget(_flow(jobs, AiTemplateDeviceStore()));
      await _open(tester);
      jobs.current = _job(AiTemplateJobState.expired);
      await tester.tap(find.text('이어서 확인'));
      await tester.pumpAndSettle();
      expect(jobs.statuses, 1);
      expect(jobs.resumes, 0);
      expect(find.byType(AiTemplateDesignReview), findsNothing);
      expect(find.textContaining('보관 기간이 끝났거나'), findsOneWidget);
      expect(jobs.creates, 0);
    },
  );
  testWidgets(
    'late ready recovery from the previous account never exposes its artwork',
    (tester) async {
      final auth = _Auth();
      final jobs = _Jobs(_job(AiTemplateJobState.ready));
      jobs.statusResult = Completer<AiTemplateJob>();
      await tester.pumpWidget(_flow(jobs, AiTemplateDeviceStore(), auth: auth));
      await _open(tester);
      await tester.tap(find.text('이어서 확인'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AlbumCreateFlowScreen)),
      );
      container.read(orderSessionOwnerProvider.notifier).observe('owner-B');
      auth.switchTo('owner-B');
      await tester.pumpAndSettle();
      jobs.statusResult!.complete(_job(AiTemplateJobState.ready));
      await tester.pumpAndSettle();
      expect(find.byType(AiTemplateDesignReview), findsNothing);
      expect(jobs.resumes, 0);
      expect(jobs.creates, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
