import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/web/web_design.dart';
import '../../../../../shared/widgets/experience_icon.dart';

Future<bool> showAlbumCompletionConfirmation(BuildContext context) async {
  if (kIsWeb) {
    return await showWebAwareDialog<bool>(
          context: context,
          maxWidth: 520,
          maxHeight: 440,
          builder: (_) => const AlbumCompletionConfirmation(),
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (_) => const AlbumCompletionConfirmation(),
      ) ??
      false;
}

class AlbumCompletionConfirmation extends StatelessWidget {
  const AlbumCompletionConfirmation({super.key});

  @override
  Widget build(BuildContext context) => kIsWeb
      ? SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExperienceIcon('BookOpen', color: WebPalette.of(context).brandInk,
                size: 28,
              ),
              const SizedBox(height: 20),
              Text(
                '책으로 만들까요?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: WebPalette.of(context).ink,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '책의 배치와 제작 금액을 확인합니다.\n'
                '아직 주문·결제 전이며 앨범은 계속 수정할 수 있습니다.',
                style: TextStyle(
                  color: WebPalette.of(context).muted,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 26),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('계속 확인하기'),
                  ),
                  FilledButton(
                    key: const ValueKey('album-completion-confirm'),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('배치·금액 확인'),
                  ),
                ],
              ),
            ],
          ),
        )
      : AlertDialog(
          constraints: const BoxConstraints(maxWidth: 520),
          scrollable: true,
          backgroundColor: SnapFitColors.surfaceOf(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const ExperienceIcon('BookOpen', color: SnapFitColors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '책으로 만들까요?',
                  style: ExperienceFormStyle.text(
                    context,
                    18,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            '책의 배치와 제작 금액을 확인해요.\n아직 주문·결제 전이며 앨범은 계속 수정할 수 있어요.',
            style: ExperienceFormStyle.text(
              context,
              14,
              secondary: true,
            ).copyWith(height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소', style: TextStyle(fontSize: 14)),
            ),
            TextButton(
              key: const ValueKey('album-completion-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('배치·금액 확인', style: TextStyle(fontSize: 14)),
            ),
          ],
        );
}
