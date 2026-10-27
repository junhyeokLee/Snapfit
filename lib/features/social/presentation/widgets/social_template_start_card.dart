import 'package:flutter/material.dart';
import '../../../../core/constants/snapfit_colors.dart';

import '../../domain/social_models.dart';
import 'social_widgets.dart';

class SocialTemplateStartCard extends StatelessWidget {
  const SocialTemplateStartCard({
    super.key,
    required this.source,
    required this.onPressed,
    this.busy = false,
  });

  final SocialTemplateSource source;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('social-template-start-card'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: SocialStyle.paper(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: SocialStyle.line(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '마음에 드는 분위기를 내 기록으로',
          style: TextStyle(
            color: SocialStyle.accent(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '이 템플릿으로 내 앨범 만들기',
          style: TextStyle(
            fontSize: 20,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(source.title, style: const TextStyle(fontSize: 15, height: 1.6)),
        const SizedBox(height: 8),
        Text(
          '작가가 사용한 공식 디자인에 내 사진과 이야기를 담아요. 템플릿 상세에서 구성과 이용 포인트를 확인할 수 있어요.',
          style: TextStyle(
            color: SnapFitColors.textSecondaryOf(context),
            height: 1.7,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('social-template-start-button'),
          onPressed: busy ? null : onPressed,
          style: SocialStyle.primary(context),
          icon: busy
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_stories_outlined, size: 18),
          label: Text(busy ? '템플릿 확인 중…' : '템플릿 보고 시작하기'),
        ),
      ],
    ),
  );
}
