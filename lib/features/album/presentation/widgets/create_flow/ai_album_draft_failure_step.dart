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
  });
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback onRetryRange;
  final VoidCallback onManualStart;
  final bool usesServerDraftProvider;
  final bool isTemplateDesign;
  final bool usesAdvancedServerAnalysis;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 24,
                      color: ExperienceFormStyle.muted(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: ExperienceFormStyle.text(
                        context,
                        20,
                        weight: FontWeight.w600,
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
                    const SizedBox(height: 12),
                    Text(
                      isTemplateDesign
                          ? '디자인 요청만 전송했어요. 사진첩에 접근하거나 사진을 전송하지 않았어요.'
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
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 672),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: ExperienceFormStyle.selectionInk(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '포인트는 차감되지 않았어요.',
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
                        onPressed: onRetryRange,
                        style: ExperienceFormStyle.primary(context),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(primaryActionLabel),
                      ),
                      TextButton(
                        onPressed: onManualStart,
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
      ],
    ),
  );
}
