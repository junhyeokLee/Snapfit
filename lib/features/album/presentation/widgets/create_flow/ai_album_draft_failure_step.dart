import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/experience_form_style.dart';

class AiAlbumDraftFailureStep extends StatelessWidget {
  const AiAlbumDraftFailureStep({
    super.key,
    this.title = 'AI 템플릿을 만들지 못했어요',
    required this.message,
    this.primaryActionLabel = '사진 범위 다시 고르기',
    required this.onRetryRange,
    required this.onManualStart,
    this.usesServerDraftProvider = false,
    this.isTemplateDesign = false,
    this.usesAdvancedServerAnalysis = false,
    this.pointUsageUnconfirmed = false,
    this.isBusy = false,
    this.showManualStart = true,
    this.requestSummary,
  });
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onRetryRange;
  final VoidCallback onManualStart;
  final bool usesServerDraftProvider;
  final bool isTemplateDesign;
  final bool usesAdvancedServerAnalysis;
  final bool pointUsageUnconfirmed;
  final bool isBusy;
  final bool showManualStart;
  final String? requestSummary;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: LayoutBuilder(
      builder: (context, bounds) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 672,
              minHeight: math.max(0, bounds.maxHeight - 48),
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 24,
                      color: ExperienceFormStyle.muted(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      title,
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: ExperienceFormStyle.text(
                      context,
                      14,
                      secondary: true,
                    ),
                  ),
                  if (requestSummary != null) ...[
                    const SizedBox(height: 16),
                    ExpansionTile(
                      key: const ValueKey('ai-failure-request-summary'),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('보낸 요청 확인'),
                      subtitle: const Text('요청 내용과 책 규격을 유지했어요.'),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            requestSummary!,
                            style: ExperienceFormStyle.text(context, 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    isTemplateDesign
                        ? '사진첩에 접근하거나 사진을 전송하지 않았어요. 요청 내용과 이용 조건을 다시 확인할 수 있어요.'
                        : usesAdvancedServerAnalysis
                        ? '선택한 미리보기 이미지를 서버에서 확인했을 수 있어요. 실패해도 앨범은 만들어지지 않아요.'
                        : usesServerDraftProvider
                        ? '선택한 사진 정보가 서버로 전송됐을 수 있어요. 실패해도 앨범은 만들어지지 않아요.'
                        : '기기 안에서만 확인해요. 사진은 업로드하지 않았어요.',
                    style: ExperienceFormStyle.text(
                      context,
                      12,
                      secondary: true,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        pointUsageUnconfirmed
                            ? Icons.info_outline
                            : Icons.check_circle_outline,
                        size: 18,
                        color: ExperienceFormStyle.selectionInk(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pointUsageUnconfirmed
                              ? '포인트 사용 처리 결과를 확인해야 해요.'
                              : '포인트는 차감되지 않았어요.',
                          key: const ValueKey('ai-failure-point-status'),
                          style: ExperienceFormStyle.text(
                            context,
                            13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const ValueKey('ai-failure-primary'),
                        onPressed: isBusy ? null : onRetryRange,
                        style: ExperienceFormStyle.primary(context),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(isBusy ? '처리 결과 확인 중' : primaryActionLabel),
                      ),
                      if (showManualStart)
                        TextButton(
                          onPressed: isBusy ? null : onManualStart,
                          style: TextButton.styleFrom(
                            foregroundColor: ExperienceFormStyle.ink(context),
                            minimumSize: const Size(0, 48),
                            textStyle: ExperienceFormStyle.text(
                              context,
                              14,
                              weight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('직접 구성하기'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
