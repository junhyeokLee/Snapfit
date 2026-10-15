import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../../core/constants/snapfit_colors.dart';
import '../../../../../shared/widgets/experience_form_style.dart';
import '../../../../../shared/web/web_design.dart';

Future<bool> showAlbumCompletionConfirmation(BuildContext context) async {
  if (kIsWeb) {
    return await showWebAwareDialog<bool>(
      context: context,
      maxWidth: 520,
      maxHeight: 440,
      builder: (_) => const AlbumCompletionConfirmation(),
    ) ?? false;
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
  Widget build(BuildContext context) => kIsWeb ? SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.auto_stories_outlined,
          color: WebPalette.of(context).brandInk, size: 28),
        const SizedBox(height: 20),
        Text('책 주문을 준비할까요?', style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w700, color: WebPalette.of(context).ink,
        )),
        const SizedBox(height: 14),
        Text(
          '앨범 전체 구성과 제작 금액을 확인한 뒤 배송지를 입력합니다. '
          '이 단계에서는 주문이나 결제가 이루어지지 않으며, 앨범도 계속 수정할 수 있습니다.',
          style: TextStyle(color: WebPalette.of(context).muted, fontSize: 14, height: 1.7),
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
              child: const Text('주문 준비 계속'),
            ),
          ],
        ),
      ],
    ),
  ) : AlertDialog(
    constraints: const BoxConstraints(maxWidth: 520),
    scrollable: true,
    backgroundColor: SnapFitColors.surfaceOf(context),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    title: Row(
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: SnapFitColors.accent,
          size: 22,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '앨범 완성',
            style: ExperienceFormStyle.text(
              context,
              18,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
    content: Text(
      '완성한 앨범을 확인하고 책으로 주문할 준비를 할 수 있어요.\n앨범은 이후에도 계속 수정할 수 있습니다.',
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
        child: const Text('확정하기', style: TextStyle(fontSize: 14)),
      ),
    ],
  );
}
