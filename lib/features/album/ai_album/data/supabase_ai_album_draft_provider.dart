import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/ai_album_draft_generation_service.dart';
import '../domain/ai_album_models.dart';
import '../domain/server_ai_album_draft_mapper.dart';

typedef SupabaseFunctionInvoker =
    Future<Object?> Function(String functionName, Map<String, Object?> body);

class SupabaseAiAlbumDraftProviderException implements Exception {
  const SupabaseAiAlbumDraftProviderException(this.code, [this.message]);

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

class SupabaseAiAlbumDraftProvider extends AiAlbumDraftProvider {
  SupabaseAiAlbumDraftProvider({
    SupabaseClient? supabase,
    SupabaseFunctionInvoker? invokeFunction,
    ServerAiAlbumDraftMapper mapper = const ServerAiAlbumDraftMapper(),
  }) : _invokeFunction =
           invokeFunction ??
           _supabaseFunctionInvoker(_requireSupabase(supabase)),
       _mapper = mapper;

  static const functionName = 'ai-album-draft';

  final SupabaseFunctionInvoker _invokeFunction;
  final ServerAiAlbumDraftMapper _mapper;

  @override
  Future<AlbumRecommendationDraft> createDraft({
    required AlbumTheme theme,
    required AiPhotoRange range,
    required List<PhotoCandidate> candidates,
  }) async {
    final request = ServerAiAlbumDraftRequest(
      theme: theme,
      range: range,
      candidates: candidates,
    );
    final response = await _invokeFunction(functionName, request.toJson());
    final json = _asStringObjectMap(response);
    final error = json['error'];
    if (error != null) {
      throw SupabaseAiAlbumDraftProviderException(
        error.toString(),
        json['message']?.toString(),
      );
    }
    return _mapper.map(theme: theme, candidates: candidates, json: json);
  }

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
      final response = await supabase.functions.invoke(
        functionName,
        body: body,
      );
      return response.data;
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
