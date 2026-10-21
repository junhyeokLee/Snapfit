import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../domain/ai_template_job.dart';

import '../domain/ai_album_draft_generation_service.dart';
import '../domain/ai_album_models.dart';
import '../domain/server_ai_album_draft_mapper.dart';

typedef SupabaseFunctionInvoker =
    Future<Object?> Function(String functionName, Map<String, Object?> body);

class SupabaseAiAlbumDraftProviderException
    implements Exception, AiAlbumDraftFailureCode {
  const SupabaseAiAlbumDraftProviderException(this.code, [this.message]);

  @override
  final String code;
  final String? message;

  @override
  String toString() {
    final detail = message?.trim();
    if (detail == null || detail.isEmpty) {
      return 'SupabaseAiAlbumDraftProviderException($code)';
    }
    return 'SupabaseAiAlbumDraftProviderException($code, $detail)';
  }
}

class SupabaseAiAlbumDraftProvider extends AiAlbumDraftProvider
    implements AiTemplateJobProvider {
  SupabaseAiAlbumDraftProvider({
    SupabaseClient? supabase,
    SupabaseFunctionInvoker? invokeFunction,
    ServerAiAlbumDraftMapper mapper = const ServerAiAlbumDraftMapper(),
    Future<void> Function(Duration)? wait,
    DateTime Function()? now,
  }) : _invokeFunction =
           invokeFunction ??
           _supabaseFunctionInvoker(_requireSupabase(supabase)),
       _mapper = mapper,
       _wait = wait,
       _now = now ?? DateTime.now;

  static const functionName = 'ai-album-draft';

  final SupabaseFunctionInvoker _invokeFunction;
  final ServerAiAlbumDraftMapper _mapper;
  final Future<void> Function(Duration)? _wait;
  final DateTime Function() _now;

  @override
  Future<AlbumRecommendationDraft> createTemplate(AiTemplateBrief brief) =>
      createTemplateJob(brief, requestId: const Uuid().v4());

  @override
  Future<AlbumRecommendationDraft> createTemplateJob(
    AiTemplateBrief brief, {
    required String requestId,
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    if (token?.canceled == true) {
      throw const SupabaseAiAlbumDraftProviderException(
        'ai_generation_observer_stopped',
      );
    }
    final envelope = await _request({
      'action': 'create',
      'generationRequestId': requestId,
      if (brief.expectedPointCost != null)
        'expectedPointCost': brief.expectedPointCost,
      'safeDesign': brief.toSafeDesignJson(),
    });
    return resumeTemplateJob(
      _matchingJob(envelope, requestId),
      token: token,
      onProgress: onProgress,
    );
  }

  @override
  Future<AiTemplateJob?> latestTemplateJob() async =>
      _job(await _request({'action': 'latest'}), allowEmpty: true);

  @override
  Future<AiTemplateJob> templateJobStatus(String requestId) async =>
      _matchingJob(
        await _request({'action': 'status', 'generationRequestId': requestId}),
        requestId,
      );

  @override
  Future<AiTemplateJob> cancelTemplateJob(String requestId) async =>
      _matchingJob(
        await _request({'action': 'cancel', 'generationRequestId': requestId}),
        requestId,
      );

  @override
  Future<AlbumRecommendationDraft> resumeTemplateJob(
    AiTemplateJob job, {
    AiTemplatePollingToken? token,
    void Function(AiTemplateJob)? onProgress,
  }) async {
    var current = job;
    final polling = token ?? AiTemplatePollingToken();
    while (!polling.canceled) {
      onProgress?.call(current);
      if (current.usable) return current.draft!;
      if (!current.pending) {
        throw SupabaseAiAlbumDraftProviderException(
          current.error ?? 'ai_generation_${current.state.name}',
        );
      }
      final duration = aiTemplateJobPollDelay(current, _now());
      if (_wait != null) {
        await _wait(duration);
      } else {
        await polling.wait(duration);
      }
      if (polling.canceled) break;
      final next = await templateJobStatus(current.id);
      if (next.id != job.id)
        throw const SupabaseAiAlbumDraftProviderException(
          'ai_generation_job_changed',
        );
      current = next;
    }
    throw const SupabaseAiAlbumDraftProviderException(
      'ai_generation_observer_stopped',
    );
  }

  Future<Map<String, Object?>> _request(Map<String, Object?> body) async {
    final json = _asStringObjectMap(await _invokeFunction(functionName, body));
    if (json['error'] != null) {
      final code = json['error'].toString();
      throw SupabaseAiAlbumDraftProviderException(
        RegExp(r'^[a-z0-9_]{1,100}$').hasMatch(code)
            ? code
            : 'ai_generation_unavailable',
      );
    }
    return json;
  }

  AiTemplateJob _matchingJob(Map<String, Object?> envelope, String requestId) {
    final job = _job(envelope)!;
    if (job.id != requestId) {
      throw const SupabaseAiAlbumDraftProviderException(
        'ai_generation_job_changed',
      );
    }
    return job;
  }

  AiTemplateJob? _job(
    Map<String, Object?> envelope, {
    bool allowEmpty = false,
  }) {
    final raw = envelope['job'];
    if (raw == null && allowEmpty) return null;
    if (raw is! Map)
      throw const SupabaseAiAlbumDraftProviderException('malformed_response');
    try {
      final id = raw['id'] as String;
      if (!RegExp(
        r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
      ).hasMatch(id)) {
        throw const FormatException('Invalid job identity');
      }
      final state = AiTemplateJobState.values.byName(raw['state'] as String);
      final brief = AiTemplateBrief.fromSafeDesign(raw['safeDesign'] as Map);
      final draft =
          (state == AiTemplateJobState.ready ||
                  (state == AiTemplateJobState.consumed &&
                      raw['alreadyAccepted'] == true)) &&
              envelope['draft'] is Map
          ? _mapper.map(
              theme: AlbumTheme.custom,
              candidates: const [],
              json: Map<String, Object?>.from(envelope['draft'] as Map),
            )
          : null;
      if ((state == AiTemplateJobState.ready && draft == null) ||
          (draft != null &&
              (draft.pageCount != brief.pageCount ||
                  draft.draftId.trim().isEmpty))) {
        throw const FormatException('Missing ready design');
      }
      return AiTemplateJob(
        id: id,
        state: state,
        stage: raw['stage'] as String? ?? '',
        completedStages: (raw['completedStages'] as num? ?? 0).toInt().clamp(
          0,
          100,
        ),
        brief: brief,
        nextAttemptAt: DateTime.tryParse(raw['nextAttemptAt'] as String? ?? ''),
        expiresAt: DateTime.tryParse(raw['expiresAt'] as String? ?? ''),
        error:
            raw['error'] is String &&
                RegExp(r'^[a-z0-9_]{1,100}$').hasMatch(raw['error'] as String)
            ? raw['error'] as String
            : null,
        draft: draft,
        alreadyAccepted: raw['alreadyAccepted'] == true,
        envelope: envelope,
      );
    } catch (_) {
      throw const SupabaseAiAlbumDraftProviderException('malformed_response');
    }
  }

  /// Personal photo metadata and previews never cross the AI boundary.
  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) => Future.error(
    const SupabaseAiAlbumDraftProviderException(
      'ai_generation_private_input_forbidden',
    ),
  );

  static SupabaseClient _requireSupabase(SupabaseClient? supabase) {
    if (supabase == null) {
      throw const SupabaseAiAlbumDraftProviderException(
        'supabase_client_required',
        'Supabase AI 앨범 초안 환경이 준비되지 않았습니다.',
      );
    }
    return supabase;
  }

  static SupabaseFunctionInvoker _supabaseFunctionInvoker(
    SupabaseClient supabase,
  ) {
    return (functionName, body) async {
      try {
        final response = await supabase.functions.invoke(
          functionName,
          body: body,
        );
        return response.data;
      } on FunctionException catch (error) {
        final details = error.details;
        if (details is Map && details['error'] is String) {
          final code = details['error'] as String;
          throw SupabaseAiAlbumDraftProviderException(
            RegExp(r'^[a-z0-9_]{1,100}$').hasMatch(code)
                ? code
                : 'ai_generation_unavailable',
          );
        }
        throw const SupabaseAiAlbumDraftProviderException(
          'ai_generation_unavailable',
        );
      }
    };
  }

  static Map<String, Object?> _asStringObjectMap(Object? value) {
    if (value is Map) return Map<String, Object?>.from(value);
    throw const SupabaseAiAlbumDraftProviderException(
      'malformed_response',
      'AI 앨범 초안 응답 형식이 올바르지 않습니다.',
    );
  }
}
