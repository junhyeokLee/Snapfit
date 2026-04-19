import 'dart:convert';

class TemplateGenerationRequest {
  final String figmaJsonPath;
  final List<String> templateTypes;
  final int count;
  final int minPages;
  final int? seed;

  const TemplateGenerationRequest({
    required this.figmaJsonPath,
    required this.templateTypes,
    required this.count,
    required this.minPages,
    this.seed,
  });

  Map<String, dynamic> toJson() => {
    'figmaJsonPath': figmaJsonPath,
    'templateTypes': templateTypes,
    'count': count,
    'minPages': minPages,
    'seed': seed,
  };

  factory TemplateGenerationRequest.fromJson(Map<String, dynamic> json) {
    return TemplateGenerationRequest(
      figmaJsonPath: (json['figmaJsonPath'] ?? '').toString(),
      templateTypes: (json['templateTypes'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      count: (json['count'] as num?)?.toInt() ?? 5,
      minPages: (json['minPages'] as num?)?.toInt() ?? 16,
      seed: (json['seed'] as num?)?.toInt(),
    );
  }
}

class TemplateGenerationMetrics {
  final double diversityScore;
  final double overlapRate;
  final double renderFailureRate;

  const TemplateGenerationMetrics({
    required this.diversityScore,
    required this.overlapRate,
    required this.renderFailureRate,
  });

  Map<String, dynamic> toJson() => {
    'diversityScore': diversityScore,
    'overlapRate': overlapRate,
    'renderFailureRate': renderFailureRate,
  };

  factory TemplateGenerationMetrics.fromJson(Map<String, dynamic> json) {
    return TemplateGenerationMetrics(
      diversityScore: (json['diversityScore'] as num?)?.toDouble() ?? 0.0,
      overlapRate: (json['overlapRate'] as num?)?.toDouble() ?? 1.0,
      renderFailureRate: (json['renderFailureRate'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class GeneratedTemplateBundle {
  final String templateId;
  final String title;
  final String templateType;
  final String coverImageUrl;
  final List<String> previewImages;
  final int pageCount;
  final Map<String, dynamic> flutterTemplateJson;
  final TemplateGenerationMetrics metrics;

  const GeneratedTemplateBundle({
    required this.templateId,
    required this.title,
    required this.templateType,
    required this.coverImageUrl,
    required this.previewImages,
    required this.pageCount,
    required this.flutterTemplateJson,
    required this.metrics,
  });

  Map<String, dynamic> toJson() => {
    'templateId': templateId,
    'title': title,
    'templateType': templateType,
    'coverImageUrl': coverImageUrl,
    'previewImages': previewImages,
    'pageCount': pageCount,
    'metrics': metrics.toJson(),
    'flutterTemplateJson': flutterTemplateJson,
  };

  factory GeneratedTemplateBundle.fromJson(Map<String, dynamic> json) {
    return GeneratedTemplateBundle(
      templateId: (json['templateId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      templateType: (json['templateType'] ?? '').toString(),
      coverImageUrl: (json['coverImageUrl'] ?? '').toString(),
      previewImages: (json['previewImages'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
      flutterTemplateJson:
          (json['flutterTemplateJson'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      metrics: TemplateGenerationMetrics.fromJson(
        (json['metrics'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
