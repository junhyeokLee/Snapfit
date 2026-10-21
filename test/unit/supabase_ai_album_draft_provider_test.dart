import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_fit/features/album/ai_album/data/supabase_ai_album_draft_provider.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_album_models.dart';
import 'package:snap_fit/features/album/ai_album/domain/ai_template_job.dart';
import '../fixtures/ai_template_design_fixture.dart';

const _id = '01234567-89ab-4cde-8123-456789abcdef';
const _brief = AiTemplateBrief(
  prompt: '개인 이름과 주소 010-1234-5678',
  pageCount: 20,
);
final _now = DateTime.utc(2026, 10, 20);
Map<String, Object?> _envelope(
  String state, {
  DateTime? next,
  bool accepted = false,
  bool withDraft = false,
}) => {
  'job': {
    'id': _id,
    'state': state,
    'stage': 'composition',
    'completedStages': 2,
    'safeDesign': _brief.toSafeDesignJson(),
    'nextAttemptAt': next?.toIso8601String(),
    'expiresAt': _now.add(const Duration(days: 7)).toIso8601String(),
    if (accepted) 'alreadyAccepted': true,
  },
  if (withDraft)
    'draft': {
      'draftId': 'valid-server-draft',
      'title': '공용 사진집',
      'pageCount': 20,
      'recommendedPhotos': <Object?>[],
      'excludedPhotos': <Object?>[],
      'storySections': <Object?>[],
      'templateSlots': [
        for (var i = 0; i <= 20; i++)
          {'slotId': 'photo-$i', 'pageIndex': i, 'role': 'photo', 'hint': '사진'},
      ],
      'design': templateDesignJson(pageCount: 20),
    },
};
Matcher _code(String code) => throwsA(
  isA<SupabaseAiAlbumDraftProviderException>().having(
    (e) => e.code,
    'code',
    code,
  ),
);

void main() {
  test(
    'create sends finite choices and the confirmed price, never private copy or photo data',
    () async {
      final bodies = <Map<String, Object?>>[];
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (name, body) async {
          expect(name, 'ai-album-draft');
          bodies.add(body);
          return _envelope('ready', withDraft: true);
        },
      );
      final result = await provider.createTemplateJob(
        _brief.withExpectedPointCost(0),
        requestId: _id,
      );
      expect(result.draftId, 'valid-server-draft');
      expect(
        bodies.single.keys,
        unorderedEquals([
          'action',
          'generationRequestId',
          'expectedPointCost',
          'safeDesign',
        ]),
      );
      expect(bodies.single['expectedPointCost'], 0);
      expect(bodies.single['action'], 'create');
      expect(bodies.single['generationRequestId'], _id);
      expect(jsonEncode(bodies), isNot(contains('010-1234')));
      expect(jsonEncode(bodies), isNot(contains('prompt')));
      expect(
        (bodies.single['safeDesign'] as Map).keys,
        unorderedEquals([
          'version',
          'topic',
          'mood',
          'palette',
          'density',
          'pageCount',
          'aspect',
        ]),
      );
    },
  );

  test(
    'queued and running polling has a 15 second floor and a 60 second ceiling',
    () async {
      final waits = <Duration>[];
      final bodies = <Map<String, Object?>>[];
      final responses = [
        _envelope('queued', next: _now.add(const Duration(seconds: 2))),
        _envelope('running', next: _now.add(const Duration(hours: 2))),
        _envelope('ready', withDraft: true),
      ];
      final provider = SupabaseAiAlbumDraftProvider(
        now: () => _now,
        wait: (d) async {
          waits.add(d);
        },
        invokeFunction: (_, body) async {
          bodies.add(body);
          return responses.removeAt(0);
        },
      );
      final stages = <AiTemplateJobState>[];
      await provider.createTemplateJob(
        _brief,
        requestId: _id,
        onProgress: (job) => stages.add(job.state),
      );
      expect(waits, [const Duration(seconds: 15), const Duration(seconds: 60)]);
      expect(stages, [
        AiTemplateJobState.queued,
        AiTemplateJobState.running,
        AiTemplateJobState.ready,
      ]);
      expect(
        bodies.skip(1),
        everyElement(equals({'action': 'status', 'generationRequestId': _id})),
      );
    },
  );

  test(
    'waiting honors distant server retry without foreground minute polling',
    () async {
      final waits = <Duration>[];
      final responses = [
        _envelope('waiting', next: _now.add(const Duration(hours: 24))),
        _envelope('ready', withDraft: true),
      ];
      final provider = SupabaseAiAlbumDraftProvider(
        now: () => _now,
        wait: (d) async {
          waits.add(d);
        },
        invokeFunction: (_, __) async => responses.removeAt(0),
      );
      await provider.createTemplateJob(_brief, requestId: _id);
      expect(waits, [const Duration(hours: 1)]);
      final waiting = await SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async =>
            _envelope('waiting', next: _now.add(const Duration(minutes: 8))),
      ).templateJobStatus(_id);
      expect(aiTemplateJobPollDelay(waiting, _now), const Duration(minutes: 8));
    },
  );

  test('latest, status and cancel contain no generation inputs', () async {
    final bodies = <Map<String, Object?>>[];
    final provider = SupabaseAiAlbumDraftProvider(
      invokeFunction: (_, body) async {
        bodies.add(body);
        return body['action'] == 'latest'
            ? {'job': null}
            : _envelope(body['action'] == 'cancel' ? 'canceled' : 'waiting');
      },
    );
    expect(await provider.latestTemplateJob(), isNull);
    expect((await provider.templateJobStatus(_id)).pending, isTrue);
    expect(
      (await provider.cancelTemplateJob(_id)).state,
      AiTemplateJobState.canceled,
    );
    expect(bodies, [
      {'action': 'latest'},
      {'action': 'status', 'generationRequestId': _id},
      {'action': 'cancel', 'generationRequestId': _id},
    ]);
  });

  test(
    'consumed result is usable only when the server confirms acceptance and retains its draft',
    () async {
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async =>
            _envelope('consumed', accepted: true, withDraft: true),
      );
      final job = (await provider.latestTemplateJob())!;
      expect(job.usable, isTrue);
      expect(job.alreadyAccepted, isTrue);
      expect(
        (await provider.resumeTemplateJob(job)).draftId,
        'valid-server-draft',
      );
      for (final accepted in [false, true]) {
        final terminal = await SupabaseAiAlbumDraftProvider(
          invokeFunction: (_, __) async =>
              _envelope('consumed', accepted: accepted),
        ).latestTemplateJob();
        expect(terminal!.usable, isFalse);
        expect(terminal.pending, isFalse);
      }
    },
  );

  test(
    'expired, canceled and failed jobs never produce a usable design',
    () async {
      for (final state in ['expired', 'canceled', 'failed']) {
        final provider = SupabaseAiAlbumDraftProvider(
          invokeFunction: (_, __) async => _envelope(state),
        );
        final job = (await provider.latestTemplateJob())!;
        await expectLater(
          provider.resumeTemplateJob(job),
          _code('ai_generation_$state'),
        );
      }
    },
  );

  test('malformed ready and blank draft IDs are refused', () async {
    for (final response in [
      _envelope('ready'),
      _envelope('ready', withDraft: true)
        ..['draft'] = {
          ...(_envelope('ready', withDraft: true)['draft'] as Map),
          'draftId': '',
        },
    ]) {
      await expectLater(
        SupabaseAiAlbumDraftProvider(
          invokeFunction: (_, __) async => response,
        ).latestTemplateJob(),
        _code('malformed_response'),
      );
    }
  });

  test(
    'an envelope from another request cannot replace the observed result',
    () async {
      final envelope = _envelope('ready', withDraft: true);
      (envelope['job'] as Map)['id'] = 'abcdef01-2345-4abc-8123-456789abcdef';
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async => envelope,
      );
      await expectLater(
        provider.createTemplateJob(_brief, requestId: _id),
        _code('ai_generation_job_changed'),
      );
      await expectLater(
        provider.templateJobStatus(_id),
        _code('ai_generation_job_changed'),
      );
      await expectLater(
        provider.cancelTemplateJob(_id),
        _code('ai_generation_job_changed'),
      );
    },
  );

  test(
    'canceling an observer interrupts its wait and prevents another network request',
    () async {
      var calls = 0;
      final token = AiTemplatePollingToken();
      final ready = Completer<void>();
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async {
          calls++;
          return _envelope('waiting', next: _now.add(const Duration(days: 1)));
        },
      );
      final future = provider.createTemplateJob(
        _brief,
        requestId: _id,
        token: token,
        onProgress: (_) {
          ready.complete();
        },
      );
      final check = expectLater(
        future,
        _code('ai_generation_observer_stopped'),
      );
      await ready.future;
      token.cancel();
      await check;
      expect(calls, 1);
      await expectLater(
        provider.createTemplateJob(_brief, requestId: _id, token: token),
        _code('ai_generation_observer_stopped'),
      );
      expect(calls, 1);
    },
  );

  test(
    'legacy remote photo analysis is forbidden even with preview references',
    () async {
      var calls = 0;
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async {
          calls++;
          return {};
        },
      );
      await expectLater(
        provider.createDraft(
          theme: AlbumTheme.travel,
          range: AiPhotoRange.limitedLibrary,
          candidates: [
            PhotoCandidate(
              assetId: 'private-photo',
              createdAt: _now,
              width: 4000,
              height: 3000,
              orientation: PhotoOrientation.landscape,
              previewStorageUri: 'supabase://private/photo.jpg',
            ),
          ],
        ),
        _code('ai_generation_private_input_forbidden'),
      );
      expect(calls, 0);
    },
  );

  test(
    'raw server error messages are never exposed as application error codes',
    () async {
      final provider = SupabaseAiAlbumDraftProvider(
        invokeFunction: (_, __) async => {
          'error': 'Bearer private-token raw-input',
          'message': 'private profile',
        },
      );
      await expectLater(
        provider.latestTemplateJob(),
        _code('ai_generation_unavailable'),
      );
    },
  );
}
