import 'package:flutter/material.dart';

import '../../../../shared/widgets/experience_form_style.dart';

/// A single dated page; the caller owns photo actions and durable draft state.
class MomentComposeNotebook extends StatelessWidget {
  const MomentComposeNotebook({
    super.key,
    required this.date,
    required this.dateConfirmed,
    required this.photoContent,
    required this.captionController,
    this.captionEnabled = true,
    this.captionReadOnly = false,
    required this.onCaptionChanged,
  });

  final DateTime date;
  final bool dateConfirmed;
  final Widget photoContent;
  final TextEditingController captionController;
  final bool captionEnabled;
  final bool captionReadOnly;
  final ValueChanged<String> onCaptionChanged;

  static const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  @override
  Widget build(BuildContext context) {
    final line = ExperienceFormStyle.line(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final memoStyle = ExperienceFormStyle.text(
      context,
      14,
    ).copyWith(height: 1.7);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.lerp(
          Theme.of(context).colorScheme.surface,
          ExperienceFormStyle.surface(context),
          .18,
        ),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dateHeader(context),
          const SizedBox(height: 22),
          photoContent,
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: line),
          ),
          Text(
            '한 줄 기록 (선택)',
            style: ExperienceFormStyle.text(
              context,
              15,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          CustomPaint(
            painter: _MemoRules(
              color: line,
              lineHeight: textScaler.scale(14) * 1.7,
              counterHeight: textScaler.scale(11) * 1.4 + 8,
            ),
            child: TextField(
              key: const ValueKey('moment-caption'),
              controller: captionController,
              enabled: captionEnabled,
              readOnly: captionReadOnly,
              onChanged: onCaptionChanged,
              maxLength: 200,
              minLines: 3,
              maxLines: 6,
              style: memoStyle,
              decoration: InputDecoration(
                hintText: '오늘 기억하고 싶은 장면은요?',
                hintStyle: memoStyle.copyWith(
                  color: ExperienceFormStyle.muted(context),
                ),
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                counterStyle: ExperienceFormStyle.text(
                  context,
                  11,
                  secondary: true,
                ).copyWith(height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '글은 기록과 피드에만 보여요. 앨범에는 자동으로 인쇄되지 않아요.',
            style: ExperienceFormStyle.text(
              context,
              11,
              secondary: true,
            ).copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _dateHeader(BuildContext context) {
    final weekday = _weekdays[date.weekday - 1];
    return Semantics(
      key: const ValueKey('moment-date'),
      readOnly: true,
      label: dateConfirmed
          ? '${date.year}년 ${date.month}월 ${date.day}일 $weekday, 한국 시간 기준. 날짜는 바꿀 수 없어요.'
          : '한국 시간 기준 오늘 날짜를 확인하고 있어요.',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            dateConfirmed ? date.day.toString().padLeft(2, '0') : '오늘',
            style: ExperienceFormStyle.text(
              context,
              34,
              weight: FontWeight.w600,
              color: ExperienceFormStyle.selectionInk(context),
            ).copyWith(height: 1.15, letterSpacing: -1),
          ),
          Container(
            width: 1,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: ExperienceFormStyle.line(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateConfirmed
                      ? '${date.year}년 ${date.month}월 · $weekday'
                      : '한국 시간 기준',
                  style: ExperienceFormStyle.text(
                    context,
                    13,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.5),
                ),
                const SizedBox(height: 3),
                Text(
                  dateConfirmed ? '한국 시간 기준' : '날짜를 확인하고 있어요',
                  style: ExperienceFormStyle.text(
                    context,
                    11,
                    secondary: true,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoRules extends CustomPainter {
  const _MemoRules({
    required this.color,
    required this.lineHeight,
    required this.counterHeight,
  });

  final Color color;
  final double lineHeight;
  final double counterHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = .75;
    // Match scaled text rows and leave the native character counter unruled.
    for (
      var y = 6 + lineHeight;
      y <= size.height - counterHeight;
      y += lineHeight
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), pen);
    }
  }

  @override
  bool shouldRepaint(_MemoRules oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.lineHeight != lineHeight ||
      oldDelegate.counterHeight != counterHeight;
}
