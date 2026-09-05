import 'ai_album_draft_generation_service.dart';
import 'ai_album_models.dart';

typedef ServerAiAlbumDraftRequester =
    Future<Map<String, Object?>> Function(ServerAiAlbumDraftRequest request);

class ServerAiAlbumDraftRequest {
  const ServerAiAlbumDraftRequest({
    required this.theme,
    required this.range,
    required this.candidates,
  });

  final AlbumTheme theme;
  final AiPhotoRange range;
  final List<PhotoCandidate> candidates;

  Map<String, Object?> toJson() {
    return {
      'theme': theme.name,
      'range': range.name,
      'candidates': candidates.map(_candidateToJson).toList(growable: false),
    };
  }

  Map<String, Object?> _candidateToJson(PhotoCandidate candidate) {
    return {
      'assetId': candidate.assetId,
      'createdAt': candidate.createdAt.toIso8601String(),
      'width': candidate.width,
      'height': candidate.height,
      'orientation': candidate.orientation.name,
      'albumName': candidate.albumName,
      'isScreenshot': candidate.isScreenshot,
    };
  }
}

class ServerAiAlbumDraftProvider extends AiAlbumDraftProvider {
  const ServerAiAlbumDraftProvider({
    required ServerAiAlbumDraftRequester requestDraft,
    ServerAiAlbumDraftMapper mapper = const ServerAiAlbumDraftMapper(),
  }) : _requestDraft = requestDraft,
       _mapper = mapper;

  final ServerAiAlbumDraftRequester _requestDraft;
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
    final json = await _requestDraft(request);
    return _mapper.map(theme: theme, candidates: candidates, json: json);
  }
}

enum ServerAiAlbumDraftMappingFailure {
  malformedResponse,
  unknownAsset,
  invalidPageCount,
  emptyRecommendedPhotos,
  duplicateAsset,
  storySectionAssetNotRecommended,
}

class ServerAiAlbumDraftMappingException implements Exception {
  const ServerAiAlbumDraftMappingException(this.failure, [this.message]);

  final ServerAiAlbumDraftMappingFailure failure;
  final String? message;

  @override
  String toString() {
    final detail = message;
    if (detail == null || detail.isEmpty) {
      return 'ServerAiAlbumDraftMappingException($failure)';
    }
    return 'ServerAiAlbumDraftMappingException($failure, $detail)';
  }
}

class ServerAiAlbumDraftMapper {
  const ServerAiAlbumDraftMapper({this.maxPageCount = 50});

  final int maxPageCount;

  AlbumRecommendationDraft map({
    required AlbumTheme theme,
    required List<PhotoCandidate> candidates,
    required Map<String, Object?> json,
  }) {
    final candidateById = <String, PhotoCandidate>{
      for (final candidate in candidates) candidate.assetId: candidate,
    };
    final pageCount = _readInt(json['pageCount'], fallback: 10);
    if (pageCount < 1 || pageCount > maxPageCount) {
      throw ServerAiAlbumDraftMappingException(
        ServerAiAlbumDraftMappingFailure.invalidPageCount,
        'pageCount=$pageCount',
      );
    }

    final recommendedPhotos =
        _readObjectList(json['recommendedPhotos'], field: 'recommendedPhotos')
            .map((item) => _recommendedPhoto(item, candidateById))
            .toList(growable: false);
    _ensureUniqueAssets(recommendedPhotos.map((photo) => photo.assetId));
    if (recommendedPhotos.isEmpty) {
      throw const ServerAiAlbumDraftMappingException(
        ServerAiAlbumDraftMappingFailure.emptyRecommendedPhotos,
        'recommendedPhotos is empty',
      );
    }

    final excludedPhotos =
        _readObjectList(
              json['excludedPhotos'],
              field: 'excludedPhotos',
              required: false,
            )
            .map((item) => _excludedPhoto(item, candidateById))
            .toList(growable: false);

    return AlbumRecommendationDraft(
      draftId: _readString(json['draftId']),
      theme: theme,
      title: _readString(json['title'], fallback: _fallbackTitleFor(theme)),
      pageCount: pageCount,
      templateTone: _readString(
        json['templateTone'],
        fallback: 'server-curated',
      ),
      recommendedPhotos: recommendedPhotos,
      excludedPhotos: excludedPhotos,
      storySections: _storySections(
        json['storySections'],
        candidateById,
        recommendedPhotos.map((photo) => photo.assetId).toSet(),
      ),
      summary: _readString(json['summary'], fallback: '사진과 앨범 흐름을 먼저 정리했어요.'),
      curationNotes: _readStringList(json['curationNotes']),
      requiresUserReview: true,
      alreadyCreatedAlbum: false,
      reviewCtaLabel: _readString(
        json['reviewCtaLabel'],
        fallback: '이 구성으로 시작하기',
      ),
    );
  }

  RecommendedPhoto _recommendedPhoto(
    Map<String, Object?> json,
    Map<String, PhotoCandidate> candidateById,
  ) {
    final assetId = _requiredString(json['assetId'], field: 'assetId');
    final candidate = _candidateFor(assetId, candidateById);
    return RecommendedPhoto(
      candidate: candidate,
      score: _readDouble(json['score'], fallback: 0.75).clamp(0.0, 1.0),
      reasons: _reasons(json['reasons']),
    );
  }

  ExcludedPhoto _excludedPhoto(
    Map<String, Object?> json,
    Map<String, PhotoCandidate> candidateById,
  ) {
    final assetId = _requiredString(json['assetId'], field: 'assetId');
    final candidate = _candidateFor(assetId, candidateById);
    return ExcludedPhoto(
      candidate: candidate,
      reasons: _reasons(json['reasons']),
    );
  }

  List<StorySection> _storySections(
    Object? value,
    Map<String, PhotoCandidate> candidateById,
    Set<String> recommendedAssetIds,
  ) {
    return _readObjectList(value, field: 'storySections', required: false)
        .map((item) {
          final ids = _readStringList(item['photoAssetIds']);
          for (final assetId in ids) {
            _candidateFor(assetId, candidateById);
            if (!recommendedAssetIds.contains(assetId)) {
              throw ServerAiAlbumDraftMappingException(
                ServerAiAlbumDraftMappingFailure
                    .storySectionAssetNotRecommended,
                'story section assetId=$assetId',
              );
            }
          }
          return StorySection(
            title: _readString(item['title'], fallback: '앨범 흐름'),
            description: _readString(
              item['description'],
              fallback: '함께 어울리는 사진을 묶었어요',
            ),
            photoAssetIds: ids,
          );
        })
        .toList(growable: false);
  }

  void _ensureUniqueAssets(Iterable<String> assetIds) {
    final seen = <String>{};
    for (final assetId in assetIds) {
      if (!seen.add(assetId)) {
        throw ServerAiAlbumDraftMappingException(
          ServerAiAlbumDraftMappingFailure.duplicateAsset,
          'duplicate assetId=$assetId',
        );
      }
    }
  }

  PhotoCandidate _candidateFor(
    String assetId,
    Map<String, PhotoCandidate> candidateById,
  ) {
    final candidate = candidateById[assetId];
    if (candidate == null) {
      throw ServerAiAlbumDraftMappingException(
        ServerAiAlbumDraftMappingFailure.unknownAsset,
        'unknown assetId=$assetId',
      );
    }
    return candidate;
  }

  List<AiCurationReason> _reasons(Object? value) {
    final items = _readObjectList(value, field: 'reasons', required: false);
    if (items.isEmpty) {
      return const [
        AiCurationReason(
          type: AiCurationReasonType.themeOrientation,
          message: '앨범 흐름에 어울려 골랐어요',
        ),
      ];
    }
    return items
        .map((item) {
          return AiCurationReason(
            type: _reasonType(_readString(item['type'])),
            message: _readString(item['message'], fallback: '앨범 흐름에 어울려 골랐어요'),
          );
        })
        .toList(growable: false);
  }

  AiCurationReasonType _reasonType(String value) {
    for (final type in AiCurationReasonType.values) {
      if (type.name == value) return type;
    }
    return AiCurationReasonType.themeOrientation;
  }

  List<Map<String, Object?>> _readObjectList(
    Object? value, {
    required String field,
    bool required = true,
  }) {
    if (value == null && !required) return const [];
    if (value is! List) {
      throw ServerAiAlbumDraftMappingException(
        ServerAiAlbumDraftMappingFailure.malformedResponse,
        '$field must be a list',
      );
    }
    return value
        .map((item) {
          if (item is Map) return Map<String, Object?>.from(item);
          throw ServerAiAlbumDraftMappingException(
            ServerAiAlbumDraftMappingFailure.malformedResponse,
            '$field item must be an object',
          );
        })
        .toList(growable: false);
  }

  String _requiredString(Object? value, {required String field}) {
    final text = _readString(value);
    if (text.isEmpty) {
      throw ServerAiAlbumDraftMappingException(
        ServerAiAlbumDraftMappingFailure.malformedResponse,
        '$field must not be empty',
      );
    }
    return text;
  }

  String _readString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  List<String> _readStringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) {
          return text.isNotEmpty;
        })
        .toList(growable: false);
  }

  int _readInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readDouble(Object? value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  String _fallbackTitleFor(AlbumTheme theme) {
    return switch (theme) {
      AlbumTheme.couple => '함께한 장면들',
      AlbumTheme.travel => '여행의 장면들',
      AlbumTheme.family => '가족의 장면들',
      AlbumTheme.baby => '아이의 장면들',
      AlbumTheme.birthday => '생일의 장면들',
      AlbumTheme.friends => '친구들과의 장면들',
      AlbumTheme.daily => '일상의 장면들',
      AlbumTheme.custom => '소중한 장면들',
    };
  }
}
