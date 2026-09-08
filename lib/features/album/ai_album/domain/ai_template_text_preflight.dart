import 'package:flutter/material.dart';
import 'ai_template_design.dart';

class AiTemplateTextIssue {
  const AiTemplateTextIssue({
    required this.pageIndex,
    required this.elementId,
    required this.availableWidth,
    required this.availableHeight,
    required this.requiredWidth,
    required this.requiredHeight,
    required this.lineCount,
  });
  final int pageIndex;
  final String elementId;
  final double availableWidth, availableHeight, requiredWidth, requiredHeight;
  final int lineCount;

  Map<String, Object> toJson() => {
    'pageIndex': pageIndex,
    'elementId': elementId,
    'availableWidth': availableWidth,
    'availableHeight': availableHeight,
    'requiredWidth': requiredWidth,
    'requiredHeight': requiredHeight,
    'lineCount': lineCount,
  };
}

/// Uses the same font metrics for app acceptance and local evaluation reports.
List<AiTemplateTextIssue> inspectAiTemplateText(AiTemplateDesign design) {
  final issues = <AiTemplateTextIssue>[];
  if (design.artDirection == null) return issues;
  for (final (pageIndex, page) in design.pages.indexed) {
    for (final e in page.elements.where((e) => e.kind == 'text')) {
      final style = TextStyle(
        fontFamily: e.fontFamily,
        fontSize: e.fontSize,
        fontWeight: FontWeight.values[e.weight ~/ 100 - 1],
        height: e.lineHeight,
        letterSpacing: 0,
      );
      final painter = TextPainter(
        text: TextSpan(text: e.text, style: style),
        textAlign: e.align,
        textDirection: TextDirection.ltr,
        strutStyle: StrutStyle.fromTextStyle(style, forceStrutHeight: true),
        textHeightBehavior: const TextHeightBehavior(
          applyHeightToFirstAscent: true,
          applyHeightToLastDescent: true,
        ),
      );
      try {
        final width = e.rect.width * design.canvasSize.width;
        final height = e.rect.height * design.canvasSize.height;
        painter.layout(maxWidth: width);
        final lines = painter.computeLineMetrics();
        final requiredWidth = lines.fold<double>(
          0,
          (max, line) => line.width > max ? line.width : max,
        );
        if (painter.height > height + .5 || requiredWidth > width + .5) {
          issues.add(
            AiTemplateTextIssue(
              pageIndex: pageIndex,
              elementId: e.id,
              availableWidth: width,
              availableHeight: height,
              requiredWidth: requiredWidth,
              requiredHeight: painter.height,
              lineCount: lines.length,
            ),
          );
        }
      } finally {
        painter.dispose();
      }
    }
  }
  return issues;
}

/// Actual-font validation before a v2 design can be accepted or charged.
/// It complements, not replaces, server geometry/contrast checks.
void validateAiTemplateText(AiTemplateDesign design) {
  final issues = inspectAiTemplateText(design);
  if (issues.isNotEmpty) {
    throw FormatException(
      'template_quality_failed: text overflow ${issues.first.elementId}',
    );
  }
}
